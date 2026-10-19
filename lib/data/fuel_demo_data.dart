import '../models/fuel_entry.dart';

/// Presentation-only fixtures. Never pass these entries to GarageRepository.
abstract final class FuelDemoData {
  static const vehicleId = '__fuel_chart_demo__';

  static List<FuelEntry> entries({DateTime? now}) {
    final clock = (now ?? DateTime.now()).toUtc();
    final start = DateTime.utc(
      clock.year,
      clock.month,
      clock.day,
    ).subtract(const Duration(days: 49));
    var odometer = 10000;
    FuelEntry fill(
      String id,
      DateTime date,
      int km,
      double liters,
      bool full,
    ) => FuelEntry(
      id: id,
      vehicleId: vehicleId,
      date: date,
      odometer: km,
      liters: liters,
      cost: liters * 20,
      recordedPrice: 20,
      fullTank: full,
    );
    final result = [fill('demo-anchor', start, odometer, 40, true)];
    const distances = [312, 336, 324, 360, 348, 375, 354];
    for (var i = 0; i < distances.length; i++) {
      result.add(
        fill(
          'demo-partial-$i',
          start.add(Duration(days: (i + 1) * 7 - 2)),
          odometer + 100,
          10,
          false,
        ),
      );
      odometer += distances[i];
      result.add(
        fill(
          'demo-full-$i',
          start.add(Duration(days: (i + 1) * 7)),
          odometer,
          20,
          true,
        ),
      );
    }
    return List.unmodifiable(result);
  }
}
