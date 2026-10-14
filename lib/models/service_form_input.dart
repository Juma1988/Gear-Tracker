import 'service_item.dart';

/// Stable reason a service-form field was rejected.
///
/// These are codes, not copy: the form maps each one to localized text, which
/// keeps the validation rules testable without a widget tree and stops copy
/// changes from silently altering validation behavior.
enum ServiceFieldProblem {
  /// The service name was blank.
  nameRequired,

  /// The field was not a whole number.
  notANumber,

  /// The value must be greater than zero.
  notPositive,

  /// The odometer value was negative.
  negativeOdometer,

  /// The odometer value is ahead of the vehicle's current reading.
  odometerAheadOfCurrent,
}

/// Validates an "installed at" odometer reading: a whole number within
/// `0 … currentOdometer`. Pure, so both the form and its tests share one rule.
ServiceFieldProblem? installKmProblem(
  String raw, {
  required int currentOdometer,
}) {
  final value = int.tryParse(raw.trim());
  if (value == null) return ServiceFieldProblem.notANumber;
  if (value < 0) return ServiceFieldProblem.negativeOdometer;
  if (value > currentOdometer) {
    return ServiceFieldProblem.odometerAheadOfCurrent;
  }
  return null;
}

/// Validates a whole-number field that must be greater than zero.
ServiceFieldProblem? positiveIntProblem(String raw) {
  final value = int.tryParse(raw.trim());
  if (value == null) return ServiceFieldProblem.notANumber;
  if (value <= 0) return ServiceFieldProblem.notPositive;
  return null;
}

/// Raw service-form text plus the rules that turn it into a [ServiceItem].
///
/// Extracted from the add-service screen (W11 BE-F30) so validation and model
/// construction live in one place instead of being spread across widget
/// callbacks. The input is intentionally the *unvalidated* controller text.
class ServiceFormInput {
  const ServiceFormInput({
    required this.name,
    required this.note,
    required this.installKm,
    required this.intervalKm,
    required this.shelfLifeMonths,
    required this.trackingMode,
    required this.installDate,
    required this.currentOdometer,
  });

  final String name;
  final String note;
  final String installKm;
  final String intervalKm;
  final String shelfLifeMonths;
  final ServiceTrackingMode trackingMode;
  final DateTime installDate;
  final int currentOdometer;

  bool get tracksMileage =>
      trackingMode == ServiceTrackingMode.mileage ||
      trackingMode == ServiceTrackingMode.mileageAndTime;
  bool get tracksTime =>
      trackingMode == ServiceTrackingMode.time ||
      trackingMode == ServiceTrackingMode.mileageAndTime;

  String get trimmedName => name.trim();
  String get trimmedNote => note.trim();

  ServiceFieldProblem? problemWithName() =>
      trimmedName.isEmpty ? ServiceFieldProblem.nameRequired : null;

  /// Validates the "installed at" odometer: a whole number within
  /// `0 … currentOdometer`.
  ServiceFieldProblem? problemWithInstallKm() => tracksMileage
      ? installKmProblem(installKm, currentOdometer: currentOdometer)
      : null;

  /// Validates the repeat interval: a whole number greater than zero.
  ServiceFieldProblem? problemWithIntervalKm() =>
      tracksMileage ? positiveIntProblem(intervalKm) : null;

  /// Validates the shelf life: a whole number of months greater than zero.
  ServiceFieldProblem? problemWithShelfLifeMonths() =>
      tracksTime ? positiveIntProblem(shelfLifeMonths) : null;

  /// True when every field that applies to the selected tracking mode is valid.
  bool get isValid =>
      problemWithName() == null &&
      problemWithInstallKm() == null &&
      problemWithIntervalKm() == null &&
      problemWithShelfLifeMonths() == null;

  /// Builds the persistable item.
  ///
  /// Throws [StateError] when [isValid] is false so no code path can persist
  /// text the form never accepted.
  ServiceItem toItem({
    required String id,
    required String iconKey,
    ServiceType type = ServiceType.type01,
    List<ServiceUnit> units = const [],
  }) {
    if (!isValid) {
      throw StateError('Service form input is not valid');
    }
    return ServiceItem(
      id: id,
      name: trimmedName,
      note: trimmedNote,
      serviceOdometer: tracksMileage ? int.parse(installKm.trim()) : null,
      intervalKm: tracksMileage ? int.parse(intervalKm.trim()) : null,
      iconKey: iconKey,
      installDate: tracksTime ? installDate : null,
      shelfLifeMonths: tracksTime ? int.parse(shelfLifeMonths.trim()) : null,
      type: type,
      units: units,
    );
  }
}
