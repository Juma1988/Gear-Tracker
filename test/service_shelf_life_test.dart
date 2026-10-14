import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/service_item.dart';
import 'package:app/models/tire_item.dart';
import 'package:app/screens/dashboard_screen.dart';
import 'package:app/widgets/app_bar.dart' as app;
import 'package:app/widgets/service_health_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _l10n = AppLocalizations(Locale('en'));

void main() {
  final service = ServiceItem(
    id: 'battery',
    name: 'Battery',
    note: '12V',
    serviceOdometer: 1000,
    intervalKm: 10000,
    iconKey: 'battery',
    installDate: DateTime(2026, 1, 15),
    hasShelfLife: true,
    shelfLifeMonths: 3,
  );

  test('calculates deterministic shelf-life calendar-day states', () {
    expect(service.shelfLifeDueDate, DateTime(2026, 4, 15));
    expect(service.shelfLifeStatusAt(DateTime(2026, 4, 6))!.daysRemaining, 9);
    expect(service.shelfLifeStatusAt(DateTime(2026, 4, 7))!.daysRemaining, 8);
    expect(service.shelfLifeStatusAt(DateTime(2026, 4, 16))!.isExpired, isTrue);
  });

  test('supports a time-only service without mileage placeholders', () {
    final battery = ServiceItem(
      id: 'time-only-battery',
      name: 'Battery',
      note: 'AGM',
      iconKey: 'battery',
      installDate: DateTime(2026, 1, 15),
      shelfLifeMonths: 36,
    );

    expect(battery.tracksMileage, isFalse);
    expect(battery.tracksTime, isTrue);
    expect(battery.metricsAt(50000), isNull);
    expect(
      battery.statusAt(50000, now: DateTime(2029, 1, 15)),
      ServiceStatus.replaceNow,
    );
    final restored = ServiceItem.fromJson(battery.toJson());
    expect(restored.tracksTime, isTrue);
    expect(restored.tracksMileage, isFalse);
  });

  test('combines tire age and mileage health with a five-year default', () {
    final tire = TireItem(
      id: 'front-left',
      code: 'FL',
      installOdometer: 1000,
      intervalKm: 50000,
      installDate: DateTime(2021, 1, 1),
    );

    expect(tire.shelfLifeMonths, 60);
    expect(
      tire.metricsAt(2000, now: DateTime(2025, 12, 31)).status,
      ServiceStatus.replaceSoon,
    );
    expect(
      tire.metricsAt(2000, now: DateTime(2026, 1, 2)).status,
      ServiceStatus.replaceNow,
    );
    expect(tire.toJson()['shelfLifeMonths'], 60);
  });

  test(
    'combines mileage and shelf-life urgency using the worse visible state',
    () {
      expect(
        service.statusAt(2000, now: DateTime(2026, 4, 6)),
        ServiceStatus.replaceSoon,
      );
      expect(
        service.statusAt(2000, now: DateTime(2026, 4, 5)),
        ServiceStatus.excellent,
      );
      expect(
        service.statusAt(2000, now: DateTime(2026, 4, 8)),
        ServiceStatus.replaceSoon,
      );
      expect(
        service.statusAt(2000, now: DateTime(2026, 4, 15)),
        ServiceStatus.replaceNow,
      );
      expect(
        service.statusAt(10500, now: DateTime(2026, 4, 8)),
        ServiceStatus.replaceSoon,
      );
    },
  );

  test('orders dashboard cards by combined red orange green urgency', () {
    final green = service.copyWith(
      name: 'Green',
      hasShelfLife: false,
      shelfLifeMonths: null,
      installDate: null,
    );
    final orange = service.copyWith(name: 'Orange');
    final red = service.copyWith(
      name: 'Red',
      installDate: DateTime(2026, 1, 8),
    );

    final cards = DashboardHealthCard.ordered(
      services: [green, orange, red],
      tires: const [],
      currentOdometer: 2000,
      now: DateTime(2026, 4, 8),
    ).whereType<DashboardServiceHealthCard>().toList();

    expect(cards.map((card) => card.service.name), ['Red', 'Orange', 'Green']);
  });

  test('keeps healthy time-only services below normal cards until 90%', () {
    final timeOnly = ServiceItem(
      id: 'time-only',
      name: 'Time only',
      note: '',
      iconKey: 'battery',
      installDate: DateTime(2026, 1, 1),
      shelfLifeMonths: 12,
    );
    final mileage = ServiceItem(
      id: 'mileage',
      name: 'Z mileage',
      note: '',
      serviceOdometer: 0,
      intervalKm: 50000,
      iconKey: 'oil',
    );

    final beforePromotion = DashboardHealthCard.ordered(
      services: [timeOnly, mileage],
      tires: const [],
      currentOdometer: 0,
      now: DateTime(2026, 10, 1),
    ).whereType<DashboardServiceHealthCard>();
    expect(beforePromotion.map((card) => card.service.id), [
      'mileage',
      'time-only',
    ]);

    final afterPromotion = DashboardHealthCard.ordered(
      services: [timeOnly, mileage],
      tires: const [],
      currentOdometer: 0,
      now: DateTime(2026, 12, 1),
    ).whereType<DashboardServiceHealthCard>();
    expect(afterPromotion.first.service.id, 'time-only');
  });

  testWidgets('does not show the decorative header indicator', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: app.AppBar(
            onSettings: _noop,
            onVehicle: _noop,
            status: ServiceStatus.replaceNow,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('dashboard-health-indicator')), findsNothing);
  });

  testWidgets(
    'hides shelf-life details while retaining combined urgency and mileage metrics',
    (tester) async {
      await tester.pumpWidget(_card(service, DateTime(2026, 4, 6)));
      await tester.pump();
      expect(find.byIcon(Icons.hourglass_top), findsNothing);
      expect(find.textContaining('Due by'), findsNothing);
      expect(find.text('9'), findsNothing);
      expect(find.text('days left'), findsNothing);
      expect(
        find.text(_l10n.status(ServiceStatusKey.replaceSoon)),
        findsOneWidget,
      );
      expect(find.textContaining('9,000 km left'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(.9, .001),
      );
    },
  );

  testWidgets('time-only card omits mileage progress and distance copy', (
    tester,
  ) async {
    final battery = ServiceItem(
      id: 'time-only-card',
      name: 'Battery',
      note: 'AGM',
      iconKey: 'battery',
      installDate: DateTime(2026, 1, 15),
      shelfLifeMonths: 36,
    );
    await tester.pumpWidget(_card(battery, DateTime(2027, 1, 15)));
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('km left'), findsNothing);
    expect(find.textContaining('Check in'), findsNothing);
  });

  testWidgets('uses content-driven height with and without shelf life', (
    tester,
  ) async {
    final noShelfLife = service.copyWith(hasShelfLife: false);

    await tester.pumpWidget(_card(noShelfLife, DateTime(2026, 4, 6)));
    await tester.pump();
    final noShelfLifeHeight = tester
        .getSize(find.byKey(const Key('service-health-card-content')))
        .height;

    await tester.pumpWidget(_card(service, DateTime(2026, 4, 6)));
    await tester.pump();
    final shelfLifeHeight = tester
        .getSize(find.byKey(const Key('service-health-card-content')))
        .height;

    expect(noShelfLifeHeight, greaterThan(0));
    expect(shelfLifeHeight, greaterThan(0));
  });

  testWidgets(
    'hides expired shelf-life details while retaining red urgency and KM metrics',
    (tester) async {
      await tester.pumpWidget(_card(service, DateTime(2026, 4, 16)));
      await tester.pump();

      expect(find.byIcon(Icons.hourglass_top), findsNothing);
      expect(find.text('Expired'), findsNothing);
      expect(find.textContaining('Due by'), findsNothing);
      expect(
        find.text(_l10n.status(ServiceStatusKey.replaceNow)),
        findsOneWidget,
      );
      expect(find.textContaining('9,000 km left'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(.9, .001),
      );
    },
  );
}

Widget _card(ServiceItem service, DateTime now) => MaterialApp(
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  home: Scaffold(
    body: SizedBox(
      width: 390,
      child: ServiceHealthCard.service(
        service: service,
        currentOdometer: 2000,
        onEditService: () {},
        now: now,
      ),
    ),
  ),
);

void _noop() {}
