import 'package:app/reminders/reminder_preferences.dart';
import 'package:app/reminders/reminder_schedule.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults to enabled Friday at 10:00 AM', () async {
    SharedPreferences.setMockInitialValues({});

    final value = await const ReminderPreferencesRepository().load();

    expect(value.enabled, isTrue);
    expect(value.repeatUntilComplete, isFalse);
    expect(value.weekday, DateTime.friday);
    expect(value.hour, 10);
    expect(value.minute, 0);
  });

  test('preferences serialize and restore', () async {
    SharedPreferences.setMockInitialValues({});
    const repository = ReminderPreferencesRepository();
    const value = ReminderPreferences(
      enabled: false,
      repeatUntilComplete: true,
      weekday: DateTime.monday,
      hour: 21,
      minute: 45,
    );

    await repository.save(value);

    expect(await repository.load(), isA<ReminderPreferences>());
    final restored = await repository.load();
    expect(restored.enabled, isFalse);
    expect(restored.repeatUntilComplete, isTrue);
    expect(restored.weekday, DateTime.monday);
    expect(restored.hour, 21);
    expect(restored.minute, 45);
  });

  test('save replaces the existing reminder snapshot atomically', () async {
    SharedPreferences.setMockInitialValues({
      'maintenance_reminders_v1': '1|0|5|10|0',
    });
    const repository = ReminderPreferencesRepository();

    await expectLater(
      repository.save(
        const ReminderPreferences(
          enabled: false,
          repeatUntilComplete: true,
          weekday: DateTime.monday,
          hour: 21,
          minute: 45,
        ),
      ),
      completes,
    );

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('maintenance_reminders_v1'), '0|1|1|21|45');
  });

  test('rejects malformed reminder snapshots', () async {
    SharedPreferences.setMockInitialValues({
      'maintenance_reminders_v1': '1|0|8|10|0',
    });

    await expectLater(
      const ReminderPreferencesRepository().load(),
      throwsFormatException,
    );
  });

  test('loads legacy reminder keys until a snapshot is saved', () async {
    SharedPreferences.setMockInitialValues({
      'maintenance_reminders_enabled': false,
      'maintenance_reminders_repeat': true,
      'maintenance_reminders_weekday': DateTime.monday,
      'maintenance_reminders_hour': 21,
      'maintenance_reminders_minute': 45,
    });
    const repository = ReminderPreferencesRepository();

    final legacy = await repository.load();
    expect(legacy.enabled, isFalse);
    expect(legacy.repeatUntilComplete, isTrue);
    expect(legacy.weekday, DateTime.monday);
    expect(legacy.hour, 21);
    expect(legacy.minute, 45);

    await repository.save(legacy);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('maintenance_reminders_v1'), '0|1|1|21|45');
  });

  test('next Friday reminder is calculated in the future', () {
    const preferences = ReminderPreferences();
    final next = ReminderScheduleCalculator.nextOccurrence(
      preferences,
      now: DateTime(2026, 10, 8, 11),
    );

    expect(next, DateTime(2026, 10, 9, 10));
  });

  test('Friday after the configured time moves to the following week', () {
    const preferences = ReminderPreferences();
    final next = ReminderScheduleCalculator.nextOccurrence(
      preferences,
      now: DateTime(2026, 10, 9, 10),
    );

    expect(next, DateTime(2026, 10, 16, 10));
  });

  test('disabled reminders cancel and repeat reminders schedule weekly', () {
    expect(
      scheduleAction(const ReminderPreferences(enabled: false)),
      ReminderScheduleAction.cancel,
    );
    expect(
      scheduleAction(const ReminderPreferences(repeatUntilComplete: true)),
      ReminderScheduleAction.scheduleWeekly,
    );
    expect(
      scheduleAction(const ReminderPreferences()),
      ReminderScheduleAction.scheduleOnce,
    );
  });
}
