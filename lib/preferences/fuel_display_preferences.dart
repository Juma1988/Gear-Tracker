import 'package:shared_preferences/shared_preferences.dart';

enum FuelConsumptionUnit {
  kmPerLiter,
  litersPer100Km;

  String get labelKey => this == kmPerLiter ? 'kmL' : 'l100';
  double fromKmPerLiter(double value) =>
      this == kmPerLiter ? value : 100 / value;
}

abstract final class FuelDisplayPreferences {
  static const key = 'fuel_consumption_unit';

  static Future<FuelConsumptionUnit> load() async {
    final value = (await SharedPreferences.getInstance()).getString(key);
    return value == FuelConsumptionUnit.litersPer100Km.name
        ? FuelConsumptionUnit.litersPer100Km
        : FuelConsumptionUnit.kmPerLiter;
  }

  static Future<bool> save(FuelConsumptionUnit unit) async =>
      (await SharedPreferences.getInstance()).setString(key, unit.name);
}
