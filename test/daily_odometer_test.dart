import 'dart:async';

import 'package:app/data/garage_repository.dart';
import 'package:app/main.dart';
import 'package:app/preferences/daily_odometer_preferences.dart';
import 'package:app/screens/dashboard_screen.dart';
import 'package:app/widgets/daily_odometer_dialog.dart';
import 'package:app/widgets/odometer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fuel_data_test.dart' show FuelMemoryStorage;
import 'fuel_widget_test.dart' show app, car;

Future<GarageRepository> repository(FuelMemoryStorage storage) async {
  final repo = GarageRepository(storage: storage);
  await repo.saveCollection(
    GarageCollection(
      vehicles: [car('a'), car('b')],
      selectedVehicleId: 'a',
      defaultVehicleId: GarageCollection.lastUsedVehicleId,
    ),
  );
  return repo;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'vehicle dropdown loads its own mileage and Save updates only that car',
    (t) async {
      final storage = FuelMemoryStorage();
      final repo = await repository(storage);
      final initial = await repo.loadCollection();
      await repo.saveCollection(
        initial.copyWith(
          vehicles: [
            initial.vehicles.first,
            initial.vehicles.last.withOdometer(50000),
          ],
        ),
      );
      await t.pumpWidget(
        app(DashboardScreen(repository: repo, enableDailyOdometerPrompt: true)),
      );
      await t.pumpAndSettle();
      t
          .widget<OdometerCard>(find.byKey(const Key('daily-odometer-card')))
          .onChanged('011000');
      await t.pump();
      await t.tap(find.byKey(const Key('daily-odometer-vehicle')));
      await t.pumpAndSettle();
      await t.tap(find.text('2022 GTI').last);
      await t.pumpAndSettle();
      expect(
        t
            .widget<OdometerCard>(find.byKey(const Key('daily-odometer-card')))
            .odometer,
        '050000',
      );
      expect((await repo.loadCollection()).selectedVehicleId, 'a');
      t
          .widget<OdometerCard>(find.byKey(const Key('daily-odometer-card')))
          .onChanged('051000');
      await t.pump();
      await t.tap(find.byKey(const Key('daily-odometer-save')));
      await t.pumpAndSettle();
      final saved = await GarageRepository(storage: storage).loadCollection();
      expect(saved.selectedVehicleId, 'b');
      expect(saved.vehicles.first.garage.odometer, 10000);
      expect(saved.vehicles.last.garage.odometer, 51000);
      expect(
        t.widget<OdometerCard>(find.byType(OdometerCard)).odometer,
        '051000',
      );
    },
  );

  testWidgets(
    'changing dialog vehicle then Not now leaves stored selection and mileage intact',
    (t) async {
      final storage = FuelMemoryStorage();
      final repo = await repository(storage);
      final before = storage.value;
      await t.pumpWidget(
        app(DashboardScreen(repository: repo, enableDailyOdometerPrompt: true)),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('daily-odometer-vehicle')));
      await t.pumpAndSettle();
      await t.tap(find.text('2022 GTI').last);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('daily-odometer-skip')));
      await t.pumpAndSettle();
      expect(storage.value, before);
      expect((await repo.loadCollection()).selectedVehicleId, 'a');
    },
  );

  testWidgets('real application root enables the daily prompt', (t) async {
    await GarageRepository().saveCollection(
      GarageCollection(
        vehicles: [car('a')],
        selectedVehicleId: 'a',
        defaultVehicleId: GarageCollection.lastUsedVehicleId,
      ),
    );
    await t.pumpWidget(const GearTrackerApp());
    await t.pumpAndSettle();
    expect(find.byKey(const Key('daily-odometer-dialog')), findsOneWidget);
    await t.tap(find.byKey(const Key('daily-odometer-skip')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('bottom-nav-home')), findsOneWidget);
  });

  testWidgets('daily dialog blocks duplicate saves and retains failed input', (
    t,
  ) async {
    final pending = Completer<bool>();
    var calls = 0;
    await t.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => DailyOdometerDialog(
                  vehicles: [car('a'), car('b')],
                  initialVehicleId: 'a',
                  onSave: (_, _) {
                    calls++;
                    return pending.future;
                  },
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('daily-odometer-save')));
    await t.pump();
    await t.tap(find.byKey(const Key('daily-odometer-save')));
    await t.pump();
    expect(calls, 1);
    expect(
      t
          .widget<TextButton>(find.byKey(const Key('daily-odometer-skip')))
          .onPressed,
      isNull,
    );
    expect(
      t
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('daily-odometer-vehicle')),
          )
          .onChanged,
      isNull,
    );
    pending.complete(false);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('daily-odometer-error')), findsOneWidget);
    expect(
      t
          .widget<OdometerCard>(find.byKey(const Key('daily-odometer-card')))
          .odometer,
      '010000',
    );
  });

  test('daily claim follows local calendar day and persists', () async {
    expect(
      await DailyOdometerPreferences.claimToday(now: DateTime(2026, 10, 19, 8)),
      isTrue,
    );
    expect(
      await DailyOdometerPreferences.claimToday(
        now: DateTime(2026, 10, 19, 23),
      ),
      isFalse,
    );
    expect(
      await DailyOdometerPreferences.claimToday(now: DateTime(2026, 10, 20)),
      isTrue,
    );
  });

  testWidgets(
    'startup prompt prefills selected vehicle; Not now prevents another prompt today',
    (t) async {
      final storage = FuelMemoryStorage();
      final repo = await repository(storage);
      final before = storage.value;
      await t.pumpWidget(
        app(DashboardScreen(repository: repo, enableDailyOdometerPrompt: true)),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const Key('daily-odometer-dialog')), findsOneWidget);
      expect(
        t
            .widget<DropdownButtonFormField<String>>(
              find.byKey(const Key('daily-odometer-vehicle')),
            )
            .initialValue,
        'a',
      );
      expect(
        t
            .widget<OdometerCard>(find.byKey(const Key('daily-odometer-card')))
            .odometer,
        '010000',
      );
      await t.tap(find.byKey(const Key('daily-odometer-skip')));
      await t.pumpAndSettle();
      expect(storage.value, before);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      await t.pumpWidget(
        app(
          DashboardScreen(
            repository: GarageRepository(storage: storage),
            enableDailyOdometerPrompt: true,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const Key('daily-odometer-dialog')), findsNothing);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(DailyOdometerPreferences.key, '2000-1-1');
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      await t.pumpWidget(
        app(
          DashboardScreen(
            repository: GarageRepository(storage: storage),
            enableDailyOdometerPrompt: true,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const Key('daily-odometer-dialog')), findsOneWidget);
    },
  );

  testWidgets(
    'prompt Save persists only selected vehicle and updates Dashboard after success',
    (t) async {
      final storage = FuelMemoryStorage();
      final repo = await repository(storage);
      await t.pumpWidget(
        app(DashboardScreen(repository: repo, enableDailyOdometerPrompt: true)),
      );
      await t.pumpAndSettle();
      t
          .widget<OdometerCard>(find.byKey(const Key('daily-odometer-card')))
          .onChanged('011000');
      await t.pump();
      expect(
        (await GarageRepository(
          storage: storage,
        ).loadCollection()).selectedVehicle.garage.odometer,
        10000,
      );
      await t.tap(find.byKey(const Key('daily-odometer-save')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('daily-odometer-dialog')), findsNothing);
      final saved = await GarageRepository(storage: storage).loadCollection();
      expect(saved.selectedVehicle.garage.odometer, 11000);
      expect(saved.vehicles.last.garage.odometer, 10000);
      expect(
        t.widget<OdometerCard>(find.byType(OdometerCard)).odometer,
        '011000',
      );
    },
  );

  testWidgets(
    'decreasing reading is rejected and failed Save retains input for retry',
    (t) async {
      final storage = FuelMemoryStorage();
      final repo = await repository(storage);
      await t.pumpWidget(
        app(DashboardScreen(repository: repo, enableDailyOdometerPrompt: true)),
      );
      await t.pumpAndSettle();
      t
          .widget<OdometerCard>(find.byKey(const Key('daily-odometer-card')))
          .onChanged('009999');
      await t.pump();
      await t.tap(find.byKey(const Key('daily-odometer-save')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('daily-odometer-error')), findsOneWidget);
      t
          .widget<OdometerCard>(find.byKey(const Key('daily-odometer-card')))
          .onChanged('011000');
      await t.pump();
      storage.fail = true;
      await t.tap(find.byKey(const Key('daily-odometer-save')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('daily-odometer-dialog')), findsOneWidget);
      expect(
        t
            .widget<OdometerCard>(find.byKey(const Key('daily-odometer-card')))
            .odometer,
        '011000',
      );
      expect(
        (await GarageRepository(
          storage: storage,
        ).loadCollection()).selectedVehicle.garage.odometer,
        10000,
      );
      storage.fail = false;
      await t.tap(find.byKey(const Key('daily-odometer-save')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('daily-odometer-dialog')), findsNothing);
    },
  );

  testWidgets('Arabic large-text prompt scrolls without overflow', (t) async {
    t.view.physicalSize = const Size(320, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => DailyOdometerDialog(
                  vehicles: [car('a'), car('b')],
                  initialVehicleId: 'a',
                  onSave: (_, _) async => true,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
        locale: const Locale('ar'),
        scale: 2,
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.ensureVisible(find.byKey(const Key('daily-odometer-skip')));
    await t.tap(find.byKey(const Key('daily-odometer-skip')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('daily-odometer-dialog')), findsNothing);
  });
}
