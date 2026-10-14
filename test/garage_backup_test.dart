import 'dart:convert';

import 'package:app/data/garage_backup.dart';
import 'package:app/data/garage_repository.dart';
import 'package:app/models/service_item.dart';
import 'package:app/models/vehicle_profile.dart';
import 'package:flutter_test/flutter_test.dart';

GarageCollection _collection({int odometer = 1500}) => GarageCollection(
  vehicles: [
    VehicleProfile(
      id: 'v1',
      year: 2020,
      make: 'Toyota',
      model: 'Corolla',
      garage: GarageSnapshot(
        odometer: odometer,
        services: const [
          ServiceItem(
            id: 'oil',
            name: 'Engine Oil',
            note: '',
            serviceOdometer: 0,
            intervalKm: 1000,
            iconKey: 'maintenance',
          ),
        ],
        tires: const [],
        history: const [],
      ),
    ),
  ],
  selectedVehicleId: 'v1',
  defaultVehicleId: GarageCollection.lastUsedVehicleId,
);

void main() {
  group('GarageBackupCodec', () {
    test('encodes a versioned envelope with the wrapped collection', () {
      final exportedAt = DateTime.utc(2026, 10, 11, 17, 20);
      final encoded = const GarageBackupCodec().encode(
        _collection(),
        exportedAt: exportedAt,
      );

      final envelope = jsonDecode(encoded) as Map<String, dynamic>;
      expect(envelope['format'], GarageBackupFormat.id);
      expect(envelope['formatVersion'], GarageBackupFormat.currentVersion);
      expect(envelope['exportedAt'], exportedAt.toIso8601String());
      expect(envelope['garage'], isA<Map<String, dynamic>>());
      expect(
        (envelope['garage'] as Map<String, dynamic>)['schemaVersion'],
        2,
      );
    });

    test('round-trips a collection through encode and decode', () {
      const codec = GarageBackupCodec();
      final text = codec.encode(
        _collection(),
        exportedAt: DateTime.utc(2026),
      );

      final restored = codec.decode(text);

      expect(restored.vehicles, hasLength(1));
      expect(restored.vehicles.single.id, 'v1');
      expect(restored.vehicles.single.garage.odometer, 1500);
      expect(restored.vehicles.single.garage.services.single.name, 'Engine Oil');
      expect(restored.selectedVehicleId, 'v1');
    });

    test('migrates supported collection and nested snapshot schemas', () {
      final envelope = jsonDecode(
        const GarageBackupCodec().encode(_collection()),
      ) as Map<String, dynamic>;
      final garage = envelope['garage'] as Map<String, dynamic>;
      garage['schemaVersion'] = 1;
      garage.remove('defaultVehicleId');
      final vehicle = (garage['vehicles'] as List).single as Map<String, dynamic>;
      final snapshot = vehicle['garage'] as Map<String, dynamic>;
      snapshot['schemaVersion'] = 2;
      (snapshot['services'] as List).single.remove('units');

      final restored = const GarageBackupCodec().decode(jsonEncode(envelope));

      expect(restored.toJson(), _collection().toJson());
    });

    test('rejects a future nested snapshot schema without writing', () async {
      final storage = _FakeStorage(jsonEncode(_collection().toJson()));
      final envelope = jsonDecode(
        const GarageBackupCodec().encode(_collection()),
      ) as Map<String, dynamic>;
      final vehicle = ((envelope['garage'] as Map<String, dynamic>)['vehicles']
          as List).single as Map<String, dynamic>;
      (vehicle['garage'] as Map<String, dynamic>)['schemaVersion'] =
          GarageSnapshot.currentSchemaVersion + 1;

      expect(
        GarageRepository(storage: storage).importBackup(jsonEncode(envelope)),
        throwsA(isA<GarageBackupException>()),
      );
      expect(storage.writes, isEmpty);
    });

    test('rejects an empty payload', () {
      expect(
        () => const GarageBackupCodec().decode('   '),
        throwsA(
          isA<GarageBackupException>().having(
            (e) => e.failure,
            'failure',
            GarageBackupFailure.empty,
          ),
        ),
      );
    });

    test('rejects malformed JSON without leaking the parser error', () {
      expect(
        () => const GarageBackupCodec().decode('{not json'),
        throwsA(
          isA<GarageBackupException>().having(
            (e) => e.failure,
            'failure',
            GarageBackupFailure.malformed,
          ),
        ),
      );
    });

    test('rejects JSON that is not a garage backup', () {
      expect(
        () => const GarageBackupCodec().decode('{"format":"other","garage":{}}'),
        throwsA(
          isA<GarageBackupException>().having(
            (e) => e.failure,
            'failure',
            GarageBackupFailure.wrongFormat,
          ),
        ),
      );
    });

    test('rejects a backup from a future format version', () {
      expect(
        () => const GarageBackupCodec().decode(
          '{"format":"${GarageBackupFormat.id}","formatVersion":'
          '${GarageBackupFormat.currentVersion + 1},"garage":{}}',
        ),
        throwsA(
          isA<GarageBackupException>().having(
            (e) => e.failure,
            'failure',
            GarageBackupFailure.unsupportedVersion,
          ),
        ),
      );
    });

    test('rejects an envelope without garage data', () {
      expect(
        () => const GarageBackupCodec().decode(
          '{"format":"${GarageBackupFormat.id}","formatVersion":1}',
        ),
        throwsA(
          isA<GarageBackupException>().having(
            (e) => e.failure,
            'failure',
            GarageBackupFailure.invalidData,
          ),
        ),
      );
    });

    test('rejects an envelope with an invalid export time', () {
      expect(
        () => const GarageBackupCodec().decode(
          '{"format":"${GarageBackupFormat.id}","formatVersion":1,'
          '"exportedAt":"not-a-timestamp","garage":{}}',
        ),
        throwsA(
          isA<GarageBackupException>().having(
            (e) => e.failure,
            'failure',
            GarageBackupFailure.invalidData,
          ),
        ),
      );
    });

    test('rejects a structurally valid but invalid collection', () {
      final text = const GarageBackupCodec().encode(_collection());
      final envelope = jsonDecode(text) as Map<String, dynamic>;
      final garage = envelope['garage'] as Map<String, dynamic>;
      // Selects a vehicle id that does not exist in the backup.
      garage['selectedVehicleId'] = 'missing';

      expect(
        () => const GarageBackupCodec().decode(jsonEncode(envelope)),
        throwsA(
          isA<GarageBackupException>().having(
            (e) => e.failure,
            'failure',
            GarageBackupFailure.invalidData,
          ),
        ),
      );
    });
  });

  group('GarageRepository backup', () {
    test('export uses the injected clock and the stored collection', () async {
      final storage = _FakeStorage(
        jsonEncode(_collection().toJson()),
      );
      final repository = GarageRepository(
        storage: storage,
        clock: () => DateTime.utc(2026, 10, 11, 17, 20),
      );

      final text = await repository.exportBackup();

      final envelope = jsonDecode(text) as Map<String, dynamic>;
      expect(envelope['format'], GarageBackupFormat.id);
      expect(envelope['exportedAt'], '2026-10-11T17:20:00.000Z');
    });

    test('import validates then writes the restored collection', () async {
      final target = _FakeStorage(null);

      final text = const GarageBackupCodec().encode(
        _collection(),
        exportedAt: DateTime.utc(2026),
      );

      final restored = await GarageRepository(
        storage: target,
      ).importBackup(text);

      expect(restored.vehicles.single.id, 'v1');
      expect(target.writes, hasLength(1));
      final written = jsonDecode(target.writes.single) as Map<String, dynamic>;
      expect(written['schemaVersion'], 2);
    });

    test('import of invalid text writes nothing', () async {
      final storage = _FakeStorage(jsonEncode(_collection().toJson()));

      await expectLater(
        GarageRepository(storage: storage).importBackup('{not a backup'),
        throwsA(isA<GarageBackupException>()),
      );

      expect(storage.writes, isEmpty);
    });

    test(
      'import rejects a garage the loader would refuse and writes nothing',
      () async {
        final storage = _FakeStorage(null);
        final text = const GarageBackupCodec().encode(_collection());
        final envelope = jsonDecode(text) as Map<String, dynamic>;
        final garage = envelope['garage'] as Map<String, dynamic>;
        // Structurally fine, but the selected vehicle is unknown.
        garage['selectedVehicleId'] = 'gone';

        await expectLater(
          GarageRepository(storage: storage).importBackup(jsonEncode(envelope)),
          throwsA(isA<GarageBackupException>()),
        );
        expect(storage.writes, isEmpty);
      },
    );
  });
}

class _FakeStorage implements GarageStorage {
  _FakeStorage(this.value);

  String? value;
  final List<String> writes = [];

  @override
  Future<String?> read() async => value;

  @override
  Future<bool> write(String value) async {
    this.value = value;
    writes.add(value);
    return true;
  }
}
