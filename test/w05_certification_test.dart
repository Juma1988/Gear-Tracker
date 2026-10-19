import 'dart:convert';
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:app/data/data.dart';
import 'package:app/data/garage_repository.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/main.dart';
import 'package:app/preferences/daily_odometer_preferences.dart';
import 'package:app/models/service_item.dart';
import 'package:app/models/vehicle_profile.dart';
import 'package:app/screens/add_service_screen.dart';
import 'package:app/widgets/date_input.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _l10n = AppLocalizations(Locale('en'));

void main() {
  setUp(() {
    final snapshot = GarageSnapshot(
      odometer: 74850,
      services: initialServices,
      tires: initialTires,
      history: const [],
    );
    SharedPreferences.setMockInitialValues({
      DailyOdometerPreferences.key: DailyOdometerPreferences.dayKey(
        DateTime.now(),
      ),
      'garage_snapshot_v1': jsonEncode(
        GarageCollection(
          selectedVehicleId: 'long-name-vehicle',
          defaultVehicleId: GarageCollection.lastUsedVehicleId,
          vehicles: [
            VehicleProfile(
              id: 'long-name-vehicle',
              year: 2026,
              make: 'Extraordinarily Long Manufacturer Name',
              model: 'An Exceptionally Long Vehicle Model Name',
              garage: snapshot,
            ),
          ],
        ).toJson(),
      ),
    });
  });

  testWidgets(
    'dashboard header keeps vehicle control and Add and Settings actions reachable at 320px and 200% text scale',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: GearTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Explicitly target Dashboard for this header accessibility check.
      await tester.tap(find.byKey(const Key('bottom-nav-home')));
      await tester.pumpAndSettle();
      final vehicleControl = find.textContaining(
        'EXTRAORDINARILY LONG MANUFACTURER NAME',
      );
      final addAction = find.byKey(const Key('bottom-nav-add-service'));
      final settingsAction = find.byTooltip(_l10n.settingsTitle);
      for (final control in [addAction, settingsAction]) {
        expect(control, findsOneWidget);
        expect(tester.getRect(control).bottom, lessThanOrEqualTo(640));
      }
      expect(tester.getRect(vehicleControl).top, greaterThanOrEqualTo(0));

      for (final action in [addAction, settingsAction]) {
        expect(
          tester
              .getSemantics(action)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
      }

      await tester.ensureVisible(vehicleControl);
      await tester.tap(vehicleControl);
      await tester.pumpAndSettle();
      expect(find.text(_l10n.yourVehicles), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.ensureVisible(addAction);
      await tester.tap(addAction);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('add-choice-dialog')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('add-choice-service')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-choice-service')));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.chooseIcon), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.ensureVisible(settingsAction);
      await tester.tap(settingsAction);
      await tester.pumpAndSettle();
      expect(find.text(_l10n.settingsTitle), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'large-text date picker keeps Cancel and Done reachable, cancels staged edits, and commits a bounded selection',
    (tester) async {
      final initialDate = DateTime(2024, 5, 8);
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _localizedApp(
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: _DateInputHarness(initialDate: initialDate),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('service-install-date-button')),
      );
      final original = _dateFromField(tester);

      await tester.tap(find.byKey(const Key('service-install-date-button')));
      await tester.pumpAndSettle();
      final picker = tester.widget<CupertinoDatePicker>(
        find.byKey(const Key('service-install-date-wheel')),
      );
      final now = DateTime.now();
      expect(picker.minimumDate, DateTime(2000));
      expect(picker.maximumDate, DateTime(now.year, now.month, now.day));
      final cancel = find.byKey(const Key('service-install-date-cancel'));
      final done = find.byKey(const Key('service-install-date-done'));
      for (final action in [cancel, done]) {
        expect(action, findsOneWidget);
        expect(tester.getRect(action).bottom, lessThanOrEqualTo(640));
      }

      await tester.drag(
        find.byKey(const Key('service-install-date-wheel')),
        const Offset(0, -80),
      );
      await tester.pumpAndSettle();
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(_dateFromField(tester), original);

      await tester.tap(find.byKey(const Key('service-install-date-button')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('service-install-date-wheel')),
        const Offset(0, -80),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('service-install-date-done')));
      await tester.pumpAndSettle();
      expect(_dateFromField(tester), isNot(original));
    },
  );

  testWidgets(
    'desktop date input uses a keyboard-friendly calendar and normalizes an unsafe range',
    (tester) async {
      await tester.pumpWidget(
        _localizedApp(
          child: Scaffold(
            body: DateInput(
              value: DateTime(2024, 5, 8),
              firstDate: DateTime(2025, 1, 1),
              lastDate: DateTime(2024, 1, 1),
              onChanged: (_) {},
              label: 'Installed on',
              fieldKey: const Key('desktop-date-input'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('desktop-date-input')));
      await tester.pumpAndSettle();

      expect(find.byType(CalendarDatePicker), findsOneWidget);
      expect(find.byType(CupertinoDatePicker), findsNothing);
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );

  testWidgets(
    'selected picker card is selected and disabled with context while available card remains actionable',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _localizedApp(
          child: const AddServiceScreen(
            hasTires: true,
            existingServices: [
              ServiceItem(
                id: 'existing-oil',
                name: 'Engine Oil',
                note: 'Installed',
                serviceOdometer: 100,
                intervalKm: 1000,
                iconKey: 'oil',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final selected = tester
          .getSemantics(find.byKey(const Key('service-preset-oil')))
          .getSemanticsData();
      expect(selected.flagsCollection.isSelected, equals(Tristate.isTrue));
      expect(selected.hasAction(SemanticsAction.tap), isFalse);
      expect(selected.label, contains(_l10n.selectedLabel('Engine oil')));
      expect(selected.hint, _l10n.alreadySelectedHint);

      expect(find.bySemanticsLabel('Air filter'), findsOneWidget);
      await tester.tap(find.byKey(const Key('service-preset-air_filter')));
      await tester.pumpAndSettle();
      expect(find.text('Air filter'), findsOneWidget);
      expect(find.byKey(const Key('add-service-name-field')), findsNothing);
      semantics.dispose();
    },
  );
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

Widget _localizedApp({required Widget child}) => MaterialApp(
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: child,
);

class _DateInputHarness extends StatefulWidget {
  const _DateInputHarness({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_DateInputHarness> createState() => _DateInputHarnessState();
}

class _DateInputHarnessState extends State<_DateInputHarness> {
  late DateTime _value = widget.initialDate;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: DateInput(
        value: _value,
        onChanged: (value) => setState(() => _value = value),
        label: 'Installed on',
        fieldKey: const Key('service-install-date-button'),
        sheetKey: const Key('service-install-date-sheet'),
        wheelKey: const Key('service-install-date-wheel'),
        cancelKey: const Key('service-install-date-cancel'),
        doneKey: const Key('service-install-date-done'),
      ),
    ),
  );
}
