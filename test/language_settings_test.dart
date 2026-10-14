import 'dart:convert';

import 'package:app/data/garage_storage.dart';
import 'package:app/main.dart';
import 'package:app/models/vehicle_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
    await preferences.setString('garage_snapshot_v1', jsonEncode(collection.toJson()));
    await tester.pumpWidget(const GearTrackerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-language-card')));
    await tester.pumpAndSettle();

    expect(find.text('اللغة'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);
    final savedPreferences = await SharedPreferences.getInstance();
    expect(savedPreferences.getString('appLocale'), 'ar');
  });
}
