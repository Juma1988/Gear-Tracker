import 'dart:convert';

import 'package:app/models/service_item.dart';
import 'package:app/reminders/reminder_notification_service.dart';
import 'package:app/reminders/reminder_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Runtime proof for W09 on a real Android device.
///
/// Exercises the real `flutter_local_notifications` plugin, the Android alarm
/// scheduler, and the notification channel. This is the device-backed evidence
/// for BE-F17, BE-F19, BE-F21, UI-F39 and UI-F40.
///
/// Prerequisite: on a freshly installed build `POST_NOTIFICATIONS` defaults to
/// denied and the system permission dialog would block an unattended run. Grant
/// it first, then run the test:
///
/// ```
/// adb shell pm grant com.i1988.geartracker android.permission.POST_NOTIFICATIONS
/// flutter test integration_test/w09_reminders_test.dart -d emulator-5554
/// ```
///
/// When notifications are not enabled the test skips instead of hanging.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final service = ReminderNotificationService();

  Future<bool> notificationsEnabled() async {
    final plugin = FlutterLocalNotificationsPlugin();
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.areNotificationsEnabled() ?? false;
  }

  testWidgets('schedules, keys, reschedules and cancels reminders on device', (
    tester,
  ) async {
    const prefs = ReminderPreferences(enabled: true, repeatUntilComplete: false);

    if (!await notificationsEnabled()) {
      markTestSkipped(
        'POST_NOTIFICATIONS not granted: run '
        '`adb shell pm grant com.i1988.geartracker '
        'android.permission.POST_NOTIFICATIONS` first.',
      );
      return;
    }

    await service.cancel();
    expect(await service.pendingForTesting(), isEmpty);

    // BE-F17: scheduling creates a pending system alarm per keyed target.
    await service.sync(
      preferences: prefs,
      targets: [_target('vehicle-a', 'Daily Driver', 'oil', 'Engine Oil')],
      forceReschedule: true,
    );
    var scheduled = await service.pendingForTesting();
    expect(scheduled, hasLength(1));
    expect(scheduled.single.id, reminderNotificationId('vehicle-a', 'oil'));

    // UI-F39: reminder copy identifies the vehicle and the service.
    expect(scheduled.single.title, contains('Daily Driver'));
    expect(scheduled.single.title, contains('Engine Oil'));

    // UI-F40: the payload routes the tap to the right vehicle + service.
    expect(scheduled.single.payload, isNotNull);
    expect(jsonDecode(scheduled.single.payload!), {
      'vehicleId': 'vehicle-a',
      'serviceId': 'oil',
    });

    // BE-F19: another vehicle gets a distinct notification id.
    await service.sync(
      preferences: prefs,
      targets: [_target('vehicle-b', 'Weekend Truck', 'oil', 'Engine Oil')],
      forceReschedule: true,
    );
    scheduled = await service.pendingForTesting();
    expect(scheduled, hasLength(1));
    expect(scheduled.single.id, reminderNotificationId('vehicle-b', 'oil'));
    expect(
      scheduled.single.id,
      isNot(reminderNotificationId('vehicle-a', 'oil')),
    );

    // BE-F17: cancellation removes the scheduled alarm.
    await service.cancel();
    expect(await service.pendingForTesting(), isEmpty);
  });

  testWidgets('disabled reminder preferences schedule nothing', (
    tester,
  ) async {
    await service.sync(
      preferences: const ReminderPreferences(
        enabled: false,
        repeatUntilComplete: false,
      ),
      targets: [_target('vehicle-a', 'Daily Driver', 'oil', 'Engine Oil')],
      forceReschedule: true,
    );
    expect(await service.pendingForTesting(), isEmpty);
  });
}

ReminderTarget _target(
  String vehicleId,
  String vehicleName,
  String serviceId,
  String serviceName,
) => ReminderTarget(
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
