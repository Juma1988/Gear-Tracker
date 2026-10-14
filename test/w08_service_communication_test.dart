import 'package:app/l10n/app_localizations.dart';
import 'package:app/screens/add_service_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _l10n = AppLocalizations(Locale('en'));

void main() {
  testWidgets('custom service opens with the automatic maintenance icon', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const AddServiceScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-custom-service-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('custom-service-icon-auto')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add-service-name-field')), findsOneWidget);
    expect(find.text('Choose an icon'), findsNothing);
  });

  testWidgets('note is progressively disclosed in the service form', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const AddServiceScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-custom-service-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('custom-service-icon-auto')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add-service-note-field')), findsNothing);
    await tester.tap(
      find.byKey(const Key('service-form-optional-details-toggle')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-service-note-field')), findsOneWidget);
  });

  testWidgets('expanded note details retain content when toggled', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const AddServiceScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-custom-service-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('custom-service-icon-auto')));
    await tester.pumpAndSettle();

    final toggle = find.byKey(
      const Key('service-form-optional-details-toggle'),
    );
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('add-service-note-field')),
      'Use the synthetic oil specification',
    );
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.text(_l10n.hideDetails), findsNothing);
    expect(find.text(_l10n.addNote), findsOneWidget);
    expect(find.byKey(const Key('add-service-note-field')), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('add-service-note-field')),
          )
          .controller!
          .text,
      'Use the synthetic oil specification',
    );
  });

}

Widget _app(Widget home) => MaterialApp(
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);
