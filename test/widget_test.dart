import 'dart:convert';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/data/data.dart';
import 'package:app/data/garage_repository.dart';
import 'package:app/main.dart';
import 'package:app/models/odometer_value.dart';
import 'package:app/models/service_item.dart';
import 'package:app/models/tire_item.dart';
import 'package:app/models/vehicle_profile.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/screens/dashboard_screen.dart'
    show
        DashboardHealthCard,
        DashboardScreen,
        DashboardServiceHealthCard,
        DashboardServiceOrdering,
        DashboardTireHealthCard;
import 'package:app/screens/edit_tire_screen.dart';
import 'package:app/screens/edit_service_screen.dart';
import 'package:app/widgets/app_bar.dart' as gear_app_bar;
import 'package:app/widgets/odometer_card.dart';
import 'package:app/widgets/service_health_card.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

const _l10n = AppLocalizations(Locale('en'));

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues(_populatedGaragePreferences),
  );

  testWidgets('renders the GearTrack dashboard', (tester) async {
    await tester.pumpWidget(const GearTrackerApp());
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bottom-nav-home')));
    await tester.pumpAndSettle();

    expect(find.text('GEAR TRACKER'), findsOneWidget);
    expect(find.text(_l10n.liveOdometerReading), findsOneWidget);
    expect(
      find.textContaining('Engine Oil', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('74850'), findsNothing);
    expect(find.byKey(const Key('bottom-nav-services')), findsOneWidget);
  });

  testWidgets('loads an explicitly persisted maximum odometer value', (
    tester,
  ) async {
    final maximumSnapshot = GarageSnapshot(
      odometer: 999999,
      services: initialServices,
      tires: initialTires,
      history: const [],
    );
    SharedPreferences.setMockInitialValues({
      'garage_snapshot_v1': jsonEncode(
        _collectionWith(maximumSnapshot).toJson(),
      ),
    });

    await tester.pumpWidget(const GearTrackerApp());
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    final raw = (await SharedPreferences.getInstance()).getString(
      'garage_snapshot_v1',
    );
    final decoded = jsonDecode(raw!) as Map<String, dynamic>;
    final vehicles = decoded['vehicles'] as List<dynamic>;
    final garage =
        (vehicles.single as Map<String, dynamic>)['garage']
            as Map<String, dynamic>;
    expect(garage['odometer'], 999999);
  });

  testWidgets('exposes History in the bottom bar, not the dashboard header', (
    tester,
  ) async {
    await tester.pumpWidget(const GearTrackerApp());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Service history'), findsNothing);
    expect(find.byKey(const Key('bottom-nav-history')), findsOneWidget);
  });

  testWidgets('pushes Settings from the dashboard header', (tester) async {
    await tester.pumpWidget(const GearTrackerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bottom-nav-home')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(_l10n.settingsTitle));
    await tester.pumpAndSettle();
    expect(find.text(_l10n.settingsTitle), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('GEAR TRACKER'), findsOneWidget);
  });

  testWidgets('shows three white then three green odometer digits', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OdometerCard(
          odometer: '074850',
          onChanged: (_) {},
          saveRevision: 0,
          isDirty: false,
        ),
      ),
    );

    expect(find.text('+530 KM'), findsNothing);
    expect(find.text('Reset Base'), findsNothing);
    expect(find.byType(ListWheelScrollView), findsNWidgets(6));
    expect(find.text('Save odometer'), findsNothing);
  });

  testWidgets('shows all four tire positions in one health card', (
    tester,
  ) async {
    await tester.pumpWidget(const GearTrackerApp());
    await tester.pumpAndSettle();

    expect(find.text('Tire Health'), findsOneWidget);
    expect(find.textContaining('FL //'), findsOneWidget);
    expect(find.textContaining('FR //'), findsOneWidget);
    expect(find.textContaining('BL //'), findsOneWidget);
    expect(find.textContaining('BR //'), findsOneWidget);
    expect(find.text('EXCELLENT', findRichText: false), findsNWidgets(4));
    expect(find.byType(LinearProgressIndicator), findsNWidgets(5));
    expect(find.byKey(const Key('tire-tile-front-left')), findsOneWidget);
  });

  test('orders service cards by lowest remaining health, then name and id', () {
    const currentOdometer = 10000;
    final services = [
      const ServiceItem(
        id: 'zeta',
        name: 'Zeta service',
        note: '',
        serviceOdometer: 0,
        intervalKm: 10000,
        iconKey: 'maintenance',
      ),
      const ServiceItem(
        id: 'beta',
        name: 'Alpha service',
        note: '',
        serviceOdometer: 1000,
        intervalKm: 10000,
        iconKey: 'maintenance',
      ),
      const ServiceItem(
        id: 'alpha',
        name: 'Alpha service',
        note: '',
        serviceOdometer: 1000,
        intervalKm: 10000,
        iconKey: 'maintenance',
      ),
    ];
    final orderedServices = services.sortedByHealth(currentOdometer);
    expect(orderedServices.map((service) => service.id), [
      'zeta',
      'alpha',
      'beta',
    ]);
  });

  test('orders dashboard cards by health using the lowest tire health', () {
    const currentOdometer = 10000;
    final tires = TireItem.defaultsForOdometer(0)
      ..[0] = TireItem(
        id: 'front-left',
        code: 'FL',
        installOdometer: 0,
        intervalKm: 10000,
        installDate: DateTime(2026),
      );
    final cards = DashboardHealthCard.ordered(
      services: const [
        ServiceItem(
          id: 'same-health',
          name: 'Same health service',
          note: '',
          serviceOdometer: 0,
          intervalKm: 10000,
          iconKey: 'maintenance',
        ),
        ServiceItem(
          id: 'healthy',
          name: 'Healthy service',
          note: '',
          serviceOdometer: 5000,
          intervalKm: 10000,
          iconKey: 'maintenance',
        ),
      ],
      tires: tires,
      currentOdometer: currentOdometer,
    );

    expect(cards[0], isA<DashboardServiceHealthCard>());
    expect((cards[0] as DashboardServiceHealthCard).service.id, 'same-health');
    expect(cards[1], isA<DashboardTireHealthCard>());
    expect(cards[2], isA<DashboardServiceHealthCard>());
    expect((cards[2] as DashboardServiceHealthCard).service.id, 'healthy');
  });

  testWidgets('expands service cards for long content at 2x text scale', (
    tester,
  ) async {
    const service = ServiceItem(
      id: 'engine-oil',
      name: 'Extraordinarily long engine oil service name for accessibility',
      note: 'A detailed synthetic oil note that remains readable at large text sizes.',
      serviceOdometer: 74850,
      intervalKm: 10000,
      iconKey: 'oil',
    );
    await tester.pumpWidget(
      _localizedApp(
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: ListView(
              children: [
                ServiceHealthCard.service(
                  service: service,
                  currentOdometer: 74850,
                  onEditService: _ignoreTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(ServiceHealthCard)).height, 165);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings header action has a 48dp hit target at narrow width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(320, 640)),
          child: Scaffold(
            body: gear_app_bar.AppBar(onSettings: () {}, onVehicle: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byTooltip(_l10n.settingsTitle)),
      const Size(48, 48),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('replaces the note with a warning state on Type 01', (
    tester,
  ) async {
    const service = ServiceItem(
      id: 'engine-oil',
      name: 'Engine Oil',
      note: '5W-40 SYN',
      serviceOdometer: 74850,
      intervalKm: 10000,
      iconKey: 'oil',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              const ServiceHealthCard.service(
                service: service,
                currentOdometer: 82350,
                onEditService: _ignoreTap,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Warning — 75% exhausted'), findsOneWidget);
    expect(find.text('5W-40 SYN'), findsNothing);
  });

  testWidgets('separates replace soon from replace now on Type 01', (
    tester,
  ) async {
    const service = ServiceItem(
      id: 'engine-oil',
      name: 'Engine Oil',
      note: '5W-40 SYN',
      serviceOdometer: 74850,
      intervalKm: 10000,
      iconKey: 'oil',
    );

    Widget card(int odometer) => MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            ServiceHealthCard.service(
              service: service,
              currentOdometer: odometer,
              onEditService: _ignoreTap,
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(card(83850));
    expect(find.text('Soon — 90% exhausted'), findsOneWidget);
    expect(
      find.textContaining('REPLACE SOON', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('REPLACE NOW', findRichText: true),
      findsNothing,
    );

    await tester.pumpWidget(card(84850));
    expect(find.text('Critical — 100% exhausted'), findsOneWidget);
    expect(
      find.textContaining('REPLACE NOW', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('REPLACE SOON', findRichText: true),
      findsNothing,
    );
    expect(find.text('0% · 0 km left'), findsOneWidget);
  });

  test('carries and borrows across odometer digits', () {
    expect(
      OdometerValue.adjustDigit(value: '000849', digitIndex: 5, delta: 1),
      '000850',
    );
    expect(
      OdometerValue.adjustDigit(value: '000850', digitIndex: 5, delta: -1),
      '000849',
    );
  });

  test('keeps odometer values within six-digit bounds', () {
    expect(
      OdometerValue.adjustDigit(value: '999999', digitIndex: 5, delta: 1),
      '999999',
    );
    expect(
      OdometerValue.adjustDigit(value: '000000', digitIndex: 5, delta: -1),
      '000000',
    );
  });

  test(
    'calculates service damage, remaining life, and thresholds from odometer',
    () {
      const oil = ServiceItem(
        id: 'engine-oil',
        name: 'Engine Oil',
        note: '5W-40 SYN',
        serviceOdometer: 74850,
        intervalKm: 10000,
        iconKey: 'oil',
      );

      final fresh = oil.metricsAt(74850)!;
      expect(fresh.damagePercent, 0);
      expect(fresh.remainingKm, 10000);
      expect(fresh.status, ServiceStatus.excellent);

      final warning = oil.metricsAt(82350)!;
      expect(warning.damagePercent, 75);
      expect(warning.status, ServiceStatus.warning);
      expect(warning.remainingKm, 2500);

      final soon = oil.metricsAt(83850)!;
      expect(soon.damagePercent, 90);
      expect(soon.status, ServiceStatus.replaceSoon);
      expect(soon.badge, 'Replace soon');
      expect(soon.remainingPercent, 10);

      final critical = oil.metricsAt(84850)!;
      expect(critical.damagePercent, 100);
      expect(critical.status, ServiceStatus.replaceNow);
      expect(critical.badge, 'Replace now');
      expect(critical.remainingPercent, 0);
      expect(critical.remainingKm, 0);
    },
  );

  testWidgets('commits a snapped wheel change to staged odometer state', (
    tester,
  ) async {
    var stagedValue = '074850';
    await tester.pumpWidget(
      MaterialApp(
        home: OdometerCard(
          odometer: stagedValue,
          onChanged: (value) => stagedValue = value,
          saveRevision: 0,
          isDirty: false,
        ),
      ),
    );

    expect(find.byKey(const Key('odometer-wheel-5')), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('odometer-wheel-5')),
      const Offset(0, -80),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(stagedValue, '074851');
  });

  testWidgets(
    'refreshes health cards and header status when odometer debounce confirms',
    (tester) async {
      final snapshot = GarageSnapshot(
        odometer: 74850,
        services: const [
          ServiceItem(
            id: 'engine-oil',
            name: 'Engine Oil',
            note: '5W-40 SYN',
            serviceOdometer: 74850,
            intervalKm: 100,
            iconKey: 'oil',
          ),
        ],
        tires: TireItem.defaultsForOdometer(74850),
        history: const [],
      );
      SharedPreferences.setMockInitialValues({
        'garage_snapshot_v1': jsonEncode(snapshot.toJson()),
      });

      await tester.pumpWidget(const GearTrackerApp());
      await tester.pump();
      await tester.pump();

      await tester.drag(
        find.byKey(const Key('odometer-wheel-3')),
        const Offset(0, -80),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.textContaining('REPLACE NOW', findRichText: true),
        findsNothing,
      );
      final header = tester.widget<gear_app_bar.AppBar>(
        find.byType(gear_app_bar.AppBar),
      );
      expect(header.status, ServiceStatus.excellent);

      await tester.pump(const Duration(seconds: 2));

      expect(
        find.textContaining('REPLACE NOW', findRichText: true),
        findsOneWidget,
      );
      final confirmedHeader = tester.widget<gear_app_bar.AppBar>(
        find.byType(gear_app_bar.AppBar),
      );
      expect(confirmedHeader.status, ServiceStatus.replaceNow);
    },
  );

  testWidgets('exposes every odometer digit as adjustable controls', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var stagedValue = '074850';

    await tester.pumpWidget(
      MaterialApp(
        home: OdometerCard(
          odometer: stagedValue,
          onChanged: (value) => stagedValue = value,
          saveRevision: 0,
          isDirty: false,
        ),
      ),
    );

    for (final label in [
      'Hundred thousands digit, current value 0',
      'Ten thousands digit, current value 7',
      'Thousands digit, current value 4',
      'Hundreds digit, current value 8',
      'Tens digit, current value 5',
      'Ones digit, current value 0',
    ]) {
      final control = find.bySemanticsLabel(label);
      expect(control, findsOneWidget);
      expect(
        tester
            .getSemantics(control)
            .getSemanticsData()
            .hasAction(SemanticsAction.increase),
        isTrue,
      );
      expect(
        tester
            .getSemantics(control)
            .getSemanticsData()
            .hasAction(SemanticsAction.decrease),
        isTrue,
      );
    }

    await tester.tap(find.byKey(const Key('odometer-wheel-3')));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    expect(stagedValue, '074950');
    semantics.dispose();
  });

  testWidgets('swipes on a leading digit adjust by its place value', (
    tester,
  ) async {
    var stagedValue = '074850';

    await tester.pumpWidget(
      MaterialApp(
        home: OdometerCard(
          odometer: stagedValue,
          onChanged: (value) => stagedValue = value,
          saveRevision: 0,
          isDirty: false,
        ),
      ),
    );

    await tester.drag(
      find.byKey(const Key('odometer-wheel-1')),
      const Offset(0, -80),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(stagedValue, '084850');
  });

  testWidgets('decrements the focused odometer wheel with ArrowDown', (
    tester,
  ) async {
    var stagedValue = '074850';
    await tester.pumpWidget(
      MaterialApp(
        home: OdometerCard(
          odometer: stagedValue,
          onChanged: (value) => stagedValue = value,
          saveRevision: 0,
          isDirty: false,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('odometer-wheel-3')));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);

    expect(stagedValue, '074750');
  });

  testWidgets(
    'shows the English service configuration instruction in the direct editor',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        ..._populatedGaragePreferences,
        'show_guidance': true,
      });
      await (await SharedPreferences.getInstance()).setBool(
        'show_guidance',
        true,
      );
      await tester.pumpWidget(const GearTrackerApp());
      await tester.pumpAndSettle();

      final semantics = tester.ensureSemantics();
      final serviceButton = find.bySemanticsLabel(
        'Engine Oil, Excellent, 100%, 10,000 km left',
      );
      expect(serviceButton, findsOneWidget);
      expect(
        tester
            .getSemantics(serviceButton)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );

      final serviceCard = find.byKey(
        const Key('service-health-card-content-engine-oil'),
      );
      await tester.ensureVisible(serviceCard);
      await tester.tap(find.byKey(const Key('service-health-card-engine-oil')));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('Current odometer')), findsOneWidget);
      expect(find.text(_l10n.markServiced, skipOffstage: false), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets(
    'shows the Arabic service configuration instruction in the direct editor',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        ..._populatedGaragePreferences,
        'show_guidance': true,
      });
      await (await SharedPreferences.getInstance()).setBool(
        'show_guidance',
        true,
      );
      await tester.pumpWidget(
        _localizedApp(
          locale: const Locale('ar'),
          child: const DashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final serviceCard = find.byKey(
        const Key('service-health-card-content-engine-oil'),
      );
      await tester.ensureVisible(serviceCard);
      await tester.tap(find.byKey(const Key('service-health-card-engine-oil')));
      await tester.pumpAndSettle();
      expect(
        find.text('تسجيل إتمام الصيانة', skipOffstage: false),
        findsNothing,
      );
    },
  );

  testWidgets('localizes the service card in Arabic with RTL-safe copy', (
    tester,
  ) async {
    const service = ServiceItem(
      id: 'engine-oil',
      name: 'زيت المحرك',
      note: 'زيت صناعي',
      serviceOdometer: 74850,
      intervalKm: 10000,
      iconKey: 'oil',
    );
    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('ar'),
        child: Scaffold(
          body: ServiceHealthCard.service(
            service: service,
            currentOdometer: 82350,
            onEditService: _ignoreTap,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('تحذير', findRichText: true), findsNWidgets(2));
    expect(
      find.textContaining('75٪ مستهلك', findRichText: true),
      findsOneWidget,
    );
    final localizations = MaterialLocalizations.of(
      tester.element(find.byType(ServiceHealthCard)),
    );
    expect(
      find.text('المستخدم: ${localizations.formatDecimal(7500)} كم'),
      findsOneWidget,
    );
    expect(
      Directionality.of(tester.element(find.byType(ServiceHealthCard))),
      TextDirection.rtl,
    );
  });

  testWidgets(
    'service card exposes a non-color status cue and keyboard action',
    (tester) async {
      var taps = 0;
      const service = ServiceItem(
        id: 'engine-oil',
        name: 'Engine Oil',
        note: '5W-40 SYN',
        serviceOdometer: 74850,
        intervalKm: 10000,
        iconKey: 'oil',
      );
      await tester.pumpWidget(
        _localizedApp(
          child: Scaffold(
            body: ServiceHealthCard.service(
              service: service,
              currentOdometer: 82350,
              onEditService: () => taps++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('WARNING', findRichText: true),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('service-health-card-engine-oil')));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(taps, 1);
    },
  );

  testWidgets('exposes each tire position as an edit button', (tester) async {
    await tester.pumpWidget(const GearTrackerApp());
    await tester.pumpAndSettle();

    final semantics = tester.ensureSemantics();
    for (final position in const [
      'Front left tire, Excellent, 100%, 50,000 km left',
      'Front right tire, Excellent, 100%, 50,000 km left',
      'Back left tire, Excellent, 100%, 50,000 km left',
      'Back right tire, Excellent, 100%, 50,000 km left',
    ]) {
      final tireButton = find.bySemanticsLabel(position);
      expect(tireButton, findsOneWidget);
      expect(
        tester
            .getSemantics(tireButton)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
    }

    semantics.dispose();
  });

  testWidgets('opens the matching editor for each tire position', (
    tester,
  ) async {
    const destinations = {
      'Front left tire, Excellent, 100%, 50,000 km left': 'Edit FL Tire',
      'Front right tire, Excellent, 100%, 50,000 km left': 'Edit FR Tire',
      'Back left tire, Excellent, 100%, 50,000 km left': 'Edit BL Tire',
      'Back right tire, Excellent, 100%, 50,000 km left': 'Edit BR Tire',
    };

    await tester.pumpWidget(const GearTrackerApp());
    await tester.pumpAndSettle();

    for (final entry in destinations.entries) {
      final tire = find.bySemanticsLabel(entry.key);
      await tester.ensureVisible(tire);
      await tester.tap(tire);
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('KM label is gray while dirty and green after save', (
    tester,
  ) async {
    const card = OdometerCard(
      odometer: '074850',
      onChanged: _ignoreChange,
      saveRevision: 0,
      isDirty: true,
    );
    await tester.pumpWidget(const MaterialApp(home: card));
    expect(
      tester
          .widget<Text>(find.text(_l10n.kilometers.toUpperCase()))
          .style
          ?.color,
      Theme.of(tester.element(find.text(_l10n.kilometers.toUpperCase())))
          .colorScheme
          .outline,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: OdometerCard(
          odometer: '074850',
          onChanged: _ignoreChange,
          saveRevision: 1,
          isDirty: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      tester
          .widget<Text>(find.text(_l10n.kilometers.toUpperCase()))
          .style
          ?.color,
      Theme.of(tester.element(find.text(_l10n.kilometers.toUpperCase())))
          .colorScheme
          .primary,
    );
  });

  testWidgets('edits a service and returns the saved values', (tester) async {
    const service = ServiceItem(
      id: 'engine-oil',
      name: 'Engine Oil',
      note: '5W-40 SYN',
      serviceOdometer: 74850,
      intervalKm: 10000,
      iconKey: 'oil',
      isCustom: true,
    );
    ServiceItem? savedService;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              savedService = await Navigator.of(context).push<ServiceItem>(
                MaterialPageRoute(
                  builder: (_) => const EditServiceScreen(
                    service: service,
                    currentOdometer: 74850,
                  ),
                ),
              );
            },
            child: const Text('Open edit'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open edit'));
    await tester.pumpAndSettle();

    final semantics = tester.ensureSemantics();
    expect(find.text(_l10n.currentOdometer('74,850')), findsOneWidget);
    expect(
      find.bySemanticsLabel(_l10n.currentOdometer('74,850')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('service-name-field')),
      'Oil change',
    );
    await tester.tap(
      find.byKey(const Key('edit-service-optional-details-toggle')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('service-note-field')),
      '0W-20 SYN',
    );
    await tester.enterText(
      find.byKey(const Key('service-interval-field')),
      '12000',
    );
    final save = find.byKey(
      const Key('save-service-button'),
      skipOffstage: false,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(savedService?.name, 'Oil change');
    expect(savedService?.note, '0W-20 SYN');
    expect(savedService?.intervalKm, 12000);
    expect(savedService?.installDate, isNull);
    semantics.dispose();
  });

  test('serializes an optional service install date', () {
    final service = ServiceItem(
      id: 'engine-oil',
      name: 'Engine Oil',
      note: '5W-40 SYN',
      serviceOdometer: 74850,
      intervalKm: 10000,
      iconKey: 'oil',
      installDate: DateTime(2026, 10, 6),
    );

    final restored = ServiceItem.fromJson(service.toJson());

    expect(restored.installDate, DateTime(2026, 10, 6));
  });

  test('calculates tire life from its installation odometer', () {
    final tire = TireItem(
      id: 'front-left',
      code: 'FL',
      installOdometer: 70000,
      intervalKm: 10000,
      installDate: DateTime(2026, 10, 6),
    );

    expect(tire.metricsAt(75000).remainingPercent, 50);
    expect(tire.metricsAt(75000).damage, .5);
    expect(tire.metricsAt(80000).remainingPercent, 0);
    expect(tire.metricsAt(80000).damage, 1);
    expect(tire.metricsAt(75000).status, ServiceStatus.good);
    expect(tire.metricsAt(80000).remainingPercent, 0);
    expect(tire.metricsAt(80000).status, ServiceStatus.replaceNow);
    expect(tire.metricsAt(80000).status, ServiceStatus.replaceNow);
  });

  test('flags a critical tire before the interval is fully used', () {
    final tire = TireItem(
      id: 'front-left',
      code: 'FL',
      installOdometer: 70000,
      intervalKm: 10000,
      installDate: DateTime(2026, 10, 6),
    );

    expect(tire.metricsAt(77500).damagePercent, 75);
    expect(tire.metricsAt(77500).status, ServiceStatus.warning);

    final soon = tire.metricsAt(79000);
    expect(soon.damagePercent, 90);
    expect(soon.status, ServiceStatus.replaceSoon);

    final expired = tire.metricsAt(79900);
    expect(expired.damagePercent, 99);
    expect(expired.status, ServiceStatus.replaceSoon);

    final due = tire.metricsAt(80000);
    expect(due.status, ServiceStatus.replaceNow);
  });

  testWidgets('turns Type 02 critical and paints bars by status', (
    tester,
  ) async {
    final units = [
      for (final unit in TireItem.defaultsForOdometer(70000))
        unit.copyWith(installOdometer: 70000, intervalKm: 10000),
    ];

    Widget card(int odometer) => MaterialApp(
      home: Scaffold(
        body: ServiceHealthCard.tireGrid(
          tires: units,
          currentOdometer: odometer,
          onEditTire: (_) {},
        ),
      ),
    );

    Color barColor() => tester
        .widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator).first,
        )
        .color!;

    await tester.pumpWidget(card(79500));

    expect(find.textContaining('REPLACE SOON'), findsNWidgets(4));
    expect(
      barColor(),
      Theme.of(tester.element(find.byType(ServiceHealthCard)))
          .colorScheme
          .tertiary,
    );

    await tester.pumpWidget(card(80000));

    expect(find.textContaining('REPLACE NOW'), findsNWidgets(4));
    expect(find.textContaining('REPLACE SOON'), findsNothing);
    expect(
      barColor(),
      Theme.of(tester.element(find.byType(ServiceHealthCard)))
          .colorScheme
          .error,
    );
  });

  testWidgets('Type 00 service layout renders one service cell and edits it', (
    tester,
  ) async {
    var taps = 0;
    const service = ServiceItem(
      id: 'engine-oil',
      name: 'Engine Oil',
      note: '5W-40 SYN',
      serviceOdometer: 74850,
      intervalKm: 10000,
      iconKey: 'oil',
    );
    final card = ServiceHealthCard.service(
      service: service,
      currentOdometer: 74850,
      onEditService: () => taps++,
    );
    await tester.pumpWidget(_localizedApp(child: Scaffold(body: card)));
    await tester.pumpAndSettle();

    expect(card.layout, ServiceHealthCardLayout.service);
    expect(
      find.byKey(const Key('service-health-card-content-engine-oil')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Engine Oil', findRichText: true),
      findsOneWidget,
    );
    expect(find.byKey(const Key('tire-tile-front-left')), findsNothing);

    await tester.tap(find.byKey(const Key('service-health-card-engine-oil')));
    expect(taps, 1);
  });

  testWidgets(
    'Type 00 tire layout renders four tire cells and edits the tapped tire',
    (tester) async {
      final editedTireIds = <String>[];
      final tires = TireItem.defaultsForOdometer(70000);
      final card = ServiceHealthCard.tireGrid(
        tires: tires.reversed.toList(),
        currentOdometer: 70000,
        onEditTire: (tire) => editedTireIds.add(tire.id),
      );
      await tester.pumpWidget(_localizedApp(child: Scaffold(body: card)));
      await tester.pumpAndSettle();

      expect(card.layout, ServiceHealthCardLayout.tireGrid);
      expect(
        find.byKey(const Key('service-health-card-tire-grid')),
        findsOneWidget,
      );
      for (final tire in tires) {
        expect(find.byKey(Key('tire-tile-${tire.id}')), findsOneWidget);
      }
      expect(find.textContaining('FL //'), findsOneWidget);
      expect(find.textContaining('FR //'), findsOneWidget);
      expect(find.textContaining('BL //'), findsOneWidget);
      expect(find.textContaining('BR //'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tire-tile-front-right')));
      expect(editedTireIds, ['front-right']);
    },
  );

  test('tire-grid mode rejects incomplete tire position sets', () {
    expect(
      () => ServiceHealthCard.tireGrid(
        tires: TireItem.defaultsForOdometer(70000).take(3).toList(),
        currentOdometer: 70000,
        onEditTire: (_) {},
      ),
      throwsAssertionError,
    );
  });

  testWidgets('keeps Type 02 tire codes left-to-right', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ServiceHealthCard.tireGrid(
            tires: TireItem.defaultsForOdometer(70000),
            currentOdometer: 70000,
            onEditTire: (_) {},
          ),
        ),
      ),
    );

    expect(
      Directionality.of(tester.element(find.textContaining('FL //'))),
      TextDirection.ltr,
    );
  });

  testWidgets('Type 02 expands its two-by-two grid at large text scales', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: SizedBox(
            width: 390,
            child: Scaffold(
              body: ListView(
                children: [
                  ServiceHealthCard.tireGrid(
                    tires: TireItem.defaultsForOdometer(70000),
                    currentOdometer: 77500,
                    onEditTire: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = tester.getRect(find.byType(ServiceHealthCard));
    final frontLeft = tester.getRect(
      find.byKey(const Key('tire-tile-front-left')),
    );
    final frontRight = tester.getRect(
      find.byKey(const Key('tire-tile-front-right')),
    );
    final backLeft = tester.getRect(
      find.byKey(const Key('tire-tile-back-left')),
    );
    final backRight = tester.getRect(
      find.byKey(const Key('tire-tile-back-right')),
    );
    expect(card.height, 167);
    expect(frontRight.top, frontLeft.top);
    expect(backLeft.top, greaterThan(frontLeft.bottom));
    expect(backRight.top, backLeft.top);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Type 02 localizes status and works by tire ID in RTL', (
    tester,
  ) async {
    final tires = TireItem.defaultsForOdometer(70000).reversed.toList();
    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('ar'),
        child: Scaffold(
          body: ServiceHealthCard.tireGrid(
            tires: tires,
            currentOdometer: 77500,
            onEditTire: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('حالة الإطارات'), findsOneWidget);
    expect(find.textContaining('ممتاز'), findsNWidgets(4));
    expect(
      find.descendant(
        of: find.byKey(const Key('tire-tile-front-left')),
        matching: find.textContaining('FL //'),
      ),
      findsOneWidget,
    );
    expect(
      Directionality.of(tester.element(find.byType(ServiceHealthCard))),
      TextDirection.rtl,
    );
  });

  testWidgets(
    'each Type 02 tire has a non-color status and keyboard-only edit actions',
    (tester) async {
      final editedTireIds = <String>[];
      final tires = [
        for (final tire in TireItem.defaultsForOdometer(70000))
          tire.copyWith(intervalKm: 10000),
      ];
      await tester.pumpWidget(
        _localizedApp(
          child: Scaffold(
            body: ServiceHealthCard.tireGrid(
              tires: tires,
              currentOdometer: 80000,
              onEditTire: (tire) => editedTireIds.add(tire.id),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel('Front left tire, Replace now, 0%, 0 km left'),
        findsOneWidget,
      );
      expect(find.textContaining('REPLACE NOW'), findsNWidgets(4));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(editedTireIds, ['front-left']);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(editedTireIds, ['front-left', 'front-right']);
      semantics.dispose();
    },
  );

  testWidgets(
    'localizes the tire editor date, number, and validation copy in Arabic',
    (tester) async {
      final tire = TireItem(
        id: 'front-left',
        code: 'FL',
        installOdometer: 70000,
        intervalKm: 50000,
        installDate: DateTime(2026, 10, 6),
      );
      await tester.pumpWidget(
        _localizedApp(
          locale: const Locale('ar'),
          child: EditTireScreen(tire: tire, currentOdometer: 74850),
        ),
      );
      await tester.pumpAndSettle();
      final material = MaterialLocalizations.of(
        tester.element(find.byType(EditTireScreen)),
      );
      expect(find.text('تعديل الإطار FL'), findsOneWidget);
      expect(
        find.text('عداد المسافة الحالي: ${material.formatDecimal(74850)} كم'),
        findsOneWidget,
      );
      expect(
        find.text(
          'تاريخ تركيب الإطار: ${material.formatMediumDate(tire.installDate)}',
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const Key('tire-interval-field')), '0');
      await tester.tap(find.byKey(const Key('save-tire-button')));
      await tester.pump();
      expect(find.text('أدخل فترة أكبر من 0 كم'), findsOneWidget);
    },
  );

  testWidgets('drains both card types as health instead of filling damage', (
    tester,
  ) async {
    const service = ServiceItem(
      id: 'engine-oil',
      name: 'Engine Oil',
      note: '5W-40 SYN',
      serviceOdometer: 74850,
      intervalKm: 10000,
      iconKey: 'oil',
    );
    final tires = [
      for (final unit in TireItem.defaultsForOdometer(70000))
        unit.copyWith(installOdometer: 70000, intervalKm: 10000),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ServiceHealthCard.service(
                service: service,
                currentOdometer: 79850,
                onEditService: _ignoreTap,
              ),
              ServiceHealthCard.tireGrid(
                tires: tires,
                currentOdometer: 75000,
                onEditTire: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    final bars = tester
        .widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .map((bar) => bar.value)
        .toList();

    expect(bars, hasLength(5));
    // Half used on both cards, so every bar reads as half health left.
    expect(bars, everyElement(closeTo(.5, .001)));
  });

  testWidgets('reads full health when new and empty when due', (tester) async {
    final tires = [
      for (final unit in TireItem.defaultsForOdometer(70000))
        unit.copyWith(installOdometer: 70000, intervalKm: 10000),
    ];

    double tireBarValues() => tester
        .widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        )
        .map((bar) => bar.value!)
        .reduce((a, b) => a > b ? a : b);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ServiceHealthCard.tireGrid(
            tires: tires,
            currentOdometer: 70000,
            onEditTire: (_) {},
          ),
        ),
      ),
    );
    expect(tireBarValues(), closeTo(1, .001));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ServiceHealthCard.tireGrid(
            tires: tires,
            currentOdometer: 80000,
            onEditTire: (_) {},
          ),
        ),
      ),
    );
    expect(tireBarValues(), closeTo(0, .001));
  });

  testWidgets('edits and returns tire lifecycle values', (tester) async {
    final tire = TireItem(
      id: 'front-left',
      code: 'FL',
      installOdometer: 70000,
      intervalKm: 50000,
      installDate: DateTime(2026, 10, 6),
    );
    TireItem? savedTire;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              savedTire = await Navigator.of(context).push<TireItem>(
                MaterialPageRoute(
                  builder: (_) =>
                      EditTireScreen(tire: tire, currentOdometer: 74850),
                ),
              );
            },
            child: const Text('Open tire edit'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open tire edit'));
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();
    expect(find.text(_l10n.currentOdometer('74,850')), findsOneWidget);
    expect(
      find.bySemanticsLabel(_l10n.currentOdometer('74,850')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('tire-install-odometer-field')),
      '72000',
    );
    await tester.enterText(
      find.byKey(const Key('tire-interval-field')),
      '60000',
    );
    await tester.tap(find.byKey(const Key('save-tire-button')));
    await tester.pumpAndSettle();

    expect(savedTire?.installOdometer, 72000);
    expect(savedTire?.intervalKm, 60000);
    semantics.dispose();
  });

  testWidgets(
    'app bar stays 80px at normal scale and grows without overflow at 2x',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                gear_app_bar.AppBar(onSettings: () {}, onVehicle: () {}),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(gear_app_bar.AppBar)).height, 80);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MediaQuery(
                  data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                  child: gear_app_bar.AppBar(
                    onSettings: () {},
                    onVehicle: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(gear_app_bar.AppBar)).height,
        greaterThanOrEqualTo(80),
      );
    },
  );
}

void _ignoreChange(String _) {}

void _ignoreTap() {}

Widget _localizedApp({
  required Widget child,
  Locale locale = const Locale('en'),
}) => MaterialApp(
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

final _populatedGaragePreferences = {
  'garage_snapshot_v1': jsonEncode(
    _collectionWith(GarageSnapshot.seeded()).toJson(),
  ),
};

GarageCollection _collectionWith(GarageSnapshot snapshot) {
  const vehicleId = 'test-vehicle';
  return GarageCollection(
    selectedVehicleId: vehicleId,
    defaultVehicleId: GarageCollection.lastUsedVehicleId,
    vehicles: [
      VehicleProfile(
        id: vehicleId,
        year: 2022,
        make: 'Test',
        model: 'Vehicle',
        garage: snapshot,
      ),
    ],
  );
}
