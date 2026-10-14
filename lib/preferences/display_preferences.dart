import 'package:shared_preferences/shared_preferences.dart';

class DisplayPreferences {
  const DisplayPreferences._();

  static const _compactTireHealthKey = 'compact_tire_health_card';
  static const _showGuidanceKey = 'show_guidance';

  static Future<bool> loadCompactTireHealth() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_compactTireHealthKey) ?? false;
  }

  static Future<void> saveCompactTireHealth(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_compactTireHealthKey, value);
  }

  static Future<bool> loadShowGuidance() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_showGuidanceKey) ?? true;
  }

  static Future<void> saveShowGuidance(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_showGuidanceKey, value);
  }
}
