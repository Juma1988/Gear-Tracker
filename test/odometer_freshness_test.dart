import 'package:app/l10n/app_localizations.dart';
import 'package:app/widgets/odometer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({required Locale locale, DateTime? lastUpdatedAt}) => MaterialApp(
  locale: locale,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: OdometerCard(
      odometer: '000100',
      onChanged: (_) {},
      saveRevision: 0,
      isDirty: false,
      lastUpdatedAt: lastUpdatedAt,
    ),
  ),
);

void main() {
  testWidgets('shows localized unknown freshness for legacy data', (tester) async {
    await tester.pumpWidget(_app(locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Last updated: Not available yet'), findsOneWidget);
  });

  testWidgets('formats a known freshness timestamp through locale services', (tester) async {
    final timestamp = DateTime.utc(2026, 10, 11, 12, 30);
    await tester.pumpWidget(
      _app(locale: const Locale('en'), lastUpdatedAt: timestamp),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Last updated:'), findsOneWidget);
    expect(find.text('Last updated: Not available yet'), findsNothing);
  });

  testWidgets('freshness label wraps at large text scale', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
        child: _app(locale: const Locale('en')),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Last updated: Not available yet'), findsOneWidget);
  });

  test('localizes freshness copy in Arabic', () {
    final l10n = AppLocalizations(const Locale('ar'));
    expect(l10n.lastUpdatedUnknown, contains('آخر تحديث'));
    expect(l10n.lastUpdatedAt('١١ أكتوبر', '١٢:٣٠'), contains('آخر تحديث'));
  });
}
