import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/service_item.dart';
import 'package:app/screens/service_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _l10n = AppLocalizations(Locale('en'));

void main() {
  testWidgets('time mode shows only time schedule fields', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-service-form')));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_l10n.trackingModeTime, skipOffstage: false));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add-service-install-km-field')), findsNothing);
    expect(find.byKey(const Key('add-service-interval-field')), findsNothing);
    expect(
      find.byKey(const Key('service-install-date-button')),
      findsOneWidget,
    );

    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('add-service-shelf-life-months-field')),
          )
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('switching battery modes preserves entered schedule values', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-service-form')));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_l10n.trackingModeMileage, skipOffstage: false));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('add-service-interval-field')),
      '12000',
    );
    await tester.tap(find.text(_l10n.trackingModeBoth, skipOffstage: false));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('add-service-interval-field')),
          )
          .controller!
          .text,
      '12000',
    );

    final timeMode = find.text(_l10n.trackingModeTime, skipOffstage: false);
    await tester.ensureVisible(timeMode);
    await tester.drag(
      find.byKey(const Key('service-form-scroll-view')),
      const Offset(0, 120),
    );
    await tester.pumpAndSettle();
    await tester.tap(timeMode);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-service-interval-field')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('tracking-mode-selector')));
    await tester.tap(find.text(_l10n.trackingModeBoth, skipOffstage: false));
    await tester.pumpAndSettle();
    expect(find.text('12000'), findsOneWidget);
  });
}

Widget _app({void Function(ServiceItem service)? onSaved}) => MaterialApp(
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(
    body: Center(
      child: Builder(
        builder: (context) => FilledButton(
          key: const Key('open-service-form'),
          onPressed: () async {
            final service = await Navigator.of(context).push<ServiceItem>(
              MaterialPageRoute(
                builder: (_) => const ServiceFormScreen(
                  currentOdometer: 50000,
                  initialIconKey: 'battery',
                  initialIcon: Icons.battery_full,
                ),
              ),
            );
            if (service != null) onSaved?.call(service);
          },
          child: const Text('Open'),
        ),
      ),
    ),
  ),
);
