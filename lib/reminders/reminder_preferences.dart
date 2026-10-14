import 'package:shared_preferences/shared_preferences.dart';

class ReminderPreferences {
  const ReminderPreferences({
    this.enabled = true,
    this.repeatUntilComplete = false,
    this.weekday = DateTime.friday,
    this.hour = 10,
    this.minute = 0,
  });

  final bool enabled;
  final bool repeatUntilComplete;
  final int weekday;
  final int hour;
  final int minute;

  ReminderPreferences copyWith({
    bool? enabled,
    bool? repeatUntilComplete,
    int? weekday,
    int? hour,
    int? minute,
  }) => ReminderPreferences(
    enabled: enabled ?? this.enabled,
    repeatUntilComplete: repeatUntilComplete ?? this.repeatUntilComplete,
    weekday: weekday ?? this.weekday,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
  );
}

class ReminderPreferencesRepository {
  static const _enabledKey = 'maintenance_reminders_enabled';
  static const _repeatKey = 'maintenance_reminders_repeat';
  static const _weekdayKey = 'maintenance_reminders_weekday';
  static const _hourKey = 'maintenance_reminders_hour';
  static const _minuteKey = 'maintenance_reminders_minute';

  const ReminderPreferencesRepository();

  Future<ReminderPreferences> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_snapshotKey);
    if (encoded != null) {
      return _decode(encoded);
    }
    return ReminderPreferences(
      enabled: preferences.getBool(_enabledKey) ?? true,
      repeatUntilComplete: preferences.getBool(_repeatKey) ?? false,
      weekday: _validWeekday(preferences.getInt(_weekdayKey))
          ? preferences.getInt(_weekdayKey)!
          : DateTime.friday,
      hour: _validHour(preferences.getInt(_hourKey))
          ? preferences.getInt(_hourKey)!
          : 10,
      minute: _validMinute(preferences.getInt(_minuteKey))
          ? preferences.getInt(_minuteKey)!
          : 0,
    );
  }

  Future<void> save(ReminderPreferences value) async {
    if (!_validWeekday(value.weekday) ||
        !_validHour(value.hour) ||
        !_validMinute(value.minute)) {
      throw ArgumentError('Invalid reminder schedule');
    }
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(_snapshotKey, _encode(value))) {
      throw StateError('Reminder preferences were not saved');
    }
  }

  static const _snapshotKey = 'maintenance_reminders_v1';

  String _encode(ReminderPreferences value) =>
      '${value.enabled ? 1 : 0}|${value.repeatUntilComplete ? 1 : 0}|${value.weekday}|${value.hour}|${value.minute}';

  ReminderPreferences _decode(String encoded) {
    final values = encoded.split('|');
    if (values.length != 5) {
      throw const FormatException('Invalid reminder preferences');
    }
    final enabled = values[0] == '1';
    final repeat = values[1] == '1';
    final weekday = int.tryParse(values[2]);
    final hour = int.tryParse(values[3]);
    final minute = int.tryParse(values[4]);
    if ((values[0] != '0' && values[0] != '1') ||
        (values[1] != '0' && values[1] != '1') ||
        !_validWeekday(weekday) ||
        !_validHour(hour) ||
        !_validMinute(minute)) {
      throw const FormatException('Invalid reminder preferences');
    }
    return ReminderPreferences(
      enabled: enabled,
      repeatUntilComplete: repeat,
      weekday: weekday!,
      hour: hour!,
      minute: minute!,
    );
  }

  static bool _validWeekday(int? value) =>
      value != null && value >= 1 && value <= 7;
  static bool _validHour(int? value) =>
      value != null && value >= 0 && value <= 23;
  static bool _validMinute(int? value) =>
      value != null && value >= 0 && value <= 59;
}
