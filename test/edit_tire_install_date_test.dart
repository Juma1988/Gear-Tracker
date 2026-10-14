import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/tire_item.dart';
import 'package:app/screens/edit_tire_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final initialDate = DateTime(2024, 5, 8);
  final tire = TireItem(
    id: 'front-left',
    code: 'FL',
    installOdometer: 100,
    intervalKm: 1000,
    installDate: initialDate,
  );

  testWidgets('uses the shared outlined date field and wheel picker', (
    tester,
  ) async {
    await tester.pumpWidget(_editorApp(tire: tire));
    await tester.pump();

    final field = find.byKey(const Key('service-install-date-button'));
    expect(field, findsOneWidget);
    final editableText = tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    expect(editableText.readOnly, isTrue);
    expect(editableText.showCursor, isFalse);
    expect(find.text('Installed on'), findsOneWidget);

    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('service-install-date-sheet')), findsOneWidget);
    expect(find.byKey(const Key('service-install-date-wheel')), findsOneWidget);

    final picker = tester.widget<CupertinoDatePicker>(
      find.byKey(const Key('service-install-date-wheel')),
    );
    expect(picker.minimumDate, DateTime(2000));
    final now = DateTime.now();
    expect(picker.maximumDate, DateTime(now.year, now.month, now.day));
  });

  testWidgets('cancel keeps the tire installation date unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(_editorApp(tire: tire));
    await tester.pump();
    final original = _formattedDate(tester, initialDate);

    await tester.tap(find.byKey(const Key('service-install-date-button')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('service-install-date-wheel')),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('service-install-date-cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('service-install-date-sheet')), findsNothing);
    expect(find.text(original), findsOneWidget);
  });

  testWidgets('done stages the selected date and saves it with the tire', (
    tester,
  ) async {
    TireItem? savedTire;
    await tester.pumpWidget(_navigationApp(tire: tire));
    await tester.pump();
    await tester.tap(find.byKey(const Key('open-tire-editor')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('service-install-date-button')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('service-install-date-wheel')),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('service-install-date-done')));
    await tester.pumpAndSettle();

    final selectedDateText = _dateFromField(tester);
    expect(selectedDateText, isNot(_formattedDate(tester, initialDate)));

    await tester.tap(find.byKey(const Key('save-tire-button')));
    await tester.pumpAndSettle();

    savedTire = tester
        .widget<_TireSaveResult>(find.byKey(const Key('tire-save-result')))
        .tire;
    expect(savedTire.installDate, isNot(initialDate));
  });
}

String _dateFromField(WidgetTester tester) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('service-install-date-button')),
        matching: find.byType(EditableText),
      ),
    )
    .controller
    .text;

String _formattedDate(WidgetTester tester, DateTime date) =>
    MaterialLocalizations.of(
      tester.element(find.byKey(const Key('service-install-date-button'))),
    ).formatMediumDate(date);

Widget _editorApp({required TireItem tire}) => MaterialApp(
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: EditTireScreen(tire: tire, currentOdometer: 100)),
);

Widget _navigationApp({required TireItem tire}) => MaterialApp(
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: _TireEditorLauncher(tire: tire),
);

class _TireEditorLauncher extends StatefulWidget {
  const _TireEditorLauncher({required this.tire});

  final TireItem tire;

  @override
  State<_TireEditorLauncher> createState() => _TireEditorLauncherState();
}

class _TireEditorLauncherState extends State<_TireEditorLauncher> {
  TireItem? _savedTire;

  Future<void> _openEditor() async {
    final result = await Navigator.of(context).push<TireItem>(
      MaterialPageRoute(
        builder: (_) => EditTireScreen(tire: widget.tire, currentOdometer: 100),
      ),
    );
    if (result != null && mounted) setState(() => _savedTire = result);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        FilledButton(
          key: const Key('open-tire-editor'),
          onPressed: _openEditor,
          child: const Text('Open editor'),
        ),
        if (_savedTire != null)
          _TireSaveResult(
            key: const Key('tire-save-result'),
            tire: _savedTire!,
          ),
      ],
    ),
  );
}

class _TireSaveResult extends StatelessWidget {
  const _TireSaveResult({super.key, required this.tire});

  final TireItem tire;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
