import 'package:shared_preferences/shared_preferences.dart';

/// User preferences that control how service creation is entered.
class ServicePreferences {
  const ServicePreferences._();

  static const customServiceKey = 'customService';

  /// True opens the service preset list; false opens the custom-service flow.
  /// Defaults to false so the center add action starts with custom service.
  static Future<bool> loadCustomService() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(customServiceKey) ?? false;
  }

  static Future<void> saveCustomService(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(customServiceKey, value);
  }
}
