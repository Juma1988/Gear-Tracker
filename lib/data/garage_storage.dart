/// Storage-format boundary for the garage.
///
/// This module owns the storage concerns that used to sit inside
/// `garage_repository.dart`: the versioned snapshot/collection envelopes,
/// the schema-migration ladder, the typed storage failures, and the storage
/// adapter interfaces. The repository layer above it only orchestrates reads,
/// writes, backup, migration backup, and quarantine.
///
/// Domain models live in `lib/models` and stay free of repository concerns;
/// their `toJson`/`fromJson` projections are the wire shape this module
/// encodes, migrates, and validates.
library;

import '../models/service_history_entry.dart';
import '../models/service_item.dart';
import '../models/tire_item.dart';
import '../models/vehicle_profile.dart';
import 'data.dart';

class GarageSnapshot {
  static const currentSchemaVersion = 7;
  const GarageSnapshot({
    required this.odometer,
    required this.services,
    required this.tires,
    required this.history,
    this.lastUpdatedAt,
  });

  final int odometer;
  final List<ServiceItem> services;
  final List<TireItem> tires;
  final List<ServiceHistoryEntry> history;

  /// The last time this snapshot was successfully persisted locally.
  ///
  /// This is storage freshness, not a maintenance/install/completion date.
  /// It is nullable so older payloads remain honest rather than inventing a
  /// timestamp during migration.
  final DateTime? lastUpdatedAt;

  factory GarageSnapshot.empty() =>
      const GarageSnapshot(odometer: 0, services: [], tires: [], history: []);

  /// Legacy fixture only. Production first launch uses [empty].
  factory GarageSnapshot.seeded({DateTime Function()? clock}) {
    final now = (clock ?? DateTime.now)();
    return GarageSnapshot(
      odometer: int.parse(initialOdometer),
      services: List.of(initialServices),
      tires: initialTiresForOdometer(int.parse(initialOdometer), now: now),
      history: const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': currentSchemaVersion,
    'odometer': odometer,
    'services': services.map((item) => item.toJson()).toList(),
    'tires': tires.map((item) => item.toJson()).toList(),
    'history': history.map((entry) => entry.toJson()).toList(),
    if (lastUpdatedAt != null) 'lastUpdatedAt': lastUpdatedAt!.toUtc().toIso8601String(),
  };

  factory GarageSnapshot.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion != currentSchemaVersion) {
      throw const FormatException('Unsupported garage snapshot schema');
    }
    final odometer = _requiredInt(json, 'odometer', min: 0, max: 999999);
    final services = _objectList(
      json,
      'services',
    ).map(ServiceItem.fromJson).toList(growable: false);
    final tires = _objectList(
      json,
      'tires',
    ).map(TireItem.fromJson).toList(growable: false);
    final history = _objectList(
      json,
      'history',
    ).map(ServiceHistoryEntry.fromJson).toList(growable: false);
    final lastUpdatedAt = _optionalTimestamp(json, 'lastUpdatedAt');

    final snapshot = GarageSnapshot(
      odometer: odometer,
      services: services,
      tires: tires,
      history: history,
      lastUpdatedAt: lastUpdatedAt,
    );
    snapshot.validate();
    return snapshot;
  }

  static GarageSnapshot migrate(Map<String, dynamic> json) {
    final migrated = Map<String, dynamic>.from(json);
    final schemaVersion = migrated['schemaVersion'];
    if (schemaVersion is! int ||
        schemaVersion < 2 ||
        schemaVersion >= currentSchemaVersion) {
      throw const FormatException('Unsupported garage snapshot schema');
    }
    migrated['schemaVersion'] = currentSchemaVersion;
    final services = _objectList(migrated, 'services');
    migrated['services'] = services
        .map((service) {
          final type = ServiceType.fromJson(service['type']);
          if (type == ServiceType.type02 && service['units'] == null) {
            final installOdometer = service['serviceOdometer'];
            if (installOdometer is! int) {
              throw const FormatException('Invalid serviceOdometer');
            }
            return {
              ...service,
              'units': [
                for (final position in ServiceUnit.positions)
                  {'position': position, 'installOdometer': installOdometer},
              ],
            };
          }
          return service;
        })
        .toList(growable: false);
    return GarageSnapshot.fromJson(migrated);
  }

  void validate() {
    final serviceIds = services.map((service) => service.id).toSet();
    final historyIds = history.map((entry) => entry.id).toSet();
    if (services.map((service) => service.id).toSet().length !=
            services.length ||
        services.any(
          (service) =>
              service.id.trim().isEmpty ||
              service.name.trim().isEmpty ||
              service.iconKey.trim().isEmpty ||
              (service.serviceOdometer != null) !=
                  (service.intervalKm != null) ||
              (service.shelfLifeMonths != null &&
                  service.installDate == null) ||
              (service.hasShelfLife && service.shelfLifeMonths == null) ||
              (service.tracksMileage &&
                  (service.serviceOdometer! < 0 ||
                      service.serviceOdometer! > 999999 ||
                      service.intervalKm! <= 0)) ||
              (!service.tracksMileage && !service.tracksTime) ||
              (service.tracksTime && service.shelfLifeMonths! <= 0) ||
              (service.type == ServiceType.type02 && !service.tracksMileage) ||
              (service.type == ServiceType.type02 &&
                  (service.units.length != ServiceUnit.positions.length ||
                      service.units
                              .map((unit) => unit.position)
                              .toSet()
                              .length !=
                          ServiceUnit.positions.length ||
                      !service.units
                          .map((unit) => unit.position)
                          .toSet()
                          .containsAll(ServiceUnit.positions) ||
                      service.units.any(
                        (unit) =>
                            unit.installOdometer < 0 ||
                            unit.installOdometer > 999999,
                      ))),
        ) ||
        (tires.isNotEmpty &&
            (tires.length != TireItem.positionIds.length ||
                tires.map((tire) => tire.id).toSet().length != tires.length ||
                !tires
                    .map((tire) => tire.id)
                    .toSet()
                    .containsAll(TireItem.positionIds))) ||
        tires.any(
          (tire) =>
              tire.id.trim().isEmpty ||
              tire.code.trim().isEmpty ||
              tire.installOdometer < 0 ||
              tire.installOdometer > 999999 ||
              tire.intervalKm <= 0 ||
              (tire.shelfLifeMonths != null && tire.shelfLifeMonths! <= 0),
        ) ||
        history.any(
          (entry) =>
              entry.id.trim().isEmpty ||
              entry.serviceId.trim().isEmpty ||
              entry.serviceName.trim().isEmpty ||
              (entry.previousServiceOdometer != null &&
                  entry.previousServiceOdometer! < 0) ||
              (entry.completedOdometer != null &&
                  entry.completedOdometer! < 0) ||
              (entry.newIntervalKm != null && entry.newIntervalKm! <= 0) ||
              (entry.completedOdometer != null &&
                  entry.previousServiceOdometer != null &&
                  entry.completedOdometer! < entry.previousServiceOdometer!) ||
              !serviceIds.contains(entry.serviceId),
        )) {
      throw const FormatException('Invalid garage snapshot data');
    }
    if (historyIds.length != history.length) {
      throw const FormatException('Duplicate history ID');
    }
    for (var index = 1; index < history.length; index++) {
      final current = history[index].completedAt;
      final previous = history[index - 1].completedAt;
      if (current.isBefore(previous)) {
        throw const FormatException('History is not chronological');
      }
    }
  }

  static int _requiredInt(
    Map<String, dynamic> json,
    String key, {
    required int min,
    required int max,
  }) {
    final value = json[key];
    if (value is! int || value < min || value > max) {
      throw FormatException('Invalid $key');
    }
    return value;
  }

  static DateTime? _optionalTimestamp(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) throw FormatException('Invalid $key');
    try {
      return DateTime.parse(value).toUtc();
    } on FormatException {
      throw FormatException('Invalid $key');
    }
  }

  static List<Map<String, dynamic>> _objectList(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value is! List) throw FormatException('Invalid $key');
    return value
        .map((item) {
          if (item is! Map) throw FormatException('Invalid $key entry');
          return Map<String, dynamic>.from(item);
        })
        .toList(growable: false);
  }
}

abstract interface class GarageStorage {
  Future<String?> read();
  Future<bool> write(String value);
}

abstract interface class GarageQuarantineStorage {
  Future<void> quarantine(String rawPayload);
}

/// Preserves a convertible payload before a schema migration rewrites it.
///
/// Unlike quarantining, this is not a failure path: the payload is valid, it is
/// simply stored in an older schema. Keeping the original makes an upgrade
/// diagnosable and reversible without weakening the corruption safeguards.
abstract interface class GarageBackupStorage {
  Future<void> backupBeforeMigration(String rawPayload);
}

enum GarageFailureKind {
  firstRun,
  parse,
  migration,
  validation,
  storage,
  write,

  /// A write was rejected because the stored garage changed after the caller
  /// read it (optimistic concurrency check).
  conflict,
}

class GarageDataException extends FormatException {
  GarageDataException(this.kind, String message, {this.rawPayload, this.cause})
    : super(message);

  final GarageFailureKind kind;
  final String? rawPayload;
  final Object? cause;
}

/// A user-safe repository outcome. Diagnostics remain on [GarageDataException]
/// for callers that use the throwing APIs; this type exposes only the failure
/// kind needed to choose a UI state.
sealed class GarageResult<T> {
  const GarageResult();
}

final class GarageSuccess<T> extends GarageResult<T> {
  const GarageSuccess(this.value);

  final T value;
}

final class GarageFailure<T> extends GarageResult<T> {
  const GarageFailure(this.kind);

  final GarageFailureKind kind;
}

/// Raised when a guarded write is rejected because another write already
/// advanced the stored garage past the revision the caller read.
class GarageConflictException extends GarageDataException {
  GarageConflictException({
    required this.expectedRevision,
    required this.actualRevision,
  }) : super(
         GarageFailureKind.conflict,
         'Garage changed since it was read',
       );

  final int expectedRevision;
  final int actualRevision;
}

class GarageCollection {
  static const currentSchemaVersion = 2;
  static const lastUsedVehicleId = '__last_used__';

  const GarageCollection({
    required this.vehicles,
    required this.selectedVehicleId,
    required this.defaultVehicleId,
  });

  final List<VehicleProfile> vehicles;
  final String selectedVehicleId;
  final String defaultVehicleId;

  VehicleProfile get selectedVehicle {
    for (final vehicle in vehicles) {
      if (vehicle.id == selectedVehicleId) return vehicle;
    }
    if (vehicles.isEmpty) {
      throw StateError('No vehicle is selected in an empty garage');
    }
    return vehicles.first;
  }

  bool get usesLastUsedVehicle => defaultVehicleId == lastUsedVehicleId;

  VehicleProfile get launchVehicle {
    if (usesLastUsedVehicle) return selectedVehicle;
    for (final vehicle in vehicles) {
      if (vehicle.id == defaultVehicleId) return vehicle;
    }
    return selectedVehicle;
  }

  bool get isEmpty => vehicles.isEmpty;

  Map<String, dynamic> toJson() => {
    'schemaVersion': currentSchemaVersion,
    'selectedVehicleId': selectedVehicleId,
    'defaultVehicleId': defaultVehicleId,
    'vehicles': vehicles.map((vehicle) => vehicle.toJson()).toList(),
  };

  factory GarageCollection.fromJson(Map<String, dynamic> json) {
    final rawVehicles = json['vehicles'];
    final schemaVersion = json['schemaVersion'];
    if ((schemaVersion != 1 && schemaVersion != 2) || rawVehicles is! List) {
      throw const FormatException('Invalid garage collection');
    }
    final vehicles = rawVehicles
        .map((vehicle) {
          if (vehicle is! Map) throw const FormatException('Invalid vehicle');
          return VehicleProfile.fromJson(Map<String, dynamic>.from(vehicle));
        })
        .toList(growable: false);
    final collection = GarageCollection(
      vehicles: vehicles,
      selectedVehicleId: json['selectedVehicleId'] as String? ?? '',
      // Schema 1 had no Last used option, so its automatic default migrates
      // to Last used rather than forcing the seeded vehicle on every launch.
      defaultVehicleId: schemaVersion == 1
          ? lastUsedVehicleId
          : json['defaultVehicleId'] as String? ?? '',
    );
    collection.validate();
    return collection;
  }

  /// Migrates a complete collection, including each vehicle's nested garage
  /// snapshot, to the current wire schema. This is kept separate from
  /// [fromJson] so ordinary persisted reads remain strict while backup imports
  /// can explicitly accept every supported historical schema.
  static GarageCollection migrate(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion is! int ||
        schemaVersion < 1 ||
        schemaVersion > currentSchemaVersion) {
      throw const FormatException('Unsupported garage collection schema');
    }
    final rawVehicles = json['vehicles'];
    if (rawVehicles is! List) {
      throw const FormatException('Invalid garage collection');
    }

    final migrated = <String, dynamic>{
      ...json,
      'schemaVersion': currentSchemaVersion,
      if (schemaVersion == 1) 'defaultVehicleId': lastUsedVehicleId,
      'vehicles': rawVehicles.map((rawVehicle) {
        if (rawVehicle is! Map) throw const FormatException('Invalid vehicle');
        final vehicle = Map<String, dynamic>.from(rawVehicle);
        final rawGarage = vehicle['garage'];
        if (rawGarage is! Map) throw const FormatException('Invalid garage');
        final garage = Map<String, dynamic>.from(rawGarage);
        final snapshotVersion = garage['schemaVersion'];
        if (snapshotVersion is! int ||
            snapshotVersion < 2 ||
            snapshotVersion > GarageSnapshot.currentSchemaVersion) {
          throw const FormatException('Unsupported garage snapshot schema');
        }
        final snapshot = snapshotVersion == GarageSnapshot.currentSchemaVersion
            ? GarageSnapshot.fromJson(garage)
            : GarageSnapshot.migrate(garage);
        vehicle['garage'] = snapshot.toJson();
        return vehicle;
      }).toList(growable: false),
    };
    return GarageCollection.fromJson(migrated);
  }

  void validate() {
    final ids = vehicles.map((vehicle) => vehicle.id).toSet();
    if (ids.length != vehicles.length ||
        vehicles.any(
          (vehicle) =>
              vehicle.id.trim().isEmpty ||
              vehicle.year < 1886 ||
              vehicle.year > 9999 ||
              vehicle.model.trim().isEmpty,
        ) ||
        (vehicles.isNotEmpty && !ids.contains(selectedVehicleId)) ||
        (vehicles.isEmpty && selectedVehicleId.isNotEmpty) ||
        (defaultVehicleId != lastUsedVehicleId &&
            !ids.contains(defaultVehicleId))) {
      throw const FormatException('Invalid garage collection state');
    }
  }

  GarageCollection copyWith({
    List<VehicleProfile>? vehicles,
    String? selectedVehicleId,
    String? defaultVehicleId,
  }) => GarageCollection(
    vehicles: vehicles ?? this.vehicles,
    selectedVehicleId: selectedVehicleId ?? this.selectedVehicleId,
    defaultVehicleId: defaultVehicleId ?? this.defaultVehicleId,
  );
}
