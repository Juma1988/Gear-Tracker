class FuelEntry {
  const FuelEntry({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.odometer,
    required this.liters,
    required this.cost,
    this.grade = 92,
    this.fullTank,
    this.note = '',
    this.recordedPrice,
    this.breaksConsumption = false,
  });

  final String id;
  final String vehicleId;
  final DateTime date;
  final int odometer;
  final double liters;
  final double cost;
  final int grade;

  /// Null means an old entry whose full/partial status was never recorded.
  final bool? fullTank;
  final String note;
  final double? recordedPrice;
  final bool breaksConsumption;
  double get pricePerLiter => cost / liters;

  FuelEntry withOwnership(String vehicleId) => FuelEntry(
    id: id,
    vehicleId: vehicleId,
    date: date,
    odometer: odometer,
    liters: liters,
    cost: cost,
    grade: grade,
    fullTank: fullTank,
    note: note,
    recordedPrice: recordedPrice,
    breaksConsumption: breaksConsumption,
  );

  FuelEntry markGap() => FuelEntry(
    id: id,
    vehicleId: vehicleId,
    date: date,
    odometer: odometer,
    liters: liters,
    cost: cost,
    grade: grade,
    fullTank: fullTank,
    note: note,
    recordedPrice: recordedPrice,
    breaksConsumption: true,
  );

  void validate() {
    if (id.trim().isEmpty ||
        vehicleId.trim().isEmpty ||
        odometer < 0 ||
        odometer > 999999 ||
        !liters.isFinite ||
        liters <= 0 ||
        !cost.isFinite ||
        cost < 0 ||
        !pricePerLiter.isFinite ||
        ![92, 95].contains(grade) ||
        note.length > 1000 ||
        (fullTank != null && cost <= 0) ||
        (recordedPrice != null &&
            (!recordedPrice!.isFinite || recordedPrice! <= 0))) {
      throw const FormatException('Invalid fuel entry');
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicleId': vehicleId,
    'date': date.toUtc().toIso8601String(),
    'odometer': odometer,
    'liters': liters,
    'cost': cost,
    'grade': grade,
    'pricePerLiter': pricePerLiter,
    'fullTank': fullTank,
    'note': note,
    if (recordedPrice != null) 'recordedPrice': recordedPrice,
    'breaksConsumption': breaksConsumption,
  };

  factory FuelEntry.fromJson(Map<String, dynamic> json) => FuelEntry(
    id: json['id'] as String,
    vehicleId: json['vehicleId'] as String? ?? '__legacy__',
    date: DateTime.parse(json['date'] as String).toUtc(),
    odometer: json['odometer'] as int,
    liters: (json['liters'] as num).toDouble(),
    cost: (json['cost'] as num).toDouble(),
    grade: json['grade'] as int? ?? 92,
    fullTank: json['fullTank'] as bool?,
    note: json['note'] as String? ?? '',
    recordedPrice: (json['recordedPrice'] as num?)?.toDouble(),
    breaksConsumption: json['breaksConsumption'] as bool? ?? false,
  );
}
