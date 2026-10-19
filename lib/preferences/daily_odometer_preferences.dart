import 'package:shared_preferences/shared_preferences.dart';

abstract final class DailyOdometerPreferences {
  static const key = 'last_daily_odometer_prompt';

  /// App-wide, based on the device's local calendar day, not a 24-hour timer.
  static String dayKey(DateTime now) {
    final local = now.toLocal();
    return '${local.year}-${local.month}-${local.day}';
  }

  static Future<bool> claimToday({DateTime? now}) async {
    final preferences = await SharedPreferences.getInstance();
    final today = dayKey(now ?? DateTime.now());
    if (preferences.getString(key) == today) return false;
    // Claim before showing, so dismissing/Not now also counts for today.
    return preferences.setString(key, today);
  }
}
