import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/service_item.dart';
import 'package:app/screens/edit_service_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final initialDate = DateTime(2024, 5, 8);
  final service = ServiceItem(
    id: 'oil',
    name: 'Engine Oil',
    note: '5W-40 SYN',
    serviceOdometer: 100,
    intervalKm: 1000,
    iconKey: 'oil',
    installDate: initialDate,
    shelfLifeMonths: 12,
  );

  testWidgets(
    'presents the localized installation date in an outlined read-only field',
    (tester) async {
      await tester.pumpWidget(_app(service: service));
      await tester.pump();
      await _showDateControls(tester);
      final material = MaterialLocalizations.of(
        tester.element(find.byKey(const Key('service-install-date-button'))),
      );
      final date = material.formatMediumDate(initialDate);

      final field = find.byKey(const Key('service-install-date-button'));
      expect(field, findsOneWidget);
      final editableText = tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      expect(editableText.readOnly, isTrue);
      expect(editableText.showCursor, isFalse);
      expect(editableText.controller.text, date);
      expect(find.text('Installed on'), findsOneWidget);
    },
  );

  testWidgets('opens wheels and cancel keeps the staged date unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(_app(service: service));
    await tester.pump();
    await _showDateControls(tester);
    final original = MaterialLocalizations.of(
      tester.element(find.byKey(const Key('service-install-date-button'))),
    ).formatMediumDate(initialDate);

    await tester.tap(find.byKey(const Key('service-install-date-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('service-install-date-sheet')), findsOneWidget);
    expect(find.byKey(const Key('service-install-date-wheel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('service-install-date-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('service-install-date-sheet')), findsNothing);
    expect(find.text(original), findsOneWidget);
  });

  testWidgets(
    'date picker constrains selection through today and saves on Done',
    (tester) async {
      await tester.pumpWidget(_app(service: service));
      await tester.pump();
      await _showDateControls(tester);
      await tester.tap(find.byKey(const Key('service-install-date-button')));
      await tester.pumpAndSettle();

      final picker = tester.widget<CupertinoDatePicker>(
        find.byKey(const Key('service-install-date-wheel')),
      );
      expect(picker.minimumDate, DateTime(2000));
      final now = DateTime.now();
      expect(picker.maximumDate, DateTime(now.year, now.month, now.day));

      await tester.drag(
        find.byKey(const Key('service-install-date-wheel')).first,
        const Offset(0, -80),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('service-install-date-done')));
      await tester.pumpAndSettle();

      expect(find.text(initialDate.toString()), findsNothing);
    },
  );

  testWidgets('date card does not overflow at large text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(service: service, textScaler: const TextScaler.linear(2)),
    );
    await tester.pump();
    await _showDateControls(tester);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  required ServiceItem service,
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: MediaQuery(
    data: MediaQueryData(textScaler: textScaler),
    child: EditServiceScreen(service: service, currentOdometer: 100),
  ),
);

Future<void> _showDateControls(WidgetTester tester) async {
  final dateField = find.byKey(const Key('service-install-date-button'));
  if (dateField.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      dateField,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
  }
  expect(dateField, findsOneWidget);
}
