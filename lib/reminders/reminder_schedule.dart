import 'reminder_preferences.dart';

class ReminderScheduleCalculator {
  const ReminderScheduleCalculator._();

  static DateTime nextOccurrence(
    ReminderPreferences preferences, {
    required DateTime now,
  }) {
    var candidate = DateTime(
      now.year,
      now.month,
      now.day,
      preferences.hour,
      preferences.minute,
    );
    var daysUntil = (preferences.weekday - now.weekday) % DateTime.daysPerWeek;
    if (daysUntil == 0 && !candidate.isAfter(now)) {
      daysUntil = DateTime.daysPerWeek;
    }
    return candidate.add(Duration(days: daysUntil));
  }
}

enum ReminderScheduleAction { cancel, scheduleOnce, scheduleWeekly }

ReminderScheduleAction scheduleAction(ReminderPreferences preferences) {
  if (!preferences.enabled) return ReminderScheduleAction.cancel;
  return preferences.repeatUntilComplete
      ? ReminderScheduleAction.scheduleWeekly
      : ReminderScheduleAction.scheduleOnce;
}
