import 'dart:async';
import 'dart:convert';

import 'package:app/data/data.dart';
import 'package:app/data/garage_repository.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/service_item.dart';
import 'package:app/models/vehicle_profile.dart';
import 'package:app/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    expect(find.text('أضف مركبتك الأولى للبدء في تتبع الصيانة.'), findsOneWidget);
    expect(find.text('إضافة مركبة'), findsOneWidget);
    final semanticLabel = tester
        .getSemantics(find.byKey(const Key('empty-garage-message')))
        .getSemanticsData()
        .label;
    expect(semanticLabel, contains('مرآبك فارغ. أضف مركبتك الأولى للبدء في تتبع الصيانة.'));
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

    expect(
      find.byKey(const Key('service-health-card-selected-service')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('service-health-card-other-service')),
      findsNothing,
    );
  });

  testWidgets('shows a localized next action when tire health is absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        GarageRepository(storage: _ImmediateStorage(_twoVehicleCollectionJson)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tire Health'), findsOneWidget);
    expect(find.text('Add tire health'), findsOneWidget);
    expect(find.byKey(const Key('empty-tire-health')), findsOneWidget);
  });

  testWidgets('guides a vehicle with no records to add its first entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(GarageRepository(storage: _ImmediateStorage(_singleVehicleCollectionJson))),
    );
    await tester.pumpAndSettle();

    expect(find.text('No records yet'), findsOneWidget);
    expect(
      find.text('Add a service or tire health entry to start tracking this vehicle.'),
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
      _app(GarageRepository(storage: _ImmediateStorage(_singleVehicleCollectionJson))),
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
    expect(retriedTimestamp.compareTo(failedTimestamp), greaterThanOrEqualTo(0));
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
      as Map<String, dynamic>)['odometer'] as int;
}

Map<String, dynamic> _withoutFreshness(String payload) {
  final collection = jsonDecode(payload) as Map<String, dynamic>;
  final vehicles = collection['vehicles'] as List<dynamic>;
  for (final vehicle in vehicles) {
    final garage = (vehicle as Map<String, dynamic>)['garage']
        as Map<String, dynamic>;
    garage.remove('lastUpdatedAt');
  }
  return collection;
}

DateTime _selectedLastUpdatedAt(String payload) {
  final collection = jsonDecode(payload) as Map<String, dynamic>;
  final vehicles = collection['vehicles'] as List<dynamic>;
  final garage = ((vehicles.single as Map<String, dynamic>)['garage'])
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
  _PayloadRecordingStorage(this.persistedPayload, {this.failedWriteAttempts = 0});

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
