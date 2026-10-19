import 'dart:async';
import 'dart:convert';

import 'package:app/data/data.dart';
import 'package:app/data/garage_repository.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/service_item.dart';
import 'package:app/models/vehicle_profile.dart';
import 'package:app/screens/dashboard_screen.dart';
import 'package:app/widgets/odometer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (odometer, automaticGroup) in [
    (50, null),
    (75, null),
    (100, 'critical'),
  ]) {
    testWidgets('only critical service auto-opens at odometer $odometer', (
      tester,
    ) async {
      final collection = GarageCollection(
        vehicles: [
          VehicleProfile(
            id: 'defaults',
            year: 2020,
            model: 'Test car',
            garage: GarageSnapshot(
              odometer: odometer,
              services: const [
                ServiceItem(
                  id: 'item',
                  name: 'Test service',
                  note: '',
                  serviceOdometer: 0,
                  intervalKm: 100,
                  iconKey: 'maintenance',
                ),
              ],
              tires: const [],
              history: const [],
            ),
          ),
        ],
        selectedVehicleId: 'defaults',
        defaultVehicleId: GarageCollection.lastUsedVehicleId,
      );
      await tester.pumpWidget(
        _app(
          GarageRepository(
            storage: _ImmediateStorage(jsonEncode(collection.toJson())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('service-summary-good')), findsNothing);
      expect(find.byKey(const Key('service-summary-warning')), findsNothing);
      expect(
        find.byKey(const Key('service-summary-critical')),
        automaticGroup == null ? findsNothing : findsOneWidget,
      );
      expect(
        find.byKey(const Key('service-health-card-item')),
        automaticGroup == null ? findsNothing : findsOneWidget,
      );
      if (automaticGroup == null) {
        final group = odometer == 75 ? 'warning' : 'good';
        await tester.tap(find.byKey(Key('service-stat-$group')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('service-health-card-item')),
          findsOneWidget,
        );
      } else {
        await tester.tap(find.byKey(const Key('service-stat-critical')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('service-health-card-item')), findsNothing);
      }
    });
  }

  testWidgets('tapping an empty status shows only its empty list', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        GarageRepository(
          storage: _ImmediateStorage(_singleVehicleCollectionJson),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('service-stat-warning')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('service-summary-warning')), findsOneWidget);
    expect(find.byKey(const Key('service-summary-empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('service-stat-critical')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('service-summary-warning')), findsNothing);
    expect(find.byKey(const Key('service-summary-critical')), findsOneWidget);
    expect(find.byKey(const Key('service-summary-empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('service-stat-critical')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('service-summary-critical')), findsNothing);
    expect(find.byKey(const Key('service-summary-empty')), findsNothing);
    await tester.tap(find.byKey(const Key('service-stat-critical')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('service-summary-critical')), findsOneWidget);
  });

  testWidgets('shows loading before the garage load resolves', (tester) async {
    final storage = _ControlledStorage();
    await tester.pumpWidget(
      _app(
        GarageRepository(storage: storage),
        odometerSaveDebounce: const Duration(seconds: 10),
      ),
    );

    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    storage.completeRead(_emptyCollectionJson);
    await tester.pumpAndSettle();
  });

  testWidgets('shows an explicitly empty persisted garage', (tester) async {
    await tester.pumpWidget(
      _app(GarageRepository(storage: _ImmediateStorage(_emptyCollectionJson))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your garage is empty'), findsOneWidget);
    expect(find.text('Engine Oil'), findsNothing);
  });

  testWidgets('empty garage copy is localized and grouped for accessibility', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        GarageRepository(storage: _ImmediateStorage(_emptyCollectionJson)),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مرآبك فارغ'), findsOneWidget);
    expect(
      find.text('أضف مركبتك الأولى للبدء في تتبع الصيانة.'),
      findsOneWidget,
    );
    expect(find.text('إضافة مركبة'), findsOneWidget);
    final semanticLabel = tester
        .getSemantics(find.byKey(const Key('empty-garage-message')))
        .getSemanticsData()
        .label;
    expect(
      semanticLabel,
      contains('مرآبك فارغ. أضف مركبتك الأولى للبدء في تتبع الصيانة.'),
    );
    semantics.dispose();
  });

  testWidgets('first launch persists no starter content', (tester) async {
    final storage = _RecordingStorage();
    final repository = GarageRepository(storage: storage);

    final collection = await repository.loadCollection();

    expect(collection.isEmpty, isTrue);
    expect(collection.vehicles, isEmpty);
    expect(storage.writes, isEmpty);

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(find.text('Your garage is empty'), findsOneWidget);
    expect(find.text('Engine Oil'), findsNothing);
    expect(find.text(initialOdometer), findsNothing);
  });

  testWidgets('retries a failed load and shows the recovered empty state', (
    tester,
  ) async {
    final storage = _SequenceStorage(
      reads: [StateError('offline'), _emptyCollectionJson],
    );
    await tester.pumpWidget(
      _app(
        GarageRepository(storage: storage),
        odometerSaveDebounce: Duration.zero,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Couldn’t load your garage. Try again.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Your garage is empty'), findsOneWidget);
  });

  testWidgets('keeps load error visible when retry fails', (tester) async {
    final storage = _SequenceStorage(
      reads: [StateError('offline'), StateError('offline again')],
    );
    await tester.pumpWidget(
      _app(
        GarageRepository(storage: storage),
        odometerSaveDebounce: const Duration(seconds: 10),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load your garage. Try again.'), findsOneWidget);
  });

  testWidgets('loads only the selected vehicle data', (tester) async {
    await tester.pumpWidget(
      _app(
        GarageRepository(storage: _ImmediateStorage(_twoVehicleCollectionJson)),
      ),
    );
    await tester.pumpAndSettle();

    // Healthy entries are hidden from Dashboard, not deleted from Services.
    expect(
      find.byKey(const Key('service-health-card-selected-service')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('bottom-nav-services')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('service-health-card-selected-service')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('service-health-card-other-service')),
      findsNothing,
    );
  });

  testWidgets(
    'healthy tire group is hidden on Dashboard and accessible in Services',
    (tester) async {
      final snapshot = GarageSnapshot(
        odometer: 100,
        services: const [],
        tires: initialTiresForOdometer(100),
        history: const [],
      );
      final collection = GarageCollection(
        vehicles: [
          VehicleProfile(
            id: 'tires',
            year: 2020,
            model: 'Test',
            garage: snapshot,
          ),
        ],
        selectedVehicleId: 'tires',
        defaultVehicleId: GarageCollection.lastUsedVehicleId,
      );
      await tester.pumpWidget(
        _app(
          GarageRepository(
            storage: _ImmediateStorage(jsonEncode(collection.toJson())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('service-health-card-tire-grid')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('bottom-nav-services')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('service-health-card-tire-grid')),
        findsOneWidget,
      );
    },
  );

  testWidgets('Fuel bottom tab opens the per-vehicle fuel screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        GarageRepository(
          storage: _ImmediateStorage(_singleVehicleCollectionJson),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bottom-nav-fuel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('bottom-nav-fuel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fuel-page-title')), findsOneWidget);
    expect(
      find.text('No fuel entries yet. Add your first fill-up.'),
      findsOneWidget,
    );
    final fuelAdd = find.byKey(const Key('bottom-nav-add-fuel'));
    expect(fuelAdd, findsOneWidget);
    expect(
      tester.widget<FloatingActionButton>(fuelAdd).shape,
      isA<CircleBorder>(),
    );
    final fuelScaffold = tester.widget<Scaffold>(
      find.ancestor(of: fuelAdd, matching: find.byType(Scaffold)).first,
    );
    expect(
      fuelScaffold.floatingActionButtonAnimator,
      same(FloatingActionButtonAnimator.noAnimation),
    );
    expect(
      tester.getCenter(fuelAdd).dx,
      moreOrLessEquals(
        tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
        epsilon: 2,
      ),
    );
    expect(find.byKey(const Key('bottom-nav-home')), findsOneWidget);
  });

  testWidgets('navigation follows Dashboard, Fuel, Services, History', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        GarageRepository(
          storage: _ImmediateStorage(_singleVehicleCollectionJson),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dashboard = find.byKey(const Key('bottom-nav-home'));
    final fuel = find.byKey(const Key('bottom-nav-fuel'));
    final services = find.byKey(const Key('bottom-nav-services'));
    final history = find.byKey(const Key('bottom-nav-history'));
    expect(dashboard, findsOneWidget);
    expect(fuel, findsOneWidget);
    expect(services, findsOneWidget);
    expect(history, findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(
      tester.getTopLeft(fuel).dx,
      greaterThan(tester.getTopLeft(dashboard).dx),
    );
    expect(
      tester.getTopLeft(services).dx,
      greaterThan(tester.getTopLeft(fuel).dx),
    );
    expect(
      tester.getTopLeft(history).dx,
      greaterThan(tester.getTopLeft(services).dx),
    );
    await tester.tap(services);
    await tester.pumpAndSettle();

    expect(find.text('No services yet'), findsOneWidget);
    expect(find.text('Add service'), findsOneWidget);
  });

  testWidgets('Dashboard groups positive counts in 60px cards at 40% opacity', (
    tester,
  ) async {
    final collection = GarageCollection(
      vehicles: [
        VehicleProfile(
          id: 'critical-vehicle',
          year: 2020,
          model: 'Test car',
          garage: GarageSnapshot(
            odometer: 100,
            services: const [
              ServiceItem(
                id: 'excellent',
                name: 'Excellent item',
                note: '',
                serviceOdometer: 0,
                intervalKm: 1000,
                iconKey: 'maintenance',
              ),
              ServiceItem(
                id: 'good',
                name: 'Good item',
                note: '',
                serviceOdometer: 50,
                intervalKm: 100,
                iconKey: 'maintenance',
              ),
              ServiceItem(
                id: 'warning',
                name: 'Warning item',
                note: '',
                serviceOdometer: 25,
                intervalKm: 100,
                iconKey: 'maintenance',
              ),
              ServiceItem(
                id: 'replace-soon',
                name: 'Replace soon item',
                note: '',
                serviceOdometer: 10,
                intervalKm: 100,
                iconKey: 'maintenance',
              ),
              ServiceItem(
                id: 'replace-now',
                name: 'Replace now item',
                note: '',
                serviceOdometer: 0,
                intervalKm: 100,
                iconKey: 'maintenance',
              ),
            ],
            tires: const [],
            history: const [],
          ),
        ),
      ],
      selectedVehicleId: 'critical-vehicle',
      defaultVehicleId: GarageCollection.lastUsedVehicleId,
    );
    await tester.pumpWidget(
      _app(
        GarageRepository(
          storage: _ImmediateStorage(jsonEncode(collection.toJson())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('service-stat-count-good')))
          .data,
      '2',
    );
    final chart = find.byKey(const Key('dashboard-fuel-chart'));
    expect(find.byKey(const Key('service-summary-critical')), findsOneWidget);
    for (final (group, ids) in [
      ('warning', ['warning', 'replace-soon']),
      ('good', ['excellent', 'good']),
      ('critical', ['replace-now']),
    ]) {
      await tester.ensureVisible(find.byKey(Key('service-stat-$group')));
      await tester.tap(find.byKey(Key('service-stat-$group')));
      await tester.pumpAndSettle();
      expect(find.byKey(Key('service-summary-$group')), findsOneWidget);
      for (final id in [
        'excellent',
        'good',
        'warning',
        'replace-soon',
        'replace-now',
      ]) {
        final item = find.byKey(Key('service-health-card-$id'));
        expect(item, ids.contains(id) ? findsOneWidget : findsNothing);
        if (ids.contains(id)) {
          expect(
            tester.getBottomLeft(item).dy,
            lessThan(tester.getTopLeft(chart).dy),
          );
        }
      }
    }
    await tester.tap(find.byKey(const Key('service-stat-critical')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('service-summary-critical')), findsNothing);
    expect(
      find.byKey(const Key('service-health-card-replace-now')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('service-stat-critical')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('service-health-card-replace-now')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('service-stat-count-warning')))
          .data,
      '2',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('service-stat-count-critical')))
          .data,
      '1',
    );
    final scheme = Theme.of(
      tester.element(find.byKey(const Key('service-stat-good'))),
    ).colorScheme;
    expect(
      tester.getTopLeft(find.byKey(const Key('service-stats'))).dy -
          tester.getBottomLeft(find.byType(OdometerCard)).dy,
      12,
    );
    expect(
      tester.widget<Card>(find.byKey(const Key('service-stat-good'))).color,
      scheme.primaryContainer.withValues(alpha: 0.4),
    );
    expect(
      tester.widget<Card>(find.byKey(const Key('service-stat-warning'))).color,
      scheme.tertiaryContainer.withValues(alpha: 0.4),
    );
    expect(
      tester.widget<Card>(find.byKey(const Key('service-stat-critical'))).color,
      scheme.errorContainer.withValues(alpha: 0.4),
    );
    for (final (severity, foreground) in [
      ('good', scheme.onPrimaryContainer),
      ('warning', scheme.onTertiaryContainer),
      ('critical', scheme.onErrorContainer),
    ]) {
      final card = find.byKey(Key('service-stat-$severity'));
      expect(tester.getSize(card).height, 60.0);
      final texts = tester.widgetList<Text>(
        find.descendant(of: card, matching: find.byType(Text)),
      );
      expect(texts, hasLength(2));
      for (final text in texts) {
        expect(text.style?.color, foreground);
        expect(text.style?.color?.a, 1.0);
      }
    }
    await tester.tap(find.byKey(const Key('bottom-nav-services')));
    await tester.pumpAndSettle();
    for (final id in [
      'excellent',
      'good',
      'warning',
      'replace-soon',
      'replace-now',
    ]) {
      expect(find.byKey(Key('service-health-card-$id')), findsOneWidget);
    }
  });

  for (final (description, payload, counts) in [
    ('all-zero counts', _singleVehicleCollectionJson, [0, 0, 0]),
    ('mixed counts', _twoVehicleCollectionJson, [1, 0, 0]),
  ]) {
    testWidgets('Dashboard stat opacity follows $description', (tester) async {
      await tester.pumpWidget(
        _app(GarageRepository(storage: _ImmediateStorage(payload))),
      );
      await tester.pumpAndSettle();

      final scheme = Theme.of(
        tester.element(find.byKey(const Key('service-stat-good'))),
      ).colorScheme;
      for (final (severity, background, count) in [
        ('good', scheme.primaryContainer, counts[0]),
        ('warning', scheme.tertiaryContainer, counts[1]),
        ('critical', scheme.errorContainer, counts[2]),
      ]) {
        final card = find.byKey(Key('service-stat-$severity'));
        expect(
          tester.widget<Card>(card).color,
          background.withValues(alpha: count >= 1 ? 0.4 : 0.1),
        );
        expect(
          tester
              .widget<Text>(find.byKey(Key('service-stat-count-$severity')))
              .data,
          '$count',
        );
        expect(tester.getSize(card).height, 60.0);
        for (final text in tester.widgetList<Text>(
          find.descendant(of: card, matching: find.byType(Text)),
        )) {
          expect(text.style?.color?.a, 1.0);
        }
      }
    });
  }

  testWidgets('Dashboard combines accent rails and status icons in one row', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        GarageRepository(
          storage: _ImmediateStorage(_singleVehicleCollectionJson),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final preview = find.byKey(const Key('service-stats'));
    expect(
      find.descendant(of: preview, matching: find.byType(Card)),
      findsNWidgets(3),
    );
    for (final (severity, icon) in [
      ('good', Icons.check_circle_outline),
      ('warning', Icons.warning_amber_rounded),
      ('critical', Icons.error_outline),
    ]) {
      final card = find.byKey(Key('service-stat-$severity'));
      expect(find.byKey(Key('service-stat-$severity-rail')), findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.byIcon(icon)),
        findsOneWidget,
      );
      expect(tester.getSize(card).height, 60);
      expect(tester.widget<Card>(card).color!.a, closeTo(0.1, 0.001));
      expect(
        tester
            .widget<Text>(find.byKey(Key('service-stat-count-$severity')))
            .data,
        '0',
      );
    }
  });

  testWidgets('does not present tire health as required when services exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        GarageRepository(storage: _ImmediateStorage(_twoVehicleCollectionJson)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tire Health'), findsNothing);
    expect(find.text('Add tire health'), findsNothing);
    expect(find.byKey(const Key('empty-tire-health')), findsNothing);
  });

  testWidgets('guides a vehicle with no records to add its first entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        GarageRepository(
          storage: _ImmediateStorage(_singleVehicleCollectionJson),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No records yet'), findsOneWidget);
    expect(
      find.text(
        'Add a service or tire health entry to start tracking this vehicle.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Add service'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('exposes unsaved, saving, saved, and failed save semantics', (
    tester,
  ) async {
    final storage = _ControlledWriteStorage(_singleVehicleCollectionJson);
    final saveStates = <DashboardSaveState>[];
    await tester.pumpWidget(
      _app(
        GarageRepository(storage: storage),
        odometerSaveDebounce: const Duration(seconds: 10),
        onSaveStateChanged: saveStates.add,
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('odometer-wheel-5')),
      const Offset(0, -80),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Unsaved changes'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(saveStates, contains(DashboardSaveState.saving));

    storage.completeNextWrite(true);
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('odometer-wheel-5')),
      const Offset(0, -80),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(saveStates, contains(DashboardSaveState.saving));

    storage.completeNextWrite(false);
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t save changes.'), findsAtLeastNWidgets(1));
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('save-state label is a live semantic status, not color-only', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        GarageRepository(
          storage: _ImmediateStorage(_singleVehicleCollectionJson),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();

    final data = tester
        .getSemantics(find.byKey(DashboardScreen.saveStatusKey))
        .getSemanticsData();
    expect(data.label, 'Saved');
    expect(data.flagsCollection.isLiveRegion, isTrue);

    semantics.dispose();
  });

  testWidgets('retry saves the exact failed odometer payload', (tester) async {
    final storage = _PayloadRecordingStorage(
      _singleVehicleCollectionJson,
      failedWriteAttempts: 1,
    );
    await tester.pumpWidget(_app(GarageRepository(storage: storage)));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('odometer-wheel-5')),
      const Offset(0, -80),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(storage.writePayloads, hasLength(1));
    final failedPayload = storage.writePayloads.single;
    expect(_selectedOdometer(failedPayload), 1);

    await tester.tap(find.byType(SnackBarAction));
    await tester.pumpAndSettle();

    expect(storage.writePayloads, hasLength(2));
    final retriedPayload = storage.writePayloads.last;
    expect(
      jsonEncode(_withoutFreshness(failedPayload)),
      jsonEncode(_withoutFreshness(retriedPayload)),
    );
    final failedTimestamp = _selectedLastUpdatedAt(failedPayload);
    final retriedTimestamp = _selectedLastUpdatedAt(retriedPayload);
    expect(
      retriedTimestamp.compareTo(failedTimestamp),
      greaterThanOrEqualTo(0),
    );
    expect(_selectedOdometer(storage.persistedPayload!), 1);
    expect(find.text('Saved'), findsOneWidget);
  });
}

Widget _app(
  GarageRepository repository, {
  Duration odometerSaveDebounce = const Duration(seconds: 1),
  ValueChanged<DashboardSaveState>? onSaveStateChanged,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: DashboardScreen(
    repository: repository,
    odometerSaveDebounce: odometerSaveDebounce,
    onSaveStateChanged: onSaveStateChanged,
  ),
);

const _emptyCollectionJson =
    '{"schemaVersion":2,"selectedVehicleId":"","defaultVehicleId":"__last_used__","vehicles":[]}';

final _twoVehicleCollectionJson = jsonEncode(
  GarageCollection(
    selectedVehicleId: 'selected',
    defaultVehicleId: GarageCollection.lastUsedVehicleId,
    vehicles: [
      VehicleProfile(
        id: 'selected',
        year: 2020,
        make: 'A',
        model: 'Selected',
        garage: GarageSnapshot(
          odometer: 100,
          services: const [
            ServiceItem(
              id: 'selected-service',
              name: 'Selected service',
              note: '',
              serviceOdometer: 0,
              intervalKm: 1000,
              iconKey: 'maintenance',
            ),
          ],
          tires: const [],
          history: const [],
        ),
      ),
      VehicleProfile(
        id: 'other',
        year: 2021,
        make: 'B',
        model: 'Other',
        garage: GarageSnapshot(
          odometer: 200,
          services: const [
            ServiceItem(
              id: 'other-service',
              name: 'Other service',
              note: '',
              serviceOdometer: 0,
              intervalKm: 1000,
              iconKey: 'maintenance',
            ),
          ],
          tires: const [],
          history: const [],
        ),
      ),
    ],
  ).toJson(),
);

final _singleVehicleCollectionJson = jsonEncode(
  GarageCollection(
    selectedVehicleId: 'vehicle',
    defaultVehicleId: GarageCollection.lastUsedVehicleId,
    vehicles: [
      VehicleProfile(
        id: 'vehicle',
        year: 2020,
        make: 'A',
        model: 'Vehicle',
        garage: GarageSnapshot.empty(),
      ),
    ],
  ).toJson(),
);

int _selectedOdometer(String payload) {
  final collection = jsonDecode(payload) as Map<String, dynamic>;
  final vehicles = collection['vehicles'] as List<dynamic>;
  return ((vehicles.single as Map<String, dynamic>)['garage']
          as Map<String, dynamic>)['odometer']
      as int;
}

Map<String, dynamic> _withoutFreshness(String payload) {
  final collection = jsonDecode(payload) as Map<String, dynamic>;
  final vehicles = collection['vehicles'] as List<dynamic>;
  for (final vehicle in vehicles) {
    final garage =
        (vehicle as Map<String, dynamic>)['garage'] as Map<String, dynamic>;
    garage.remove('lastUpdatedAt');
  }
  return collection;
}

DateTime _selectedLastUpdatedAt(String payload) {
  final collection = jsonDecode(payload) as Map<String, dynamic>;
  final vehicles = collection['vehicles'] as List<dynamic>;
  final garage =
      ((vehicles.single as Map<String, dynamic>)['garage'])
          as Map<String, dynamic>;
  return DateTime.parse(garage['lastUpdatedAt'] as String);
}

class _ControlledStorage implements GarageStorage {
  final _read = Completer<String?>();

  @override
  Future<String?> read() => _read.future;

  void completeRead(String value) => _read.complete(value);

  @override
  Future<bool> write(String value) async => true;
}

class _ImmediateStorage implements GarageStorage {
  _ImmediateStorage(this.value);
  final String value;
  @override
  Future<String?> read() async => value;
  @override
  Future<bool> write(String value) async => true;
}

class _SequenceStorage implements GarageStorage {
  _SequenceStorage({required this.reads});
  final List<Object> reads;
  int _index = 0;
  @override
  Future<String?> read() async {
    final value = reads[_index++];
    if (value is String) return value;
    throw value;
  }

  @override
  Future<bool> write(String value) async => true;
}

class _RecordingStorage implements GarageStorage {
  final List<String> writes = [];

  @override
  Future<String?> read() async => null;

  @override
  Future<bool> write(String value) async {
    writes.add(value);
    return true;
  }
}

class _ControlledWriteStorage implements GarageStorage {
  _ControlledWriteStorage(this.value);

  final String value;
  final _writes = <Completer<bool>>[];

  @override
  Future<String?> read() async => value;

  @override
  Future<bool> write(String value) {
    final write = Completer<bool>();
    _writes.add(write);
    return write.future;
  }

  void completeNextWrite(bool result) => _writes.removeAt(0).complete(result);
}

class _PayloadRecordingStorage implements GarageStorage {
  _PayloadRecordingStorage(
    this.persistedPayload, {
    this.failedWriteAttempts = 0,
  });

  String? persistedPayload;
  int failedWriteAttempts;
  final List<String> writePayloads = [];

  @override
  Future<String?> read() async => persistedPayload;

  @override
  Future<bool> write(String value) async {
    writePayloads.add(value);
    if (failedWriteAttempts > 0) {
      failedWriteAttempts--;
      return false;
    }
    persistedPayload = value;
    return true;
  }
}
