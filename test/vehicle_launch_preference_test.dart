import 'package:app/data/garage_repository.dart';
import 'package:app/models/vehicle_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final vehicles = [
    VehicleProfile(
      id: 'vehicle-a',
      year: 2022,
      make: 'Volkswagen',
      model: 'Golf GTI',
      garage: GarageSnapshot.seeded(),
    ),
    VehicleProfile(
      id: 'vehicle-b',
      year: 2020,
      make: 'Toyota',
      model: 'RAV4',
      garage: GarageSnapshot.seeded(),
    ),
  ];

  test('specific default vehicle wins on launch', () {
    final collection = GarageCollection(
      vehicles: vehicles,
      selectedVehicleId: 'vehicle-a',
      defaultVehicleId: 'vehicle-b',
    );

    expect(collection.launchVehicle.id, 'vehicle-b');
  });

  test('last used preference restores the selected vehicle on launch', () {
    final collection = GarageCollection(
      vehicles: vehicles,
      selectedVehicleId: 'vehicle-b',
      defaultVehicleId: GarageCollection.lastUsedVehicleId,
    );

    expect(collection.launchVehicle.id, 'vehicle-b');
  });

  test('last used preference survives JSON persistence', () {
    final collection = GarageCollection(
      vehicles: vehicles,
      selectedVehicleId: 'vehicle-a',
      defaultVehicleId: GarageCollection.lastUsedVehicleId,
    );

    final restored = GarageCollection.fromJson(collection.toJson());

    expect(restored.defaultVehicleId, GarageCollection.lastUsedVehicleId);
    expect(restored.launchVehicle.id, 'vehicle-a');
  });

  test('schema 1 automatic default migrates to last used', () {
    final collection = GarageCollection(
      vehicles: vehicles,
      selectedVehicleId: 'vehicle-b',
      defaultVehicleId: 'vehicle-a',
    );
    final legacyJson = {...collection.toJson(), 'schemaVersion': 1};

    final restored = GarageCollection.fromJson(legacyJson);

    expect(restored.defaultVehicleId, GarageCollection.lastUsedVehicleId);
    expect(restored.launchVehicle.id, 'vehicle-b');
  });
}
