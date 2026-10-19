import 'fuel_entry.dart';

class FuelInterval {
  const FuelInterval({
    required this.startId,
    required this.endId,
    required this.distanceKm,
    required this.liters,
  });
  final String startId;
  final String endId;
  final int distanceKm;
  final double liters;
  double get kmPerLiter => distanceKm / liters;
  double get litersPer100Km => 100 * liters / distanceKm;
}

abstract final class FuelCalculations {
  static List<FuelEntry> ordered(
    Iterable<FuelEntry> entries,
    String vehicleId,
  ) => entries.where((e) => e.vehicleId == vehicleId).toList()
    ..sort((a, b) {
      final date = a.date.compareTo(b.date);
      if (date != 0) return date;
      final odo = a.odometer.compareTo(b.odometer);
      return odo != 0 ? odo : a.id.compareTo(b.id);
    });

  static List<FuelInterval> intervals(
    Iterable<FuelEntry> entries,
    String vehicleId,
  ) {
    final result = <FuelInterval>[];
    FuelEntry? anchor;
    FuelEntry? previous;
    var liters = 0.0;
    for (final entry in ordered(entries, vehicleId)) {
      if (entry.breaksConsumption ||
          entry.fullTank == null ||
          !entry.liters.isFinite ||
          entry.liters <= 0 ||
          (previous != null && entry.odometer < previous.odometer)) {
        anchor = null;
        liters = 0;
      }
      previous = entry;
      if (entry.fullTank == null ||
          !entry.liters.isFinite ||
          entry.liters <= 0) {
        continue;
      }
      if (anchor != null) liters += entry.liters;
      if (entry.fullTank!) {
        if (anchor != null &&
            entry.odometer > anchor.odometer &&
            liters.isFinite &&
            liters > 0) {
          result.add(
            FuelInterval(
              startId: anchor.id,
              endId: entry.id,
              distanceKm: entry.odometer - anchor.odometer,
              liters: liters,
            ),
          );
        }
        anchor = entry;
        liters = 0;
      }
    }
    return result;
  }

  static bool fitsOdometerOrder(FuelEntry entry, Iterable<FuelEntry> existing) {
    final sorted = ordered([
      ...existing.where((e) => e.id != entry.id),
      entry,
    ], entry.vehicleId);
    final index = sorted.indexWhere((e) => e.id == entry.id);
    return (index == 0 || sorted[index - 1].odometer <= entry.odometer) &&
        (index == sorted.length - 1 ||
            sorted[index + 1].odometer >= entry.odometer);
  }

  /// A deletion can remove fuel needed for an interval. Mark the next entry as
  /// a known gap rather than report an artificially good economy figure.
  static List<FuelEntry> withoutEntry(
    Iterable<FuelEntry> entries,
    String vehicleId,
    String id,
  ) {
    final sorted = ordered(entries, vehicleId);
    final index = sorted.indexWhere((e) => e.id == id);
    if (index < 0) return sorted;
    sorted.removeAt(index);
    if (index < sorted.length) sorted[index] = sorted[index].markGap();
    return sorted;
  }
}

abstract final class FuelInput {
  static double? decimal(String text) {
    var normalized = text.trim().replaceAll('٫', '.').replaceAll(',', '.');
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    for (var i = 0; i < 10; i++) {
      normalized = normalized
          .replaceAll(arabic[i], '$i')
          .replaceAll(persian[i], '$i');
    }
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(normalized)) return null;
    final value = double.tryParse(normalized);
    return value != null && value.isFinite ? value : null;
  }

  static double? litersFromAmount(double amount, double price) =>
      amount.isFinite && amount > 0 && price.isFinite && price > 0
      ? amount / price
      : null;
  static double? amountFromLiters(double liters, double price) =>
      liters.isFinite && liters > 0 && price.isFinite && price > 0
      ? liters * price
      : null;
}
