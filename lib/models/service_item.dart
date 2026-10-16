import 'package:flutter/material.dart';

import 'maintenance_health.dart';

export 'maintenance_health.dart' show ServiceStatus, ServiceStatusLabel;

class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.name,
    required this.note,
    this.serviceOdometer,
    this.intervalKm,
    required this.iconKey,
    this.installDate,
    this.hasShelfLife = false,
    this.shelfLifeMonths,
    this.type = ServiceType.type01,
    this.units = const [],
  });
  final String id, name, note;
  final int? serviceOdometer, intervalKm;
  final String iconKey;
  final DateTime? installDate;
  @Deprecated('Use shelfLifeMonths != null instead.')
  final bool hasShelfLife;
  final int? shelfLifeMonths;

  bool get tracksMileage => serviceOdometer != null && intervalKm != null;
  bool get tracksTime => installDate != null && shelfLifeMonths != null;

  DateTime? get shelfLifeDueDate => tracksTime
      ? DateTime(
          installDate!.year,
          installDate!.month + shelfLifeMonths!,
          installDate!.day,
        )
      : null;

  /// Type 01 is a single vehicle-wide service. Type 02 owns four generic
  /// positions; the current tire tracker remains a separate legacy feature.
  final ServiceType type;
  final List<ServiceUnit> units;
  static IconData iconForKey(String iconKey) => switch (iconKey) {
    'oil' => Icons.oil_barrel,
    'oil_filter' => Icons.oil_barrel,
    'air_filter' => Icons.air,
    'cabin_filter' => Icons.air_outlined,
    'brake_pads' => Icons.car_repair,
    'brake_fluid' => Icons.opacity,
    'tires' => Icons.tire_repair,
    'battery' => Icons.battery_full,
    'spark_plugs' => Icons.bolt,
    'coolant' => Icons.water_drop,
    'transmission_fluid' => Icons.settings,
    'power_steering' => Icons.water_drop_outlined,
    'timing_belt' => Icons.timer_outlined,
    'drive_belts' => Icons.sync_alt,
    'wipers' => Icons.visibility,
    'suspension' => Icons.height,
    'fuel_filter' => Icons.local_gas_station,
    'ac' => Icons.ac_unit,
    'maintenance' => Icons.build_outlined,
    _ => Icons.build_outlined,
  };
  IconData get icon => iconForKey(iconKey);
  ServiceItem copyWith({
    String? name,
    String? note,
    String? iconKey,
    Object? serviceOdometer = _unset,
    Object? intervalKm = _unset,
    Object? installDate = _unset,
    Object? shelfLifeMonths = _unset,
    bool? hasShelfLife,
    ServiceType? type,
    List<ServiceUnit>? units,
  }) => ServiceItem(
    id: id,
    name: name ?? this.name,
    note: note ?? this.note,
    serviceOdometer: identical(serviceOdometer, _unset)
        ? this.serviceOdometer
        : serviceOdometer as int?,
    intervalKm: identical(intervalKm, _unset)
        ? this.intervalKm
        : intervalKm as int?,
    iconKey: iconKey ?? this.iconKey,
    installDate: identical(installDate, _unset)
        ? this.installDate
        : installDate as DateTime?,
    shelfLifeMonths: identical(shelfLifeMonths, _unset)
        ? this.shelfLifeMonths
        : shelfLifeMonths as int?,
    hasShelfLife: hasShelfLife ?? this.hasShelfLife,
    type: type ?? this.type,
    units: units ?? this.units,
  );

  /// Shelf life is canonical when `shelfLifeMonths` is present.  The old
  /// `hasShelfLife` flag is read only as a schema-1 compatibility field.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'note': note,
    if (serviceOdometer != null) 'serviceOdometer': serviceOdometer,
    if (intervalKm != null) 'intervalKm': intervalKm,
    'iconKey': iconKey,
    'type': type.name,
    if (type == ServiceType.type02)
      'units': units.map((unit) => unit.toJson()).toList(),
    if (installDate != null) 'installDate': installDate!.toIso8601String(),
    if (shelfLifeMonths != null) 'shelfLifeMonths': shelfLifeMonths,
  };
  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    final type = ServiceType.fromJson(json['type']);
    final hasLegacyShelfLife = json['hasShelfLife'];
    if (hasLegacyShelfLife is! bool && hasLegacyShelfLife != null) {
      throw const FormatException('Invalid hasShelfLife');
    }
    if (hasLegacyShelfLife == true && !json.containsKey('shelfLifeMonths')) {
      throw const FormatException('Legacy shelf-life service has no duration');
    }
    final shelfLifeMonths = json.containsKey('shelfLifeMonths')
        ? json['shelfLifeMonths'] as int?
        : null;
    return ServiceItem(
      id: json['id'] as String,
      name: json['name'] as String,
      note: json['note'] as String,
      serviceOdometer: json['serviceOdometer'] as int?,
      intervalKm: json['intervalKm'] as int?,
      iconKey: json['iconKey'] as String,
      installDate: json['installDate'] == null
          ? null
          : DateTime.parse(json['installDate'] as String),
      hasShelfLife: shelfLifeMonths != null,
      shelfLifeMonths: shelfLifeMonths,
      type: type,
      units: _unitsFromJson(json),
    );
  }

  static List<ServiceUnit> _unitsFromJson(Map<String, dynamic> json) {
    if (ServiceType.fromJson(json['type']) != ServiceType.type02) {
      return const [];
    }
    final raw = json['units'];
    // v2 did not have generic position data. Preserve the service while
    // supplying the v3 four-position default during migration.
    if (raw == null) {
      final installOdometer = json['serviceOdometer'];
      if (installOdometer is! int) {
        throw const FormatException('Invalid serviceOdometer');
      }
      return [
        for (final position in ServiceUnit.positions)
          ServiceUnit(position: position, installOdometer: installOdometer),
      ];
    }
    if (raw is! List) {
      throw const FormatException('Invalid service units');
    }
    return raw
        .map(
          (value) =>
              ServiceUnit.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList(growable: false);
  }

  ServiceMetrics? metricsAt(int currentOdometer, {DateTime? now}) {
    if (!tracksMileage) return null;
    final mileageHealth = MaintenanceHealthPolicy.calculate(
      currentOdometer: currentOdometer,
      installationOdometer: serviceOdometer!,
      intervalKm: intervalKm!,
    );
    return ServiceMetrics.fromHealth(mileageHealth);
  }

  ShelfLifeStatus? shelfLifeStatusAt(DateTime now) {
    final dueDate = shelfLifeDueDate;
    if (dueDate == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(
      installDate!.year,
      installDate!.month,
      installDate!.day,
    );
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final totalDays = due.difference(start).inDays;
    final daysRemaining = due.difference(today).inDays;
    final remainingProgress = totalDays <= 0
        ? 0.0
        : (daysRemaining / totalDays).clamp(0.0, 1.0);
    return ShelfLifeStatus(
      daysRemaining: daysRemaining,
      remainingProgress: remainingProgress,
    );
  }

  ServiceStatus statusAt(int currentOdometer, {DateTime? now}) {
    final mileageStatus = metricsAt(currentOdometer)?.status;
    final shelfLifeStatus = shelfLifeStatusAt(now ?? DateTime.now());
    return ServiceUrgencyPolicy.combinedStatus(
      mileageStatus: mileageStatus,
      shelfLifeStatus: shelfLifeStatus,
    );
  }
}

class ShelfLifeStatus {
  const ShelfLifeStatus({
    required this.daysRemaining,
    required this.remainingProgress,
  });

  static const warningProgress = .1;
  static const cautionProgress = .25;

  final int daysRemaining;
  final double remainingProgress;

  bool get isExpired => daysRemaining < 0;
  bool get isDueOrExpired => daysRemaining <= 0;
  bool get isWarning => remainingProgress <= warningProgress;
  bool get isCaution => remainingProgress < cautionProgress;
}

/// Shared service urgency policy for cards, ordering, and dashboard health.
/// Mileage keeps its detailed lifecycle status; shelf life contributes orange
/// within nine calendar days and red when due or expired.
class ServiceUrgencyPolicy {
  const ServiceUrgencyPolicy._();

  static ServiceStatus combinedStatus({
    ServiceStatus? mileageStatus,
    ShelfLifeStatus? shelfLifeStatus,
  }) {
    final shelfLifeUrgency = shelfLifeStatus == null
        ? ServiceStatus.excellent
        : shelfLifeStatus.isDueOrExpired
        ? ServiceStatus.replaceNow
        : shelfLifeStatus.isWarning
        ? ServiceStatus.replaceSoon
        : ServiceStatus.excellent;
    if (mileageStatus == null) return shelfLifeUrgency;
    return urgencyRank(shelfLifeUrgency) > urgencyRank(mileageStatus)
        ? shelfLifeUrgency
        : mileageStatus;
  }

  /// Visible dashboard priority: red, orange, then green.
  static int urgencyRank(ServiceStatus status) => switch (status) {
    ServiceStatus.replaceNow => 2,
    ServiceStatus.replaceSoon || ServiceStatus.warning => 1,
    ServiceStatus.good || ServiceStatus.excellent => 0,
  };

  static int compare(
    ServiceItem a,
    ServiceItem b, {
    required int currentOdometer,
    DateTime? now,
  }) {
    final aTimeOnlyDeferred = isTimeOnlyBelowPromotion(a, now: now);
    final bTimeOnlyDeferred = isTimeOnlyBelowPromotion(b, now: now);
    if (aTimeOnlyDeferred != bTimeOnlyDeferred) {
      return aTimeOnlyDeferred ? 1 : -1;
    }
    final statusComparison = urgencyRank(b.statusAt(currentOdometer, now: now))
        .compareTo(urgencyRank(a.statusAt(currentOdometer, now: now)));
    if (statusComparison != 0) return statusComparison;

    final deadlineComparison =
        _urgencyDeadline(
          a,
          currentOdometer: currentOdometer,
          now: now,
        ).compareTo(
          _urgencyDeadline(b, currentOdometer: currentOdometer, now: now),
        );
    if (deadlineComparison != 0) return deadlineComparison;

    final nameComparison = a.name.compareTo(b.name);
    return nameComparison != 0 ? nameComparison : a.id.compareTo(b.id);
  }

  static bool isTimeOnlyBelowPromotion(ServiceItem service, {DateTime? now}) {
    if (service.tracksMileage || !service.tracksTime) return false;
    final start = service.installDate!;
    final due = service.shelfLifeDueDate!;
    final total = due.difference(start).inMilliseconds;
    if (total <= 0) return false;
    final elapsed = (now ?? DateTime.now()).difference(start).inMilliseconds;
    return elapsed / total < .9;
  }

  static double _urgencyDeadline(
    ServiceItem service, {
    required int currentOdometer,
    DateTime? now,
  }) {
    final metrics = service.metricsAt(currentOdometer);
    final shelfLifeStatus = service.shelfLifeStatusAt(now ?? DateTime.now());
    final shelfLifeUrgency = shelfLifeStatus == null
        ? ServiceStatus.excellent
        : shelfLifeStatus.isDueOrExpired
        ? ServiceStatus.replaceNow
        : shelfLifeStatus.isWarning
        ? ServiceStatus.replaceSoon
        : ServiceStatus.excellent;
    if (metrics == null ||
        urgencyRank(shelfLifeUrgency) >= urgencyRank(metrics.status)) {
      return shelfLifeStatus?.daysRemaining.toDouble() ?? double.infinity;
    }
    return metrics.remainingKm.toDouble();
  }
}

const _unset = Object();

enum ServiceType {
  type01,
  type02;

  static ServiceType fromJson(Object? value) => switch (value) {
    'type02' => ServiceType.type02,
    'type01' => ServiceType.type01,
    _ => throw FormatException('Unknown service type: $value'),
  };
}

enum ServiceTrackingMode { mileage, time, mileageAndTime }

class ServiceUnit {
  const ServiceUnit({required this.position, required this.installOdometer});

  static const positions = [
    'front-left',
    'front-right',
    'back-left',
    'back-right',
  ];

  final String position;
  final int installOdometer;

  Map<String, dynamic> toJson() => {
    'position': position,
    'installOdometer': installOdometer,
  };

  factory ServiceUnit.fromJson(Map<String, dynamic> json) => ServiceUnit(
    position: json['position'] as String,
    installOdometer: json['installOdometer'] as int,
  );
}

class ServiceMetrics extends MaintenanceHealth {
  const ServiceMetrics({required super.usedKm, required super.intervalKm});
  factory ServiceMetrics.fromHealth(MaintenanceHealth health) =>
      ServiceMetrics(usedKm: health.usedKm, intervalKm: health.intervalKm);
  String get badge => status.badge;
  String get condition => switch (status) {
    ServiceStatus.replaceNow => 'Critical - $damagePercent% Exhausted',
    ServiceStatus.replaceSoon => 'Soon - $damagePercent% Exhausted',
    _ => 'Warning - $damagePercent% Exhausted',
  };
}
