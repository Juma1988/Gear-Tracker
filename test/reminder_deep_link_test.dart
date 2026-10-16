import 'dart:convert';

import 'package:app/data/garage_repository.dart';
import 'package:app/models/service_item.dart';
import 'package:app/models/vehicle_profile.dart';
import 'package:app/screens/dashboard_screen.dart';
import 'package:app/screens/edit_service_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'reminder payload opens the matching service on the active vehicle',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      _deliver(
        tester,
        jsonEncode({'vehicleId': 'vehicle', 'serviceId': 'oil'}),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EditServiceScreen), findsOneWidget);
      expect(find.text('Engine Oil'), findsOneWidget);
    },
  );

  testWidgets('reminder payload switches vehicle before opening the service', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Notification targets the *other* vehicle, which is not active yet.
    _deliver(tester, jsonEncode({'vehicleId': 'other', 'serviceId': 'brakes'}));
    await tester.pumpAndSettle();

    expect(find.byType(EditServiceScreen), findsOneWidget);
    expect(find.text('Brake Pads'), findsOneWidget);
  });

  testWidgets(
    'cold-start reminder retains its vehicle until the garage loads',
    (tester) async {
      await tester.pumpWidget(_app());

      // Deliver before the asynchronous garage load completes.
      _deliver(
        tester,
        jsonEncode({'vehicleId': 'other', 'serviceId': 'brakes'}),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EditServiceScreen), findsOneWidget);
      expect(find.text('Brake Pads'), findsOneWidget);
    },
  );

  testWidgets('unknown cold-start vehicle does not open a service', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    _deliver(tester, jsonEncode({'vehicleId': 'missing', 'serviceId': 'oil'}));
    await tester.pumpAndSettle();

    expect(find.byType(EditServiceScreen), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().toLowerCase().contains('engine oil'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('malformed reminder payload does not disturb navigation', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    _deliver(tester, 'not-json');
    await tester.pumpAndSettle();

    expect(find.byType(EditServiceScreen), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().toLowerCase().contains('engine oil'),
      ),
      findsOneWidget,
    );
  });
}

void _deliver(WidgetTester tester, String payload) {
  tester
      .state<DashboardScreenState>(find.byType(DashboardScreen))
      .deliverReminderResponseForTesting(payload);
}

Widget _app() => MaterialApp(
  home: DashboardScreen(
    repository: GarageRepository(storage: _Storage(_collectionJson)),
    odometerSaveDebounce: const Duration(seconds: 10),
  ),
);

final _collectionJson = jsonEncode(
  GarageCollection(
    selectedVehicleId: 'vehicle',
    defaultVehicleId: GarageCollection.lastUsedVehicleId,
    vehicles: [
      VehicleProfile(
        id: 'vehicle',
        year: 2020,
        make: 'A',
        model: 'Vehicle',
        garage: GarageSnapshot(
          odometer: 100,
          services: const [
            ServiceItem(
              id: 'oil',
              name: 'Engine Oil',
              note: '',
              serviceOdometer: 0,
              intervalKm: 1000,
              iconKey: 'maintenance',
            ),
          ],
          tires: const [],
          history: const [],
        ),
      ),
      VehicleProfile(
        id: 'other',
        year: 2021,
        make: 'B',
        model: 'Other',
        garage: GarageSnapshot(
          odometer: 200,
          services: const [
            ServiceItem(
              id: 'brakes',
              name: 'Brake Pads',
              note: '',
              serviceOdometer: 0,
              intervalKm: 1000,
              iconKey: 'maintenance',
            ),
          ],
          tires: const [],
          history: const [],
        ),
      ),
    ],
  ).toJson(),
);

class _Storage implements GarageStorage {
  _Storage(this.value);
  final String value;

  @override
  Future<String?> read() async => value;

  @override
  Future<bool> write(String value) async => true;
}
