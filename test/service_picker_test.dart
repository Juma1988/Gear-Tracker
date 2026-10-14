import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/service_item.dart';
import 'package:app/screens/add_service_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _l10n = AppLocalizations(Locale('en'));

Future<void> _showOptionalServiceDetails(WidgetTester tester) async {
  final toggle = find.byKey(
    const Key('service-form-optional-details-toggle'),
  );
  await _scrollFormIntoView(tester, toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

void main() {
  test('provides the approved service presets in their display order', () {
    expect(servicePresetNames, const [
       'Engine oil',
       'Oil filter',
      'Air filter',
      'Cabin filter',
      'Brake pads',
      'Brake fluid',
       'Tire rotation and alignment',
      'Battery',
      'Spark plugs',
      'Coolant',
      'Transmission fluid',
      'Power steering fluid',
      'Timing belt / chain inspection',
      'Drive belts',
      'Wiper blades',
      'Suspension / shocks inspection',
      'Fuel filter',
      'AC service',
    ]);
  });

  test(
    'assigns every preset a distinct icon that can be restored from its key',
    () {
      expect(servicePresets, hasLength(18));
      expect(
        servicePresets.map((preset) => preset.iconKey).toSet(),
        hasLength(18),
      );
      expect(
        servicePresets.map((preset) => preset.icon).toSet(),
        hasLength(17),
      );
      for (final preset in servicePresets) {
        expect(ServiceItem.iconForKey(preset.iconKey), preset.icon);
      }
    },
  );

  testWidgets('opens the creation form with the selected preset name', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(const AddServiceScreen()));
    await tester.pumpAndSettle();

    await _scrollCardIntoView(
      tester,
      find.byKey(const Key('service-preset-tires')),
    );
    await tester.tap(find.byKey(const Key('service-preset-tires')));
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(
      find.byKey(const Key('add-service-name-field')),
    );
     expect(field.controller!.text, 'Tire rotation and alignment');
  });

  testWidgets('uses the shared install date picker after selecting a service', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(const AddServiceScreen()));
    await tester.pumpAndSettle();

    await _scrollCardIntoView(
      tester,
      find.byKey(const Key('service-preset-battery')),
    );
    await tester.tap(find.byKey(const Key('service-preset-battery')));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_l10n.trackingModeTime, skipOffstage: false));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('service-install-date-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('add-service-install-date-button')),
      findsNothing,
    );

    await _scrollFormIntoView(
      tester,
      find.byKey(const Key('service-install-date-button')),
    );
    await tester.tap(find.byKey(const Key('service-install-date-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('service-install-date-sheet')), findsOneWidget);
    expect(find.byKey(const Key('service-install-date-wheel')), findsOneWidget);
    expect(find.byKey(const Key('service-install-date-done')), findsOneWidget);
  });

  testWidgets('Custom service is the first picker card', (tester) async {
    await tester.pumpWidget(_testApp(const AddServiceScreen()));
    await tester.pumpAndSettle();

    expect(
      tester
          .getTopLeft(find.byKey(const Key('start-custom-service-button')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const Key('service-preset-oil_filter')))
            .dy,
      ),
    );
  });

  testWidgets('hides added preset icons but leaves custom names available', (
    tester,
  ) async {
    const existingPreset = ServiceItem(
      id: 'existing-oil-filter',
      name: 'Renamed custom label',
      note: 'Installed',
      serviceOdometer: 100,
      intervalKm: 1000,
      iconKey: 'oil_filter',
    );
    const customNamedLikePreset = ServiceItem(
      id: 'custom-air-filter',
      name: 'Air filter',
      note: 'Custom',
      serviceOdometer: 100,
      intervalKm: 1000,
      iconKey: 'maintenance',
    );

    await tester.pumpWidget(
      _testApp(
        const AddServiceScreen(
          existingServices: [existingPreset, customNamedLikePreset],
        ),
      ),
    );
    await tester.pumpAndSettle();

     expect(find.byKey(const Key('service-preset-oil_filter')), findsOneWidget);
    expect(find.byKey(const Key('service-preset-air_filter')), findsOneWidget);
  });

  testWidgets('asks before adding a normalized duplicate custom name', (
    tester,
  ) async {
    ServiceItem? createdService;
    await tester.pumpWidget(
      _testApp(
        Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              key: const Key('open-duplicate-picker'),
              onPressed: () async {
                createdService = await Navigator.of(context).push<ServiceItem>(
                  MaterialPageRoute(
                    builder: (_) => const AddServiceScreen(
                      existingServices: [
                        ServiceItem(
                          id: 'existing',
                          name: 'Cabin filter',
                          note: 'OEM',
                          serviceOdometer: 0,
                          intervalKm: 10000,
                          iconKey: 'maintenance',
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: const Text('Open picker'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-duplicate-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-custom-service-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('custom-service-icon-maintenance')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('add-service-name-field')),
      '  CABIN   FILTER  ',
    );
    await _showOptionalServiceDetails(tester);
    await _scrollFormIntoView(
      tester,
      find.byKey(const Key('add-service-note-field')),
    );
    await tester.enterText(
      find.byKey(const Key('add-service-note-field')),
      'Duplicate allowed',
    );
    await tester.enterText(
      find.byKey(const Key('add-service-interval-field')),
      '10000',
    );
    await _tapFormSave(tester);

    expect(find.text(_l10n.addDuplicateServiceQuestion), findsOneWidget);
    await tester.tap(find.text(_l10n.cancel));
    await tester.pumpAndSettle();
    expect(find.text(_l10n.addDuplicateServiceQuestion), findsNothing);

    await _tapFormSave(tester);
    await tester.tap(find.text(_l10n.addAnyway));
    await tester.pumpAndSettle();

    expect(createdService?.name, 'CABIN   FILTER');
  });

  testWidgets(
    'Custom service form has no position toggle and shows the preview',
    (tester) async {
      await tester.pumpWidget(_testApp(const AddServiceScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('start-custom-service-button')));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.chooseIcon), findsOneWidget);
      final tireIcon = find.byKey(const Key('custom-service-icon-tires'));
      await _scrollCardIntoView(tester, tireIcon);
      await tester.tap(tireIcon);
      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(
        find.byKey(const Key('add-service-name-field')),
      );
      expect(field.controller!.text, isEmpty);
      expect(find.byIcon(Icons.tire_repair), findsWidgets);
      expect(
        find.byKey(const Key('custom-service-position-toggle')),
        findsNothing,
      );
      expect(find.text('Track one vehicle-wide service.'), findsNothing);
      await _scrollFormIntoView(
        tester,
        find.byKey(const Key('custom-service-preview')),
      );
      expect(find.byKey(const Key('custom-service-preview')), findsOneWidget);
      expect(
        find.byKey(const Key('add-service-install-km-front-left-field')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Battery starts distance-only with its selected icon',
    (tester) async {
      ServiceItem? createdService;
      await tester.pumpWidget(
        _testApp(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    createdService = await Navigator.of(context)
                        .push<ServiceItem>(
                          MaterialPageRoute(
                            builder: (_) =>
                                const AddServiceScreen(currentOdometer: 74850),
                          ),
                        );
                  },
                  child: const Text('Open custom picker'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open custom picker'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start-custom-service-button')));
      await tester.pumpAndSettle();
      final batteryIcon = find.byKey(const Key('custom-service-icon-battery'));
      await _scrollCardIntoView(tester, batteryIcon);
      await tester.tap(batteryIcon);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.battery_full), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('add-service-name-field')),
        'Battery inspection',
      );
      await tester.enterText(
        find.byKey(const Key('add-service-interval-field')),
        '1000',
      );
      await _showOptionalServiceDetails(tester);
      await tester.enterText(
        find.byKey(const Key('add-service-note-field')),
        'Terminal check',
      );
      await _tapFormSave(tester);

      expect(createdService?.type, ServiceType.type01);
      expect(createdService?.iconKey, 'battery');
      expect(createdService?.icon, Icons.battery_full);
      expect(createdService?.tracksMileage, isTrue);
      expect(createdService?.shelfLifeMonths, isNull);
    },
  );

  testWidgets('Custom service always creates a single type01 service', (
    tester,
  ) async {
    ServiceItem? createdService;
    await tester.pumpWidget(
      _testApp(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              createdService = await Navigator.of(context).push<ServiceItem>(
                MaterialPageRoute(
                  builder: (_) => const AddServiceScreen(currentOdometer: 1200),
                ),
              );
            },
            child: const Text('Open custom picker'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open custom picker'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-custom-service-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('custom-service-icon-maintenance')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('custom-service-position-toggle')),
      findsNothing,
    );
    await _scrollFormIntoView(
      tester,
      find.byKey(const Key('add-service-name-field')),
    );
    await tester.enterText(
      find.byKey(const Key('add-service-name-field')),
      'Four-wheel inspection',
    );
    await _showOptionalServiceDetails(tester);
    await _scrollFormIntoView(
      tester,
      find.byKey(const Key('add-service-note-field')),
    );
    await tester.enterText(
      find.byKey(const Key('add-service-note-field')),
      'Inspect all positions',
    );
    await tester.enterText(
      find.byKey(const Key('add-service-interval-field')),
      '5000',
    );
    await _tapFormSave(tester);

    expect(createdService?.type, ServiceType.type01);
    expect(createdService?.units, isEmpty);
  });

  testWidgets('persists the selected preset icon key in the created service', (
    tester,
  ) async {
    ServiceItem? createdService;
    await tester.pumpWidget(
      _testApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  createdService = await Navigator.of(context)
                      .push<ServiceItem>(
                        MaterialPageRoute(
                          builder: (_) =>
                              const AddServiceScreen(currentOdometer: 74850),
                        ),
                      );
                },
                child: const Text('Open picker'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    await _scrollCardIntoView(
      tester,
      find.byKey(const Key('service-preset-oil_filter')),
    );
    await tester.tap(find.byKey(const Key('service-preset-oil_filter')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('add-service-name-field')),
      'Oil filter',
    );
    await _showOptionalServiceDetails(tester);
    await tester.enterText(
      find.byKey(const Key('add-service-note-field')),
      'Replaced with synthetic filter',
    );
    await tester.enterText(
      find.byKey(const Key('add-service-interval-field')),
      '10000',
    );
    await _tapFormSave(tester);

    expect(createdService, isNotNull);
    expect(createdService!.name, 'Oil filter');
    expect(createdService!.serviceOdometer, 74850);
    expect(createdService!.iconKey, 'oil_filter');
    expect(createdService!.icon, Icons.oil_barrel);
  });
}

Widget _testApp(Widget child) => MaterialApp(
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: child,
);

Future<void> _scrollCardIntoView(WidgetTester tester, Finder finder) async {
  // ListView.builder only builds visible cards, so first drag until the card
  // exists, then align it fully inside the viewport before tapping. The picker
  // also hosts a search field with its own internal Scrollable, so target the
  // outer list explicitly.
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _scrollFormIntoView(WidgetTester tester, Finder finder) async {
  final form = find.byKey(const Key('service-form-scroll-view'));
  final formScrollables = find.descendant(
    of: form,
    matching: find.byType(Scrollable),
  );
    if (finder.evaluate().isEmpty && form.evaluate().isNotEmpty) {
    final scrollState = tester.state<ScrollableState>(formScrollables.first);
    scrollState.position.jumpTo(
      finder.evaluate().isEmpty &&
              finder.toString().contains('service-form-sticky-save-button')
          ? scrollState.position.maxScrollExtent
          : 0,
    );
    await tester.pump();
  }
  final scrollable = formScrollables.first;
  await tester.scrollUntilVisible(finder, 200, scrollable: scrollable);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapFormSave(WidgetTester tester) async {
  final saveButton = find.byKey(
    const Key('service-form-sticky-save-button'),
    skipOffstage: false,
  );
  await tester.ensureVisible(saveButton);
  await tester.tap(saveButton);
  await tester.pumpAndSettle();
}
