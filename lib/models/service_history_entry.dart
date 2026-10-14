class ServiceHistoryEntry {
  const ServiceHistoryEntry({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    this.previousServiceOdometer,
    this.completedOdometer,
    required this.newNote,
    this.newIntervalKm,
    required this.completedAt,
  });
  final String id, serviceId, serviceName, newNote;
  final int? previousServiceOdometer, completedOdometer, newIntervalKm;
  /// The required calendar date on which this service was completed.
  ///
  /// History is ordered by this value, so completion events cannot be
  /// undated.
  final DateTime completedAt;
  Map<String, dynamic> toJson() => {
    'id': id,
    'serviceId': serviceId,
    'serviceName': serviceName,
    if (previousServiceOdometer != null)
      'previousServiceOdometer': previousServiceOdometer,
    if (completedOdometer != null) 'completedOdometer': completedOdometer,
    'newNote': newNote,
    if (newIntervalKm != null) 'newIntervalKm': newIntervalKm,
    'completedAt': completedAt.toIso8601String(),
  };
  factory ServiceHistoryEntry.fromJson(Map<String, dynamic> json) {
    final completedAt = json['completedAt'];
    if (completedAt is! String) {
      throw const FormatException('History completion date is required');
    }
    try {
      return ServiceHistoryEntry(
        id: json['id'] as String,
        serviceId: json['serviceId'] as String,
        serviceName: json['serviceName'] as String,
        previousServiceOdometer: json['previousServiceOdometer'] as int?,
        completedOdometer: json['completedOdometer'] as int?,
        newNote: json['newNote'] as String,
        newIntervalKm: json['newIntervalKm'] as int?,
        completedAt: DateTime.parse(completedAt),
      );
    } on TypeError {
      throw const FormatException('Invalid history entry');
    } on FormatException {
      throw const FormatException('Invalid history completion date');
    }
  }
}
