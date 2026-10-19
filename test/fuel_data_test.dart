import 'dart:convert';

import 'package:app/controllers/dashboard_controller.dart';
import 'package:app/data/garage_repository.dart';
import 'package:app/models/fuel_entry.dart';
import 'package:app/models/fuel_calculations.dart';
import 'package:app/models/vehicle_profile.dart';
import 'package:flutter_test/flutter_test.dart';

FuelEntry fill(
  String id,
  int km,
  double liters, {
  String vehicle = 'a',
  bool? full = true,
  int day = 1,
  int grade = 92,
  double? cost,
}) => FuelEntry(
  id: id,
  vehicleId: vehicle,
  date: DateTime.utc(2026, 1, day),
  odometer: km,
  liters: liters,
  cost: cost ?? liters * 20,
  grade: grade,
  fullTank: full,
);
GarageCollection garage() => GarageCollection(
  vehicles: [
    for (final id in ['a', 'b'])
      VehicleProfile(
        id: id,
        year: 2012,
        model: id,
        garage: GarageSnapshot.empty(),
      ),
  ],
  selectedVehicleId: 'a',
  defaultVehicleId: GarageCollection.lastUsedVehicleId,
);

class FuelMemoryStorage implements GarageStorage, GarageBackupStorage {
  String? value;
  String? backup;
  bool fail = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<bool> write(String text) async {
    if (fail) return false;
    value = text;
    return true;
  }

  @override
  Future<void> backupBeforeMigration(String raw) async {
    backup = raw;
  }
}

void main() {
  test('last saved pump price overrides suggestion, persists and preserves old receipts', () async {
    final storage = FuelMemoryStorage();
    final repo = GarageRepository(storage: storage);
    await repo.saveCollection(garage());
    final controller = DashboardController(repository: repo);
    await controller.load();
    expect(
      await controller.saveFuel(fill('newer', 200, 10, day: 3), usualGrade: 92),
      isTrue,
    );
    expect(
      await controller.saveFuel(
        fill('95', 300, 10, day: 4, grade: 95, cost: 300),
        usualGrade: 92,
      ),
      isTrue,
    );
    final oldReceipt = controller.fuelEntries.first.toJson();
    final backdated = FuelEntry(
      id: 'backdated',
      vehicleId: 'a',
      date: DateTime.utc(2026, 1, 2),
      odometer: 100,
      liters: 10,
      cost: 250,
      grade: 92,
      recordedPrice: 25,
      fullTank: true,
    );
    expect(await controller.saveFuel(backdated, usualGrade: 92), isTrue);
    expect(controller.vehicle!.fuelPreferences.prices, {92: 25, 95: 30});
    expect(
      controller.fuelEntries.firstWhere((e) => e.id == 'newer').toJson(),
      oldReceipt,
    );
    final loaded = await GarageRepository(storage: storage).loadCollection();
    expect(loaded.selectedVehicle.fuelPreferences.prices, {92: 25, 95: 30});
    expect(loaded.vehicles.last.fuelPreferences.prices, isEmpty);
    storage.fail = true;
    expect(
      await controller.saveFuel(
        fill('failed', 400, 10, day: 5, cost: 400),
        usualGrade: 92,
      ),
      isFalse,
    );
    expect(controller.vehicle!.fuelPreferences.prices[92], 25);
  });

  test('full-partial-full excludes the anchor liters and gives 10 km/L', () {
    final entries = [
      fill('first', 10000, 40),
      fill('partial', 10100, 10, full: false, day: 2),
      fill('end', 10300, 20, day: 3),
    ];
    expect(FuelCalculations.intervals(entries.take(1), 'a'), isEmpty);
    expect(FuelCalculations.intervals(entries.take(2), 'a'), isEmpty);
    final result = FuelCalculations.intervals(entries, 'a').single;
    expect(result.distanceKm, 300);
    expect(result.liters, 30);
    expect(result.kmPerLiter, 10);
    expect(result.litersPer100Km, 10);
  });
  test(
    'vehicle isolation, equal odometer, unknown fills, and gaps do not guess',
    () {
      expect(
        FuelCalculations.intervals([
          fill('a', 100, 20),
          fill('b', 300, 10, vehicle: 'b', day: 2),
        ], 'a'),
        isEmpty,
      );
      expect(
        FuelCalculations.intervals([
          fill('a', 100, 20),
          fill('b', 100, 10, day: 2),
        ], 'a'),
        isEmpty,
      );
      expect(
        FuelCalculations.intervals([
          fill('a', 100, 20),
          fill('unknown', 150, 10, day: 2, full: null),
          fill('b', 300, 10, day: 3),
        ], 'a'),
        isEmpty,
      );
      final entries = [
        fill('a', 10000, 40),
        fill('partial', 10100, 10, full: false, day: 2),
        fill('b', 10300, 20, day: 3),
      ];
      expect(
        FuelCalculations.intervals(
          FuelCalculations.withoutEntry(entries, 'a', 'partial'),
          'a',
        ),
        isEmpty,
      );
      final corrected = [
        entries.first,
        fill('partial', 10100, 20, full: false, day: 2),
        entries.last,
      ];
      expect(FuelCalculations.intervals(corrected, 'a').single.kmPerLiter, 7.5);
    },
  );
  test('Arabic decimals, receipt conversions and invalid inputs', () {
    expect(FuelInput.decimal('١٢٫٥'), 12.5);
    expect(FuelInput.decimal('NaN'), isNull);
    expect(FuelInput.decimal('Infinity'), isNull);
    expect(FuelInput.litersFromAmount(600, 20), 30);
    expect(FuelInput.amountFromLiters(30, 20), 600);
    expect(FuelInput.litersFromAmount(600, 0), isNull);
    final receipt = fill('receipt', 100, 29.97, cost: 600);
    expect(receipt.cost, 600);
    expect(receipt.pricePerLiter, closeTo(20.02002, 0.00001));
  });
  test('schema 8 collection migration backs up and binds old receipts without guessing full status', () async {
    final raw = garage().toJson();
    for (final vehicle in raw['vehicles'] as List) {
      final snapshot = vehicle['garage'] as Map;
      snapshot['schemaVersion'] = 8;
      snapshot['fuelEntries'] = [
        {
          'id': 'old-${vehicle['id']}',
          'date': '2026-01-01T00:00:00Z',
          'odometer': 100,
          'liters': 10.0,
          'cost': 200.0,
        },
      ];
      vehicle.remove('fuelPreferences');
    }
    final storage = FuelMemoryStorage()..value = jsonEncode(raw);
    final original = storage.value;
    final loaded = await GarageRepository(storage: storage).loadCollection();
    expect(storage.backup, original);
    expect(loaded.vehicles, hasLength(2));
    for (final vehicle in loaded.vehicles) {
      final entry = vehicle.garage.fuelEntries.single;
      expect(entry.vehicleId, vehicle.id);
      expect(entry.fullTank, isNull);
      expect(entry.cost, 200);
      expect(vehicle.fuelPreferences.usualGrade, 92);
    }
    expect(
      (await GarageRepository(storage: storage).loadCollection()).vehicles,
      hasLength(2),
    );
  });
  test('create/edit/delete persist with per-vehicle per-grade suggestions and reject foreign records', () async {
    final storage = FuelMemoryStorage();
    final repo = GarageRepository(storage: storage);
    await repo.saveCollection(garage());
    final controller = DashboardController(repository: repo);
    await controller.load();
    expect(
      await controller.saveFuel(fill('92', 100, 10), usualGrade: 92),
      isTrue,
    );
    expect(
      await controller.saveFuel(
        fill('95', 200, 10, day: 2, grade: 95, cost: 250),
        usualGrade: 95,
      ),
      isTrue,
    );
    expect(controller.vehicle!.fuelPreferences.prices, {92: 20, 95: 25});
    expect(
      await controller.saveFuel(
        fill('bad', 300, 10, vehicle: 'b'),
        usualGrade: 92,
      ),
      isFalse,
    );
    expect(
      await controller.saveFuel(fill('order', 50, 10, day: 3), usualGrade: 92),
      isFalse,
    );
    final persisted = await GarageRepository(storage: storage).loadCollection();
    expect(persisted.vehicles.last.garage.fuelEntries, isEmpty);
    expect(persisted.vehicles.last.fuelPreferences.prices, isEmpty);
    final restarted = DashboardController(
      repository: GarageRepository(storage: storage),
    );
    await restarted.load();
    expect(restarted.vehicle!.fuelPreferences.usualGrade, 95);
    expect(restarted.fuelEntries, hasLength(2));
    expect(
      await restarted.saveFuel(
        fill('95', 200, 12, day: 2, grade: 95, cost: 250),
        usualGrade: 95,
      ),
      isTrue,
    );
    expect(restarted.fuelEntries.last.liters, 12);
    expect(await restarted.deleteFuel('a', '92'), isTrue);
    expect(
      (await GarageRepository(
        storage: storage,
      ).loadCollection()).selectedVehicle.garage.fuelEntries.single.id,
      '95',
    );
    final aPrice = restarted.vehicle!.fuelPreferences.prices[95];
    var selected = restarted.collection!.copyWith(selectedVehicleId: 'b');
    restarted.selectVehicle(selected.selectedVehicle, selected);
    expect(restarted.fuelEntries, isEmpty);
    expect(restarted.vehicle!.fuelPreferences.prices, isEmpty);
    expect(
      await restarted.saveFuel(
        fill('95', 500, 10, vehicle: 'b', grade: 95, cost: 300),
        usualGrade: 95,
      ),
      isTrue,
    );
    expect(restarted.vehicle!.fuelPreferences.prices[95], 30);
    selected = restarted.collection!.copyWith(selectedVehicleId: 'a');
    restarted.selectVehicle(selected.selectedVehicle, selected);
    expect(restarted.vehicle!.fuelPreferences.prices[95], aPrice);
    expect(restarted.fuelEntries.single.cost, 250);
    expect(
      restarted.collection!.vehicles.last.garage.fuelEntries.single.vehicleId,
      'b',
    );
    storage.fail = true;
    expect(
      await restarted.saveFuel(fill('failed', 300, 10, day: 3), usualGrade: 92),
      isFalse,
    );
    expect(restarted.fuelEntries, hasLength(1));
    final foreign = garage().vehicles.first.copyWith(
      garage: GarageSnapshot(
        odometer: 0,
        services: const [],
        tires: const [],
        history: const [],
        fuelEntries: [fill('foreign', 0, 10, vehicle: 'b')],
      ),
    );
    expect(
      () => garage()
          .copyWith(vehicles: [foreign, garage().vehicles.last])
          .validate(),
      throwsFormatException,
    );
  });
}
