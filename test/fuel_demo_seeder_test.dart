import 'dart:convert';

import 'package:app/data/fuel_demo_seeder.dart';
import 'package:app/data/garage_repository.dart';
import 'package:app/models/fuel_calculations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fuel_data_test.dart' show FuelMemoryStorage, garage, fill;

void main() {
  test(
    'seed real selected profile atomically, reload and do not duplicate',
    () async {
      final storage = FuelMemoryStorage();
      final repo = GarageRepository(storage: storage);
      final original = garage();
      await repo.saveCollection(original);
      final beforeSeed = await repo.loadCollection();
      expect(
        await FuelDemoSeeder.seedSelected(
          repo,
          now: DateTime.utc(2026, 10, 19),
        ),
        15,
      );
      final reloaded = await GarageRepository(storage: storage)
          .loadCollection();
      final entries = reloaded.selectedVehicle.garage.fuelEntries;
      expect(entries, hasLength(15));
      expect(
        entries.every(
          (e) => e.vehicleId == 'a' && e.note == '[Demo fuel data]',
        ),
        isTrue,
      );
      expect(FuelCalculations.intervals(entries, 'a'), hasLength(7));
      expect(FuelCalculations.intervals(entries, 'a').last.kmPerLiter, 11.8);
      // Repository saves intentionally refresh every snapshot's metadata.
      // Compare all persisted vehicle data except that save timestamp.
      final otherBefore = beforeSeed.vehicles.last.toJson();
      final otherAfter = reloaded.vehicles.last.toJson();
      (otherBefore['garage'] as Map).remove('lastUpdatedAt');
      (otherAfter['garage'] as Map).remove('lastUpdatedAt');
      expect(jsonEncode(otherAfter), jsonEncode(otherBefore));
      expect(
        reloaded.selectedVehicle.garage.services,
        original.selectedVehicle.garage.services,
      );
      expect(
        reloaded.selectedVehicle.garage.odometer,
        original.selectedVehicle.garage.odometer,
      );
      final stored = storage.value;
      expect(await FuelDemoSeeder.seedSelected(repo), 0);
      expect(storage.value, stored);
    },
  );

  test(
    'existing fills preserved exactly and no interval bridges real-to-demo',
    () async {
      final storage = FuelMemoryStorage();
      final repo = GarageRepository(storage: storage);
      final original = garage();
      final real = fill('real', 10000, 40);
      final vehicle = original.selectedVehicle.copyWith(
        garage: GarageSnapshot(
          odometer: 10000,
          services: const [],
          tires: const [],
          history: const [],
          fuelEntries: [real],
        ),
      );
      await repo.saveCollection(
        original.copyWith(vehicles: [vehicle, original.vehicles.last]),
      );
      await FuelDemoSeeder.seedSelected(repo, now: DateTime.utc(2026, 10, 19));
      final entries =
          (await repo.loadCollection()).selectedVehicle.garage.fuelEntries;
      expect(entries.first.toJson(), real.toJson());
      expect(entries, hasLength(16));
      for (final e in entries) {
        expect(FuelCalculations.fitsOdometerOrder(e, entries), isTrue);
      }
      final intervals = FuelCalculations.intervals(entries, 'a');
      expect(intervals, hasLength(7));
      expect(intervals.every((i) => i.startId != real.id), isTrue);
    },
  );

  test('failed write leaves original collection intact', () async {
    final storage = FuelMemoryStorage();
    final repo = GarageRepository(storage: storage);
    await repo.saveCollection(garage());
    final before = storage.value;
    storage.fail = true;
    await expectLater(FuelDemoSeeder.seedSelected(repo), throwsA(anything));
    expect(storage.value, before);
  });
}
