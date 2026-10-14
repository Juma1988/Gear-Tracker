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

class MaintenanceHealth {
  const MaintenanceHealth({required this.usedKm, required this.intervalKm});

  final int usedKm;
  final int intervalKm;

  double get damage => usedKm / intervalKm;
  int get damagePercent => (damage * 100).round();
  double get health => 1 - damage;
  int get healthPercent => 100 - damagePercent;
  int get remainingKm => intervalKm - usedKm;
  int get remainingPercent => healthPercent;
  ServiceStatus get status => MaintenanceHealthPolicy.statusFor(damagePercent);
  bool get showCondition =>
      status != ServiceStatus.excellent && status != ServiceStatus.good;
}

/// Shared mileage-only lifecycle policy for services and tires.
class MaintenanceHealthPolicy {
  const MaintenanceHealthPolicy._();

  static MaintenanceHealth calculate({
    required int currentOdometer,
    required int installationOdometer,
    required int intervalKm,
  }) {
    if (intervalKm <= 0) {
      throw ArgumentError.value(
        intervalKm,
        'intervalKm',
        'must be greater than 0',
      );
    }
    return MaintenanceHealth(
      usedKm: (currentOdometer - installationOdometer).clamp(0, intervalKm),
      intervalKm: intervalKm,
    );
  }

  static ServiceStatus statusFor(int damagePercent) => damagePercent >= 100
      ? ServiceStatus.replaceNow
      : damagePercent >= 90
      ? ServiceStatus.replaceSoon
      : damagePercent >= 75
      ? ServiceStatus.warning
      : damagePercent >= 50
      ? ServiceStatus.good
      : ServiceStatus.excellent;
}
