import 'dart:convert';

import 'package:app/data/garage_backup.dart';
import 'package:app/data/garage_repository.dart';
import 'package:app/models/service_history_entry.dart';
import 'package:app/models/vehicle_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('persistence corruption fixtures', () {
    test('rejects the supported malformed snapshot matrix', () {
      final fixtures = <String, Map<String, dynamic>>{
        'malformed shape': {'schemaVersion': GarageSnapshot.currentSchemaVersion},
        'unknown service enum': _snapshot((json) {
          (json['services'] as List).first['type'] = 'future-service-type';
        }),
        // Tracking mode is derived from the persisted fields rather than
        // stored as an enum. This represents the unknown/unrepresentable mode.
        'unknown tracking mode': _snapshot((json) {
          final service = (json['services'] as List).first;
          service
            ..remove('serviceOdometer')
            ..remove('intervalKm')
            ..['trackingMode'] = 'future-mode';
        }),
        'duplicate service ID': _snapshot((json) {
          final services = json['services'] as List;
          services.add(Map<String, dynamic>.from(services.first));
        }),
        'duplicate history ID': _snapshot((json) {
          final history = _history().toJson();
          (json['history'] as List).add(history);
          (json['history'] as List).add(Map<String, dynamic>.from(history));
        }),
        'orphan history service reference': _snapshot((json) {
          (json['history'] as List).add(
            _history(serviceId: 'missing-service').toJson(),
          );
        }),
        'duplicate tire ID': _snapshot((json) {
          final tires = json['tires'] as List;
          tires[1]['id'] = tires.first['id'];
        }),
      };

      for (final entry in fixtures.entries) {
        expect(
          () => GarageSnapshot.fromJson(entry.value),
          throwsA(isA<FormatException>()),
          reason: entry.key,
        );
      }
    });

    test('rejects duplicate vehicle IDs in a collection', () {
      final collection = _collection().toJson();
      final vehicles = collection['vehicles'] as List;
      vehicles.add(Map<String, dynamic>.from(vehicles.first));

      expect(
        () => GarageCollection.fromJson(collection),
        throwsA(isA<FormatException>()),
      );
    });

    test('repository rejects corruption without writing over the raw payload', () async {
      final fixtures = <String, String>{
        'malformed JSON': '{not json',
        'malformed shape': jsonEncode(['not', 'a', 'garage']),
        'unknown service enum': jsonEncode(_snapshot((json) {
          (json['services'] as List).first['type'] = 'future-service-type';
        })),
        'duplicate vehicle ID': jsonEncode(() {
          final json = _collection().toJson();
          final vehicles = json['vehicles'] as List;
          vehicles.add(Map<String, dynamic>.from(vehicles.first));
          return json;
        }()),
        'orphan history reference': jsonEncode(_collectionWithOrphan().toJson()),
      };

      for (final entry in fixtures.entries) {
        final storage = _RecordingStorage(entry.value);
        await expectLater(
          GarageRepository(storage: storage).loadLegacySnapshot(),
          throwsA(isA<GarageDataException>()),
          reason: entry.key,
        );
        expect(storage.value, entry.value, reason: entry.key);
        expect(storage.writes, isEmpty, reason: entry.key);
      }
    });

    test('rejects corrupt backup data without replacing valid storage', () async {
      final valid = _collection();
      final storage = _RecordingStorage(jsonEncode(valid.toJson()));
      final envelope = jsonDecode(
        const GarageBackupCodec().encode(valid),
      ) as Map<String, dynamic>;
      final garage = envelope['garage'] as Map<String, dynamic>;
      final vehicles = garage['vehicles'] as List;
      vehicles.add(Map<String, dynamic>.from(vehicles.first));

      await expectLater(
        GarageRepository(storage: storage).importBackup(jsonEncode(envelope)),
        throwsA(isA<GarageBackupException>()),
      );
      expect(storage.value, jsonEncode(valid.toJson()));
      expect(storage.writes, isEmpty);
    });
  });
}

Map<String, dynamic> _snapshot(
  void Function(Map<String, dynamic>) mutate,
) {
  final json = GarageSnapshot.seeded(clock: () => DateTime.utc(2026)).toJson();
  mutate(json);
  return json;
}

GarageCollection _collection() => GarageCollection(
  vehicles: [
    VehicleProfile(
      id: 'vehicle-1',
      year: 2020,
      make: 'Toyota',
      model: 'Corolla',
      garage: GarageSnapshot.seeded(clock: () => DateTime.utc(2026)),
    ),
  ],
  selectedVehicleId: 'vehicle-1',
  defaultVehicleId: GarageCollection.lastUsedVehicleId,
);

GarageCollection _collectionWithOrphan() {
  final vehicle = _collection().vehicles.single;
  return GarageCollection(
    vehicles: [
      vehicle.copyWith(
        garage: GarageSnapshot(
          odometer: vehicle.garage.odometer,
          services: vehicle.garage.services,
          tires: vehicle.garage.tires,
          history: [_history(serviceId: 'missing-service')],
        ),
      ),
    ],
    selectedVehicleId: 'vehicle-1',
    defaultVehicleId: GarageCollection.lastUsedVehicleId,
  );
}

ServiceHistoryEntry _history({String serviceId = 'engine-oil'}) =>
    ServiceHistoryEntry(
      id: 'history-1',
      serviceId: serviceId,
      serviceName: 'Engine Oil',
      completedOdometer: 100,
      newNote: '',
      newIntervalKm: 1000,
      completedAt: DateTime.utc(2026),
    );

class _RecordingStorage implements GarageStorage {
  _RecordingStorage(this.value);

  String? value;
  final List<String> writes = [];

  @override
  Future<String?> read() async => value;

  @override
  Future<bool> write(String value) async {
    writes.add(value);
    this.value = value;
    return true;
  }
}
