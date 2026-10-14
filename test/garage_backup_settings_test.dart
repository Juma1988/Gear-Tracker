import 'dart:convert';

import 'package:app/data/garage_backup.dart';
import 'package:app/data/garage_repository.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/service_item.dart';
import 'package:app/models/vehicle_profile.dart';
import 'package:app/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _l10n = AppLocalizations(Locale('en'));

GarageCollection _collection({String vehicleId = 'v1'}) => GarageCollection(
  vehicles: [
    VehicleProfile(
      id: vehicleId,
      year: 2020,
      make: 'Toyota',
      model: 'Corolla',
      garage: const GarageSnapshot(
        odometer: 1500,
        services: [
          ServiceItem(
            id: 'oil',
            name: 'Engine Oil',
            note: '',
            serviceOdometer: 0,
            intervalKm: 1000,
            iconKey: 'maintenance',
          ),
        ],
        tires: [],
        history: [],
      ),
    ),
  ],
  selectedVehicleId: vehicleId,
  defaultVehicleId: GarageCollection.lastUsedVehicleId,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('exposes local-storage and backup guidance', (tester) async {
    final storage = _FakeStorage(jsonEncode(_collection().toJson()));

    await tester.pumpWidget(_app(storage: storage));

    expect(find.byKey(const Key('settings-backup-card')), findsOneWidget);
    expect(find.text(_l10n.backupAndRestore), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-backup-card')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('backup-dialog')), findsOneWidget);
    expect(find.text(_l10n.localStorageTitle), findsOneWidget);
    expect(find.text(_l10n.localStorageGuidance), findsOneWidget);
    expect(find.text(_l10n.backupGuidance), findsWidgets);
  });

  test('localizes storage, plaintext, and restore guidance in Arabic', () {
    const arabic = AppLocalizations(Locale('ar'));

    expect(arabic.localStorageTitle, isNotEmpty);
    expect(arabic.localStorageGuidance, contains('خدمة'));
    expect(arabic.backupGuidance, contains('نص عادي'));
    expect(arabic.backupGuidance, contains('بيانات خاصة'));
    expect(arabic.restoreConfirmMessage, contains('سيستبدل'));
  });

  testWidgets('copies a versioned backup to the clipboard', (tester) async {
    final storage = _FakeStorage(jsonEncode(_collection().toJson()));
    final clipboard = _FakeClipboard();

    await tester.pumpWidget(_app(storage: storage, clipboard: clipboard));
    await tester.tap(find.byKey(const Key('settings-backup-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-dialog-copy')));
    await tester.pumpAndSettle();

    expect(clipboard.writes, hasLength(1));
    final envelope = jsonDecode(clipboard.writes.single);
    expect(envelope['format'], GarageBackupFormat.id);
    expect(envelope['formatVersion'], GarageBackupFormat.currentVersion);
    expect(find.text(_l10n.backupCopied), findsOneWidget);
  });

  testWidgets('restores a valid backup after explicit confirmation', (
    tester,
  ) async {
    final storage = _FakeStorage(jsonEncode(_collection().toJson()));
    final clipboard = _FakeClipboard(
      text: const GarageBackupCodec().encode(_collection(vehicleId: 'v7')),
    );
    var restores = 0;

    await tester.pumpWidget(
      _app(
        storage: storage,
        clipboard: clipboard,
        onGarageRestored: () async => restores++,
      ),
    );

    await _tapRestoreAndConfirm(tester);

    expect(find.text(_l10n.restoreComplete), findsOneWidget);
    expect(restores, 1);
    expect(storage.writes, hasLength(1));
    expect(storage.writes.single, contains('v7'));
  });

  testWidgets('declining the confirmation imports nothing', (tester) async {
    final storage = _FakeStorage(jsonEncode(_collection().toJson()));
    final clipboard = _FakeClipboard(
      text: const GarageBackupCodec().encode(_collection(vehicleId: 'v7')),
    );

    await tester.pumpWidget(_app(storage: storage, clipboard: clipboard));

    await tester.tap(find.byKey(const Key('settings-backup-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-dialog-restore')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('restore-confirm-dialog')), findsOneWidget);
    await tester.tap(find.text(_l10n.cancel));
    await tester.pumpAndSettle();

    expect(storage.writes, isEmpty);
    expect(find.text(_l10n.restoreComplete), findsNothing);
  });

  testWidgets('rejects a non-backup clipboard value without raw errors', (
    tester,
  ) async {
    final storage = _FakeStorage(jsonEncode(_collection().toJson()));
    final clipboard = _FakeClipboard(text: 'not a backup at all');

    await tester.pumpWidget(_app(storage: storage, clipboard: clipboard));
    await _tapRestoreAndConfirm(tester);

    expect(find.text(_l10n.restoreFailed), findsOneWidget);
    expect(storage.writes, isEmpty);
  });

  testWidgets('reports an empty clipboard instead of importing', (
    tester,
  ) async {
    final storage = _FakeStorage(jsonEncode(_collection().toJson()));
    final clipboard = _FakeClipboard(text: '   ');

    await tester.pumpWidget(_app(storage: storage, clipboard: clipboard));

    await tester.tap(find.byKey(const Key('settings-backup-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('backup-dialog-restore')));
    await tester.pumpAndSettle();

    expect(find.text(_l10n.clipboardEmptyBackup), findsOneWidget);
    expect(find.byKey(const Key('restore-confirm-dialog')), findsNothing);
    expect(storage.writes, isEmpty);
  });

  testWidgets('explains and confirms changing the default vehicle', (tester) async {
    final changed = <String>[];
    await tester.pumpWidget(
      _app(
        storage: _FakeStorage(jsonEncode(_collection().toJson())),
        vehicles: [
          ..._collection().vehicles,
          VehicleProfile(
            id: 'v2',
            year: 2021,
            make: 'Honda',
            model: 'Civic',
            garage: GarageSnapshot.seeded(),
          ),
        ],
        defaultVehicleId: 'v1',
        onDefaultVehicleChanged: (id) async => changed.add(id),
      ),
    );
    await tester.tap(find.byKey(const Key('settings-default-vehicle-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('default-vehicle-option-v2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('default-vehicle-confirm-dialog')), findsOneWidget);
    expect(find.text(_l10n.defaultVehicleChangeMessage('2021 Honda Civic')), findsOneWidget);
    await tester.tap(find.byKey(const Key('default-vehicle-confirm-action')));
    await tester.pumpAndSettle();
    expect(changed, ['v2']);
  });

  testWidgets('cancelling default vehicle change leaves it unchanged', (tester) async {
    final changed = <String>[];
    await tester.pumpWidget(
      _app(
        storage: _FakeStorage(jsonEncode(_collection().toJson())),
        vehicles: [..._collection().vehicles, VehicleProfile(id: 'v2', year: 2021, make: 'Honda', model: 'Civic', garage: GarageSnapshot.seeded())],
        defaultVehicleId: 'v1',
        onDefaultVehicleChanged: (id) async => changed.add(id),
      ),
    );
    await tester.tap(find.byKey(const Key('settings-default-vehicle-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('default-vehicle-option-v2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l10n.cancel));
    await tester.pumpAndSettle();
    expect(changed, isEmpty);
    expect(find.text('2020 Toyota Corolla'), findsOneWidget);
  });
}

Future<void> _tapRestoreAndConfirm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('settings-backup-card')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('backup-dialog-restore')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('restore-confirm-action')));
  await tester.pumpAndSettle();
}

Widget _app({
  required _FakeStorage storage,
  GarageClipboard? clipboard,
  Future<void> Function()? onGarageRestored,
  List<VehicleProfile>? vehicles,
  String? defaultVehicleId,
  Future<void> Function(String)? onDefaultVehicleChanged,
}) => MaterialApp(
  home: SettingsScreen(
    vehicles: vehicles ?? const [],
    defaultVehicleId: defaultVehicleId,
    onDefaultVehicleChanged: onDefaultVehicleChanged,
    repository: GarageRepository(storage: storage),
    clipboard: clipboard ?? _FakeClipboard(),
    onGarageRestored: onGarageRestored,
  ),
);

class _FakeClipboard implements GarageClipboard {
  _FakeClipboard({this.text});

  String? text;
  final List<String> writes = [];

  @override
  Future<String?> read() async => text;

  @override
  Future<void> write(String value) async {
    writes.add(value);
    text = value;
  }
}

class _FakeStorage implements GarageStorage {
  _FakeStorage(this.value);

  String? value;
  final List<String> writes = [];

  @override
  Future<String?> read() async => value;

  @override
  Future<bool> write(String value) async {
    this.value = value;
    writes.add(value);
    return true;
  }
}
