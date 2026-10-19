// Kira W07 independent QA gate for UI-F27-F32 (discoverability & interaction).
//
// This file is independent from test/discoverability_test.dart: it probes the
// exact acceptance-critical behaviors that the feature tests may not pin down:
//   - undo restores a deleted service at its PRIOR INDEX and a FRESH repository
//     reloads the restored order (relaunch persistence), not just presence;
//   - the undo window is a real bounded timer (actionable before 5s, gone after);
//   - the card/vehicle menus and their items are reachable in semantics;
//   - preset search keeps Custom and Tire entry points when nothing matches;
//   - the new menus do not regress the W05 320px / 200% dashboard;
//   - deleting a service referenced by history is characterized (edge case).
import 'dart:convert';
import 'dart:ui' show SemanticsAction;

import 'package:app/data/garage_repository.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/service_history_entry.dart';
import 'package:app/models/service_item.dart';
import 'package:app/models/tire_item.dart';
import 'package:app/models/vehicle_profile.dart';
import 'package:app/screens/add_service_screen.dart';
import 'package:app/screens/dashboard_screen.dart';
import 'package:app/screens/vehicle_selector_screen.dart';
import 'package:app/widgets/service_health_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/preferences/service_preferences.dart';

const _l10n = AppLocalizations(Locale('en'));

ServiceItem _service(String id, String name) => ServiceItem(
  id: id,
  name: name,
  note: '$name note',
  serviceOdometer: 70000,
  intervalKm: 20000,
  iconKey: switch (id) {
    'engine-oil' => 'oil',
    'battery' => 'battery',
    'spark-plugs' => 'spark_plugs',
    _ => 'maintenance',
  },
);

final _threeServices = [
  _service('engine-oil', 'Engine Oil'),
  _service('battery', 'Battery'),
  _service('spark-plugs', 'Spark plugs'),
];

String _collectionJson({
  List<ServiceItem>? services,
  List<ServiceHistoryEntry>? history,
}) => jsonEncode(
  GarageCollection(
    selectedVehicleId: 'vehicle',
    defaultVehicleId: GarageCollection.lastUsedVehicleId,
    vehicles: [
      VehicleProfile(
        id: 'vehicle',
        year: 2020,
        make: 'A',
        model: 'Vehicle',
        garage: GarageSnapshot(
          odometer: 74850,
          services: services ?? _threeServices,
          tires: const [],
          history: history ?? const [],
        ),
      ),
    ],
  ).toJson(),
);

List<String> _serviceIds(String payload) {
  final collection = jsonDecode(payload) as Map<String, dynamic>;
  final garage =
      (collection['vehicles'] as List<dynamic>).single['garage']
          as Map<String, dynamic>;
  return [
    for (final service in garage['services'] as List<dynamic>)
      (service as Map<String, dynamic>)['id'] as String,
  ];
}

Future<void> _deleteServiceFromMenu(WidgetTester tester, String id) async {
  final menu = find.byKey(Key('service-health-card-menu-$id'));
  await tester.ensureVisible(menu);
  await tester.pumpAndSettle();
  await tester.tap(menu);
  await tester.pumpAndSettle();
  await tester.tap(find.text(_l10n.deleteService));
  await tester.pumpAndSettle();
  expect(find.text(_l10n.deleteServiceQuestion), findsOneWidget);
  await tester.tap(find.widgetWithText(FilledButton, _l10n.delete));
  await tester.pumpAndSettle();
}

void main() {
  group('UI-F30 undo restore order and relaunch persistence', () {
    testWidgets(
      'undo restores the deleted service at its prior index in the persisted payload',
      (tester) async {
        final storage = _RecordingStorage(_collectionJson());
        await tester.pumpWidget(_dashboard(storage));
        await tester.pumpAndSettle();

        // Delete the middle service; the canonical order was
        // [engine-oil, battery, spark-plugs].
        await _deleteServiceFromMenu(tester, 'battery');
        expect(_serviceIds(storage.lastPayload!), [
          'engine-oil',
          'spark-plugs',
        ]);

        await tester.tap(find.text(_l10n.undoAction));
        await tester.pumpAndSettle();

        // Restore must put Battery back BEFORE Spark plugs (prior index 1).
        expect(find.text(_l10n.serviceRestored('Battery')), findsOneWidget);
        expect(_serviceIds(storage.lastPayload!), [
          'engine-oil',
          'battery',
          'spark-plugs',
        ]);
      },
    );

    testWidgets(
      'a fresh repository reloads the restored order after undo (relaunch)',
      (tester) async {
        final storage = _RecordingStorage(_collectionJson());
        await tester.pumpWidget(_dashboard(storage));
        await tester.pumpAndSettle();

        await _deleteServiceFromMenu(tester, 'battery');
        await tester.tap(find.text(_l10n.undoAction));
        await tester.pumpAndSettle();

        // Simulate relaunch: a completely new repository over the same bytes.
        final reloaded = await GarageRepository(storage: storage)
            .loadCollection();
        final services = reloaded.selectedVehicle.garage.services;
        expect(services.map((s) => s.id).toList(), [
          'engine-oil',
          'battery',
          'spark-plugs',
        ]);
        final restored = services.firstWhere((s) => s.id == 'battery');
        expect(restored.name, 'Battery');
        expect(restored.note, 'Battery note');
        expect(restored.intervalKm, 20000);
      },
    );
  });

  group('UI-F30 undo window is a real bounded timer', () {
    testWidgets(
      'undo is still actionable inside the window and the deletion stands after it',
      (tester) async {
        final storage = _RecordingStorage(_collectionJson());
        await tester.pumpWidget(_dashboard(storage));
        await tester.pumpAndSettle();

        await _deleteServiceFromMenu(tester, 'engine-oil');

        // Inside the 5s window the undo must still be actionable.
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(find.text(_l10n.undoAction), findsOneWidget);

        // Cross the 5s boundary; the snack bar must dismiss itself and the
        // deletion must stand in state AND in the persisted payload.
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.text(_l10n.undoAction), findsNothing);
        expect(
          find.byKey(const Key('service-health-card-content-engine-oil')),
          findsNothing,
        );
        expect(
          _serviceIds(storage.lastPayload!),
          isNot(contains('engine-oil')),
        );

        // Relaunch: the deletion persisted.
        final reloaded = await GarageRepository(storage: storage)
            .loadCollection();
        expect(
          reloaded.selectedVehicle.garage.services.map((s) => s.id),
          isNot(contains('engine-oil')),
        );
      },
    );
  });

  group('UI-F27/F28/F29 menu semantics reachability', () {
    testWidgets('service card menu is a named, tappable semantics node', (
      tester,
    ) async {
      final storage = _RecordingStorage(_collectionJson());
      await tester.pumpWidget(_dashboard(storage));
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();

      final menu = find.byTooltip(_l10n.serviceMenuTooltip);
      expect(menu, findsWidgets);
      await tester.ensureVisible(menu.first);
      await tester.pumpAndSettle();
      final data = tester.getSemantics(menu.first).getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.tooltip, _l10n.serviceMenuTooltip);

      // Open the menu and verify both actions are present and labeled.
      await tester.tap(menu.first);
      await tester.pumpAndSettle();
      expect(find.text(_l10n.editServiceHint), findsOneWidget);
      expect(find.text(_l10n.deleteService), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('vehicle selector menu is a named, tappable semantics node', (
      tester,
    ) async {
      final vehicles = [
        VehicleProfile(
          id: 'v1',
          year: 2020,
          make: 'A',
          model: 'One',
          garage: GarageSnapshot.empty(),
        ),
      ];
      await tester.pumpWidget(
        _localizedApp(
          VehicleSelectorScreen(vehicles: vehicles, selectedVehicleId: 'v1'),
        ),
      );
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();

      final menu = find.byTooltip(_l10n.vehicleMenuTooltip);
      expect(menu, findsOneWidget);
      final data = tester.getSemantics(menu).getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.tooltip, _l10n.vehicleMenuTooltip);

      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(find.text(_l10n.editVehicle), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('tire grid exposes each edit affordance and routes its tile', (
      tester,
    ) async {
      final tires = TireItem.defaultsForOdometer(70000);
      TireItem? edited;
      await tester.pumpWidget(
        _localizedApp(
          ServiceHealthCard.tireGrid(
            tires: tires,
            currentOdometer: 74850,
            onEditTire: (tire) => edited = tire,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();

      final node = find.bySemanticsLabel(RegExp('Front left tire'));
      expect(node, findsOneWidget);
      expect(
        tester
            .getSemantics(node)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );

      await tester.tap(find.byKey(const Key('tire-tile-front-left')));
      expect(edited?.id, 'front-left');
      semantics.dispose();
    });
  });

  group('UI-F32 search entry points', () {
    testWidgets('Custom and Tire stay reachable while no preset matches', (
      tester,
    ) async {
      await tester.pumpWidget(_localizedApp(const AddServiceScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('service-preset-search-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('service-preset-search-field')),
        'zzz-no-match',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('no-service-presets-message')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('start-custom-service-button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('tire-health-service-card')), findsNothing);
    });
  });

  group('W05 regression at 320px / 200%', () {
    testWidgets('dashboard with new card menus renders without overflow', (
      tester,
    ) async {
      final storage = _RecordingStorage(_collectionJson());
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _localizedAppWithScale(
          child: DashboardScreen(
            repository: GarageRepository(storage: storage),
          ),
          scale: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final menu = find.byTooltip(_l10n.serviceMenuTooltip).first;
      await tester.ensureVisible(menu);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(menu).bottom, lessThanOrEqualTo(640));
    });
  });

  group('UI-F30 delete edge case: service referenced by history', () {
    testWidgets(
      'deleting a serviced service removes its history and the garage still loads',
      (tester) async {
        final history = [
          ServiceHistoryEntry(
            id: 'h1',
            serviceId: 'engine-oil',
            serviceName: 'Engine Oil',
            completedOdometer: 60000,
            newNote: '',
            newIntervalKm: 10000,
            completedAt: DateTime(2026, 1, 1),
          ),
        ];
        final storage = _RecordingStorage(_collectionJson(history: history));
        await tester.pumpWidget(_dashboard(storage));
        await tester.pumpAndSettle();

        await _deleteServiceFromMenu(tester, 'engine-oil');

        // 1) The dashboard treats the delete as successful (no save error).
        expect(find.text(_l10n.undoAction), findsOneWidget);
        expect(find.text(_l10n.changesSaveFailed), findsNothing);
        final written = storage.lastPayload!;

        // 2) The written payload references no deleted service: neither the
        // service nor its history entry remains.
        final collection = jsonDecode(written) as Map<String, dynamic>;
        final garage =
            (collection['vehicles'] as List<dynamic>).single['garage']
                as Map<String, dynamic>;
        final serviceIds = [
          for (final service in garage['services'] as List<dynamic>)
            (service as Map<String, dynamic>)['id'] as String,
        ];
        expect(serviceIds, isNot(contains('engine-oil')));
        expect(garage['history'] as List<dynamic>, isEmpty);

        // 3) Simulate relaunch: loading the same bytes succeeds.
        final reloaded = await GarageRepository(storage: storage)
            .loadCollection();
        expect(reloaded.selectedVehicle.garage.history, isEmpty);
        expect(
          reloaded.selectedVehicle.garage.services.map((s) => s.id),
          isNot(contains('engine-oil')),
        );
      },
    );
  });

  group('static bottom navigation', () {
    testWidgets('service dialog opens that service history', (tester) async {
      final entry = ServiceHistoryEntry(
        id: 'engine-oil-history',
        serviceId: 'engine-oil',
        serviceName: 'Engine Oil',
        completedOdometer: 70000,
        newNote: '',
        newIntervalKm: 20000,
        completedAt: DateTime(2026, 3, 8),
      );
      await tester.pumpWidget(
        _dashboard(_RecordingStorage(_collectionJson(history: [entry]))),
      );
      await tester.pumpAndSettle();

      final content = find.byKey(
        const Key('service-health-card-content-engine-oil'),
      );
      await tester.ensureVisible(content);
      await tester.tap(
        find.descendant(of: content, matching: find.byType(InkWell)).first,
      );
      await tester.pumpAndSettle();
      final historyAction = find.byKey(
        const Key('service-dialog-history-action'),
      );
      final editAction = find.byKey(const Key('service-dialog-edit-action'));
      final recordAction = find.byKey(
        const Key('service-dialog-record-action'),
      );
      expect(
        tester.getSize(historyAction).width,
        tester.getSize(editAction).width,
      );
      expect(
        tester.getSize(historyAction).width,
        tester.getSize(recordAction).width,
      );
      expect(tester.widget(historyAction), isA<OutlinedButton>());
      expect(tester.widget(editAction), isA<OutlinedButton>());
      expect(tester.widget(recordAction), isA<OutlinedButton>());
      await tester.ensureVisible(historyAction);
      await tester.tap(historyAction);
      await tester.pumpAndSettle();

      expect(find.text('Engine Oil history'), findsOneWidget);
      expect(find.text('Engine Oil'), findsOneWidget);
      expect(find.text('Battery'), findsNothing);
    });

    testWidgets('record action is emphasized at Warning health or worse', (
      tester,
    ) async {
      final warningService = _service(
        'engine-oil',
        'Engine Oil',
      ).copyWith(intervalKm: 6000);
      await tester.pumpWidget(
        _dashboard(
          _RecordingStorage(_collectionJson(services: [warningService])),
        ),
      );
      await tester.pumpAndSettle();

      final content = find.byKey(
        const Key('service-health-card-content-engine-oil'),
      );
      await tester.ensureVisible(content);
      await tester.tap(
        find.descendant(of: content, matching: find.byType(InkWell)).first,
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget(find.byKey(const Key('service-dialog-record-action'))),
        isA<FilledButton>(),
      );
    });

    testWidgets(
      'opens overall history, returns home, and hides navigation on Add service',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final history = [
          ServiceHistoryEntry(
            id: 'history-engine',
            serviceId: 'engine-oil',
            serviceName: 'Engine Oil',
            completedOdometer: 60000,
            newNote: '',
            newIntervalKm: 10000,
            completedAt: DateTime(2026, 1, 1),
          ),
          ServiceHistoryEntry(
            id: 'history-battery',
            serviceId: 'battery',
            serviceName: 'Battery replacement',
            completedOdometer: 65000,
            newNote: '',
            newIntervalKm: 30000,
            completedAt: DateTime(2026, 2, 1),
          ),
        ];
        await tester.pumpWidget(
          _dashboard(_RecordingStorage(_collectionJson(history: history))),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<BottomAppBar>(find.byType(BottomAppBar)).height,
          68,
        );

        await tester.tap(find.byKey(const Key('bottom-nav-history')));
        await tester.pumpAndSettle();
        expect(find.text('Overall history'), findsOneWidget);
        expect(find.text('Engine Oil'), findsOneWidget);
        expect(find.text('Battery replacement'), findsOneWidget);

        await tester.tap(find.byKey(const Key('bottom-nav-home')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('bottom-nav-add-service')), findsOneWidget);

        await tester.tap(find.byKey(const Key('bottom-nav-add-service')));
        await tester.pumpAndSettle();
        expect(find.text(_l10n.chooseIcon), findsOneWidget);
        expect(find.byKey(const Key('bottom-nav-home')), findsNothing);
      },
    );

    testWidgets('plus follows the persisted customService preference', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_dashboard(_RecordingStorage(_collectionJson())));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('bottom-nav-add-service')));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.chooseIcon), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await ServicePreferences.saveCustomService(true);
      await tester.tap(find.byKey(const Key('bottom-nav-add-service')));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.addServiceTitle), findsOneWidget);
      expect(
        find.byKey(const Key('start-custom-service-button')),
        findsOneWidget,
      );
    });

    testWidgets('direct custom Back exits to dashboard from picker and form', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_dashboard(_RecordingStorage(_collectionJson())));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('bottom-nav-add-service')));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.chooseIcon), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bottom-nav-home')), findsOneWidget);
      expect(find.text(_l10n.chooseIcon), findsNothing);

      await tester.tap(find.byKey(const Key('bottom-nav-add-service')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('custom-service-icon-auto')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add-service-name-field')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bottom-nav-home')), findsOneWidget);
      expect(find.byKey(const Key('add-service-name-field')), findsNothing);
    });
  });
}

Widget _dashboard(GarageStorage storage) => _localizedApp(
  DashboardScreen(repository: GarageRepository(storage: storage)),
);

Widget _localizedApp(Widget child) =>
    _localizedAppWithScale(child: child, scale: 1.0);

Widget _localizedAppWithScale({required Widget child, required double scale}) =>
    MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: child,
      ),
    );

class _RecordingStorage implements GarageStorage {
  _RecordingStorage(this.persistedPayload);

  String? persistedPayload;
  final List<String> writes = [];

  String? get lastPayload => persistedPayload;

  @override
  Future<String?> read() async => persistedPayload;

  @override
  Future<bool> write(String value) async {
    writes.add(value);
    persistedPayload = value;
    return true;
  }
}
