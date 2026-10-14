import 'package:app/models/service_form_input.dart';
import 'package:app/models/service_item.dart';
import 'package:flutter_test/flutter_test.dart';

ServiceFormInput _input({
  String name = 'Engine Oil',
  String note = '',
  String installKm = '1000',
  String intervalKm = '10000',
  String shelfLifeMonths = '12',
  ServiceTrackingMode trackingMode = ServiceTrackingMode.mileage,
  DateTime? installDate,
  int currentOdometer = 1500,
}) => ServiceFormInput(
  name: name,
  note: note,
  installKm: installKm,
  intervalKm: intervalKm,
  shelfLifeMonths: shelfLifeMonths,
  trackingMode: trackingMode,
  installDate: installDate ?? DateTime(2026, 10, 11),
  currentOdometer: currentOdometer,
);

void main() {
  group('ServiceFormInput validation', () {
    test('accepts a valid mileage-tracked service', () {
      final input = _input();
      expect(input.problemWithName(), isNull);
      expect(input.problemWithInstallKm(), isNull);
      expect(input.problemWithIntervalKm(), isNull);
      expect(input.isValid, isTrue);
    });

    test('requires a name', () {
      expect(
        _input(name: '   ').problemWithName(),
        ServiceFieldProblem.nameRequired,
      );
    });

    test('rejects a non-numeric install reading', () {
      expect(
        _input(installKm: 'abc').problemWithInstallKm(),
        ServiceFieldProblem.notANumber,
      );
    });

    test('rejects a negative install reading', () {
      expect(
        _input(installKm: '-1').problemWithInstallKm(),
        ServiceFieldProblem.negativeOdometer,
      );
    });

    test('rejects an install reading ahead of the current odometer', () {
      expect(
        _input(installKm: '1501', currentOdometer: 1500).problemWithInstallKm(),
        ServiceFieldProblem.odometerAheadOfCurrent,
      );
      // The boundary (exactly the current reading) is accepted.
      expect(
        _input(installKm: '1500', currentOdometer: 1500).problemWithInstallKm(),
        isNull,
      );
    });

    test('rejects a zero or negative interval', () {
      expect(
        _input(intervalKm: '0').problemWithIntervalKm(),
        ServiceFieldProblem.notPositive,
      );
      expect(
        _input(intervalKm: '-5').problemWithIntervalKm(),
        ServiceFieldProblem.notPositive,
      );
      expect(
        _input(intervalKm: '').problemWithIntervalKm(),
        ServiceFieldProblem.notANumber,
      );
    });

    test('rejects a zero or negative shelf life', () {
      expect(
        _input(
          trackingMode: ServiceTrackingMode.time,
          shelfLifeMonths: '0',
        ).problemWithShelfLifeMonths(),
        ServiceFieldProblem.notPositive,
      );
    });

    test('ignores fields the tracking mode does not use', () {
      final timeOnly = _input(
        trackingMode: ServiceTrackingMode.time,
        installKm: 'nonsense',
        intervalKm: 'nonsense',
      );
      expect(timeOnly.problemWithInstallKm(), isNull);
      expect(timeOnly.problemWithIntervalKm(), isNull);
      expect(timeOnly.isValid, isTrue);

      final mileageOnly = _input(
        shelfLifeMonths: 'nonsense',
      );
      expect(mileageOnly.problemWithShelfLifeMonths(), isNull);
      expect(mileageOnly.isValid, isTrue);

      final both = _input(trackingMode: ServiceTrackingMode.mileageAndTime);
      expect(both.tracksMileage, isTrue);
      expect(both.tracksTime, isTrue);
      expect(both.isValid, isTrue);
    });
  });

  group('ServiceFormInput construction', () {
    test('builds a mileage-tracked item with trimmed text', () {
      final item = _input(
        name: '  Engine Oil  ',
        note: '  5W-40  ',
      ).toItem(id: 'oil', iconKey: 'oil');

      expect(item.id, 'oil');
      expect(item.name, 'Engine Oil');
      expect(item.note, '5W-40');
      expect(item.serviceOdometer, 1000);
      expect(item.intervalKm, 10000);
      expect(item.installDate, isNull);
      expect(item.shelfLifeMonths, isNull);
    });

    test('builds a time-tracked item without odometer fields', () {
      final installDate = DateTime(2026, 3, 1);
      final item = _input(
        trackingMode: ServiceTrackingMode.time,
        installDate: installDate,
        shelfLifeMonths: '36',
      ).toItem(id: 'battery', iconKey: 'battery');

      expect(item.serviceOdometer, isNull);
      expect(item.intervalKm, isNull);
      expect(item.installDate, installDate);
      expect(item.shelfLifeMonths, 36);
    });

    test('refuses to build an item from invalid input', () {
      expect(
        () => _input(intervalKm: '0').toItem(id: 'oil', iconKey: 'oil'),
        throwsStateError,
      );
      expect(
        () => _input(name: '').toItem(id: 'oil', iconKey: 'oil'),
        throwsStateError,
      );
    });
  });

  group('shared field rules', () {
    test('installKmProblem mirrors the form boundary', () {
      expect(installKmProblem('0', currentOdometer: 10), isNull);
      expect(installKmProblem('11', currentOdometer: 10),
          ServiceFieldProblem.odometerAheadOfCurrent);
    });

    test('positiveIntProblem requires a whole number above zero', () {
      expect(positiveIntProblem('1'), isNull);
      expect(positiveIntProblem('0'), ServiceFieldProblem.notPositive);
      expect(positiveIntProblem('x'), ServiceFieldProblem.notANumber);
    });
  });
}
