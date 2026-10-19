import 'dart:async';

import 'package:app/data/garage_repository.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/fuel_entry.dart';
import 'package:app/models/fuel_preferences.dart';
import 'package:app/models/vehicle_profile.dart';
import 'package:app/screens/fuel_form_screen.dart';
import 'package:app/screens/fuel_screen.dart';
import 'package:app/screens/dashboard_screen.dart';
import 'package:app/screens/add_service_screen.dart';
import 'package:app/screens/settings_screen.dart';
import 'package:app/screens/vehicle_selector_screen.dart';
import 'package:app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fuel_data_test.dart' show FuelMemoryStorage;

VehicleProfile car(
  String id, {
  List<FuelEntry> entries = const [],
  int usual = 92,
}) => VehicleProfile(
  id: id,
  year: id == 'a' ? 2012 : 2022,
  model: id == 'a' ? 'Corolla' : 'GTI',
  fuelPreferences: FuelPreferences(usualGrade: usual, prices: {92: 20, 95: 25}),
  garage: GarageSnapshot(
    odometer: 10000,
    services: const [],
    tires: const [],
    history: const [],
    fuelEntries: entries,
  ),
);
Widget app(
  Widget child, {
  Locale locale = const Locale('en'),
  double scale = 1,
}) => MaterialApp(
  locale: locale,
  theme: AppTheme.classic(),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: child,
);
Future<void> tall(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

TextEditingController field(WidgetTester t, String key) =>
    t.widget<TextFormField>(find.byKey(Key('fuel-$key'))).controller!;
Future<void> type(WidgetTester t, String key, String value) async {
  await t.ensureVisible(find.byKey(Key('fuel-$key')));
  await t.enterText(find.byKey(Key('fuel-$key')), value);
  await t.pump();
}

void main() {
  testWidgets(
    'Services uses Fuel-style title without branding and retains settings and vehicle selection',
    (t) async {
      await tall(t);
      final repo = GarageRepository(storage: FuelMemoryStorage());
      await repo.saveCollection(
        GarageCollection(
          vehicles: [car('a')],
          selectedVehicleId: 'a',
          defaultVehicleId: GarageCollection.lastUsedVehicleId,
        ),
      );
      await t.pumpWidget(app(DashboardScreen(repository: repo)));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('bottom-nav-services')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('services-page-title')), findsOneWidget);
      expect(find.text('GEAR TRACKER'), findsNothing);
      await t.tap(find.byKey(const Key('services-vehicle')));
      await t.pumpAndSettle();
      expect(find.byType(VehicleSelectorScreen), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Settings'));
      await t.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    },
  );

  testWidgets(
    'center Add offers both flows on all tabs and cancellation leaves the tab unchanged',
    (t) async {
      await tall(t);
      SharedPreferences.setMockInitialValues({'customService': true});
      final repo = GarageRepository(storage: FuelMemoryStorage());
      await repo.saveCollection(
        GarageCollection(
          vehicles: [car('a')],
          selectedVehicleId: 'a',
          defaultVehicleId: GarageCollection.lastUsedVehicleId,
        ),
      );
      await t.pumpWidget(app(DashboardScreen(repository: repo)));
      await t.pumpAndSettle();
      for (final tab in ['home', 'fuel', 'services', 'history']) {
        await t.tap(find.byKey(Key('bottom-nav-$tab')));
        await t.pumpAndSettle();
        final add = find.byType(FloatingActionButton);
        final center = t.getCenter(add);
        expect(t.widget<FloatingActionButton>(add).shape, isA<CircleBorder>());
        await t.tap(add);
        await t.pumpAndSettle();
        expect(find.byKey(const Key('add-choice-fuel')), findsOneWidget);
        expect(find.byKey(const Key('add-choice-service')), findsOneWidget);
        await t.tap(find.byKey(const Key('add-choice-cancel')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('add-choice-dialog')), findsNothing);
        expect(t.getCenter(add), center);
      }
      await t.tap(find.byType(FloatingActionButton));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('add-choice-fuel')));
      await t.pumpAndSettle();
      expect(find.byType(FuelFormScreen), findsOneWidget);
      expect(find.byKey(const Key('add-choice-dialog')), findsNothing);
      await t.pageBack();
      await t.pumpAndSettle();
      await t.tap(find.byType(FloatingActionButton));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('add-choice-service')));
      await t.pumpAndSettle();
      expect(find.byType(AddServiceScreen), findsOneWidget);
      expect(find.byKey(const Key('add-choice-dialog')), findsNothing);
    },
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'latest edited field calculates its counterpart, save is single-flight and errors retain data',
    (t) async {
      await tall(t);
      final pending = Completer<bool>();
      var calls = 0;
      FuelEntry? saved;
      await t.pumpWidget(
        app(
          FuelFormScreen(
            vehicle: car('a'),
            onSave: (entry, grade) {
              calls++;
              saved = entry;
              return pending.future;
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(field(t, 'price').text, '20.0');
      expect(find.byKey(const Key('fuel-time')), findsNothing);
      expect(find.text('Fill time'), findsNothing);
      final reviewText = t
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('fuel-review')),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.data ?? '')
          .join(' ');
      expect(RegExp(r'\d{1,2}:\d{2}').hasMatch(reviewText), isFalse);
      expect(
        t.widget<SwitchListTile>(find.byKey(const Key('fuel-full'))).value,
        isTrue,
      );
      await type(t, 'amount', '600');
      expect(field(t, 'liters').text, '30.000');
      await type(t, 'liters', '29.97');
      expect(field(t, 'amount').text, '599.40');
      await type(t, 'price', '25');
      expect(field(t, 'liters').text, '29.97');
      expect(field(t, 'amount').text, '749.25');
      await type(t, 'amount', '500');
      expect(field(t, 'liters').text, '20.000');
      await type(t, 'price', '20');
      expect(field(t, 'amount').text, '500');
      expect(field(t, 'liters').text, '25.000');
      await type(t, 'liters', '');
      expect(field(t, 'amount').text, isEmpty);
      await type(t, 'liters', '29.97');
      expect(field(t, 'amount').text, '599.40');
      await t.tap(find.byKey(const Key('fuel-save')));
      await t.pump();
      await t.tap(find.byKey(const Key('fuel-save')));
      await t.pump();
      expect(calls, 1);
      expect(saved!.liters, 29.97);
      expect(saved!.cost, 599.4);
      expect(saved!.vehicleId, 'a');
      pending.complete(false);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('fuel-form-error')), findsOneWidget);
      expect(field(t, 'liters').text, '29.97');
      expect(field(t, 'amount').text, '599.40');
    },
  );
  testWidgets(
    '92/95 price suggestions, automatic litres input, partial fill and usual grade',
    (t) async {
      await tall(t);
      FuelEntry? saved;
      int? usual;
      await t.pumpWidget(
        app(
          FuelFormScreen(
            vehicle: car('b'),
            onSave: (entry, grade) async {
              saved = entry;
              usual = grade;
              return false;
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('fuel-grade')));
      await t.pumpAndSettle();
      await t.tap(find.text('95').last);
      await t.pumpAndSettle();
      expect(field(t, 'price').text, '25.0');
      expect(find.byKey(const Key('fuel-by-amount')), findsNothing);
      expect(find.byKey(const Key('fuel-by-liters')), findsNothing);
      await type(t, 'liters', '12.5');
      expect(field(t, 'amount').text, '312.50');
      await t.tap(find.byKey(const Key('fuel-full')));
      await t.pump();
      await t.tap(find.byKey(const Key('fuel-usual')));
      await t.pump();
      await t.tap(find.byKey(const Key('fuel-save')));
      await t.pumpAndSettle();
      expect(saved!.fullTank, isFalse);
      expect(saved!.grade, 95);
      expect(usual, 95);
      expect(saved!.vehicleId, 'b');
    },
  );
  testWidgets(
    'required, nonfinite, zero-price and odometer-order errors do not save',
    (t) async {
      await tall(t);
      var calls = 0;
      final old = FuelEntry(
        id: 'old',
        vehicleId: 'a',
        date: DateTime.utc(2026, 1, 1),
        odometer: 10000,
        liters: 20,
        cost: 400,
        fullTank: true,
      );
      await t.pumpWidget(
        app(
          FuelFormScreen(
            vehicle: car('a', entries: [old]),
            onSave: (_, _) async {
              calls++;
              return false;
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('fuel-save')));
      await t.pumpAndSettle();
      expect(calls, 0);
      await type(t, 'price', '0');
      await type(t, 'amount', '600');
      await t.tap(find.byKey(const Key('fuel-save')));
      await t.pumpAndSettle();
      expect(calls, 0);
      await type(t, 'price', '20');
      await type(t, 'amount', 'Infinity');
      await t.tap(find.byKey(const Key('fuel-save')));
      await t.pumpAndSettle();
      expect(calls, 0);
      await type(t, 'amount', '600');
      await type(t, 'odometer', '9999');
      await t.tap(find.byKey(const Key('fuel-save')));
      await t.pumpAndSettle();
      expect(find.textContaining('earlier and later fills'), findsOneWidget);
      expect(calls, 0);
    },
  );
  testWidgets(
    'real Fuel navigation switches every summary and history to the selected vehicle',
    (t) async {
      await tall(t);
      final storage = FuelMemoryStorage();
      final repo = GarageRepository(storage: storage);
      await repo.saveCollection(
        GarageCollection(
          vehicles: [
            car(
              'a',
              entries: [
                FuelEntry(
                  id: 'corolla-fill',
                  vehicleId: 'a',
                  date: DateTime.utc(2026, 1, 1),
                  odometer: 10000,
                  liters: 10,
                  cost: 200,
                  fullTank: true,
                ),
              ],
            ),
            car(
              'b',
              usual: 95,
              entries: [
                FuelEntry(
                  id: 'gti-fill',
                  vehicleId: 'b',
                  date: DateTime.utc(2026, 1, 1),
                  odometer: 10000,
                  liters: 20,
                  cost: 500,
                  grade: 95,
                  fullTank: true,
                ),
              ],
            ),
          ],
          selectedVehicleId: 'a',
          defaultVehicleId: GarageCollection.lastUsedVehicleId,
        ),
      );
      await t.pumpWidget(
        app(DashboardScreen(repository: repo, initialFuelSelected: true)),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const Key('fuel-record-corolla-fill')), findsOneWidget);
      expect(find.byKey(const Key('fuel-record-gti-fill')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('fuel-total-spending')),
          matching: find.text('200.00 EGP'),
        ),
        findsOneWidget,
      );
      await t.tap(find.byKey(const Key('fuel-vehicle')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('vehicle-card-b')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('fuel-record-corolla-fill')), findsNothing);
      expect(find.byKey(const Key('fuel-record-gti-fill')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('fuel-total-spending')),
          matching: find.text('500.00 EGP'),
        ),
        findsOneWidget,
      );
      await t.tap(find.byKey(const Key('fuel-add')));
      await t.pumpAndSettle();
      expect(field(t, 'price').text, '25.0');
      expect(find.text('2022 GTI'), findsNWidgets(2)); // Header and review.
    },
  );
  testWidgets('fuel details support editing and require delete confirmation', (
    t,
  ) async {
    await tall(t);
    final entry = FuelEntry(
      id: 'one',
      vehicleId: 'a',
      date: DateTime.utc(2026, 1, 1),
      odometer: 10000,
      liters: 10,
      cost: 200,
      fullTank: true,
    );
    var edits = 0;
    var deletes = 0;
    await t.pumpWidget(
      app(
        FuelScreen(
          vehicle: car('a', entries: [entry]),
          onAdd: () {},
          onEdit: (_) => edits++,
          onDelete: (_) async {
            deletes++;
            return false;
          },
          onVehicle: () {},
          onSettings: () {},
          onRetry: () {},
          onAddVehicle: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('fuel-record-one')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('fuel-edit')));
    await t.pumpAndSettle();
    expect(edits, 1);
    await t.tap(find.byKey(const Key('fuel-record-one')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('fuel-delete')));
    await t.pumpAndSettle();
    expect(deletes, 0);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(deletes, 0);
    await t.tap(find.byKey(const Key('fuel-record-one')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('fuel-delete')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('fuel-confirm-delete')));
    await t.pumpAndSettle();
    expect(deletes, 1);
    expect(find.byKey(const Key('fuel-record-one')), findsOneWidget);
  });
  testWidgets(
    'create, edit, restart and delete round-trip through the real Fuel navigation',
    (t) async {
      await tall(t);
      final storage = FuelMemoryStorage();
      var repo = GarageRepository(storage: storage);
      await repo.saveCollection(
        GarageCollection(
          vehicles: [car('a'), car('b')],
          selectedVehicleId: 'a',
          defaultVehicleId: GarageCollection.lastUsedVehicleId,
        ),
      );
      await t.pumpWidget(
        app(DashboardScreen(repository: repo, initialFuelSelected: true)),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('fuel-add')));
      await t.pumpAndSettle();
      await type(t, 'price', '25');
      await type(t, 'amount', '600');
      await t.tap(find.byKey(const Key('fuel-save')));
      await t.pumpAndSettle();
      var collection = await GarageRepository(storage: storage)
          .loadCollection();
      final id = collection.selectedVehicle.garage.fuelEntries.single.id;
      expect(collection.selectedVehicle.garage.fuelEntries.single.cost, 600);
      expect(collection.vehicles.last.garage.fuelEntries, isEmpty);
      await t.tap(find.byKey(const Key('fuel-add')));
      await t.pumpAndSettle();
      expect(field(t, 'price').text, '25.0');
      await t.pageBack();
      await t.pumpAndSettle();
      await t.tap(find.byKey(Key('fuel-record-$id')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('fuel-edit')));
      await t.pumpAndSettle();
      expect(field(t, 'amount').text, '600.0');
      await type(t, 'amount', '700');
      await t.tap(find.byKey(const Key('fuel-save')));
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      repo = GarageRepository(storage: storage);
      await t.pumpWidget(
        app(DashboardScreen(repository: repo, initialFuelSelected: true)),
      );
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('fuel-total-spending')),
          matching: find.text('700.00 EGP'),
        ),
        findsOneWidget,
      );
      await t.tap(find.byKey(Key('fuel-record-$id')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('fuel-delete')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('fuel-confirm-delete')));
      await t.pumpAndSettle();
      collection = await GarageRepository(storage: storage).loadCollection();
      expect(collection.selectedVehicle.garage.fuelEntries, isEmpty);
      expect(find.byKey(Key('fuel-record-$id')), findsNothing);
    },
  );

  testWidgets('Arabic large-text form and empty fuel page have no overflow', (
    t,
  ) async {
    t.view.physicalSize = const Size(640, 1400);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      app(
        FuelFormScreen(vehicle: car('a'), onSave: (_, _) async => false),
        locale: const Locale('ar'),
        scale: 2,
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.pumpWidget(
      app(
        FuelScreen(
          vehicle: car('a'),
          onAdd: () {},
          onEdit: (_) {},
          onDelete: (_) async => false,
          onVehicle: () {},
          onSettings: () {},
          onRetry: () {},
          onAddVehicle: () {},
        ),
        locale: const Locale('ar'),
        scale: 2,
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.pumpWidget(
      app(
        FuelScreen(
          vehicle: car(
            'a',
            entries: [
              FuelEntry(
                id: 'rtl',
                vehicleId: 'a',
                date: DateTime.utc(2026, 1, 1),
                odometer: 10000,
                liters: 30,
                cost: 600,
                fullTank: false,
              ),
            ],
          ),
          onAdd: () {},
          onEdit: (_) {},
          onDelete: (_) async => false,
          onVehicle: () {},
          onSettings: () {},
          onRetry: () {},
          onAddVehicle: () {},
        ),
        locale: const Locale('ar'),
        scale: 2,
      ),
    );
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.byKey(const Key('fuel-record-rtl')), 250);
    expect(t.takeException(), isNull);
  });
}
