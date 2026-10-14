import 'package:app/l10n/app_localizations.dart';
import 'package:app/reminders/reminder_preferences.dart';
import 'package:app/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _l10n = AppLocalizations(Locale('en'));

void main() {
  testWidgets('reminder dialog exposes reminder controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReminderSettingsDialog(initial: const ReminderPreferences()),
      ),
    );

    expect(find.byKey(const Key('reminders-enabled-switch')), findsOneWidget);
    expect(find.byKey(const Key('reminders-repeat-switch')), findsOneWidget);
    expect(find.byKey(const Key('reminders-weekday-selector')), findsOneWidget);
    expect(find.byKey(const Key('reminders-time-picker')), findsOneWidget);
    expect(find.text(_l10n.saveAction), findsOneWidget);
    expect(find.text(_l10n.cancel), findsOneWidget);
  });
}
