import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/fuel_demo_seeder.dart';
import '../data/garage_repository.dart';

/// Run explicitly with flutter run -t lib/dev/seed_selected_vehicle_fuel.dart.
/// Writes the real selected vehicle's garage, only after user authorization.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode) throw StateError('Demo seeding is development-only');
  final repository = GarageRepository();
  try {
    final raw = await SharedPreferencesGarageStorage().read();
    final preferences = await SharedPreferences.getInstance();
    const backupKey = 'garage_before_fuel_demo_seed_v1';
    if (raw != null && !preferences.containsKey(backupKey)) {
      if (!await preferences.setString(backupKey, raw)) {
        throw StateError('Could not back up garage before demo import');
      }
    }
    final count = await FuelDemoSeeder.seedSelected(repository);
    final reloaded = await GarageRepository().loadCollection();
    final vehicle = reloaded.selectedVehicle;
    final stored = vehicle.garage.fuelEntries
        .where((e) => e.id.startsWith(FuelDemoSeeder.prefix))
        .length;
    if (stored != 15) {
      throw StateError('Native reload did not retain 15 demo records');
    }
    final message =
        'FUEL_DEMO_SEED_OK added=$count stored=$stored vehicle=${vehicle.id}';
    debugPrint(message);
    runApp(
      MaterialApp(
        home: Scaffold(body: Center(child: Text(message))),
      ),
    );
  } catch (error) {
    debugPrint('FUEL_DEMO_SEED_FAILED $error');
    rethrow;
  }
}
