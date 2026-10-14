import 'maintenance_health.dart';

class TireItem {
  const TireItem({
    required this.id,
    required this.code,
    required this.installOdometer,
    required this.intervalKm,
    required this.installDate,
    this.shelfLifeMonths = 60,
  });

  final String id;
  final String code;
  final int installOdometer;
  final int intervalKm;
  final DateTime installDate;
  final int? shelfLifeMonths;

  static const positionIds = <String>[
    'front-left',
    'front-right',
    'back-left',
    'back-right',
  ];

  static List<TireItem> defaultsForOdometer(int odometer, {DateTime? now}) {
    final installDate = now ?? DateTime.now();
    return [
      TireItem(
        id: 'front-left',
        code: 'FL',
        installOdometer: odometer,
        intervalKm: 50000,
        installDate: installDate,
        shelfLifeMonths: 60,
      ),
      TireItem(
        id: 'front-right',
        code: 'FR',
        installOdometer: odometer,
        intervalKm: 50000,
        installDate: installDate,
        shelfLifeMonths: 60,
      ),
      TireItem(
        id: 'back-left',
        code: 'BL',
        installOdometer: odometer,
        intervalKm: 50000,
        installDate: installDate,
        shelfLifeMonths: 60,
      ),
      TireItem(
        id: 'back-right',
        code: 'BR',
        installOdometer: odometer,
        intervalKm: 50000,
        installDate: installDate,
        shelfLifeMonths: 60,
      ),
    ];
  }

  TireMetrics metricsAt(int currentOdometer, {DateTime? now}) => TireMetrics.fromHealth(
    MaintenanceHealthPolicy.calculate(
      currentOdometer: currentOdometer,
      installationOdometer: installOdometer,
      intervalKm: intervalKm,
    ),
    shelfLifeDueDate: shelfLifeDueDate,
    shelfLifeStartDate: installDate,
    now: now ?? DateTime.now(),
  );

  DateTime? get shelfLifeDueDate => shelfLifeMonths == null
      ? null
      : DateTime(
          installDate.year,
          installDate.month + shelfLifeMonths!,
          installDate.day,
        );

  TireItem copyWith({
    int? installOdometer,
    int? intervalKm,
    DateTime? installDate,
    int? shelfLifeMonths,
  }) => TireItem(
    id: id,
    code: code,
    installOdometer: installOdometer ?? this.installOdometer,
    intervalKm: intervalKm ?? this.intervalKm,
    installDate: installDate ?? this.installDate,
    shelfLifeMonths: shelfLifeMonths ?? this.shelfLifeMonths,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'installOdometer': installOdometer,
    'intervalKm': intervalKm,
    'installDate': installDate.toIso8601String(),
    if (shelfLifeMonths != null) 'shelfLifeMonths': shelfLifeMonths,
  };

  factory TireItem.fromJson(Map<String, dynamic> json) => TireItem(
    id: json['id'] as String,
    code: json['code'] as String,
    installOdometer: json['installOdometer'] as int,
    intervalKm: json['intervalKm'] as int,
    installDate: json['installDate'] == null
        ? DateTime.now()
        : DateTime.parse(json['installDate'] as String),
    shelfLifeMonths: json['shelfLifeMonths'] as int? ?? 60,
  );
}

class TireMetrics extends MaintenanceHealth {
  const TireMetrics({
    required super.usedKm,
    required super.intervalKm,
    this.shelfLifeDueDate,
    this.shelfLifeStartDate,
    this.now,
  });

  final DateTime? shelfLifeDueDate;
  final DateTime? shelfLifeStartDate;
  final DateTime? now;

  factory TireMetrics.fromHealth(
    MaintenanceHealth health, {
    DateTime? shelfLifeDueDate,
    DateTime? shelfLifeStartDate,
    DateTime? now,
  }) => TireMetrics(
    usedKm: health.usedKm,
    intervalKm: health.intervalKm,
    shelfLifeDueDate: shelfLifeDueDate,
    shelfLifeStartDate: shelfLifeStartDate,
    now: now,
  );

  @override
  ServiceStatus get status {
    final mileageStatus = super.status;
    if (shelfLifeDueDate == null || now == null) return mileageStatus;
    final daysRemaining = shelfLifeDueDate!
        .difference(DateTime(now!.year, now!.month, now!.day))
        .inDays;
    final totalDays = shelfLifeStartDate == null
        ? 0
        : shelfLifeDueDate!
              .difference(
                DateTime(
                  shelfLifeStartDate!.year,
                  shelfLifeStartDate!.month,
                  shelfLifeStartDate!.day,
                ),
              )
              .inDays;
    final warningDays = (totalDays * .1).ceil();
    final ageStatus = daysRemaining <= 0
        ? ServiceStatus.replaceNow
        : daysRemaining <= warningDays
        ? ServiceStatus.replaceSoon
        : ServiceStatus.excellent;
    return ageStatus.index > mileageStatus.index ? ageStatus : mileageStatus;
  }
}
