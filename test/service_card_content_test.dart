import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/service_item.dart';
import 'package:app/widgets/service_card_content.dart';
import 'package:app/widgets/service_health_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// BE-F31 focused tests for the extracted service-card content boundary.
///
/// These lock the conditional layout decisions (condition line, details
/// toggle, detail copy, progress) that used to live inline in one long
/// `build` method.
const _l10n = AppLocalizations(Locale('en'));

const _oilChange = ServiceItem(
  id: 'engine-oil',
  name: 'Engine Oil',
  note: '5W-40 SYN',
  serviceOdometer: 74850,
  intervalKm: 10000,
  iconKey: 'oil',
);

const _timeBased = ServiceItem(
  id: 'air-filter',
  name: 'Air Filter',
  note: 'OEM paper element',
  iconKey: 'maintenance',
);

Future<BuildContext> _pumpContext(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (inner) {
          context = inner;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return context;
}

void main() {
  testWidgets('shows the note behind the details toggle when there is no '
      'condition', (tester) async {
    final context = await _pumpContext(tester);
    final data = ServiceCardViewData.of(
      context,
      service: _oilChange,
      currentOdometer: 78000,
      now: DateTime(2026, 1, 1),
    );

    expect(data.metrics, isNotNull);
    expect(data.showsConditionLine, isFalse);
    expect(data.showsDetailsToggle, isFalse);
    expect(data.alwaysShowsDetail, isFalse);
    expect(data.detail, '5W-40 SYN');
    expect(data.showsDetailText(false), isFalse);
    expect(data.showsDetailText(true), isTrue);
    expect(data.remainingKmLabel, isNotNull);
  });

  testWidgets('shows the condition line and hides the toggle when a service '
      'is damaged', (tester) async {
    final context = await _pumpContext(tester);
    final data = ServiceCardViewData.of(
      context,
      service: _oilChange,
      currentOdometer: 82350,
      now: DateTime(2026, 1, 1),
    );

    expect(data.metrics!.damagePercent, 75);
    expect(data.showsConditionLine, isTrue);
    expect(data.showsDetailsToggle, isFalse);
    expect(data.showsDetailText(true), isFalse);
    expect(data.detail, _l10n.condition(ServiceStatusKey.warning, '75'));
  });

  testWidgets('hides shelf-life copy from the service card', (tester) async {
    final context = await _pumpContext(tester);
    final data = ServiceCardViewData.of(
      context,
      service: _timeBased.copyWith(
        installDate: DateTime(2026, 1, 1),
        shelfLifeMonths: 12,
      ),
      currentOdometer: 78000,
      now: DateTime(2026, 1, 1),
    );

    expect(data.metrics, isNull);
    expect(data.remainingKmLabel, isNull);
    expect(data.alwaysShowsDetail, isTrue);
    expect(data.showsConditionLine, isFalse);
    expect(data.showsDetailsToggle, isFalse);
    expect(data.showsDetailText(false), isFalse);
    expect(data.showsDetailText(true), isFalse);
    expect(data.detail, _l10n.checkIn('365'));
    expect(data.timeProgress, closeTo(1, 0.0001));
  });

  testWidgets('renders a condition line instead of the note', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ServiceHealthCard.service(
                service: _oilChange,
                currentOdometer: 82350,
                onEditService: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('5W-40 SYN'), findsNothing);
    expect(
      find.byKey(const Key('service-health-card-details-engine-oil')),
      findsNothing,
    );
    expect(find.textContaining('75'), findsWidgets);
  });

  testWidgets('does not render a Show details control', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ServiceHealthCard.service(
                service: _oilChange,
                currentOdometer: 78000,
                onEditService: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('5W-40 SYN'), findsNothing);
    expect(
      find.byKey(const Key('service-health-card-details-engine-oil')),
      findsNothing,
    );
    expect(find.text(_l10n.showDetails), findsNothing);
    expect(find.text(_l10n.hideDetails), findsNothing);
    expect(find.text('5W-40 SYN'), findsNothing);
    expect(
      find.byKey(const Key('service-health-card-content')),
      findsOneWidget,
    );

    final bar = tester.widget<LinearProgressIndicator>(
      find.descendant(
        of: find.byType(HealthProgressBar),
        matching: find.byType(LinearProgressIndicator),
      ),
    );
    expect(bar.value, closeTo(0.685, 0.0001));
  });

  testWidgets('HealthProgressBar exposes the shared implementation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HealthProgressBar(
            label: 'Progress: 31%',
            valueLabel: '31%',
            value: 0.69,
            color: Colors.green,
            backgroundColor: Colors.white,
            height: 8,
          ),
        ),
      ),
    );

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.69);
    expect(bar.minHeight, 8);
  });
}
