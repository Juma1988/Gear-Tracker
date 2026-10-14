import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/service_item.dart';
import 'reminder_preferences.dart';
import 'reminder_schedule.dart';

enum ReminderPermissionState { granted, denied }

/// Coarse, user-safe outcomes for reminder synchronization. Platform/plugin
/// exceptions remain available only to callers of the throwing [sync] API.
enum ReminderFailureKind { permission, plugin }

sealed class ReminderResult {
  const ReminderResult();
}

final class ReminderSuccess extends ReminderResult {
  const ReminderSuccess();
}

final class ReminderFailure extends ReminderResult {
  const ReminderFailure(this.kind);

  final ReminderFailureKind kind;
}

/// Remembers which time zone pending reminders were computed in, so a device
/// time zone change can be detected and the alarms recomputed.
class ReminderTimeZoneStore {
  const ReminderTimeZoneStore();

  static const _key = 'reminder_schedule_timezone_v1';

  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  Future<void> write(String identifier) async =>
      (await SharedPreferences.getInstance()).setString(_key, identifier);
}

class ReminderTarget {
  const ReminderTarget({required this.vehicleId, required this.vehicleName, required this.service});

  final String vehicleId;
  final String vehicleName;
  final ServiceItem service;

  int get notificationId => reminderNotificationId(vehicleId, service.id);
  String get payload => jsonEncode({'vehicleId': vehicleId, 'serviceId': service.id});
}

/// Small seam around the platform plugin so reminder behavior can be tested
/// without invoking Android method channels.
abstract class ReminderNotificationPlugin {
  Future<void> initialize(void Function(String? payload) onResponse);
  Future<bool> requestPermission();
  Future<List<PendingNotificationRequest>> pendingNotificationRequests();
  Future<void> schedule({
    required int id,
    required DateTime scheduledDate,
    required String title,
    required String body,
    required String payload,
    required bool repeatWeekly,
  });
  Future<void> cancel(int id);
}

class _FlutterReminderNotificationPlugin implements ReminderNotificationPlugin {
  _FlutterReminderNotificationPlugin(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize(void Function(String? payload) onResponse) async {
    const settings = InitializationSettings(android: AndroidInitializationSettings('launch_logo'));
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) => onResponse(response.payload),
    );
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() =>
      _plugin.pendingNotificationRequests();

  @override
  Future<void> schedule({
    required int id,
    required DateTime scheduledDate,
    required String title,
    required String body,
    required String payload,
    required bool repeatWeekly,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        ReminderNotificationService.channelId,
        'Maintenance reminders',
        channelDescription: 'Reminders to review vehicle maintenance',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: payload,
      matchDateTimeComponents: repeatWeekly ? DateTimeComponents.dayOfWeekAndTime : null,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}

/// Stable, positive Android request code derived from the vehicle and service.
/// It avoids one global reminder silently replacing a different vehicle's due work.
int reminderNotificationId(String vehicleId, String serviceId) {
  var hash = 0x811c9dc5;
  for (final unit in '$vehicleId\u0000$serviceId'.codeUnits) {
    hash = (hash ^ unit) * 0x01000193;
    hash &= 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

class ReminderNotificationService {
  ReminderNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    this._onNotificationResponse,
    ReminderTimeZoneStore? timeZoneStore,
    ReminderNotificationPlugin? notificationPlugin,
    Future<String> Function()? timezoneIdentifier,
    bool? androidPlatform,
    Future<void> Function(Set<int> ids)? nativeCancel,
  })  : _plugin = notificationPlugin ?? _FlutterReminderNotificationPlugin(plugin ?? FlutterLocalNotificationsPlugin()),
        _timeZoneStore = timeZoneStore ?? const ReminderTimeZoneStore(),
        _timezoneIdentifier = timezoneIdentifier ?? (() async => (await FlutterTimezone.getLocalTimezone()).identifier),
        _androidPlatform = androidPlatform ?? defaultTargetPlatform == TargetPlatform.android,
        _nativeCancel = nativeCancel ?? ((ids) => _nativeChannel.invokeMethod<void>('cancelScheduledReminders', {'ids': ids.toList()}));

  static const _nativeChannel = MethodChannel('gear_tracker/reminders');
  static const channelId = 'maintenance_reminders';
  final ReminderNotificationPlugin _plugin;
  final void Function(String payload)? _onNotificationResponse;
  final ReminderTimeZoneStore _timeZoneStore;
  final Future<String> Function() _timezoneIdentifier;
  final bool _androidPlatform;
  final Future<void> Function(Set<int> ids) _nativeCancel;
  bool _initialized = false;
  Future<void>? _syncInFlight;
  ReminderPermissionState _permissionState = ReminderPermissionState.granted;

  ReminderPermissionState get permissionState => _permissionState;

  /// A reschedule is required when the caller asks for one, when the device
  /// time zone changed since the alarms were computed, or when the desired
  /// keyed reminders are not all pending yet.
  static bool needsReschedule({
    required bool forceReschedule,
    required bool timeZoneChanged,
    required Set<int> desiredIds,
    required Set<int> existingIds,
  }) =>
      forceReschedule ||
      timeZoneChanged ||
      !desiredIds.every(existingIds.contains);

  Future<void> _initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    final timezone = await _timezoneIdentifier();
    tz.setLocalLocation(tz.getLocation(timezone));
    await _plugin.initialize((payload) {
      if (payload != null && payload.isNotEmpty) _onNotificationResponse?.call(payload);
    });
    _initialized = true;
  }

  Future<ReminderPermissionState> requestPermission() async {
    if (!_androidPlatform) return _permissionState;
    await _initialize();
    final permitted = await _plugin.requestPermission();
    _permissionState = permitted ? ReminderPermissionState.granted : ReminderPermissionState.denied;
    return _permissionState;
  }

  Future<void> sync({
    required ReminderPreferences preferences,
    required List<ReminderTarget> targets,
    bool forceReschedule = false,
  }) async {
    while (_syncInFlight != null) {
      await _syncInFlight;
    }
    final operation = _syncInternal(
      preferences: preferences,
      targets: targets,
      forceReschedule: forceReschedule,
    );
    _syncInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_syncInFlight, operation)) _syncInFlight = null;
    }
  }

  /// Exception-free boundary for UI callers. Raw plugin and platform errors
  /// never cross this boundary.
  Future<ReminderResult> syncResult({
    required ReminderPreferences preferences,
    required List<ReminderTarget> targets,
    bool forceReschedule = false,
  }) async {
    try {
      await sync(
        preferences: preferences,
        targets: targets,
        forceReschedule: forceReschedule,
      );
      return permissionState == ReminderPermissionState.denied
          ? const ReminderFailure(ReminderFailureKind.permission)
          : const ReminderSuccess();
    } catch (_) {
      return const ReminderFailure(ReminderFailureKind.plugin);
    }
  }

  Future<void> _syncInternal({
    required ReminderPreferences preferences,
    required List<ReminderTarget> targets,
    required bool forceReschedule,
  }) async {
    if (!_androidPlatform) return;
    await _initialize();
    if (!preferences.enabled || targets.isEmpty) {
      await cancel();
      return;
    }
    if (await requestPermission() == ReminderPermissionState.denied) {
      await cancel();
      return;
    }
    final desiredIds = targets.map((target) => target.notificationId).toSet();
    final pending = await _plugin.pendingNotificationRequests();
    final existingIds = pending.map((request) => request.id).toSet();
    final currentTimeZone = tz.local.name;
    final scheduledTimeZone = await _timeZoneStore.read();
    final timeZoneChanged =
        scheduledTimeZone != null && scheduledTimeZone != currentTimeZone;
    if (!needsReschedule(
      forceReschedule: forceReschedule,
      timeZoneChanged: timeZoneChanged,
      desiredIds: desiredIds,
      existingIds: existingIds,
    )) {
      return;
    }
    await _cancelIds(existingIds);

    final next = ReminderScheduleCalculator.nextOccurrence(preferences, now: DateTime.now());
    for (final target in targets) {
      await _plugin.schedule(
        id: target.notificationId,
        scheduledDate: tz.TZDateTime.from(next, tz.local),
        title: '${target.vehicleName}: ${target.service.name}',
        body: 'Maintenance reminder for ${target.service.name}.',
        payload: target.payload,
        repeatWeekly: preferences.repeatUntilComplete,
      );
    }
    await _timeZoneStore.write(currentTimeZone);
  }

  Future<void> cancel() async {
    final ids = (await _plugin.pendingNotificationRequests()).map((request) => request.id).toSet();
    await _cancelIds(ids);
  }

  /// Device-backed inspection used by the W09 integration test.
  @visibleForTesting
  Future<List<PendingNotificationRequest>> pendingForTesting() async {
    await _initialize();
    return _plugin.pendingNotificationRequests();
  }

  Future<void> _cancelIds(Set<int> ids) async {
    for (final id in ids) {
      await _plugin.cancel(id);
    }
    if (_androidPlatform && ids.isNotEmpty) {
      await _nativeCancel(ids);
    }
  }

  static List<ReminderTarget> dueTargets({
    required String vehicleId,
    required String vehicleName,
    required List<ServiceItem> services,
    required int currentOdometer,
  }) => services
      .where((service) => service.statusAt(currentOdometer).index >= ServiceStatus.replaceSoon.index)
      .map((service) => ReminderTarget(vehicleId: vehicleId, vehicleName: vehicleName, service: service))
      .toList(growable: false);
}
