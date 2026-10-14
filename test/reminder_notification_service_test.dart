import 'dart:convert';

import 'package:app/models/service_item.dart';
import 'package:app/reminders/reminder_notification_service.dart';
import 'package:app/reminders/reminder_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() {
  const dueService = ServiceItem(
    id: 'oil',
    name: 'Engine oil',
    note: '',
    serviceOdometer: 0,
    intervalKm: 1000,
    iconKey: 'oil',
  );

  test('notification IDs are stable and unique per vehicle and service', () {
    final first = reminderNotificationId('vehicle-a', 'oil');
    expect(first, reminderNotificationId('vehicle-a', 'oil'));
    expect(first, isNot(reminderNotificationId('vehicle-b', 'oil')));
    expect(first, isNot(reminderNotificationId('vehicle-a', 'brakes')));
  });

  test('due targets identify vehicle and service and carry a safe deep-link payload', () {
    final targets = ReminderNotificationService.dueTargets(
      vehicleId: 'vehicle-a',
      vehicleName: '2026 Gear Coupe',
      services: const [dueService],
      currentOdometer: 1000,
    );

    expect(targets, hasLength(1));
    expect(targets.single.vehicleName, '2026 Gear Coupe');
    expect(targets.single.service.name, 'Engine oil');
    expect(jsonDecode(targets.single.payload), {
      'vehicleId': 'vehicle-a',
      'serviceId': 'oil',
    });
  });

  group('needsReschedule', () {
    test('is false when every desired reminder is already pending', () {
      expect(
        ReminderNotificationService.needsReschedule(
          forceReschedule: false,
          timeZoneChanged: false,
          desiredIds: {1, 2},
          existingIds: {1, 2, 3},
        ),
        isFalse,
      );
    });

    test('reschedules when a desired reminder is missing', () {
      expect(
        ReminderNotificationService.needsReschedule(
          forceReschedule: false,
          timeZoneChanged: false,
          desiredIds: {1, 2},
          existingIds: {1},
        ),
        isTrue,
      );
    });

    test('reschedules after a device time zone change', () {
      expect(
        ReminderNotificationService.needsReschedule(
          forceReschedule: false,
          timeZoneChanged: true,
          desiredIds: {1},
          existingIds: {1},
        ),
        isTrue,
      );
    });

    test('honours an explicit force reschedule', () {
      expect(
        ReminderNotificationService.needsReschedule(
          forceReschedule: true,
          timeZoneChanged: false,
          desiredIds: {1},
          existingIds: {1},
        ),
        isTrue,
      );
    });
  });

  test('fake plugin keeps same-service reminders distinct across vehicles', () async {
    final plugin = _FakeNotificationPlugin();
    final service = _service(plugin);

    await service.sync(
      preferences: const ReminderPreferences(enabled: true, repeatUntilComplete: true),
      targets: [
        _target('vehicle-a', 'Daily Driver', 'oil', 'Engine Oil'),
        _target('vehicle-b', 'Weekend Truck', 'oil', 'Engine Oil'),
      ],
      forceReschedule: true,
    );

    expect(plugin.scheduled, hasLength(2));
    expect(plugin.scheduled.map((item) => item.id), containsAll(<int>[
      reminderNotificationId('vehicle-a', 'oil'),
      reminderNotificationId('vehicle-b', 'oil'),
    ]));
    final dailyDriverReminder = plugin.scheduled.singleWhere(
      (item) => item.id == reminderNotificationId('vehicle-a', 'oil'),
    );
    expect(dailyDriverReminder.title, 'Daily Driver: Engine Oil');
    expect(dailyDriverReminder.body, 'Maintenance reminder for Engine Oil.');
    final weekendTruckReminder = plugin.scheduled.singleWhere(
      (item) => item.id == reminderNotificationId('vehicle-b', 'oil'),
    );
    expect(weekendTruckReminder.title, 'Weekend Truck: Engine Oil');
    expect(weekendTruckReminder.body, 'Maintenance reminder for Engine Oil.');
    expect(plugin.scheduled.map((item) => jsonDecode(item.payload)), containsAll(<Map<String, String>>[
      {'vehicleId': 'vehicle-a', 'serviceId': 'oil'},
      {'vehicleId': 'vehicle-b', 'serviceId': 'oil'},
    ]));
    expect(plugin.scheduled.every((item) => item.repeatWeekly), isTrue);

    await service.sync(
      preferences: const ReminderPreferences(enabled: true),
      targets: [_target('vehicle-a', 'Daily Driver', 'oil', 'Engine Oil')],
      forceReschedule: true,
    );
    expect(plugin.cancelled, containsAll(<int>[
      reminderNotificationId('vehicle-a', 'oil'),
      reminderNotificationId('vehicle-b', 'oil'),
    ]));
    expect(plugin.scheduled.last.repeatWeekly, isFalse);
  });

  test('permission denial cancels pending reminders and does not schedule', () async {
    final plugin = _FakeNotificationPlugin(permissionGranted: false);
    final service = _service(plugin);

    await service.sync(
      preferences: const ReminderPreferences(enabled: true),
      targets: [_target('vehicle-a', 'Daily Driver', 'oil', 'Engine Oil')],
      forceReschedule: true,
    );

    expect(service.permissionState, ReminderPermissionState.denied);
    expect(plugin.scheduled, isEmpty);
    expect(plugin.cancelled, isEmpty);
  });

  test('permission recovery schedules reminders after a later grant', () async {
    final plugin = _FakeNotificationPlugin(permissionGranted: false);
    final service = _service(plugin);

    await service.sync(
      preferences: const ReminderPreferences(enabled: true),
      targets: [_target('vehicle-a', 'Daily Driver', 'oil', 'Engine Oil')],
      forceReschedule: true,
    );
    expect(service.permissionState, ReminderPermissionState.denied);

    plugin.permissionGranted = true;
    await service.sync(
      preferences: const ReminderPreferences(enabled: true),
      targets: [_target('vehicle-a', 'Daily Driver', 'oil', 'Engine Oil')],
    );

    expect(service.permissionState, ReminderPermissionState.granted);
    expect(plugin.scheduled, hasLength(1));
  });

  test('time zone changes reschedule persisted keyed reminders', () async {
    final plugin = _FakeNotificationPlugin();
    final store = _FakeTimeZoneStore();
    var timezone = 'America/New_York';
    final initialService = _service(
      plugin,
      timeZoneStore: store,
      timezoneIdentifier: () async => timezone,
    );
    final target = _target('vehicle-a', 'Daily Driver', 'oil', 'Engine Oil');

    await initialService.sync(
      preferences: const ReminderPreferences(enabled: true),
      targets: [target],
      forceReschedule: true,
    );
    expect(store.value, 'America/New_York');

    timezone = 'Europe/London';
    plugin.cancelled.clear();
    // A process restart re-reads the device zone before syncing persisted work.
    final restartedService = _service(
      plugin,
      timeZoneStore: store,
      timezoneIdentifier: () async => timezone,
    );
    await restartedService.sync(
      preferences: const ReminderPreferences(enabled: true),
      targets: [target],
    );

    expect(plugin.cancelled, contains(target.notificationId));
    expect(plugin.scheduled, hasLength(1));
    expect(store.value, 'Europe/London');
  });

  test('a new service instance preserves pending schedules after reboot', () async {
    final plugin = _FakeNotificationPlugin();
    final store = _FakeTimeZoneStore();
    final target = _target('vehicle-a', 'Daily Driver', 'oil', 'Engine Oil');
    final preferences = const ReminderPreferences(enabled: true, repeatUntilComplete: true);

    await _service(plugin, timeZoneStore: store).sync(
      preferences: preferences,
      targets: [target],
      forceReschedule: true,
    );
    plugin.cancelled.clear();
    final rebootedService = _service(plugin, timeZoneStore: store);
    await rebootedService.sync(preferences: preferences, targets: [target]);

    expect(plugin.cancelled, isEmpty);
    expect(plugin.scheduled, hasLength(1));
    expect(plugin.scheduled.single.repeatWeekly, isTrue);
  });

  test('plugin failures are surfaced to the optional caller for mapping', () async {
    final plugin = _FakeNotificationPlugin(scheduleError: StateError('plugin unavailable'));
    final service = _service(plugin);

    expect(
      () => service.sync(
        preferences: const ReminderPreferences(enabled: true),
        targets: [_target('vehicle-a', 'Daily Driver', 'oil', 'Engine Oil')],
        forceReschedule: true,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('sync result maps plugin failures without exposing diagnostics', () async {
    final plugin = _FakeNotificationPlugin(scheduleError: StateError('private detail'));
    final result = await _service(plugin).syncResult(
      preferences: const ReminderPreferences(enabled: true),
      targets: [_target('vehicle-a', 'Daily Driver', 'oil', 'Engine Oil')],
      forceReschedule: true,
    );

    expect(result, isA<ReminderFailure>());
    expect((result as ReminderFailure).kind, ReminderFailureKind.plugin);
  });

  test('sync result maps denied permission to a typed user-safe outcome', () async {
    final result = await _service(_FakeNotificationPlugin(permissionGranted: false)).syncResult(
      preferences: const ReminderPreferences(enabled: true),
      targets: [_target('vehicle-a', 'Daily Driver', 'oil', 'Engine Oil')],
      forceReschedule: true,
    );

    expect(result, isA<ReminderFailure>());
    expect((result as ReminderFailure).kind, ReminderFailureKind.permission);
  });
}

ReminderNotificationService _service(
  _FakeNotificationPlugin plugin, {
  ReminderTimeZoneStore? timeZoneStore,
  Future<String> Function()? timezoneIdentifier,
}) => ReminderNotificationService(
      notificationPlugin: plugin,
      androidPlatform: true,
      timezoneIdentifier: timezoneIdentifier ?? (() async => 'America/New_York'),
      nativeCancel: (_) async {},
      timeZoneStore: timeZoneStore ?? _FakeTimeZoneStore(),
    );

ReminderTarget _target(String vehicleId, String vehicleName, String serviceId, String serviceName) => ReminderTarget(
      vehicleId: vehicleId,
      vehicleName: vehicleName,
      service: ServiceItem(
        id: serviceId,
        name: serviceName,
        note: '',
        serviceOdometer: 0,
        intervalKm: 1000,
        iconKey: 'maintenance',
      ),
    );

class _FakeTimeZoneStore extends ReminderTimeZoneStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String identifier) async => value = identifier;
}

class _ScheduledReminder {
  _ScheduledReminder(this.id, this.title, this.body, this.payload, this.repeatWeekly);
  final int id;
  final String title;
  final String body;
  final String payload;
  final bool repeatWeekly;
}

class _FakeNotificationPlugin implements ReminderNotificationPlugin {
  _FakeNotificationPlugin({this.permissionGranted = true, this.scheduleError});

  bool permissionGranted;
  final Object? scheduleError;
  final scheduled = <_ScheduledReminder>[];
  final cancelled = <int>[];

  @override
  Future<void> initialize(void Function(String? payload) onResponse) async {}

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async => scheduled
      .map((item) => PendingNotificationRequest(item.id, item.title, item.body, item.payload))
      .toList(growable: false);

  @override
  Future<void> schedule({
    required int id,
    required DateTime scheduledDate,
    required String title,
    required String body,
    required String payload,
    required bool repeatWeekly,
  }) async {
    if (scheduleError != null) throw scheduleError!;
    scheduled.add(_ScheduledReminder(id, title, body, payload, repeatWeekly));
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.removeWhere((item) => item.id == id);
  }
}
