import 'service_item.dart';

class TireItem {
  const TireItem({
    required this.id,
    required this.code,
    required this.installOdometer,
    required this.intervalKm,
    required this.installDate,
  });

  final String id;
  final String code;
  final int installOdometer;
  final int intervalKm;
  final DateTime installDate;

  static List<TireItem> defaultsForOdometer(int odometer) => [
    TireItem(
      id: 'front-left',
      code: 'FL',
      installOdometer: odometer,
      intervalKm: 50000,
      installDate: DateTime.now(),
    ),
    TireItem(
      id: 'front-right',
      code: 'FR',
      installOdometer: odometer,
      intervalKm: 50000,
      installDate: DateTime.now(),
    ),
    TireItem(
      id: 'back-left',
      code: 'BL',
      installOdometer: odometer,
      intervalKm: 50000,
      installDate: DateTime.now(),
    ),
    TireItem(
      id: 'back-right',
      code: 'BR',
      installOdometer: odometer,
      intervalKm: 50000,
      installDate: DateTime.now(),
    ),
  ];

  TireMetrics metricsAt(int currentOdometer) => TireMetrics(
    usedKm: (currentOdometer - installOdometer).clamp(0, intervalKm),
    intervalKm: intervalKm,
  );

  TireItem copyWith({
    int? installOdometer,
    int? intervalKm,
    DateTime? installDate,
  }) => TireItem(
    id: id,
    code: code,
    installOdometer: installOdometer ?? this.installOdometer,
    intervalKm: intervalKm ?? this.intervalKm,
    installDate: installDate ?? this.installDate,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'installOdometer': installOdometer,
    'intervalKm': intervalKm,
    'installDate': installDate.toIso8601String(),
  };

  factory TireItem.fromJson(Map<String, dynamic> json) => TireItem(
    id: json['id'] as String,
    code: json['code'] as String,
    installOdometer: json['installOdometer'] as int,
    intervalKm: json['intervalKm'] as int,
    installDate: json['installDate'] == null
        ? DateTime.now()
        : DateTime.parse(json['installDate'] as String),
  );
}

class TireMetrics {
  const TireMetrics({required this.usedKm, required this.intervalKm});

  final int usedKm;
  final int intervalKm;

  double get damage => usedKm / intervalKm;
  int get damagePercent => (damage * 100).round();
  double get health => 1 - damage;
  int get healthPercent => 100 - damagePercent;
  int get remainingPercent => healthPercent;
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
    ServiceStatus.replaceNow => 'Critical - $damagePercent% Used',
    ServiceStatus.replaceSoon => 'Soon - $damagePercent% Used',
    _ => 'Warning - $damagePercent% Used',
  };
}
