import 'dart:convert';

import 'package:app/data/data.dart';
import 'package:app/data/garage_repository.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/service_history_entry.dart';
import 'package:app/models/service_item.dart';
import 'package:app/models/tire_item.dart';
import 'package:app/models/vehicle_profile.dart';
import 'package:app/screens/dashboard_screen.dart';
import 'package:app/screens/add_service_screen.dart';
import 'package:app/screens/edit_service_screen.dart';
import 'package:app/screens/edit_tire_screen.dart';
import 'package:app/screens/history_screen.dart';
import 'package:app/widgets/odometer_card.dart';
import 'package:app/widgets/history_entry_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _l10n = AppLocalizations(Locale('en'));
const _numbers = DefaultMaterialLocalizations();

Future<void> _tapServiceCard(WidgetTester tester) async {
  final serviceCard = find.byKey(
    const Key('service-health-card-content-engine-oil'),
  );
  await tester.ensureVisible(serviceCard);
  await tester.tap(
    find.descendant(of: serviceCard, matching: find.byType(InkWell)).first,
  );
}

Future<void> _openServiceEditor(WidgetTester tester) async {
  await _tapServiceCard(tester);
  await tester.pumpAndSettle();
  final edit = find.text(_l10n.editServiceHint);
  if (edit.evaluate().isNotEmpty) {
    await tester.tap(edit.last);
    await tester.pumpAndSettle();
  }
}

Future<void> _openServiceCompletion(WidgetTester tester) async {
  await _tapServiceCard(tester);
  await tester.pumpAndSettle();
  final mark = find.text(_l10n.serviceActionMarkServiced);
  if (mark.evaluate().isNotEmpty) {
    await tester.tap(mark.last);
    await tester.pumpAndSettle();
  }
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  final form = find.byKey(const Key('service-form-scroll-view'));
  final formScrollable = find.descendant(
    of: form,
    matching: find.byType(Scrollable),
  );
  final isStickySave = finder.toString().contains(
    'service-form-sticky-save-button',
  );
  if (!isStickySave &&
      form.evaluate().isNotEmpty &&
      formScrollable.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: formScrollable.first,
    );
    final scrollState = tester.state<ScrollableState>(formScrollable.first);
    scrollState.position.jumpTo(scrollState.position.maxScrollExtent);
    await tester.pump();
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<void> _openCustomServiceForm(WidgetTester tester) async {
  final customEntry = find.byKey(const Key('start-custom-service-button'));
  if (customEntry.evaluate().isNotEmpty) {
    await tester.tap(customEntry);
  }
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('custom-service-icon-auto')));
  await tester.pumpAndSettle();
}

Future<void> _showEditOptionalDetails(WidgetTester tester) async {
  final toggle = find.byKey(const Key('edit-service-optional-details-toggle'));
  if (toggle.evaluate().isNotEmpty) {
    await tester.tap(toggle);
    await tester.pumpAndSettle();
  }
}

Future<void> _showOptionalServiceDetails(WidgetTester tester) async {
  final toggle = find.byKey(const Key('service-form-optional-details-toggle'));
  final form = find.byKey(const Key('service-form-scroll-view'));
  final formScrollables = find.descendant(
    of: form,
    matching: find.byType(Scrollable),
  );
  if (toggle.evaluate().isEmpty && formScrollables.evaluate().isNotEmpty) {
    tester.state<ScrollableState>(formScrollables.first).position.jumpTo(0);
    await tester.pump();
  }
  await tester.scrollUntilVisible(
    toggle,
    300,
    scrollable: formScrollables.evaluate().isNotEmpty
        ? formScrollables.first
        : find.byType(Scrollable).last,
  );
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'migrates a v2 snapshot to v3, preserves history, and rewrites it',
    () async {
      final history = _historyEntry();
      final storage = _FakeGarageStorage(
        jsonEncode({
          ...GarageSnapshot(
            odometer: 75000,
            services: initialServices,
            tires: initialTires,
            history: [history],
          ).toJson(),
          'schemaVersion': 2,
        }),
      );

      final loaded = await GarageRepository(storage: storage)
          .loadLegacySnapshot();

      expect(loaded.odometer, 75000);
      expect(loaded.history.single.id, history.id);
      expect(storage.writes, hasLength(1));
      expect(
        jsonDecode(storage.writes.single)['schemaVersion'],
        GarageSnapshot.currentSchemaVersion,
      );
    },
  );

  test(
    'reports malformed and unsupported snapshots without overwriting them',
    () async {
      for (final raw in [
        'not json',
        jsonEncode({'schemaVersion': 999}),
      ]) {
        final storage = _FakeGarageStorage(raw);

        await expectLater(
          GarageRepository(storage: storage).loadLegacySnapshot(),
          throwsA(isA<GarageDataException>()),
        );
        expect(storage.writes, isEmpty);
      }
    },
  );

  test(
    'quarantines corrupt collection data and recovers to an empty garage',
    () async {
      const raw = 'not json';
      final storage = _QuarantineGarageStorage(raw);

      final collection = await GarageRepository(storage: storage)
          .loadCollection();

      expect(collection.isEmpty, isTrue);
      expect(storage.quarantinedPayloads, [raw]);
      expect(storage.writes, isEmpty);
      expect(storage.value, raw);
    },
  );

  test('rejects snapshots with invalid lifecycle data', () {
    final json = GarageSnapshot.seeded().toJson();
    (json['services'] as List).first['intervalKm'] = 0;

    expect(
      () => GarageSnapshot.fromJson(json),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'persists shelf-life fields and defaults legacy services to disabled',
    () {
      final json = GarageSnapshot.seeded().toJson();
      final service = (json['services'] as List).first as Map<String, dynamic>;
      service['hasShelfLife'] = true;
      service['shelfLifeMonths'] = 24;

      final restored = GarageSnapshot.fromJson(json).services.single;

      expect(restored.hasShelfLife, isTrue);
      expect(restored.shelfLifeMonths, 24);
      expect(restored.shelfLifeDueDate, isNotNull);
      final legacyJson = Map<String, dynamic>.from(service)
        ..remove('hasShelfLife')
        ..remove('shelfLifeMonths');
      expect(ServiceItem.fromJson(legacyJson).hasShelfLife, isFalse);
    },
  );

  test(
    'uses the earliest mileage or shelf-life deadline for service status',
    () {
      final service = ServiceItem(
        id: 'battery',
        name: 'Battery',
        note: '12V',
        serviceOdometer: 0,
        intervalKm: 100000,
        iconKey: 'battery',
        installDate: DateTime(2026, 1, 31),
        hasShelfLife: true,
        shelfLifeMonths: 1,
      );

      expect(service.shelfLifeDueDate, DateTime(2026, 3, 3));
      expect(
        service.statusAt(1, now: DateTime(2026, 3, 3)),
        ServiceStatus.replaceNow,
      );
    },
  );

  test('rejects tire snapshots with duplicate or missing position IDs', () {
    final duplicate = GarageSnapshot.seeded().toJson();
    (duplicate['tires'] as List)[1]['id'] = 'front-left';
    final missing = GarageSnapshot.seeded().toJson();
    (missing['tires'] as List).removeLast();

    expect(
      () => GarageSnapshot.fromJson(duplicate),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => GarageSnapshot.fromJson(missing),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects service snapshots with duplicate or blank IDs', () {
    final duplicate = GarageSnapshot.seeded().toJson();
    (duplicate['services'] as List).add(
      Map<String, dynamic>.from((duplicate['services'] as List).first),
    );
    final blank = GarageSnapshot.seeded().toJson();
    (blank['services'] as List).first['id'] = '  ';

    expect(
      () => GarageSnapshot.fromJson(duplicate),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => GarageSnapshot.fromJson(blank),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'rejects malformed tire position snapshots without overwriting them',
    () async {
      final malformed = GarageSnapshot.seeded().toJson();
      (malformed['tires'] as List)[1]['id'] = 'front-left';
      final storage = _FakeGarageStorage(jsonEncode(malformed));

      await expectLater(
        GarageRepository(storage: storage).loadLegacySnapshot(),
        throwsA(isA<GarageDataException>()),
      );
      expect(storage.writes, isEmpty);
    },
  );

  test('surfaces a failed storage write to callers', () async {
    final storage = _FakeGarageStorage(null, failWrites: true);
    final repository = GarageRepository(storage: storage);

    expect(
      repository.save(GarageSnapshot.seeded()),
      throwsA(
        isA<GarageDataException>().having(
          (error) => error.kind,
          'kind',
          GarageFailureKind.write,
        ),
      ),
    );
  });

  testWidgets(
    'persists odometer changes and history across dashboard restart',
    (tester) async {
      final history = _historyEntry();
      final storage = _FakeGarageStorage(
        jsonEncode(
          GarageSnapshot(
            odometer: 74850,
            services: initialServices,
            tires: initialTires,
            history: [history],
          ).toJson(),
        ),
      );
      final repository = GarageRepository(storage: storage);

      await tester.pumpWidget(
        MaterialApp(home: DashboardScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('odometer-wheel-5')),
        const Offset(0, -80),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      final saved = await repository.loadLegacySnapshot();
      expect(saved.odometer, 74851);
      expect(saved.history.single.id, history.id);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(home: DashboardScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<OdometerCard>(find.byType(OdometerCard)).odometer,
        '074851',
      );
    },
  );

  testWidgets(
    'reports the complete legacy sentinel state without overwriting it',
    (tester) async {
      final storage = _FakeGarageStorage(
        jsonEncode(
          GarageSnapshot(
            odometer: 999999,
            services: const [],
            tires: initialTires,
            history: [_historyEntry()],
          ).toJson(),
        ),
      );
      final repository = GarageRepository(storage: storage);

      await expectLater(
        repository.loadLegacySnapshot(),
        throwsA(isA<GarageDataException>()),
      );
      expect(storage.writes, isEmpty);
    },
  );

  testWidgets('shows a retryable message when dashboard persistence fails', (
    tester,
  ) async {
    final storage = _FakeGarageStorage(
      jsonEncode(_seededCollection().toJson()),
      failWrites: true,
    );
    final repository = GarageRepository(storage: storage);

    await tester.pumpWidget(
      MaterialApp(home: DashboardScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('odometer-wheel-5')),
      const Offset(0, -80),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Couldn’t save changes.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(storage.writeAttempts, 1);
    await tester.tap(find.byType(SnackBarAction));
    await tester.pump();
    expect(storage.writeAttempts, 2);
  });

  testWidgets(
    'keeps tire UI unchanged after a failed save and commits it on retry',
    (tester) async {
      final storage = _FakeGarageStorage(
        jsonEncode(_seededCollection().toJson()),
        failedWriteAttempts: 1,
      );
      final repository = GarageRepository(storage: storage);
      await tester.pumpWidget(
        MaterialApp(home: DashboardScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tire-tile-front-left')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('tire-install-odometer-field')),
        '70000',
      );
      await tester.tap(find.byKey(const Key('save-tire-button')));
      await tester.pumpAndSettle();

      expect(find.text('Couldn’t save tire. Try again.'), findsOneWidget);
      expect(find.text('FL tire saved'), findsNothing);
      expect(
        (await repository.loadLegacySnapshot()).tires.first.installOdometer,
        int.parse(initialOdometer),
      );

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(
        (await repository.loadLegacySnapshot()).tires.first.installOdometer,
        70000,
      );
      expect(find.text('FL tire saved'), findsOneWidget);
    },
  );

  testWidgets(
    'opens EditServiceScreen directly when a dashboard service card is tapped',
    (tester) async {
      final repository = GarageRepository(
        storage: _FakeGarageStorage(
          jsonEncode(
            GarageSnapshot(
              odometer: 76000,
              services: const [_service],
              tires: initialTires,
              history: const [],
            ).toJson(),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: DashboardScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      await _openServiceEditor(tester);

      expect(find.byType(EditServiceScreen), findsOneWidget);
      expect(find.text(_l10n.currentOdometer('76,000')), findsOneWidget);
      expect(
        find.byKey(const Key('mark-service-button'), skipOffstage: false),
        findsNothing,
      );
    },
  );

  testWidgets(
    'updates a service configuration and persists it without creating history',
    (tester) async {
      final storage = _FakeGarageStorage(
        jsonEncode(
          _collectionSnapshot(
            GarageSnapshot(
              odometer: 76000,
              services: const [_service],
              tires: initialTires,
              history: const [],
            ),
          ).toJson(),
        ),
      );
      final repository = GarageRepository(storage: storage);

      await tester.pumpWidget(
        MaterialApp(home: DashboardScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      await _openServiceEditor(tester);
      await _showEditOptionalDetails(tester);
      await tester.enterText(
        find.byKey(const Key('service-note-field')),
        '0W-20',
      );
      final saveButton = find.byKey(
        const Key('save-service-button'),
        skipOffstage: false,
      );
      expect(saveButton, findsOneWidget);
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Engine Oil saved'), findsOneWidget);
      final saved = await repository.loadLegacySnapshot();
      expect(saved.services.single.note, '0W-20');
      expect(saved.history, isEmpty);
    },
  );

  testWidgets(
    'does not report a service configuration save when persistence fails',
    (tester) async {
      final storage = _FakeGarageStorage(
        jsonEncode(
          _collectionSnapshot(
            GarageSnapshot(
              odometer: 76000,
              services: const [_service],
              tires: initialTires,
              history: const [],
            ),
          ).toJson(),
        ),
        failedWriteAttempts: 1,
      );
      final repository = GarageRepository(storage: storage);

      await tester.pumpWidget(
        MaterialApp(home: DashboardScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      await _openServiceEditor(tester);
      await _showEditOptionalDetails(tester);
      await tester.enterText(
        find.byKey(const Key('service-note-field')),
        '0W-20',
      );
      final saveButton = find.byKey(
        const Key('save-service-button'),
        skipOffstage: false,
      );
      await tester.ensureVisible(saveButton);
      await tester.pump();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Engine Oil saved'), findsNothing);
      expect(find.text('Couldn’t save changes.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      final saved = await repository.loadLegacySnapshot();
      expect(saved.services.single.serviceOdometer, 74850);
      expect(saved.history, isEmpty);
    },
  );

  testWidgets(
    'retries a failed service configuration save without history changes',
    (tester) async {
      final storage = _FakeGarageStorage(
        jsonEncode(
          _collectionSnapshot(
            GarageSnapshot(
              odometer: 76000,
              services: const [_service],
              tires: initialTires,
              history: const [],
            ),
          ).toJson(),
        ),
        failedWriteAttempts: 1,
      );
      final repository = GarageRepository(storage: storage);

      await tester.pumpWidget(
        MaterialApp(home: DashboardScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      await _openServiceEditor(tester);
      await _showEditOptionalDetails(tester);
      await tester.enterText(
        find.byKey(const Key('service-note-field')),
        '0W-20',
      );
      final saveButton = find.byKey(
        const Key('save-service-button'),
        skipOffstage: false,
      );
      await tester.ensureVisible(saveButton);
      await tester.pump();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(storage.writeAttempts, 1);
      expect(find.text('Engine Oil saved'), findsNothing);
      expect(find.text('Couldn’t save changes.'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      final saved = await repository.loadLegacySnapshot();
      expect(storage.writeAttempts, 2);
      expect(storage.writes, hasLength(1));
      expect(saved.history, isEmpty);
      expect(saved.services.single.note, '0W-20');
      expect(find.text('Engine Oil saved'), findsOneWidget);
    },
  );

  testWidgets(
    'marks a service complete with an edited date and KM, resetting one card and adding history',
    (tester) async {
      final storage = _FakeGarageStorage(
        jsonEncode(
          GarageSnapshot(
            odometer: 76000,
            services: const [_service],
            tires: initialTires,
            history: const [],
          ).toJson(),
        ),
      );
      final repository = GarageRepository(storage: storage);
      await tester.pumpWidget(
        MaterialApp(home: DashboardScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      await _openServiceCompletion(tester);

      await tester.enterText(
        find.byKey(const Key('service-completion-km-field')),
        '75500',
      );
      await tester.tap(
        find.byKey(const Key('service-completion-confirm-button')),
      );
      await tester.pumpAndSettle();

      final saved = await repository.loadLegacySnapshot();
      expect(saved.services, hasLength(1));
      expect(saved.services.single.id, _service.id);
      expect(saved.services.single.serviceOdometer, 75500);
      expect(saved.services.single.installDate, isNotNull);
      expect(saved.history, hasLength(1));
      final history = saved.history.single;
      expect(history.id, startsWith('service-'));
      expect(history.serviceId, _service.id);
      expect(history.serviceName, _service.name);
      expect(history.previousServiceOdometer, _service.serviceOdometer);
      expect(history.completedOdometer, 75500);
      expect(history.newNote, _service.note);
      expect(history.newIntervalKm, _service.intervalKm);
      expect(history.completedAt, isNotNull);
      expect(history.completedAt.isAfter(DateTime(2000)), isTrue);
    },
  );

  testWidgets(
    'marks a Type 02 service complete, resets every unit, and records one exact-ID history entry',
    (tester) async {
      const type02Service = ServiceItem(
        id: 'coil-pack',
        name: 'Coil Pack',
        note: 'Four corner set',
        serviceOdometer: 70000,
        intervalKm: 20000,
        iconKey: 'default',
        type: ServiceType.type02,
        units: [
          ServiceUnit(position: 'front-left', installOdometer: 70000),
          ServiceUnit(position: 'front-right', installOdometer: 71000),
          ServiceUnit(position: 'back-left', installOdometer: 72000),
          ServiceUnit(position: 'back-right', installOdometer: 73000),
        ],
      );
      final storage = _FakeGarageStorage(
        jsonEncode(
          GarageSnapshot(
            odometer: 76000,
            services: const [_service, type02Service],
            tires: initialTires,
            history: const [],
          ).toJson(),
        ),
      );
      final repository = GarageRepository(storage: storage);
      await tester.pumpWidget(
        MaterialApp(home: DashboardScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      final type02Card = find.byKey(const Key('service-health-card-coil-pack'));
      await tester.ensureVisible(type02Card);
      await tester.tap(
        find.descendant(of: type02Card, matching: find.byType(InkWell)).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n.serviceActionMarkServiced));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('service-completion-km-field')),
        '75500',
      );
      await tester.tap(
        find.byKey(const Key('service-completion-confirm-button')),
      );
      await tester.pumpAndSettle();

      final saved = await repository.loadLegacySnapshot();
      final updated = saved.services.singleWhere(
        (service) => service.id == type02Service.id,
      );
      expect(updated.serviceOdometer, 75500);
      expect(updated.units, hasLength(ServiceUnit.positions.length));
      expect(updated.units.map((unit) => unit.position), ServiceUnit.positions);
      expect(
        updated.units.every((unit) => unit.installOdometer == 75500),
        isTrue,
      );
      expect(saved.history, hasLength(1));
      expect(
        saved.history.where((entry) => entry.serviceId == type02Service.id),
        hasLength(1),
      );
      expect(saved.history.single.serviceId, type02Service.id);
      expect(saved.history.single.completedOdometer, 75500);
    },
  );

  testWidgets('rejects invalid service completion KM', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EditServiceScreen(
          service: _service,
          currentOdometer: 76000,
          openCompletionOnLaunch: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('service-completion-km-field')),
      '76001',
    );
    await tester.tap(
      find.byKey(const Key('service-completion-confirm-button')),
    );
    await tester.pump();

    expect(
      find.text(
        _l10n.completionKmHelperText(
          _numbers.formatDecimal(74850),
          _numbers.formatDecimal(76000),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        _l10n.enterCompletionKmRange(
          _numbers.formatDecimal(74850),
          _numbers.formatDecimal(76000),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('service-completion-confirm-button')),
      findsOneWidget,
    );
  });

  testWidgets(
    'retries a service completion without duplicating its history event',
    (tester) async {
      final storage = _FakeGarageStorage(
        jsonEncode(
          _collectionSnapshot(
            GarageSnapshot(
              odometer: 76000,
              services: const [_service],
              tires: initialTires,
              history: const [],
            ),
          ).toJson(),
        ),
        failedWriteAttempts: 1,
      );
      final repository = GarageRepository(storage: storage);
      await tester.pumpWidget(
        MaterialApp(home: DashboardScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      await _openServiceCompletion(tester);
      await tester.tap(
        find.byKey(const Key('service-completion-confirm-button')),
      );
      await tester.pumpAndSettle();

      expect((await repository.loadLegacySnapshot()).history, isEmpty);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      final saved = await repository.loadLegacySnapshot();
      expect(saved.services.single.serviceOdometer, 76000);
      expect(saved.history, hasLength(1));
      expect(saved.history.single.completedOdometer, 76000);
      expect(storage.writes, hasLength(1));
    },
  );

  testWidgets('shows service history newest first', (tester) async {
    final older = _historyEntry();
    final newer = ServiceHistoryEntry(
      id: 'history-2',
      serviceId: 'air-filter',
      serviceName: 'Air Filter',
      previousServiceOdometer: 70000,
      completedOdometer: 76000,
      newNote: 'OEM',
      newIntervalKm: 15000,
      completedAt: DateTime(2026, 10, 7),
    );

    await tester.pumpWidget(
      MaterialApp(home: HistoryScreen(history: [older, newer])),
    );

    expect(
      tester.getTopLeft(find.text('Air Filter')).dy,
      lessThan(tester.getTopLeft(find.text('Engine Oil')).dy),
    );
  });

  testWidgets('shows the immutable completion snapshot and service note', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: HistoryScreen(history: [_historyEntry()])),
    );

    expect(find.text('Completed at 74,850 km'), findsOneWidget);
    expect(find.textContaining('Oct 6'), findsOneWidget);
    expect(find.text('Next interval: 10,000 km'), findsOneWidget);
    expect(find.text('Note: 5W-40 SYN'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(HistoryEntryCard)).label,
      contains('Engine Oil, completed at 74,850 km'),
    );
  });

  testWidgets('filters per-service history by stable service ID only', (
    tester,
  ) async {
    final matching = _historyEntry();
    final sameNameDifferentId = ServiceHistoryEntry(
      id: 'history-2',
      serviceId: 'replacement-engine-oil',
      serviceName: 'Engine Oil',
      previousServiceOdometer: 70000,
      completedOdometer: 76000,
      newNote: 'Synthetic',
      newIntervalKm: 10000,
      completedAt: DateTime(2026, 10, 7),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(
          history: [matching, sameNameDifferentId],
          serviceId: 'engine-oil',
          serviceName: 'Engine Oil',
        ),
      ),
    );

    expect(find.text('Engine Oil'), findsOneWidget);
    expect(find.text('Synthetic'), findsNothing);
  });

  testWidgets('opens filtered history from Edit Service using the stable ID', (
    tester,
  ) async {
    final repository = GarageRepository(
      storage: _FakeGarageStorage(
        jsonEncode(
          _collectionSnapshot(
            GarageSnapshot(
              odometer: 76000,
              services: const [_service],
              tires: initialTires,
              history: [_historyEntry()],
            ),
          ).toJson(),
        ),
      ),
    );

    final snapshot = await repository.loadLegacySnapshot();
    await tester.pumpWidget(
      MaterialApp(
        home: EditServiceScreen(
          service: _service,
          currentOdometer: snapshot.odometer,
          history: snapshot.history,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('edit-service-history-button')));
    await tester.pumpAndSettle();

    expect(find.text('Engine Oil history'), findsOneWidget);
    expect(find.text('Other service'), findsNothing);
  });

  testWidgets('shows an empty state when there is no service history', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HistoryScreen(history: [])),
    );

    expect(find.text(_l10n.noServiceHistoryYet), findsOneWidget);
    expect(find.text(_l10n.completedServiceUpdatesWillAppear), findsOneWidget);
  });

  testWidgets('validates positive service intervals before saving', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EditServiceScreen(service: _service, currentOdometer: 74850),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('service-interval-field')),
      '0',
    );
    await _tapVisible(
      tester,
      find.byKey(const Key('save-service-button'), skipOffstage: false),
    );
    await tester.pump();

    expect(find.text(_l10n.enterPositiveServiceInterval), findsOneWidget);
  });

  testWidgets('validates add-service fields and returns a new service', (
    tester,
  ) async {
    ServiceItem? createdService;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              createdService = await Navigator.of(context).push<ServiceItem>(
                MaterialPageRoute(
                  builder: (_) =>
                      const AddServiceScreen(currentOdometer: 76000),
                ),
              );
            },
            child: const Text('Add a service'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Add a service'));
    await tester.pumpAndSettle();
    await _openCustomServiceForm(tester);

    await tester.enterText(
      find.byKey(const Key('add-service-name-field')),
      'Cabin filter',
    );
    await _showOptionalServiceDetails(tester);
    await tester.enterText(
      find.byKey(const Key('add-service-note-field')),
      'OEM filter',
    );
    await tester.enterText(
      find.byKey(const Key('add-service-interval-field')),
      '15000',
    );
    await _tapVisible(
      tester,
      find.byKey(
        const Key('service-form-sticky-save-button'),
        skipOffstage: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(createdService?.id, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(createdService?.name, 'Cabin filter');
    expect(createdService?.note, 'OEM filter');
    expect(createdService?.serviceOdometer, 76000);
    expect(createdService?.intervalKm, 15000);
    expect(createdService?.iconKey, 'maintenance');
  });

  testWidgets('adds a service from the dashboard and persists it', (
    tester,
  ) async {
    final repository = GarageRepository(
      storage: _FakeGarageStorage(jsonEncode(_seededCollection().toJson())),
    );
    await tester.pumpWidget(
      MaterialApp(home: DashboardScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(_l10n.addService));
    await tester.pumpAndSettle();
    await _openCustomServiceForm(tester);
    await tester.enterText(
      find.byKey(const Key('add-service-name-field')),
      'Cabin filter',
    );
    await _showOptionalServiceDetails(tester);
    await tester.enterText(
      find.byKey(const Key('add-service-note-field')),
      'OEM filter',
    );
    await tester.enterText(
      find.byKey(const Key('add-service-interval-field')),
      '15000',
    );
    await _tapVisible(
      tester,
      find.byKey(
        const Key('service-form-sticky-save-button'),
        skipOffstage: false,
      ),
    );
    await tester.pumpAndSettle();

    final saved = await repository.loadLegacySnapshot();
    final added = saved.services.last;
    expect(saved.services, hasLength(2));
    expect(added.name, 'Cabin filter');
    expect(added.serviceOdometer, 74850);
    expect(find.text('Cabin filter saved'), findsOneWidget);
  });

  testWidgets('keeps dashboard services unchanged when adding fails to save', (
    tester,
  ) async {
    final repository = GarageRepository(
      storage: _FakeGarageStorage(
        jsonEncode(_seededCollection().toJson()),
        failedWriteAttempts: 1,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: DashboardScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(_l10n.addService));
    await tester.pumpAndSettle();
    await _openCustomServiceForm(tester);
    await tester.enterText(
      find.byKey(const Key('add-service-name-field')),
      'Cabin filter',
    );
    await _showOptionalServiceDetails(tester);
    await tester.enterText(
      find.byKey(const Key('add-service-note-field')),
      'OEM filter',
    );
    await tester.enterText(
      find.byKey(const Key('add-service-interval-field')),
      '15000',
    );
    await _tapVisible(
      tester,
      find.byKey(
        const Key('service-form-sticky-save-button'),
        skipOffstage: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cabin filter'), findsNothing);
    expect(find.text('Couldn’t save changes.'), findsOneWidget);
    expect((await repository.loadLegacySnapshot()).services, hasLength(1));

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect((await repository.loadLegacySnapshot()).services, hasLength(2));
    expect(find.text('Cabin filter saved'), findsOneWidget);
  });

  testWidgets('validates a tire installation reading against current mileage', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: EditTireScreen(tire: _tire, currentOdometer: 74850)),
    );
    await tester.enterText(
      find.byKey(const Key('tire-install-odometer-field')),
      '74851',
    );
    await tester.tap(find.byKey(const Key('save-tire-button')));
    await tester.pump();

    expect(
      find.text('Installation km cannot exceed current km'),
      findsOneWidget,
    );
  });
}

const _service = ServiceItem(
  id: 'engine-oil',
  name: 'Engine Oil',
  note: '5W-40 SYN',
  serviceOdometer: 74850,
  intervalKm: 10000,
  iconKey: 'oil',
);

final _tire = TireItem(
  id: 'front-left',
  code: 'FL',
  installOdometer: 70000,
  intervalKm: 50000,
  installDate: DateTime(2026, 10, 6),
);

ServiceHistoryEntry _historyEntry() => ServiceHistoryEntry(
  id: 'history-1',
  serviceId: 'engine-oil',
  serviceName: 'Engine Oil',
  previousServiceOdometer: 70000,
  completedOdometer: 74850,
  newNote: '5W-40 SYN',
  newIntervalKm: 10000,
  completedAt: DateTime(2026, 10, 6),
);

class _FakeGarageStorage implements GarageStorage {
  _FakeGarageStorage(
    this.value, {
    this.failWrites = false,
    this.failedWriteAttempts = 0,
  });

  String? value;
  final bool failWrites;
  int failedWriteAttempts;
  final List<String> writes = [];
  int writeAttempts = 0;

  @override
  Future<String?> read() async => value;

  @override
  Future<bool> write(String value) async {
    writeAttempts++;
    if (failWrites) return false;
    if (failedWriteAttempts > 0) {
      failedWriteAttempts--;
      return false;
    }
    this.value = value;
    writes.add(value);
    return true;
  }
}

class _QuarantineGarageStorage extends _FakeGarageStorage
    implements GarageQuarantineStorage {
  _QuarantineGarageStorage(super.value);

  final List<String> quarantinedPayloads = [];

  @override
  Future<void> quarantine(String rawPayload) async {
    quarantinedPayloads.add(rawPayload);
  }
}

GarageCollection _collectionSnapshot(GarageSnapshot snapshot) {
  final vehicle = VehicleProfile(
    id: '2022-golf-gti',
    year: 2022,
    make: 'Volkswagen',
    model: 'Golf GTI',
    garage: snapshot,
  );
  return GarageCollection(
    vehicles: [vehicle],
    selectedVehicleId: vehicle.id,
    defaultVehicleId: vehicle.id,
  );
}

GarageCollection _seededCollection() =>
    _collectionSnapshot(GarageSnapshot.seeded());
