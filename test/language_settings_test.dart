import 'dart:convert';

import 'package:app/data/garage_storage.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/main.dart';
import 'package:app/models/vehicle_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('vehicle manufacturer label uses the updated terminology', () {
    expect(
      const AppLocalizations(Locale('en')).makeOptional,
      'Manufacturer (optional)',
    );
    expect(
      const AppLocalizations(Locale('ar')).makeOptional,
      'الشركة المصنعة (اختياري)',
    );
  });

  testWidgets('language setting switches to Arabic and persists the choice', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final collection = GarageCollection(
      vehicles: [
        VehicleProfile(
          id: 'vehicle-1',
          year: 2020,
          make: 'Toyota',
          model: 'Corolla',
          garage: GarageSnapshot.empty(),
        ),
      ],
      selectedVehicleId: 'vehicle-1',
      defaultVehicleId: 'vehicle-1',
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'garage_snapshot_v1',
      jsonEncode(collection.toJson()),
    );
    await tester.pumpWidget(const GearTrackerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('settings-egyptian-dialect-switch')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('settings-language-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-option-arabic')));
    await tester.pumpAndSettle();

    expect(find.text('اللغة'), findsOneWidget);
    expect(find.text('العربية'), findsWidgets);
    final savedPreferences = await SharedPreferences.getInstance();
    expect(savedPreferences.getString('appLocale'), 'ar');
  });

  testWidgets('Arabic exposes Egyptian dialect toggle and persists ar-EG', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final collection = GarageCollection(
      vehicles: [
        VehicleProfile(
          id: 'vehicle-1',
          year: 2020,
          make: 'Toyota',
          model: 'Corolla',
          garage: GarageSnapshot.empty(),
        ),
      ],
      selectedVehicleId: 'vehicle-1',
      defaultVehicleId: 'vehicle-1',
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'garage_snapshot_v1',
      jsonEncode(collection.toJson()),
    );
    await tester.pumpWidget(const GearTrackerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-language-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-option-arabic')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('settings-egyptian-dialect-switch')),
      findsOneWidget,
    );
    expect(find.text('اللهجة المصرية'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-egyptian-dialect-switch')));
    await tester.pumpAndSettle();

    final appState = tester.state<GearTrackerAppState>(
      find.byType(GearTrackerApp),
    );
    expect(appState.isEgyptianArabic, isTrue);
    final savedDialectPreferences = await SharedPreferences.getInstance();
    expect(savedDialectPreferences.getString('appLocale'), 'ar-EG');
    expect(
      const AppLocalizations(Locale('ar', 'EG'))
          .servicePresetName('spark_plugs', 'Spark plugs'),
      'بوجيهات',
    );
    const egyptian = AppLocalizations(Locale('ar', 'EG'));
    expect(
      egyptian.servicePresetName('cabin_filter', 'Cabin filter'),
      'فلتر التكييف',
    );
    expect(egyptian.servicePresetName('brake_pads', 'Brake pads'), 'تيل فرامل');
    expect(
      egyptian.servicePresetName('tires', 'Tire rotation and alignment'),
      'تدوير الكاوتش وضبط الزوايا',
    );
    expect(
      egyptian.servicePresetName(
        'timing_belt',
        'Timing belt / chain inspection',
      ),
      'فحص سير الكاتينة',
    );
    expect(
      egyptian.servicePresetName('transmission_fluid', 'Transmission fluid'),
      'زيت فتيس',
    );
  });
}
