import 'dart:convert';

import 'package:app/data/fuel_demo_data.dart';
import 'package:app/data/fuel_demo_seeder.dart';
import 'package:app/data/garage_repository.dart';
import 'package:app/screens/dashboard_screen.dart';
import 'package:app/models/fuel_calculations.dart';
import 'package:app/models/fuel_entry.dart';
import 'package:app/widgets/fuel_consumption_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fuel_data_test.dart' show FuelMemoryStorage, garage;
import 'fuel_widget_test.dart' show app;

FuelEntry fill(String id, String vehicle, int km, int day) => FuelEntry(
  id: id,
  vehicleId: vehicle,
  date: DateTime.utc(2026, 1, day),
  odometer: km,
  liters: 20,
  cost: 400,
  fullTank: true,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'demo fixture produces seven full-to-full intervals for explicit import',
    () {
      final entries = FuelDemoData.entries(now: DateTime.utc(2026, 10, 19));
      expect(entries, hasLength(15));
      for (final entry in entries) {
        entry.validate();
      }
      expect(
        FuelCalculations.intervals(
          entries,
          FuelDemoData.vehicleId,
        ).map((e) => e.kmPerLiter),
        [10.4, 11.2, 10.8, 12, 11.6, 12.5, 11.8],
      );
      expect(FuelCalculations.intervals(entries, 'my-car'), isEmpty);
    },
  );

  testWidgets(
    'vehicle chart has no mode chips and exposes navigable values without mutation',
    (t) async {
      final real = FuelDemoData.entries()
          .map((e) => e.withOwnership('a'))
          .toList();
      final before = jsonEncode(real.map((e) => e.toJson()).toList());
      await t.pumpWidget(
        app(
          Scaffold(
            body: SingleChildScrollView(
              child: FuelConsumptionChart(
                vehicleId: 'a',
                vehicleName: 'Corolla',
                entries: real,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const Key('fuel-chart-demo')), findsNothing);
      expect(find.byKey(const Key('fuel-chart-live')), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('Demo data'), findsNothing);
      expect(find.text('My vehicle'), findsNothing);
      expect(find.text('Corolla'), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const Key('fuel-chart-value'))).data,
        '11.80 km/L',
      );
      await t.ensureVisible(find.byKey(const Key('fuel-chart-previous')));
      await t.tap(find.byKey(const Key('fuel-chart-previous')));
      await t.pumpAndSettle();
      expect(
        t.widget<Text>(find.byKey(const Key('fuel-chart-value'))).data,
        '12.50 km/L',
      );
      await t.ensureVisible(find.byKey(const Key('fuel-chart-values')));
      await t.tap(find.byKey(const Key('fuel-chart-values')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('fuel-chart-point-0')), findsOneWidget);
      expect(jsonEncode(real.map((e) => e.toJson()).toList()), before);
    },
  );

  testWidgets(
    'Dashboard uses saved chart entries without writing garage data',
    (t) async {
      final storage = FuelMemoryStorage();
      final repository = GarageRepository(storage: storage);
      await repository.saveCollection(garage());
      await FuelDemoSeeder.seedSelected(repository);
      final before = storage.value;
      await t.pumpWidget(app(DashboardScreen(repository: repository)));
      await t.pumpAndSettle();
      expect(
        t.widget<Text>(find.byKey(const Key('fuel-chart-value'))).data,
        '11.80 km/L',
      );
      expect(find.byKey(const Key('fuel-chart-demo')), findsNothing);
      expect(find.byKey(const Key('fuel-chart-live')), findsNothing);
      expect(storage.value, before);
    },
  );

  testWidgets('chart filters by vehicle and refreshes on vehicle change', (
    t,
  ) async {
    final entries = [
      fill('first', 'a', 10000, 1),
      fill('last', 'a', 10200, 2),
      fill('first', 'b', 500, 1),
      fill('last', 'b', 800, 2),
    ];
    Widget chart(String id) => app(
      Scaffold(
        body: SingleChildScrollView(
          child: FuelConsumptionChart(
            vehicleId: id,
            vehicleName: id == 'a' ? 'Corolla' : 'GTI',
            entries: entries,
          ),
        ),
      ),
    );
    await t.pumpWidget(chart('a'));
    await t.pumpAndSettle();
    expect(
      t.widget<Text>(find.byKey(const Key('fuel-chart-value'))).data,
      '10.00 km/L',
    );
    await t.pumpWidget(chart('b'));
    await t.pumpAndSettle();
    expect(
      t.widget<Text>(find.byKey(const Key('fuel-chart-value'))).data,
      '15.00 km/L',
    );
    expect(
      t.widget<Text>(find.byKey(const Key('fuel-chart-source'))).data,
      'GTI',
    );
  });

  testWidgets(
    'without a full pair no preview or guessed value is substituted',
    (t) async {
      await t.pumpWidget(
        app(
          Scaffold(
            body: FuelConsumptionChart(
              vehicleId: 'a',
              vehicleName: 'Corolla',
              entries: [fill('first', 'a', 10000, 1)],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const Key('fuel-consumption-plot')), findsNothing);
      expect(find.byKey(const Key('fuel-chart-value')), findsNothing);
      expect(
        find.text('Needs another full fill after a known full tank.'),
        findsOneWidget,
      );
    },
  );

  for (final size in [const Size(320, 700), const Size(800, 360)]) {
    testWidgets('saved chart fits Arabic 200% text at $size', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        app(
          Scaffold(
            body: SingleChildScrollView(
              child: FuelConsumptionChart(
                vehicleId: 'a',
                vehicleName: 'Corolla',
                entries: FuelDemoData.entries()
                    .map((e) => e.withOwnership('a'))
                    .toList(),
              ),
            ),
          ),
          locale: const Locale('ar'),
          scale: 2,
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const Key('fuel-consumption-plot')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
