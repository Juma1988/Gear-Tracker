import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/main.dart';
import 'package:app/models/odometer_value.dart';
import 'package:app/models/service_item.dart';
import 'package:app/models/tire_item.dart';
import 'package:app/screens/edit_tire_screen.dart';
import 'package:app/screens/edit_service_screen.dart';
import 'package:app/widgets/odometer_card.dart';
import 'package:app/widgets/service_health_card_01.dart';
import 'package:app/widgets/service_health_card_02.dart';

void main() {
  testWidgets('renders the GearTrack dashboard', (tester) async {
    await tester.pumpWidget(const GearTrackerApp());

    expect(find.text('GEAR TRACKER'), findsOneWidget);
    expect(find.text('LIVE Odometer Reading'), findsOneWidget);
    expect(find.text('Engine Oil'), findsOneWidget);
    expect(find.text('74850'), findsNothing);
    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('switches to the placeholder navigation pages', (tester) async {
    await tester.pumpWidget(const GearTrackerApp());

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('History'), findsNWidgets(2));

    await tester.tap(find.text('Services'));
    await tester.pumpAndSettle();
    expect(find.text('Services'), findsNWidgets(2));
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

    expect(find.text('Tire Health'), findsOneWidget);
    expect(find.text('FL'), findsOneWidget);
    expect(find.text('FR'), findsOneWidget);
    expect(find.text('BL'), findsOneWidget);
    expect(find.text('BR'), findsOneWidget);
    expect(find.text('0% USED · 0 KM'), findsNWidgets(4));
    expect(find.byType(LinearProgressIndicator), findsNWidgets(5));
    expect(tester.getSize(find.byType(ServiceHealthCardType02)).height, 125);
  });

  testWidgets('uses a fixed 125 pixel service card height', (tester) async {
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
              ServiceHealthCardType01(
                service: service,
                currentOdometer: 74850,
                onDoubleTap: _ignoreTap,
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(ServiceHealthCardType01)).height, 125);
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
              const ServiceHealthCardType01(
                service: service,
                currentOdometer: 82350,
                onDoubleTap: _ignoreTap,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('WARNING - 75% EXHAUSTED'), findsOneWidget);
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
            ServiceHealthCardType01(
              service: service,
              currentOdometer: odometer,
              onDoubleTap: _ignoreTap,
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(card(83850));
    expect(find.text('SOON - 90% EXHAUSTED'), findsOneWidget);
    expect(find.text('REPLACE SOON'), findsOneWidget);
    expect(find.text('REPLACE NOW'), findsNothing);

    await tester.pumpWidget(card(84850));
    expect(find.text('CRITICAL - 100% EXHAUSTED'), findsOneWidget);
    expect(find.text('REPLACE NOW'), findsOneWidget);
    expect(find.text('REPLACE SOON'), findsNothing);
    expect(find.text('0% · 0 KM Left'), findsOneWidget);
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

      final fresh = oil.metricsAt(74850);
      expect(fresh.damagePercent, 0);
      expect(fresh.remainingKm, 10000);
      expect(fresh.status, ServiceStatus.excellent);

      final warning = oil.metricsAt(82350);
      expect(warning.damagePercent, 75);
      expect(warning.status, ServiceStatus.warning);
      expect(warning.remainingKm, 2500);

      final soon = oil.metricsAt(83850);
      expect(soon.damagePercent, 90);
      expect(soon.status, ServiceStatus.replaceSoon);
      expect(soon.badge, 'Replace soon');
      expect(soon.remainingPercent, 10);

      final critical = oil.metricsAt(84850);
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
      tester.widget<Text>(find.text('KM')).style?.color,
      const Color(0xFF86948A),
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
      tester.widget<Text>(find.text('KM')).style?.color,
      const Color(0xFF4EDEA3),
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
    );
    ServiceItem? savedService;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              savedService = await Navigator.of(context).push<ServiceItem>(
                MaterialPageRoute(
                  builder: (_) => const EditServiceScreen(service: service),
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

    await tester.enterText(
      find.byKey(const Key('service-name-field')),
      'Oil change',
    );
    await tester.enterText(
      find.byKey(const Key('service-note-field')),
      '0W-20 SYN',
    );
    await tester.enterText(
      find.byKey(const Key('service-interval-field')),
      '12000',
    );
    await tester.tap(find.byKey(const Key('save-service-button')));
    await tester.pumpAndSettle();

    expect(savedService?.name, 'Oil change');
    expect(savedService?.note, '0W-20 SYN');
    expect(savedService?.intervalKm, 12000);
    expect(savedService?.installDate, isNotNull);
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
    expect(tire.metricsAt(80000).condition, 'Critical - 100% Used');
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
    expect(tire.metricsAt(77500).condition, 'Warning - 75% Used');

    final soon = tire.metricsAt(79000);
    expect(soon.damagePercent, 90);
    expect(soon.status, ServiceStatus.replaceSoon);
    expect(soon.badge, 'Replace soon');
    expect(soon.condition, 'Soon - 90% Used');

    final expired = tire.metricsAt(79900);
    expect(expired.damagePercent, 99);
    expect(expired.status, ServiceStatus.replaceSoon);

    final due = tire.metricsAt(80000);
    expect(due.status, ServiceStatus.replaceNow);
    expect(due.badge, 'Replace now');
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
        body: ServiceHealthCardType02(
          title: 'Tires',
          icon: Icons.tire_repair,
          units: units,
          currentOdometer: odometer,
          onEditUnit: (_) {},
        ),
      ),
    );

    Color barColor() => tester
        .widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator).first,
        )
        .color!;

    await tester.pumpWidget(card(79500));

    expect(find.text('SOON - 95% USED'), findsNWidgets(4));
    expect(find.text('REPLACE SOON'), findsOneWidget);
    expect(barColor(), const Color(0xFFFFB95F));

    await tester.pumpWidget(card(80000));

    expect(find.text('CRITICAL - 100% USED'), findsNWidgets(4));
    expect(find.text('REPLACE NOW'), findsOneWidget);
    expect(find.text('SOON - 95% USED'), findsNothing);
    expect(barColor(), const Color(0xFFFFB4AB));
  });

  testWidgets('places Type 02 unit text beside an enlarged code chip', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ServiceHealthCardType02(
            title: 'Tires',
            icon: Icons.tire_repair,
            units: TireItem.defaultsForOdometer(70000),
            currentOdometer: 70000,
            onEditUnit: (_) {},
          ),
        ),
      ),
    );

    final chip = find
        .ancestor(of: find.text('FL'), matching: find.byType(Container))
        .first;
    expect(tester.getSize(chip).width, 28);
    expect(tester.getSize(chip).height, 20);

    final chipBox = tester.getRect(chip);
    final textBox = tester.getRect(find.text('0% USED · 0 KM').first);
    expect(textBox.left, greaterThan(chipBox.right));
  });

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
              ServiceHealthCardType01(
                service: service,
                currentOdometer: 79850,
                onDoubleTap: _ignoreTap,
              ),
              ServiceHealthCardType02(
                title: 'Tires',
                icon: Icons.tire_repair,
                units: tires,
                currentOdometer: 75000,
                onEditUnit: (_) {},
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
          body: ServiceHealthCardType02(
            title: 'Tires',
            icon: Icons.tire_repair,
            units: tires,
            currentOdometer: 70000,
            onEditUnit: (_) {},
          ),
        ),
      ),
    );
    expect(tireBarValues(), closeTo(1, .001));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ServiceHealthCardType02(
            title: 'Tires',
            icon: Icons.tire_repair,
            units: tires,
            currentOdometer: 80000,
            onEditUnit: (_) {},
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
  });
}

void _ignoreChange(String _) {}

void _ignoreTap() {}
