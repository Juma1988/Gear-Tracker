import 'dart:convert';

import 'package:app/data/garage_storage.dart';
import 'package:app/models/service_item.dart';
import 'package:app/models/fuel_entry.dart';
import 'package:app/models/vehicle_profile.dart';
import 'package:flutter_test/flutter_test.dart';

GarageSnapshot _snapshotFixture() => GarageSnapshot(
  odometer: 42000,
  services: [
    const ServiceItem(
      id: 'oil',
      name: 'Engine Oil',
      note: 'synthetic',
      serviceOdometer: 40000,
      intervalKm: 10000,
      iconKey: 'oil',
    ),
    ServiceItem(
      id: 'tires',
      name: 'Tires',
      note: '',
      serviceOdometer: 40000,
      intervalKm: 50000,
      iconKey: 'tires',
      type: ServiceType.type02,
      units: [
        for (final position in ServiceUnit.positions)
          ServiceUnit(position: position, installOdometer: 40000),
      ],
    ),
  ],
  tires: const [],
  history: const [],
  fuelEntries: [
    FuelEntry(
      id: 'fuel-1',
      vehicleId: 'vehicle-1',
      date: DateTime.utc(2026, 10, 19),
      odometer: 42000,
      liters: 42.5,
      cost: 2500,
    ),
  ],
);

GarageCollection _collectionFixture() => GarageCollection(
  vehicles: [
    VehicleProfile(
      id: 'vehicle-1',
      year: 2020,
      make: 'Toyota',
      model: 'Corolla',
      garage: _snapshotFixture(),
    ),
  ],
  selectedVehicleId: 'vehicle-1',
  defaultVehicleId: GarageCollection.lastUsedVehicleId,
);

void main() {
  test('round-trips every supported garage snapshot schema version', () {
    final canonical = _snapshotFixture().toJson();

    for (final version in [
      2,
      3,
      4,
      5,
      6,
      7,
      GarageSnapshot.currentSchemaVersion,
    ]) {
      final source = jsonDecode(jsonEncode(canonical)) as Map<String, dynamic>;
      source['schemaVersion'] = version;
      if (version == 2) {
        // v2 had no generic position data; migration must recreate it.
        (source['services'] as List).last.remove('units');
      }
      if (version < 8) source.remove('fuelEntries');

      final restored = version == GarageSnapshot.currentSchemaVersion
          ? GarageSnapshot.fromJson(source)
          : GarageSnapshot.fromJson(GarageSnapshot.migrate(source).toJson());

      expect(
        restored.toJson(),
        version < 8 ? {...canonical, 'fuelEntries': []} : canonical,
        reason: 'schema v$version should round-trip to the current schema',
      );
    }
  });

  test('round-trips every supported garage collection schema version', () {
    final canonical = _collectionFixture().toJson();

    for (final version in [1, 2]) {
      final source = jsonDecode(jsonEncode(canonical)) as Map<String, dynamic>;
      source['schemaVersion'] = version;
      if (version == 1) source.remove('defaultVehicleId');

      final restored = GarageCollection.fromJson(source);

      expect(
        restored.toJson(),
        canonical,
        reason: 'collection schema v$version should round-trip to v2',
      );
    }
  });
}
