import 'package:app/models/service_item.dart';
import 'package:app/models/service_history_entry.dart';
import 'package:app/screens/edit_service_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('preserves mileage-only tracking when editing and saving', (
    tester,
  ) async {
    final saved = await _save(tester, _mileageService);

    expect(saved.tracksMileage, isTrue);
    expect(saved.tracksTime, isFalse);
    expect(saved.serviceOdometer, 74850);
    expect(saved.intervalKm, 10000);
    expect(saved.installDate, isNull);
    expect(saved.shelfLifeMonths, isNull);
  });

  testWidgets('preserves time-only tracking without mileage requirements', (
    tester,
  ) async {
    final saved = await _save(tester, _timeService);

    expect(saved.tracksMileage, isFalse);
    expect(saved.tracksTime, isTrue);
    expect(saved.serviceOdometer, isNull);
    expect(saved.intervalKm, isNull);
    expect(saved.installDate, _timeService.installDate);
    expect(saved.shelfLifeMonths, 36);
    expect(find.byKey(const Key('service-install-km-field')), findsNothing);
    expect(find.byKey(const Key('service-interval-field')), findsNothing);
  });

  testWidgets('preserves combined mileage-and-time tracking when saving', (
    tester,
  ) async {
    final saved = await _save(tester, _combinedService);

    expect(saved.tracksMileage, isTrue);
    expect(saved.tracksTime, isTrue);
    expect(saved.serviceOdometer, 74850);
    expect(saved.intervalKm, 10000);
    expect(saved.installDate, _combinedService.installDate);
    expect(saved.shelfLifeMonths, 12);
  });

  testWidgets('completes a time-only service without requesting mileage', (
    tester,
  ) async {
    ServiceCompletionResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await Navigator.of(context).push<ServiceCompletionResult>(
                MaterialPageRoute(
                  builder: (_) => EditServiceScreen(
                    service: _timeService,
                    currentOdometer: 80000,
                    openCompletionOnLaunch: true,
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.updatedService.serviceOdometer, isNull);
    expect(result!.updatedService.intervalKm, isNull);
    expect(result!.updatedService.installDate, isNotNull);
    expect(result!.historyEntry.completedOdometer, isNull);
    expect(result!.historyEntry.previousServiceOdometer, isNull);
    expect(result!.historyEntry.newIntervalKm, isNull);
  });

  test('history events preserve their completion snapshot after schedules change', () {
    final history = ServiceHistoryEntry(
      id: 'battery-1',
      serviceId: _timeService.id,
      serviceName: _timeService.name,
      newNote: _timeService.note,
      completedAt: DateTime(2026, 10, 11),
    );
    final changedSchedule = _timeService.copyWith(
      name: 'Replacement battery',
      note: 'Changed configuration',
      shelfLifeMonths: 24,
    );

    expect(history.serviceName, 'Time service');
    expect(history.newNote, 'Note');
    expect(changedSchedule.name, 'Replacement battery');
    expect(changedSchedule.shelfLifeMonths, 24);
  });
}

Future<ServiceItem> _save(WidgetTester tester, ServiceItem service) async {
  ServiceItem? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => FilledButton(
          onPressed: () async {
            result = await Navigator.of(context).push<ServiceItem>(
              MaterialPageRoute(
                builder: (_) => EditServiceScreen(
                  service: service,
                  currentOdometer: 80000,
                ),
              ),
            );
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  final saveButton = find.byKey(
    const Key('save-service-button'),
    skipOffstage: false,
  );
  await tester.drag(find.byType(ListView).first, const Offset(0, -500));
  await tester.pumpAndSettle();
  await tester.tap(saveButton);
  await tester.pumpAndSettle();
  return result!;
}

const _mileageService = ServiceItem(
  id: 'mileage',
  name: 'Mileage service',
  note: 'Note',
  serviceOdometer: 74850,
  intervalKm: 10000,
  iconKey: 'maintenance',
);

final _timeService = ServiceItem(
  id: 'time',
  name: 'Time service',
  note: 'Note',
  iconKey: 'battery',
  installDate: DateTime(2026, 1, 15),
  shelfLifeMonths: 36,
);

final _combinedService = ServiceItem(
  id: 'combined',
  name: 'Combined service',
  note: 'Note',
  serviceOdometer: 74850,
  intervalKm: 10000,
  iconKey: 'battery',
  installDate: DateTime(2026, 1, 15),
  shelfLifeMonths: 12,
);
