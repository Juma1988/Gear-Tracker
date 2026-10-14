import 'dart:convert';

import 'package:app/data/data.dart';
import 'package:app/data/garage_repository.dart';
import 'package:app/models/service_history_entry.dart';
import 'package:app/models/service_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first run loads an empty collection without writing storage', () async {
    final storage = _Storage(null);
    final repository = GarageRepository(storage: storage);

    final collection = await repository.loadCollection();

    expect(collection.isEmpty, isTrue);
    expect(collection.vehicles, isEmpty);
    expect(storage.writes, isEmpty);
  });

  test(
    'classifies parse, storage, validation, migration, and write failures',
    () async {
      await expectLater(
        GarageRepository(storage: _Storage('{')).loadLegacySnapshot(),
        throwsA(
          isA<GarageDataException>().having(
            (e) => e.kind,
            'kind',
            GarageFailureKind.parse,
          ),
        ),
      );
      await expectLater(
        GarageRepository(storage: _Storage(null, readError: true)).loadLegacySnapshot(),
        throwsA(
          isA<GarageDataException>().having(
            (e) => e.kind,
            'kind',
            GarageFailureKind.storage,
          ),
        ),
      );
      await expectLater(
        GarageRepository(storage: _Storage(jsonEncode({'schemaVersion': 99})))
            .loadLegacySnapshot(),
        throwsA(
          isA<GarageDataException>().having(
            (e) => e.kind,
            'kind',
            GarageFailureKind.validation,
          ),
        ),
      );
      final invalidV2 = GarageSnapshot.seeded().toJson()..['schemaVersion'] = 2;
      (invalidV2['services'] as List).first['type'] = 'unknown';
      await expectLater(
        GarageRepository(storage: _Storage(jsonEncode(invalidV2))).loadLegacySnapshot(),
        throwsA(
          isA<GarageDataException>().having(
            (e) => e.kind,
            'kind',
            GarageFailureKind.migration,
          ),
        ),
      );
      await expectLater(
        GarageRepository(storage: _Storage(null, writeSucceeds: false))
            .save(GarageSnapshot.seeded()),
        throwsA(
          isA<GarageDataException>().having(
            (e) => e.kind,
            'kind',
            GarageFailureKind.write,
          ),
        ),
      );
    },
  );

  test(
    'migration backs up the original payload before writing upgraded data',
    () async {
      final original = GarageSnapshot.seeded().toJson()..['schemaVersion'] = 4;
      final storage = _Storage(jsonEncode(original));

      final loaded = await GarageRepository(storage: storage).loadLegacySnapshot();

      expect(loaded.odometer, int.parse(initialOdometer));
      expect(storage.preMigrationBackups, [jsonEncode(original)]);
      expect(
        storage.quarantined,
        isNull,
        reason: 'a valid older schema is not corruption',
      );
      expect(
        jsonDecode(storage.writes.single)['schemaVersion'],
        GarageSnapshot.currentSchemaVersion,
      );
    },
  );

  test(
    'failed migration backup preserves the original payload and reports a write failure',
    () async {
      final original = GarageSnapshot.seeded().toJson()..['schemaVersion'] = 4;
      final raw = jsonEncode(original);
      final storage = _Storage(raw, backupFails: true);

      await expectLater(
        GarageRepository(storage: storage).loadLegacySnapshot(),
        throwsA(
          isA<GarageDataException>()
              .having((e) => e.kind, 'kind', GarageFailureKind.write)
              .having((e) => e.rawPayload, 'raw payload', raw),
        ),
      );
      expect(storage.value, raw);
      expect(storage.preMigrationBackups, isEmpty);
      expect(storage.writes, isEmpty);
    },
  );

  test('failed migration quarantines the original payload and recovers safely', () async {
    final original = GarageSnapshot.seeded().toJson()..['schemaVersion'] = 2;
    (original['services'] as List).first['type'] = 'unknown';
    final raw = jsonEncode(original);
    final storage = _Storage(raw);

    final loaded = await GarageRepository(storage: storage).loadCollection();

    expect(loaded.isEmpty, isTrue);
    expect(storage.quarantined, raw);
    expect(storage.writes, isEmpty);
    expect(storage.preMigrationBackups, isEmpty);
  });

  test('quarantine failure retains a typed internal diagnostic', () async {
    const raw = '{';
    final storage = _Storage(raw, quarantineFails: true);

    await expectLater(
      GarageRepository(storage: storage).loadCollection(),
      throwsA(
        isA<GarageDataException>()
            .having((e) => e.kind, 'kind', GarageFailureKind.write)
            .having((e) => e.rawPayload, 'raw payload', raw),
      ),
    );
  });

  test('migrates every supported legacy schema version to v6', () async {
    for (final version in [2, 3, 4, 5]) {
      final original = GarageSnapshot.seeded().toJson()..['schemaVersion'] = version;
      final storage = _Storage(jsonEncode(original));

      final loaded = await GarageRepository(storage: storage).loadLegacySnapshot();

      expect(loaded.odometer, int.parse(initialOdometer), reason: 'v$version');
      expect(storage.preMigrationBackups, hasLength(1), reason: 'v$version');
      expect(
        storage.preMigrationBackups.single,
        jsonEncode(original),
        reason: 'v$version',
      );
      expect(storage.writes, hasLength(1), reason: 'v$version');
      expect(
        jsonDecode(storage.writes.single)['schemaVersion'],
        GarageSnapshot.currentSchemaVersion,
        reason: 'v$version',
      );
    }
  });

  test('collection migration backs up once before its primary write', () async {
    final original = GarageSnapshot.seeded().toJson()..['schemaVersion'] = 5;
    final storage = _Storage(jsonEncode(original));

    final loaded = await GarageRepository(storage: storage).loadCollection();

    expect(loaded.vehicles, hasLength(1));
    expect(storage.preMigrationBackups, [jsonEncode(original)]);
    expect(storage.writes, hasLength(1));
    expect(jsonDecode(storage.writes.single)['schemaVersion'], 2);
  });

  test('collection migration does not write when its backup fails', () async {
    final original = GarageSnapshot.seeded().toJson()..['schemaVersion'] = 5;
    final storage = _Storage(jsonEncode(original), backupFails: true);

    await expectLater(
      GarageRepository(storage: storage).loadCollection(),
      throwsA(
        isA<GarageDataException>().having(
          (error) => error.kind,
          'kind',
          GarageFailureKind.write,
        ),
      ),
    );

    expect(storage.writes, isEmpty);
    expect(storage.preMigrationBackups, isEmpty);
    expect(storage.value, jsonEncode(original));
  });

  test('rejects invalid collections, duplicate history, orphan history, and nonchronological history', () {
    final snapshot = GarageSnapshot.seeded();
    final collection = {
      'schemaVersion': 2,
      'selectedVehicleId': 'missing',
      'defaultVehicleId': GarageCollection.lastUsedVehicleId,
      'vehicles': [],
    };
    expect(() => GarageCollection.fromJson(collection), throwsFormatException);

    final history = ServiceHistoryEntry(
      id: 'event',
      serviceId: 'engine-oil',
      serviceName: 'Engine Oil',
      previousServiceOdometer: 1,
      completedOdometer: 2,
        newNote: 'note',
        newIntervalKm: 1,
        completedAt: DateTime(2026),
    );
    expect(
      () => GarageSnapshot(
        odometer: snapshot.odometer,
        services: snapshot.services,
        tires: snapshot.tires,
        history: [history, history],
      ).validate(),
      throwsFormatException,
    );
    expect(
      () => GarageSnapshot(
        odometer: snapshot.odometer,
        services: snapshot.services,
        tires: snapshot.tires,
        history: [history.copyWithServiceId('missing')],
      ).validate(),
      throwsFormatException,
    );
  });

  test(
    'requires exact tracking-mode fields and canonical shelf-life fields',
    () {
      final base = GarageSnapshot.seeded().toJson();
      final service = (base['services'] as List).first as Map<String, dynamic>;
      service.remove('intervalKm');
      expect(() => GarageSnapshot.fromJson(base), throwsFormatException);

      final shelf = GarageSnapshot.seeded().toJson();
      final shelfService =
          (shelf['services'] as List).first as Map<String, dynamic>;
      shelfService['hasShelfLife'] = true;
      expect(() => GarageSnapshot.fromJson(shelf), throwsFormatException);
    },
  );

  test('persists valid tracking modes and rejects invalid field combinations', () {
    final mileageOnly = GarageSnapshot.seeded().toJson();
    final timeOnly = GarageSnapshot.seeded().toJson();
    final combined = GarageSnapshot.seeded().toJson();
    final timeService = (timeOnly['services'] as List).first
        as Map<String, dynamic>;
    final combinedService = (combined['services'] as List).first
        as Map<String, dynamic>;

    timeService
      ..remove('serviceOdometer')
      ..remove('intervalKm')
      ..['installDate'] = '2026-01-01T00:00:00.000'
      ..['shelfLifeMonths'] = 12;
    combinedService
      ..['installDate'] = '2026-01-01T00:00:00.000'
      ..['shelfLifeMonths'] = 12;

    expect(GarageSnapshot.fromJson(mileageOnly).services.single.tracksMileage, isTrue);
    expect(GarageSnapshot.fromJson(mileageOnly).services.single.tracksTime, isFalse);
    expect(GarageSnapshot.fromJson(timeOnly).services.single.tracksMileage, isFalse);
    expect(GarageSnapshot.fromJson(timeOnly).services.single.tracksTime, isTrue);
    expect(GarageSnapshot.fromJson(combined).services.single.tracksMileage, isTrue);
    expect(GarageSnapshot.fromJson(combined).services.single.tracksTime, isTrue);

    final missingMileagePair = GarageSnapshot.seeded().toJson();
    (missingMileagePair['services'] as List).first.remove('intervalKm');
    final shelfLifeWithoutDate = GarageSnapshot.seeded().toJson();
    final shelfLifeService = (shelfLifeWithoutDate['services'] as List).first
        as Map<String, dynamic>;
    shelfLifeService
      ..remove('serviceOdometer')
      ..remove('intervalKm')
      ..remove('installDate')
      ..['shelfLifeMonths'] = 12;
    final noTrackingMode = GarageSnapshot.seeded().toJson();
    final noTrackingService = (noTrackingMode['services'] as List).first
        as Map<String, dynamic>;
    noTrackingService
      ..remove('serviceOdometer')
      ..remove('intervalKm');

    expect(() => GarageSnapshot.fromJson(missingMileagePair), throwsFormatException);
    expect(() => GarageSnapshot.fromJson(shelfLifeWithoutDate), throwsFormatException);
    expect(() => GarageSnapshot.fromJson(noTrackingMode), throwsFormatException);
  });

  test(
    'repository save and reload preserves mileage, time, and combined tracking modes',
    () async {
      final storage = _Storage(null);
      final repository = GarageRepository(storage: storage);
      const mileageOnly = ServiceItem(
        id: 'mileage-only',
        name: 'Mileage only',
        note: 'Oil',
        serviceOdometer: 71000,
        intervalKm: 10000,
        iconKey: 'oil',
      );
      final timeOnly = ServiceItem(
        id: 'time-only',
        name: 'Time only',
        note: 'Brake fluid',
        iconKey: 'brake_fluid',
        installDate: DateTime(2026, 2, 3),
        shelfLifeMonths: 24,
      );
      final combined = ServiceItem(
        id: 'combined',
        name: 'Combined',
        note: 'Battery',
        serviceOdometer: 70000,
        intervalKm: 60000,
        iconKey: 'battery',
        installDate: DateTime(2026, 1, 2),
        shelfLifeMonths: 36,
      );

      await repository.save(
        GarageSnapshot(
          odometer: 75000,
          services: [mileageOnly, timeOnly, combined],
          tires: const [],
          history: const [],
        ),
      );
      final reloaded = await GarageRepository(storage: storage).loadLegacySnapshot();

      final restoredMileage = reloaded.services.singleWhere(
        (service) => service.id == mileageOnly.id,
      );
      final restoredTime = reloaded.services.singleWhere(
        (service) => service.id == timeOnly.id,
      );
      final restoredCombined = reloaded.services.singleWhere(
        (service) => service.id == combined.id,
      );
      expect(restoredMileage.tracksMileage, isTrue);
      expect(restoredMileage.tracksTime, isFalse);
      expect(restoredTime.tracksMileage, isFalse);
      expect(restoredTime.tracksTime, isTrue);
      expect(restoredTime.serviceOdometer, isNull);
      expect(restoredTime.intervalKm, isNull);
      expect(restoredCombined.tracksMileage, isTrue);
      expect(restoredCombined.tracksTime, isTrue);
    },
  );

  test(
    'repository reload preserves a time-only completion and immutable history snapshot after schedule edit',
    () async {
      final storage = _Storage(null);
      final repository = GarageRepository(storage: storage);
      final completedAt = DateTime(2026, 10, 10);
      final completedService = ServiceItem(
        id: 'brake-fluid',
        name: 'Brake Fluid',
        note: 'DOT 4',
        iconKey: 'brake_fluid',
        installDate: completedAt,
        shelfLifeMonths: 24,
      );
      final completion = ServiceHistoryEntry(
        id: 'service-completion-1',
        serviceId: completedService.id,
        serviceName: completedService.name,
        newNote: completedService.note,
        completedAt: completedAt,
      );
      await repository.save(
        GarageSnapshot(
          odometer: 75000,
          services: [completedService],
          tires: const [],
          history: [completion],
        ),
      );
      final afterCompletionReload =
          await GarageRepository(storage: storage).loadLegacySnapshot();
      final persistedCompletion = afterCompletionReload.history.single;
      expect(persistedCompletion.previousServiceOdometer, isNull);
      expect(persistedCompletion.completedOdometer, isNull);
      expect(persistedCompletion.newIntervalKm, isNull);
      expect(persistedCompletion.completedAt, completedAt);

      final editedSchedule = afterCompletionReload.services.single.copyWith(
        note: 'DOT 5.1',
        installDate: DateTime(2026, 10, 11),
        shelfLifeMonths: 36,
      );
      await repository.save(
        GarageSnapshot(
          odometer: afterCompletionReload.odometer,
          services: [editedSchedule],
          tires: afterCompletionReload.tires,
          history: afterCompletionReload.history,
        ),
      );
      final afterEditReload = await GarageRepository(storage: storage).loadLegacySnapshot();

      expect(afterEditReload.services.single.note, 'DOT 5.1');
      expect(afterEditReload.services.single.shelfLifeMonths, 36);
      final immutableHistory = afterEditReload.history.single;
      expect(immutableHistory.newNote, 'DOT 4');
      expect(immutableHistory.completedAt, completedAt);
      expect(immutableHistory.previousServiceOdometer, isNull);
      expect(immutableHistory.completedOdometer, isNull);
      expect(immutableHistory.newIntervalKm, isNull);
    },
  );

  test(
    'schedule edits preserve every mileage completion snapshot field',
    () async {
      final storage = _Storage(null);
      final repository = GarageRepository(storage: storage);
      final completedAt = DateTime(2026, 10, 10);
      const completedService = ServiceItem(
        id: 'engine-oil',
        name: 'Engine Oil',
        note: '0W-20 synthetic',
        serviceOdometer: 70000,
        intervalKm: 10000,
        iconKey: 'oil',
      );
      final completion = ServiceHistoryEntry(
        id: 'service-completion-mileage-1',
        serviceId: completedService.id,
        serviceName: completedService.name,
        previousServiceOdometer: completedService.serviceOdometer,
        completedOdometer: 75500,
        newNote: completedService.note,
        newIntervalKm: completedService.intervalKm,
        completedAt: completedAt,
      );
      await repository.save(
        GarageSnapshot(
          odometer: 75500,
          services: [completedService],
          tires: const [],
          history: [completion],
        ),
      );

      final loaded = await repository.loadLegacySnapshot();
      final editedSchedule = loaded.services.single.copyWith(
        name: 'Premium Engine Oil',
        note: '5W-30 synthetic',
        serviceOdometer: 75500,
        intervalKm: 15000,
      );
      await repository.save(
        GarageSnapshot(
          odometer: loaded.odometer,
          services: [editedSchedule],
          tires: loaded.tires,
          history: loaded.history,
        ),
      );

      final afterEdit = await repository.loadLegacySnapshot();
      final history = afterEdit.history.single;
      expect(history.serviceId, completedService.id);
      expect(history.serviceName, completedService.name);
      expect(history.previousServiceOdometer, 70000);
      expect(history.completedOdometer, 75500);
      expect(history.newNote, completedService.note);
      expect(history.newIntervalKm, 10000);
      expect(history.completedAt, completedAt);
    },
  );

  test('rejects completion history without a date', () {
    final json = GarageSnapshot.seeded().toJson();
    (json['history'] as List).add({
      'id': 'undated-completion',
      'serviceId': 'engine-oil',
      'serviceName': 'Engine Oil',
      'newNote': '5W-40 SYN',
    });

    expect(() => GarageSnapshot.fromJson(json), throwsFormatException);
  });
}

extension on ServiceHistoryEntry {
  ServiceHistoryEntry copyWithServiceId(String serviceId) =>
      ServiceHistoryEntry(
        id: id,
        serviceId: serviceId,
        serviceName: serviceName,
        previousServiceOdometer: previousServiceOdometer,
        completedOdometer: completedOdometer,
        newNote: newNote,
        newIntervalKm: newIntervalKm,
        completedAt: completedAt,
      );
}

class _Storage implements GarageStorage, GarageQuarantineStorage, GarageBackupStorage {
  _Storage(
    this.value, {
    this.readError = false,
    this.writeSucceeds = true,
    this.backupFails = false,
    this.quarantineFails = false,
  });
  String? value;
  final bool readError;
  final bool writeSucceeds;
  final bool backupFails;
  final bool quarantineFails;
  final List<String> writes = [];
  String? quarantined;
  final List<String> preMigrationBackups = [];

  @override
  Future<String?> read() async {
    if (readError) throw StateError('unavailable');
    return value;
  }

  @override
  Future<bool> write(String value) async {
    if (!writeSucceeds) return false;
    this.value = value;
    writes.add(value);
    return true;
  }

  @override
  Future<void> quarantine(String rawPayload) async {
    if (quarantineFails) throw StateError('quarantine unavailable');
    quarantined = rawPayload;
  }

  @override
  Future<void> backupBeforeMigration(String rawPayload) async {
    if (backupFails) throw StateError('backup unavailable');
    preMigrationBackups.add(rawPayload);
  }
}
