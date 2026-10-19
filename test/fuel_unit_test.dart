import 'package:app/data/garage_repository.dart';
import 'package:app/data/fuel_demo_seeder.dart';
import 'package:app/preferences/fuel_display_preferences.dart';
import 'package:app/screens/dashboard_screen.dart';
import 'package:app/widgets/fuel_consumption_chart.dart';
import 'package:app/screens/fuel_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fuel_data_test.dart' show FuelMemoryStorage, garage, fill;
import 'fuel_widget_test.dart' show app, car;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('unit defaults, conversion and persisted reload', () async {
    expect(await FuelDisplayPreferences.load(), FuelConsumptionUnit.kmPerLiter);
    expect(FuelConsumptionUnit.litersPer100Km.fromKmPerLiter(12.5), 8);
    expect(
      await FuelDisplayPreferences.save(FuelConsumptionUnit.litersPer100Km),
      isTrue,
    );
    expect(
      await FuelDisplayPreferences.load(),
      FuelConsumptionUnit.litersPer100Km,
    );
    expect(
      await FuelDisplayPreferences.save(FuelConsumptionUnit.kmPerLiter),
      isTrue,
    );
    expect(await FuelDisplayPreferences.load(), FuelConsumptionUnit.kmPerLiter);
  });

  testWidgets(
    'Settings choice persists and updates Dashboard immediately without changing garage',
    (t) async {
      t.view.physicalSize = const Size(900, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final storage = FuelMemoryStorage();
      final repo = GarageRepository(storage: storage);
      await repo.saveCollection(garage());
      await FuelDemoSeeder.seedSelected(repo);
      final before = storage.value;
      await t.pumpWidget(app(DashboardScreen(repository: repo)));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Settings'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('settings-fuel-unit')));
      await t.tap(find.byKey(const Key('settings-fuel-unit')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('fuel-unit-litersPer100Km')));
      await t.pumpAndSettle();
      expect(
        await FuelDisplayPreferences.load(),
        FuelConsumptionUnit.litersPer100Km,
      );
      await t.pageBack();
      await t.pumpAndSettle();
      expect(
        t.widget<Text>(find.byKey(const Key('fuel-chart-value'))).data,
        '8.47 L/100 km',
      );
      expect(storage.value, before);
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(app(DashboardScreen(repository: repo)));
      await t.pumpAndSettle();
      expect(
        t
            .widget<FuelConsumptionChart>(find.byType(FuelConsumptionChart))
            .consumptionUnit,
        FuelConsumptionUnit.litersPer100Km,
      );
    },
  );

  testWidgets('Fuel summary uses selected unit and keeps reliable interval', (
    t,
  ) async {
    await t.pumpWidget(
      app(
        FuelScreen(
          consumptionUnit: FuelConsumptionUnit.litersPer100Km,
          vehicle: car(
            'a',
            entries: [fill('start', 10000, 40), fill('end', 10300, 20, day: 2)],
          ),
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
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.byKey(const Key('fuel-consumption')), 200);
    expect(find.text('6.67 L/100 km'), findsOneWidget);
  });
}
