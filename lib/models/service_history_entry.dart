class ServiceHistoryEntry {
  const ServiceHistoryEntry({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.previousServiceOdometer,
    required this.completedOdometer,
    required this.newNote,
    required this.newIntervalKm,
    required this.completedAt,
  });
  final String id, serviceId, serviceName, newNote;
  final int previousServiceOdometer, completedOdometer, newIntervalKm;
  final DateTime completedAt;
  Map<String, dynamic> toJson() => {
    'id': id,
    'serviceId': serviceId,
    'serviceName': serviceName,
    'previousServiceOdometer': previousServiceOdometer,
    'completedOdometer': completedOdometer,
    'newNote': newNote,
    'newIntervalKm': newIntervalKm,
    'completedAt': completedAt.toIso8601String(),
  };
  factory ServiceHistoryEntry.fromJson(Map<String, dynamic> json) =>
      ServiceHistoryEntry(
        id: json['id'] as String,
        serviceId: json['serviceId'] as String,
        serviceName: json['serviceName'] as String,
        previousServiceOdometer: json['previousServiceOdometer'] as int,
        completedOdometer: json['completedOdometer'] as int,
        newNote: json['newNote'] as String,
        newIntervalKm: json['newIntervalKm'] as int,
        completedAt: DateTime.parse(json['completedAt'] as String),
      );
}
