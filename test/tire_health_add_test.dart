import 'package:app/screens/add_service_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'tapping Tire health returns TireHealthAdded without opening a form',
    (tester) async {
      Object? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  key: const Key('open-add-service'),
                  onPressed: () async {
                    result = await Navigator.of(context).push<Object>(
                      MaterialPageRoute(
                        builder: (_) =>
                            const AddServiceScreen(currentOdometer: 1000),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open-add-service')));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(find.text('Tire health'), findsOneWidget);
      expect(
        find.byKey(const Key('add-service-name-field')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('tire-health-service-card')));
      await tester.pumpAndSettle();

      expect(result, isA<TireHealthAdded>());
      expect(find.byKey(const Key('add-service-name-field')), findsNothing);
    },
  );
}
