import 'package:flutter/material.dart';

enum ServiceStatus { excellent, good, warning, replaceSoon, replaceNow }

extension ServiceStatusLabel on ServiceStatus {
  String get badge => switch (this) {
    ServiceStatus.excellent => 'Excellent',
    ServiceStatus.good => 'Good',
    ServiceStatus.warning => 'Warning',
    ServiceStatus.replaceSoon => 'Replace soon',
    ServiceStatus.replaceNow => 'Replace now',
  };
}

class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.name,
    required this.note,
    required this.serviceOdometer,
    required this.intervalKm,
    required this.iconKey,
    this.installDate,
  });
  final String id, name, note;
  final int serviceOdometer, intervalKm;
  final String iconKey;
  final DateTime? installDate;
  IconData get icon => switch (iconKey) {
    'oil' => Icons.oil_barrel,
    _ => Icons.build,
  };
  ServiceItem copyWith({
    String? name,
    String? note,
    int? serviceOdometer,
    int? intervalKm,
    DateTime? installDate,
  }) => ServiceItem(
    id: id,
    name: name ?? this.name,
    note: note ?? this.note,
    serviceOdometer: serviceOdometer ?? this.serviceOdometer,
    intervalKm: intervalKm ?? this.intervalKm,
    iconKey: iconKey,
    installDate: installDate ?? this.installDate,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'note': note,
    'serviceOdometer': serviceOdometer,
    'intervalKm': intervalKm,
    'iconKey': iconKey,
    if (installDate != null) 'installDate': installDate!.toIso8601String(),
  };
  factory ServiceItem.fromJson(Map<String, dynamic> json) => ServiceItem(
    id: json['id'] as String,
    name: json['name'] as String,
    note: json['note'] as String,
    serviceOdometer: json['serviceOdometer'] as int,
    intervalKm: json['intervalKm'] as int,
    iconKey: json['iconKey'] as String,
    installDate: json['installDate'] == null
        ? null
        : DateTime.parse(json['installDate'] as String),
  );
  ServiceMetrics metricsAt(int currentOdometer) => ServiceMetrics(
    usedKm: (currentOdometer - serviceOdometer).clamp(0, intervalKm),
    intervalKm: intervalKm,
  );
}

class ServiceMetrics {
  const ServiceMetrics({required this.usedKm, required this.intervalKm});
  final int usedKm, intervalKm;
  double get damage => usedKm / intervalKm;
  int get damagePercent => (damage * 100).round();
  double get health => 1 - damage;
  int get healthPercent => 100 - damagePercent;
  int get remainingKm => intervalKm - usedKm;
  int get remainingPercent => 100 - damagePercent;
  ServiceStatus get status => damagePercent >= 100
      ? ServiceStatus.replaceNow
      : damagePercent >= 90
      ? ServiceStatus.replaceSoon
      : damagePercent >= 75
      ? ServiceStatus.warning
      : damagePercent >= 50
      ? ServiceStatus.good
      : ServiceStatus.excellent;
  bool get showCondition =>
      status != ServiceStatus.excellent && status != ServiceStatus.good;
  String get badge => status.badge;
  String get condition => switch (status) {
    ServiceStatus.replaceNow => 'Critical - $damagePercent% Exhausted',
    ServiceStatus.replaceSoon => 'Soon - $damagePercent% Exhausted',
    _ => 'Warning - $damagePercent% Exhausted',
  };
}
