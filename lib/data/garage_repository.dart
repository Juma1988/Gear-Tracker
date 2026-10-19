import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/vehicle_profile.dart';
import 'garage_backup.dart';
import 'garage_storage.dart';

export 'garage_storage.dart';

class SharedPreferencesGarageStorage
    implements GarageStorage, GarageQuarantineStorage, GarageBackupStorage {
  static const _key = 'garage_snapshot_v1';
  static const _quarantineKey = 'garage_snapshot_quarantine_v1';
  static const _preMigrationBackupKey =
      'garage_snapshot_premigration_backup_v1';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<bool> write(String value) async =>
      (await SharedPreferences.getInstance()).setString(_key, value);

  @override
  Future<void> quarantine(String rawPayload) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(_quarantineKey, rawPayload)) {
      throw StateError('Garage payload was not quarantined');
    }
  }

  @override
  Future<void> backupBeforeMigration(String rawPayload) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(_preMigrationBackupKey, rawPayload)) {
      throw StateError('Garage payload was not backed up');
    }
  }
}

class GarageRepository {
  GarageRepository({GarageStorage? storage, DateTime Function()? clock})
    : _storage = storage ?? SharedPreferencesGarageStorage(),
      _now = clock ?? DateTime.now;

  final GarageStorage _storage;
  final DateTime Function() _now;

  Future<void> _writeChain = Future<void>.value();
  int _revision = 0;

  /// Number of successful writes this repository instance has performed.
  ///
  /// Used with the [saveCollection] `expectedRevision` guard so a caller holding
  /// an out-of-date snapshot is rejected instead of silently reverting newer data.
  int get revision => _revision;

  /// Serializes the whole garage into the versioned backup envelope.
  ///
  /// Reads through [loadCollection] so an outgoing backup is always a payload
  /// this build can read back.
  Future<String> exportBackup() async {
    final collection = await loadCollection();
    return const GarageBackupCodec().encode(
      collection,
      exportedAt: _now().toUtc(),
    );
  }

  /// Validates an imported backup and only then applies it.
  ///
  /// [GarageBackupCodec.decode] performs full structural and integrity
  /// validation (duplicate ids, orphaned history, unsupported schemas) before
  /// anything is written, so a rejected import leaves the garage untouched.
  Future<GarageCollection> importBackup(String text) async {
    final collection = const GarageBackupCodec().decode(text);
    await saveCollection(collection);
    return collection;
  }

  /// Legacy single-garage view over the stored payload.
  ///
  /// This is the *old* read shape (`GarageSnapshot` for one vehicle). It exists
  /// only to bridge pre-collection payloads into [loadCollection], which is the
  /// single read API production code uses. Call it from the legacy path or from
  /// tests that assert the legacy schema/migration contract — not from screens.
  Future<GarageSnapshot> loadLegacySnapshot() async {
    final raw = await _read();
    if (raw == null) return GarageSnapshot.empty();
    final json = _decode(raw);
    try {
      if (json.containsKey('vehicles')) {
        final collection = GarageCollection.fromJson(json);
        if (collection.vehicles.isEmpty) return GarageSnapshot.empty();
        return collection.selectedVehicle.garage;
      }
      final snapshot = await _loadLegacySnapshot(raw, persistMigration: true);
      return snapshot;
    } on GarageDataException {
      rethrow;
    } on FormatException catch (error) {
      final schemaVersion = json['schemaVersion'];
      final needsMigration =
          schemaVersion is int &&
          schemaVersion >= 2 &&
          schemaVersion < GarageSnapshot.currentSchemaVersion;
      final kind = needsMigration
          ? GarageFailureKind.migration
          : GarageFailureKind.validation;
      throw GarageDataException(
        kind,
        error.message,
        rawPayload: raw,
        cause: error,
      );
    } catch (error) {
      throw GarageDataException(
        GarageFailureKind.migration,
        'Garage migration failed',
        rawPayload: raw,
        cause: error,
      );
    }
  }

  Future<void> save(GarageSnapshot snapshot) async {
    try {
      snapshot.validate();
    } on GarageDataException {
      rethrow;
    } on FormatException catch (error) {
      throw GarageDataException(
        GarageFailureKind.validation,
        error.message,
        cause: error,
      );
    }
    try {
      final saved = await _storage.write(
        jsonEncode(_stamped(snapshot).toJson()),
      );
      if (!saved) throw StateError('Garage snapshot was not saved');
    } catch (error) {
      throw GarageDataException(
        GarageFailureKind.write,
        'Garage snapshot was not saved',
        cause: error,
      );
    }
  }

  Future<GarageCollection> loadCollection() async {
    final raw = await _read();
    if (raw == null) {
      return const GarageCollection(
        vehicles: [],
        selectedVehicleId: '',
        defaultVehicleId: GarageCollection.lastUsedVehicleId,
      );
    }
    try {
      final json = _decode(raw);
      if (json.containsKey('vehicles')) {
        final needsMigration =
            json['schemaVersion'] != 2 ||
            (json['vehicles'] as List).any(
              (v) =>
                  (v as Map)['garage']['schemaVersion'] !=
                  GarageSnapshot.currentSchemaVersion,
            );
        final collection = needsMigration
            ? GarageCollection.migrate(json)
            : GarageCollection.fromJson(json);
        if (needsMigration) {
          await _backupBeforeMigration(raw);
          await saveCollection(collection);
        }
        return collection;
      }
      // Parse the legacy payload without persisting its intermediate snapshot.
      // The collection migration must back up the original before its first
      // primary write; loadLegacySnapshot's compatibility behavior cannot be
      // used here because it writes the legacy form first.
      final legacy = await _loadLegacySnapshot(raw, persistMigration: false);
      final migrated = _collectionFromLegacy(legacy);
      await _backupBeforeMigration(raw);
      await saveCollection(migrated);
      return migrated;
    } on GarageDataException catch (error) {
      if (error.kind != GarageFailureKind.parse &&
          error.kind != GarageFailureKind.validation &&
          error.kind != GarageFailureKind.migration) {
        rethrow;
      }
      await _quarantine(raw);
      return const GarageCollection(
        vehicles: [],
        selectedVehicleId: '',
        defaultVehicleId: GarageCollection.lastUsedVehicleId,
      );
    } on FormatException {
      await _quarantine(raw);
      return const GarageCollection(
        vehicles: [],
        selectedVehicleId: '',
        defaultVehicleId: GarageCollection.lastUsedVehicleId,
      );
    } catch (error) {
      throw GarageDataException(
        GarageFailureKind.write,
        'Garage data was not saved',
        rawPayload: raw,
        cause: error,
      );
    }
  }

  Future<GarageSnapshot> _loadLegacySnapshot(
    String raw, {
    required bool persistMigration,
  }) async {
    final json = _decode(raw);
    final schemaVersion = json['schemaVersion'];
    final needsMigration =
        schemaVersion is int &&
        schemaVersion >= 2 &&
        schemaVersion < GarageSnapshot.currentSchemaVersion;
    final snapshot = needsMigration
        ? GarageSnapshot.migrate(json)
        : GarageSnapshot.fromJson(json);
    if (needsMigration && persistMigration) {
      await _persistLegacyMigration(raw, snapshot);
    }
    return snapshot;
  }

  Future<void> _persistLegacyMigration(
    String raw,
    GarageSnapshot snapshot,
  ) async {
    await _backupBeforeMigration(raw);
    await save(snapshot);
  }

  /// Exception-free boundary for UI callers; preserves [loadCollection]'s
  /// existing recovery behavior and exposes no raw payload or cause.
  Future<GarageResult<GarageCollection>> loadCollectionResult() async {
    try {
      return GarageSuccess(await loadCollection());
    } on GarageDataException catch (error) {
      return GarageFailure(error.kind);
    } catch (_) {
      return const GarageFailure(GarageFailureKind.storage);
    }
  }

  /// Enqueues a whole-snapshot write so overlapping saves cannot interleave.
  ///
  /// Several dashboard paths write asynchronously (odometer debounce, service
  /// edit, completion, reminder sync). Without ordering, two in-flight writes
  /// could land out of order and silently revert the newer one. Writes are
  /// therefore chained: each save starts after the previous one has finished,
  /// and a failed write never blocks or corrupts the ones queued behind it.
  ///
  /// Pass [expectedRevision] to opt into an optimistic-concurrency check: when
  /// it does not match the current [revision], the save is rejected with
  /// [GarageConflictException] and nothing is written.
  Future<void> saveCollection(
    GarageCollection collection, {
    int? expectedRevision,
  }) {
    final next = _writeChain.then((_) async {
      if (expectedRevision != null && expectedRevision != _revision) {
        throw GarageConflictException(
          expectedRevision: expectedRevision,
          actualRevision: _revision,
        );
      }
      await _writeCollection(collection);
      _revision++;
    });
    // Keep the queue chain error-free so one failure cannot poison later saves,
    // while still surfacing the failure to the caller that awaited [next].
    _writeChain = next.then((_) {}, onError: (_) {});
    return next;
  }

  /// Exception-free boundary for UI callers; the throwing API remains
  /// available to domain code and existing integrations.
  Future<GarageResult<void>> saveCollectionResult(
    GarageCollection collection, {
    int? expectedRevision,
  }) async {
    try {
      await saveCollection(collection, expectedRevision: expectedRevision);
      return const GarageSuccess(null);
    } on GarageDataException catch (error) {
      return GarageFailure(error.kind);
    } catch (_) {
      return const GarageFailure(GarageFailureKind.write);
    }
  }

  Future<void> _writeCollection(GarageCollection collection) async {
    final stamped = collection.copyWith(
      vehicles: [
        for (final vehicle in collection.vehicles)
          vehicle.copyWith(garage: _stamped(vehicle.garage)),
      ],
    );
    try {
      stamped.validate();
      // Persisting a payload the loader would reject (for example, a history
      // entry whose service no longer exists) traps the dashboard in a
      // permanent load failure. Validate the full snapshot for every vehicle
      // so no code path can write data the loader will refuse to read.
      for (final vehicle in stamped.vehicles) {
        vehicle.garage.validate();
      }
    } on FormatException catch (error) {
      throw GarageDataException(
        GarageFailureKind.validation,
        error.message,
        cause: error,
      );
    }
    try {
      final saved = await _storage.write(jsonEncode(stamped.toJson()));
      if (!saved) throw StateError('Garage collection was not saved');
    } catch (error) {
      throw GarageDataException(
        GarageFailureKind.write,
        'Garage collection was not saved',
        cause: error,
      );
    }
  }

  GarageSnapshot _stamped(GarageSnapshot snapshot) => GarageSnapshot(
    odometer: snapshot.odometer,
    services: snapshot.services,
    tires: snapshot.tires,
    history: snapshot.history,
    fuelEntries: snapshot.fuelEntries,
    lastUpdatedAt: _now().toUtc(),
  );

  Future<String?> _read() async {
    try {
      return await _storage.read();
    } catch (error) {
      throw GarageDataException(
        GarageFailureKind.storage,
        'Garage storage could not be read',
        cause: error,
      );
    }
  }

  Map<String, dynamic> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('Garage payload is not an object');
      }
      return Map<String, dynamic>.from(decoded);
    } catch (error) {
      throw GarageDataException(
        GarageFailureKind.parse,
        'Garage payload is not valid JSON',
        rawPayload: raw,
        cause: error,
      );
    }
  }

  Future<void> _quarantine(String raw) async {
    if (_storage case final GarageQuarantineStorage storage) {
      try {
        await storage.quarantine(raw);
      } catch (error) {
        throw GarageDataException(
          GarageFailureKind.write,
          'Garage payload could not be quarantined',
          rawPayload: raw,
          cause: error,
        );
      }
    }
  }

  /// Preserves the pre-migration payload so an upgrade never discards the
  /// original data, even if the upgraded form later turns out to be unusable.
  Future<void> _backupBeforeMigration(String raw) async {
    if (_storage case final GarageBackupStorage storage) {
      try {
        await storage.backupBeforeMigration(raw);
      } catch (error) {
        throw GarageDataException(
          GarageFailureKind.write,
          'Garage payload was not backed up before migration',
          rawPayload: raw,
          cause: error,
        );
      }
    }
  }

  GarageCollection _collectionFromLegacy(GarageSnapshot legacy) {
    const id = '2022-golf-gti';
    final bound = GarageSnapshot.fromJson({
      ...legacy.toJson(),
      'fuelEntries': legacy.fuelEntries
          .map((e) => e.withOwnership(id).toJson())
          .toList(),
    });
    final vehicle = VehicleProfile(
      id: id,
      year: 2022,
      make: 'Volkswagen',
      model: 'Golf GTI',
      garage: bound,
    );
    return GarageCollection(
      vehicles: [vehicle],
      selectedVehicleId: id,
      defaultVehicleId: GarageCollection.lastUsedVehicleId,
    );
  }
}
