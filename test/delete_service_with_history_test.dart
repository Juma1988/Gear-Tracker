// Regression tests for the W07 UI-F30 P0 defect: deleting a service that has
// completion history must delete the service AND its history together so the
// persisted garage never references a missing service (which previously made
// every subsequent load fail validation). Undo within the 5s window restores
// both at their prior positions; after expiry the deletion stands.
import 'dart:convert';

import 'package:app/data/garage_repository.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/service_history_entry.dart';
import 'package:app/models/service_item.dart';
import 'package:app/models/vehicle_profile.dart';
import 'package:app/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _l10n = AppLocalizations(Locale('en'));

const _serviceOrder = ['engine-oil', 'battery', 'spark-plugs'];

/// Chronologically ordered history with entries interleaved between services,
/// so undo position restoration is actually exercised (Battery has an entry at
/// index 1 and index 3).
final _history = [
  ServiceHistoryEntry(
    id: 'h-oil-1',
    serviceId: 'engine-oil',
    serviceName: 'Engine Oil',
    completedOdometer: 60000,
    newNote: '',
    newIntervalKm: 10000,
    completedAt: DateTime(2025, 1, 1),
  ),
  ServiceHistoryEntry(
    id: 'h-batt-1',
    serviceId: 'battery',
    serviceName: 'Battery',
    completedOdometer: 65000,
    newNote: '',
    newIntervalKm: 20000,
    completedAt: DateTime(2025, 3, 1),
  ),
  ServiceHistoryEntry(
    id: 'h-oil-2',
    serviceId: 'engine-oil',
    serviceName: 'Engine Oil',
    completedOdometer: 70000,
    newNote: '',
    newIntervalKm: 10000,
    completedAt: DateTime(2025, 6, 1),
  ),
  ServiceHistoryEntry(
    id: 'h-batt-2',
    serviceId: 'battery',
    serviceName: 'Battery',
    completedOdometer: 72000,
    newNote: '',
    newIntervalKm: 20000,
    completedAt: DateTime(2025, 7, 1),
  ),
  ServiceHistoryEntry(
    id: 'h-spark-1',
    serviceId: 'spark-plugs',
    serviceName: 'Spark plugs',
    completedOdometer: 74000,
    newNote: '',
    newIntervalKm: 30000,
    completedAt: DateTime(2025, 9, 1),
  ),
];

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

List<ServiceItem> get _services => [
  for (final id in _serviceOrder) _service(id, _displayName(id)),
];

String _displayName(String id) => switch (id) {
  'engine-oil' => 'Engine Oil',
  'battery' => 'Battery',
  'spark-plugs' => 'Spark plugs',
  _ => id,
};

String _collectionJson({List<ServiceHistoryEntry>? history}) => jsonEncode(
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
          services: _services,
          tires: const [],
          history: history ?? _history,
        ),
      ),
    ],
  ).toJson(),
);

Map<String, dynamic> _garageOf(String payload) {
  final collection = jsonDecode(payload) as Map<String, dynamic>;
  return (collection['vehicles'] as List<dynamic>).single['garage']
      as Map<String, dynamic>;
}

List<String> _serviceIds(String payload) => [
  for (final service in _garageOf(payload)['services'] as List<dynamic>)
    (service as Map<String, dynamic>)['id'] as String,
];

List<String> _historyIds(String payload) => [
  for (final entry in _garageOf(payload)['history'] as List<dynamic>)
    (entry as Map<String, dynamic>)['id'] as String,
];

List<String> _historyServiceIds(String payload) => [
  for (final entry in _garageOf(payload)['history'] as List<dynamic>)
    (entry as Map<String, dynamic>)['serviceId'] as String,
];

void main() {
  group('UI-F30 delete service with completion history', () {
    testWidgets(
      'confirmation states the history will also be removed when history exists',
      (tester) async {
        final storage = _RecordingStorage(_collectionJson());
        await tester.pumpWidget(_dashboard(storage));
        await tester.pumpAndSettle();

        await _openDeleteDialog(tester, 'battery');

        expect(
          find.text(_l10n.removeServiceAndHistoryFromVehicle('Battery')),
          findsOneWidget,
        );

        // Cancel leaves both service and history untouched.
        await tester.tap(find.text(_l10n.cancel));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('service-health-card-content-battery')),
          findsOneWidget,
        );
        expect(_serviceIds(storage.lastPayload!), _serviceOrder);
        expect(_historyIds(storage.lastPayload!), [
          'h-oil-1',
          'h-batt-1',
          'h-oil-2',
          'h-batt-2',
          'h-spark-1',
        ]);
      },
    );

    testWidgets(
      'deleting a serviced service removes its history and the garage still loads after relaunch',
      (tester) async {
        final storage = _RecordingStorage(_collectionJson());
        await tester.pumpWidget(_dashboard(storage));
        await tester.pumpAndSettle();

        await _deleteServiceFromMenu(tester, 'engine-oil');

        // No save error, undo window is offered.
        expect(find.text(_l10n.changesSaveFailed), findsNothing);
        expect(find.text(_l10n.undoAction), findsOneWidget);

        // The written payload removed the service AND its history entries.
        expect(
          _serviceIds(storage.lastPayload!),
          isNot(contains('engine-oil')),
        );
        expect(
          _historyServiceIds(storage.lastPayload!),
          isNot(contains('engine-oil')),
        );
        expect(_historyIds(storage.lastPayload!), [
          'h-batt-1',
          'h-batt-2',
          'h-spark-1',
        ]);

        // Simulated relaunch over the same bytes loads without validation error.
        final reloaded = await GarageRepository(storage: storage)
            .loadCollection();
        final garage = reloaded.selectedVehicle.garage;
        expect(garage.services.map((s) => s.id), isNot(contains('engine-oil')));
        expect(
          garage.history.map((entry) => entry.serviceId),
          isNot(contains('engine-oil')),
        );
        expect(garage.history, hasLength(3));
      },
    );

    testWidgets(
      'undo restores the service AND its history at prior positions and survives a fresh reload',
      (tester) async {
        final storage = _RecordingStorage(_collectionJson());
        await tester.pumpWidget(_dashboard(storage));
        await tester.pumpAndSettle();

        await _deleteServiceFromMenu(tester, 'battery');

        // Deletion removed the service and both Battery history entries.
        expect(_serviceIds(storage.lastPayload!), [
          'engine-oil',
          'spark-plugs',
        ]);
        expect(_historyIds(storage.lastPayload!), [
          'h-oil-1',
          'h-oil-2',
          'h-spark-1',
        ]);

        await tester.tap(find.text(_l10n.undoAction));
        await tester.pumpAndSettle();

        // Service restored at its prior index (1) in the persisted payload.
        expect(_serviceIds(storage.lastPayload!), _serviceOrder);
        // Both history entries restored at their prior positions 1 and 3.
        expect(_historyIds(storage.lastPayload!), [
          'h-oil-1',
          'h-batt-1',
          'h-oil-2',
          'h-batt-2',
          'h-spark-1',
        ]);

        // A completely fresh repository reloads the restored order (relaunch).
        final reloaded = await GarageRepository(storage: storage)
            .loadCollection();
        final garage = reloaded.selectedVehicle.garage;
        expect(garage.services.map((s) => s.id).toList(), _serviceOrder);
        expect(garage.history.map((e) => e.id).toList(), [
          'h-oil-1',
          'h-batt-1',
          'h-oil-2',
          'h-batt-2',
          'h-spark-1',
        ]);
        final restoredBattery = garage.services.firstWhere(
          (s) => s.id == 'battery',
        );
        expect(restoredBattery.name, 'Battery');
        expect(restoredBattery.intervalKm, 20000);
      },
    );

    testWidgets(
      'after the 5s window the deletion of service and history stands and the garage remains loadable',
      (tester) async {
        final storage = _RecordingStorage(_collectionJson());
        await tester.pumpWidget(_dashboard(storage));
        await tester.pumpAndSettle();

        await _deleteServiceFromMenu(tester, 'spark-plugs');

        // Inside the window undo is actionable.
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(find.text(_l10n.undoAction), findsOneWidget);

        // Cross the boundary: snack bar dismisses itself.
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.text(_l10n.undoAction), findsNothing);
        expect(
          find.byKey(const Key('service-health-card-content-spark-plugs')),
          findsNothing,
        );

        // Service and its history are gone from the persisted payload.
        expect(
          _serviceIds(storage.lastPayload!),
          isNot(contains('spark-plugs')),
        );
        expect(
          _historyServiceIds(storage.lastPayload!),
          isNot(contains('spark-plugs')),
        );

        // Relaunch stays loadable.
        final reloaded = await GarageRepository(storage: storage)
            .loadCollection();
        expect(
          reloaded.selectedVehicle.garage.services.map((s) => s.id),
          isNot(contains('spark-plugs')),
        );
        expect(
          reloaded.selectedVehicle.garage.history.map((e) => e.serviceId),
          isNot(contains('spark-plugs')),
        );
      },
    );
  });

  group('GarageRepository defense in depth', () {
    test('saveCollection rejects a snapshot with orphaned history and does not write', () async {
      final invalidCollection = GarageCollection(
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
              services: [_service('battery', 'Battery')],
              tires: const [],
              // References a service that is not in the garage.
              history: [
                ServiceHistoryEntry(
                  id: 'h-orphan',
                  serviceId: 'engine-oil',
                  serviceName: 'Engine Oil',
                  completedOdometer: 60000,
                  newNote: '',
                  newIntervalKm: 10000,
                  completedAt: DateTime(2025, 1, 1),
                ),
              ],
            ),
          ),
        ],
      );
      final storage = _RecordingStorage(null);

      await expectLater(
        GarageRepository(storage: storage).saveCollection(invalidCollection),
        throwsA(
          isA<GarageDataException>().having(
            (error) => error.kind,
            'kind',
            GarageFailureKind.validation,
          ),
        ),
      );

      // Non-destructive: nothing was written to storage.
      expect(storage.writes, isEmpty);
      expect(storage.lastPayload, isNull);
    });

    test(
      'saveCollection still accepts a valid snapshot with history',
      () async {
        final storage = _RecordingStorage(null);
        final valid = GarageCollection(
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
                services: _services,
                tires: const [],
                history: _history,
              ),
            ),
          ],
        );

        await GarageRepository(storage: storage).saveCollection(valid);

        expect(storage.writes, hasLength(1));
        final reloaded = await GarageRepository(storage: storage)
            .loadCollection();
        expect(reloaded.selectedVehicle.garage.history, hasLength(5));
      },
    );
  });
}

Future<void> _openDeleteDialog(WidgetTester tester, String id) async {
  final card = find.byKey(Key('service-health-card-$id'));
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.longPress(card);
  await tester.pumpAndSettle();
  await tester.tap(find.text(_l10n.deleteService));
  await tester.pumpAndSettle();
  expect(find.text(_l10n.deleteServiceQuestion), findsOneWidget);
}

Future<void> _deleteServiceFromMenu(WidgetTester tester, String id) async {
  await _openDeleteDialog(tester, id);
  await tester.tap(find.widgetWithText(FilledButton, _l10n.delete));
  await tester.pumpAndSettle();
}

Widget _dashboard(GarageStorage storage) => _localizedApp(
  DashboardScreen(repository: GarageRepository(storage: storage)),
);

Widget _localizedApp(Widget child) => MaterialApp(
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: child,
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
