import 'dart:convert';

import 'package:app/data/garage_repository.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/service_item.dart';
import 'package:app/models/vehicle_profile.dart';
import 'package:app/screens/add_service_screen.dart';
import 'package:app/screens/dashboard_screen.dart';
import 'package:app/screens/edit_service_screen.dart';
import 'package:app/screens/vehicle_selector_screen.dart';
import 'package:app/widgets/gear_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _l10n = AppLocalizations(Locale('en'));

final _services = [
  ServiceItem(
    id: 'engine-oil',
    name: 'Engine Oil',
    note: '5W-40 SYN',
    serviceOdometer: 74850,
    intervalKm: 10000,
    iconKey: 'oil',
  ),
  ServiceItem(
    id: 'battery',
    name: 'Battery',
    note: 'AGM',
    serviceOdometer: 70000,
    intervalKm: 20000,
    iconKey: 'battery',
  ),
];

String _collectionJson({List<ServiceItem>? services}) => jsonEncode(
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
          services: services ?? _services,
          tires: const [],
          history: const [],
        ),
      ),
    ],
  ).toJson(),
);

List<String> _serviceIds(String payload) {
  final collection = jsonDecode(payload) as Map<String, dynamic>;
  final vehicles = collection['vehicles'] as List<dynamic>;
  final garage =
      (vehicles.single as Map<String, dynamic>)['garage']
          as Map<String, dynamic>;
  return [
    for (final service in garage['services'] as List<dynamic>)
      (service as Map<String, dynamic>)['id'] as String,
  ];
}

void main() {
  testWidgets('service presets are translated in Arabic', (tester) async {
    await tester.pumpWidget(_localizedApp(const AddServiceScreen(), locale: Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('زيت المحرك'), findsOneWidget);
    expect(find.text('فلتر الزيت'), findsOneWidget);
    expect(find.text('Engine oil'), findsNothing);
    expect(find.text('السوائل والفلاتر'), findsOneWidget);
  });

  group('preset search', () {
    test('matches case-insensitively and trims the query', () {
      expect(filterServicePresets(''), hasLength(servicePickerPresets.length));
      expect(
        filterServicePresets('  BRAKE ').map((preset) => preset.name),
        ['Brake pads', 'Brake fluid'],
      );
      expect(filterServicePresets('tire'), hasLength(2));
      expect(filterServicePresets('definitely-not-a-service'), isEmpty);
    });
  });

  group('service picker discoverability', () {
    testWidgets('labels each preset section in display order', (tester) async {
      await tester.pumpWidget(_localizedApp(const AddServiceScreen()));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('service-preset-group-fluids')),
        findsOneWidget,
      );
      expect(find.text(_l10n.presetGroupFluids), findsOneWidget);

      final semantics = tester.ensureSemantics();
      final headerData = tester
          .getSemantics(find.byKey(const Key('service-preset-group-fluids')))
          .getSemanticsData();
      expect(headerData.flagsCollection.isHeader, isTrue);
      semantics.dispose();

      for (final category in servicePresetCategoryOrder) {
        final header = find.byKey(Key('service-preset-group-${category.name}'));
        await _scrollTo(tester, header);
        expect(header, findsOneWidget);
      }
    });

    testWidgets('filters presets and hides empty sections while searching', (
      tester,
    ) async {
      await tester.pumpWidget(_localizedApp(const AddServiceScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('service-preset-search-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('service-preset-search-field')),
        'brake',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('service-preset-brake_pads')), findsOneWidget);
      expect(
        find.byKey(const Key('service-preset-brake_fluid')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('service-preset-oil')), findsNothing);
      expect(
        find.byKey(const Key('service-preset-group-fluids')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('service-preset-group-engine')),
        findsNothing,
      );
      // Custom and tire entry points stay reachable regardless of the query.
      expect(
        find.byKey(const Key('start-custom-service-button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('tire-health-service-card')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('service-preset-search-field')),
        'no-such-service',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('no-service-presets-message')),
        findsOneWidget,
      );
      expect(find.text(_l10n.noServicesMatch), findsOneWidget);
      expect(find.byKey(const Key('tire-health-service-card')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('service-preset-search-field')),
        '',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('service-preset-oil')), findsOneWidget);
    });

    testWidgets('search field exposes localized keyboard semantics', (
      tester,
    ) async {
      await tester.pumpWidget(_localizedApp(const AddServiceScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('service-preset-search-button')));
      await tester.pumpAndSettle();

      final field = find.byKey(const Key('service-preset-search-field'));
      final semantics = tester.ensureSemantics();
      final data = tester.getSemantics(field).getSemanticsData();
      final widget = tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );

      expect(data.flagsCollection.isTextField, isTrue);
      expect(
        tester.widget<GearTextField>(field).inputDecoration.hintText,
        _l10n.searchServicesHint,
      );
      expect(widget.textInputAction, TextInputAction.search);
      semantics.dispose();
    });

    testWidgets('added preset exposes a visible remove action', (tester) async {
      await tester.pumpWidget(
        _localizedApp(
          const AddServiceScreen(
            existingServices: [
              ServiceItem(
                id: 'existing-oil',
                name: 'Engine Oil',
                note: '',
                serviceOdometer: 0,
                intervalKm: 1000,
                iconKey: 'oil',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final menu = find.byKey(const Key('service-preset-menu-oil'));
      expect(menu, findsOneWidget);

      await tester.ensureVisible(menu);
      await tester.pumpAndSettle();
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(find.text(_l10n.removeAction), findsOneWidget);
    });
  });

  group('vehicle card actions', () {
    testWidgets('offers a visible edit menu instead of long-press only', (
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
          VehicleSelectorScreen(
            vehicles: vehicles,
            selectedVehicleId: 'v1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final menu = find.byKey(const Key('vehicle-menu-v1'));
      expect(menu, findsOneWidget);
      await tester.tap(menu);
      await tester.pumpAndSettle();

      await tester.tap(find.text(_l10n.editVehicle));
      await tester.pumpAndSettle();

      // Lands on the edit form rather than a create form. The form repeats
      // this label in its heading, so scope the assertion to the app bar.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(_l10n.editVehicle),
        ),
        findsOneWidget,
      );
      expect(find.text(_l10n.saveAction), findsOneWidget);
    });
  });

  group('service card actions', () {
    testWidgets('exposes edit and delete from the service card actions', (
      tester,
    ) async {
      await tester.pumpWidget(_dashboard(_RecordingStorage(_collectionJson())));
      await tester.pumpAndSettle();

      final card = find.byKey(const Key('service-health-card-engine-oil'));
      expect(card, findsOneWidget);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();

      await tester.longPress(card);
      await tester.pumpAndSettle();

      expect(find.text(_l10n.editServiceHint), findsOneWidget);
      expect(find.text(_l10n.deleteService), findsOneWidget);

      await tester.tap(find.text(_l10n.editServiceHint));
      await tester.pumpAndSettle();

      // The dashboard presents the edit/service choice before opening the
      // editor for a card action.
      expect(find.text(_l10n.edit), findsOneWidget);
      await tester.tap(find.text(_l10n.edit));
      await tester.pumpAndSettle();

      expect(find.byType(EditServiceScreen), findsOneWidget);
    });

    testWidgets('undo restores and persists a deleted service', (tester) async {
      final storage = _RecordingStorage(_collectionJson());
      await tester.pumpWidget(_dashboard(storage));
      await tester.pumpAndSettle();

      await _deleteServiceFromMenu(tester, 'engine-oil');

      expect(
        find.byKey(const Key('service-health-card-content-engine-oil')),
        findsNothing,
      );
      expect(find.text(_l10n.serviceDeleted('Engine Oil')), findsOneWidget);
      expect(find.text(_l10n.undoAction), findsOneWidget);
      expect(_serviceIds(storage.lastPayload!), isNot(contains('engine-oil')));

      await tester.tap(find.text(_l10n.undoAction));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('service-health-card-content-engine-oil')),
        findsOneWidget,
      );
      expect(find.text(_l10n.serviceRestored('Engine Oil')), findsOneWidget);
      expect(_serviceIds(storage.lastPayload!), contains('engine-oil'));
    });

    testWidgets('a deletion stands once the undo window elapses', (
      tester,
    ) async {
      final storage = _RecordingStorage(_collectionJson());
      await tester.pumpWidget(_dashboard(storage));
      await tester.pumpAndSettle();

      await _deleteServiceFromMenu(tester, 'engine-oil');

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.undoAction), findsNothing);
      expect(
        find.byKey(const Key('service-health-card-content-engine-oil')),
        findsNothing,
      );
      expect(_serviceIds(storage.lastPayload!), isNot(contains('engine-oil')));
    });
  });
}

Future<void> _deleteServiceFromMenu(WidgetTester tester, String id) async {
  final card = find.byKey(Key('service-health-card-$id'));
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.longPress(card);
  await tester.pumpAndSettle();
  await tester.tap(find.text(_l10n.deleteService));
  await tester.pumpAndSettle();
  expect(find.text(_l10n.deleteServiceQuestion), findsOneWidget);
  await tester.tap(find.widgetWithText(FilledButton, _l10n.delete));
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Widget _dashboard(GarageStorage storage) => _localizedApp(
  DashboardScreen(repository: GarageRepository(storage: storage)),
);

Widget _localizedApp(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
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
