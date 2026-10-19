import '../models/fuel_entry.dart';
import '../models/fuel_calculations.dart';
import '../models/fuel_preferences.dart';
import 'fuel_demo_data.dart';
import 'garage_repository.dart';

/// Explicit development operation; never runs automatically at app startup.
abstract final class FuelDemoSeeder {
  static const prefix = 'persisted-fuel-demo-v1-';

  static Future<int> seedSelected(
    GarageRepository repository, {
    DateTime? now,
  }) async {
    final collection = await repository.loadCollection();
    if (collection.isEmpty) throw StateError('No selected vehicle');
    final vehicle = collection.selectedVehicle;
    final old = vehicle.garage;
    if (old.fuelEntries.any((e) => e.id.startsWith(prefix))) return 0;
    final clock = (now ?? DateTime.now()).toUtc();
    final template = FuelDemoData.entries(now: clock);
    final ordered = FuelCalculations.ordered(old.fuelEntries, vehicle.id);
    final latest = ordered.isEmpty ? null : ordered.last;
    final start = latest == null
        ? template.first.date
        : latest.date.add(const Duration(microseconds: 1));
    if (!start.isBefore(clock)) {
      throw StateError('No past date range available for demo records');
    }
    final distance = template.last.odometer - template.first.odometer;
    final startOdometer =
        latest?.odometer ??
        (old.odometer >= distance ? old.odometer - distance : 0);
    if (startOdometer + distance > 999999) {
      throw StateError('Demo odometer would exceed supported range');
    }
    final span = clock.difference(start).inMicroseconds;
    final templateSpan = template.last.date
        .difference(template.first.date)
        .inMicroseconds;
    final entries = [
      for (final entry in template)
        FuelEntry(
          id: '$prefix${entry.id}',
          vehicleId: vehicle.id,
          date: start.add(
            Duration(
              microseconds:
                  (span *
                          (entry.date
                                  .difference(template.first.date)
                                  .inMicroseconds /
                              templateSpan))
                      .round(),
            ),
          ),
          odometer: startOdometer + entry.odometer - template.first.odometer,
          liters: entry.liters,
          cost: entry.cost,
          recordedPrice: entry.recordedPrice,
          grade: entry.grade,
          fullTank: entry.fullTank,
          note: '[Demo fuel data]',
          // Do not report a made-up interval from a real fill to the demo anchor.
          breaksConsumption: entry.id == template.first.id,
        ),
    ];
    final updated = vehicle.copyWith(
      fuelPreferences: FuelPreferences(
        usualGrade: vehicle.fuelPreferences.usualGrade,
        prices: {...vehicle.fuelPreferences.prices, 92: 20},
      ),
      garage: GarageSnapshot(
        odometer: old.odometer,
        services: old.services,
        tires: old.tires,
        history: old.history,
        fuelEntries: [...old.fuelEntries, ...entries],
        lastUpdatedAt: clock,
      ),
    );
    await repository.saveCollection(
      collection.copyWith(
        vehicles: [
          for (final v in collection.vehicles) v.id == vehicle.id ? updated : v,
        ],
      ),
      expectedRevision: repository.revision,
    );
    return entries.length;
  }
}
