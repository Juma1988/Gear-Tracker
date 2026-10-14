import 'dart:convert';

import 'package:app/controllers/dashboard_controller.dart';
import 'package:app/data/garage_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/vehicle_profile.dart';

void main() {
  test('load success exposes the selected garage and recovers after an error', () async {
    final storage = _Storage(failReads: true);
    final controller = DashboardController(repository: GarageRepository(storage: storage));

    await controller.load();
    expect(controller.loadState, DashboardLoadState.error);

    storage.failReads = false;
    await controller.load();
    expect(controller.loadState, DashboardLoadState.ready);
    expect(controller.savedOdometer, '000123');
  });

  test('save reports failure and optimistic conflicts', () async {
    final repository = GarageRepository(storage: _Storage());
    final controller = DashboardController(repository: repository);
    const empty = GarageCollection(
      vehicles: [],
      selectedVehicleId: '',
      defaultVehicleId: GarageCollection.lastUsedVehicleId,
    );

    expect(await controller.saveCollection(empty), isTrue);
    expect(await controller.saveCollection(empty, expectedRevision: 0), isFalse);
    expect(controller.saveState, DashboardSaveState.failed);
  });

  test('odometer update persists through the controller boundary', () async {
    final storage = _Storage();
    final controller = DashboardController(
      repository: GarageRepository(storage: storage),
    );
    await controller.load();

    expect(await controller.updateOdometer('000456'), isTrue);
    final loaded = await GarageRepository(storage: storage).loadCollection();
    expect(loaded.selectedVehicle.garage.odometer, 456);
    expect(controller.saveState, DashboardSaveState.saved);
  });

  test('persistGarage accepts the staged odometer without stale controller state', () async {
    final storage = _Storage();
    final controller = DashboardController(
      repository: GarageRepository(storage: storage),
    );
    await controller.load();

    expect(
      await controller.persistGarage(odometer: '000789'),
      isTrue,
    );
    final loaded = await GarageRepository(storage: storage).loadCollection();
    expect(loaded.selectedVehicle.garage.odometer, 789);
  });
}

class _Storage implements GarageStorage {
  _Storage({this.failReads = false});

  bool failReads;
  String? payload;

  @override
  Future<String?> read() async {
    if (failReads) throw StateError('offline');
    if (payload != null) return payload;
    final vehicle = VehicleProfile(
      id: 'vehicle-1',
      year: 2022,
      model: 'Golf GTI',
      garage: GarageSnapshot(
        odometer: 123,
        services: const [],
        tires: const [],
        history: const [],
        lastUpdatedAt: DateTime.utc(2024),
      ),
    );
    return jsonEncode(GarageCollection(
      vehicles: [vehicle],
      selectedVehicleId: vehicle.id,
      defaultVehicleId: GarageCollection.lastUsedVehicleId,
    ).toJson());
  }

  @override
  Future<bool> write(String value) async {
    payload = value;
    return true;
  }
}
