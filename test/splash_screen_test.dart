import 'package:app/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the animated splash before the app content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SplashScreen(child: Text('Dashboard'))),
    );

    expect(find.byKey(const Key('splash-gear-rotation')), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);

    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('does not rotate when reduced motion is enabled', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: SplashScreen(child: Text('Dashboard'))),
      ),
    );

    expect(find.byKey(const Key('splash-gear-rotation')), findsNothing);
    expect(find.text('Dashboard'), findsNothing);
  });
}
