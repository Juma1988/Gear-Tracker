import 'package:app/l10n/app_localizations.dart';
import 'package:app/screens/tire_health_wizard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts with current odometer and blank tire inputs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const TireHealthWizardScreen(currentOdometer: 120000),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('wizard-install-odometer-field')),
          )
          .controller!
          .text,
      '120000',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('wizard-interval-field')))
          .controller!
          .text,
      isEmpty,
    );
  });
}
