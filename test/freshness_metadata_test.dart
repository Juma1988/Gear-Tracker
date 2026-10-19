import 'dart:convert';

import 'package:app/data/garage_repository.dart';
import 'package:app/models/vehicle_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('freshness metadata serializes independently of maintenance dates', () {
    final timestamp = DateTime.utc(2026, 10, 11, 12, 30);
    final snapshot = GarageSnapshot(
      odometer: 100,
      services: const [],
      tires: const [],
      history: const [],
      lastUpdatedAt: timestamp,
    );

    final restored = GarageSnapshot.fromJson(snapshot.toJson());
    expect(restored.lastUpdatedAt, timestamp);
    expect(snapshot.toJson()['lastUpdatedAt'], timestamp.toIso8601String());
  });

  test('legacy snapshots default freshness to unknown', () {
    final json = <String, dynamic>{
      'schemaVersion': GarageSnapshot.currentSchemaVersion,
      'odometer': 100,
      'services': <dynamic>[],
      'tires': <dynamic>[],
      'history': <dynamic>[],
      'fuelEntries': <dynamic>[],
    };

    expect(GarageSnapshot.fromJson(json).lastUpdatedAt, isNull);
    expect(GarageSnapshot.migrate({...json, 'schemaVersion': 6})
        .lastUpdatedAt, isNull);
  });

  test('successful persistence stamps local freshness', () async {
    final timestamp = DateTime.utc(2026, 10, 11, 13);
    final storage = _MemoryStorage();
    final repository = GarageRepository(
      storage: storage,
      clock: () => timestamp,
    );
    final collection = GarageCollection(
      vehicles: [
        VehicleProfile(
          id: 'v1',
          year: 2020,
          model: 'Test',
          garage: GarageSnapshot.empty(),
        ),
      ],
      selectedVehicleId: 'v1',
      defaultVehicleId: GarageCollection.lastUsedVehicleId,
    );

    await repository.saveCollection(collection);
    final payload = jsonDecode(storage.value!) as Map<String, dynamic>;
    final vehicle = (payload['vehicles'] as List).single as Map;
    final garage = vehicle['garage'] as Map;
    expect(garage['lastUpdatedAt'], timestamp.toIso8601String());
  });

  test('legacy migration stamps freshness with the repository clock', () async {
    final timestamp = DateTime.utc(2026, 10, 11, 14);
    final legacy = GarageSnapshot.empty().toJson()..['schemaVersion'] = 6;
    final storage = _MemoryStorage()..value = jsonEncode(legacy);
    final repository = GarageRepository(
      storage: storage,
      clock: () => timestamp,
    );

    await repository.loadCollection();

    final payload = jsonDecode(storage.value!) as Map<String, dynamic>;
    final garage = ((payload['vehicles'] as List).single
        as Map<String, dynamic>)['garage'] as Map<String, dynamic>;
    expect(garage['lastUpdatedAt'], timestamp.toIso8601String());
  });

  test('seeded fixture uses its injected clock for tire dates', () {
    final timestamp = DateTime.utc(2026, 10, 11, 15);

    final snapshot = GarageSnapshot.seeded(clock: () => timestamp);

    expect(snapshot.tires, isNotEmpty);
    expect(snapshot.tires.every((tire) => tire.installDate == timestamp), isTrue);
  });
}

class _MemoryStorage implements GarageStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<bool> write(String value) async {
    this.value = value;
    return true;
  }
}
