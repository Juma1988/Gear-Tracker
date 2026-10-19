import 'package:app/controllers/dashboard_controller.dart';
import 'package:app/data/garage_repository.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/fuel_calculations.dart';
import 'package:app/models/fuel_entry.dart';
import 'package:app/models/vehicle_profile.dart';
import 'package:app/screens/fuel_screen.dart';
import 'package:app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Never use the production garage key or schedule maintenance reminders here.
class _NativeFuelQaStorage implements GarageStorage {
  static const key = 'geartracker_fuel_isolated_qa_v1';
  @override
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences
        .reload(); // Force a native disk read, not a cached fixture.
    return preferences.getString(key);
  }

  @override
  Future<bool> write(String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native fuel disk reload, isolation, correction and safe deletion',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_NativeFuelQaStorage.key);
      try {
        GarageRepository repository() =>
            GarageRepository(storage: _NativeFuelQaStorage());
        await repository().saveCollection(
          GarageCollection(
            vehicles: [
              for (final id in ['corolla', 'gti'])
                VehicleProfile(
                  id: id,
                  year: 2012,
                  model: 'Fuel QA $id',
                  garage: GarageSnapshot.empty(),
                ),
            ],
            selectedVehicleId: 'corolla',
            defaultVehicleId: GarageCollection.lastUsedVehicleId,
          ),
        );
        var controller = DashboardController(repository: repository());
        await controller.load();
        final today = DateTime.now().toUtc();
        FuelEntry entry(
          String id,
          int km,
          double liters,
          int days, {
          String vehicle = 'corolla',
          bool full = true,
          int grade = 92,
          double price = 20,
        }) => FuelEntry(
          id: id,
          vehicleId: vehicle,
          date: today.subtract(Duration(days: days)),
          odometer: km,
          liters: liters,
          cost: liters * price,
          recordedPrice: price,
          fullTank: full,
          grade: grade,
        );
        expect(
          await controller.saveFuel(
            entry('anchor', 10000, 40, 3),
            usualGrade: 92,
          ),
          isTrue,
        );
        expect(
          await controller.saveFuel(
            entry('partial', 10100, 10, 2, full: false),
            usualGrade: 92,
          ),
          isTrue,
        );
        expect(
          await controller.saveFuel(entry('end', 10300, 20, 1), usualGrade: 92),
          isTrue,
        );
        controller = DashboardController(repository: repository());
        await controller.load();
        expect(controller.fuelEntries, hasLength(3));
        expect(
          FuelCalculations.intervals(
            controller.fuelEntries,
            'corolla',
          ).single.kmPerLiter,
          10,
        );
        expect(controller.vehicle!.fuelPreferences.prices[92], 20);
        var selected = controller.collection!.copyWith(
          selectedVehicleId: 'gti',
        );
        controller.selectVehicle(selected.selectedVehicle, selected);
        expect(controller.fuelEntries, isEmpty);
        expect(controller.vehicle!.fuelPreferences.prices, isEmpty);
        expect(
          await controller.saveFuel(
            entry('gti-fill', 500, 20, 0, vehicle: 'gti', grade: 95, price: 30),
            usualGrade: 95,
          ),
          isTrue,
        );
        controller = DashboardController(repository: repository());
        await controller.load();
        expect(controller.vehicle!.id, 'gti');
        expect(controller.vehicle!.fuelPreferences.usualGrade, 95);
        expect(controller.vehicle!.fuelPreferences.prices[95], 30);
        expect(controller.fuelEntries.single.id, 'gti-fill');
        selected = controller.collection!.copyWith(
          selectedVehicleId: 'corolla',
        );
        expect(await controller.saveCollection(selected), isTrue);
        expect(controller.vehicle!.fuelPreferences.prices[92], 20);
        expect(controller.vehicle!.fuelPreferences.prices[95], isNull);
        expect(
          await controller.saveFuel(
            entry('partial', 10100, 20, 2, full: false),
            usualGrade: 92,
          ),
          isTrue,
        );
        expect(
          FuelCalculations.intervals(
            controller.fuelEntries,
            'corolla',
          ).single.kmPerLiter,
          7.5,
        );
        expect(await controller.deleteFuel('corolla', 'partial'), isTrue);
        controller = DashboardController(repository: repository());
        await controller.load();
        expect(
          FuelCalculations.intervals(controller.fuelEntries, 'corolla'),
          isEmpty,
        );
        expect(
          controller.collection!.vehicles.last.garage.fuelEntries.single.id,
          'gti-fill',
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.classic(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: FuelScreen(
              vehicle: controller.vehicle,
              onAdd: () {},
              onEdit: (_) {},
              onDelete: (_) async => false,
              onVehicle: () {},
              onSettings: () {},
              onRetry: () {},
              onAddVehicle: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('fuel-page-title')), findsOneWidget);
        expect(find.byKey(const Key('fuel-total-spending')), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await preferences.remove(_NativeFuelQaStorage.key);
      }
    },
  );
}
