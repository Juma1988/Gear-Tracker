import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'widgets/dev_overlay.dart';

void main() => runApp(const RestartWidget(child: GearTrackerApp()));

final bool isDebug = true;

class RestartWidget extends StatefulWidget {
  const RestartWidget({super.key, required this.child});

  final Widget child;

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()?.restart();
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key _key = UniqueKey();

  void restart() => setState(() => _key = UniqueKey());

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}

class GearTrackerApp extends StatelessWidget {
  const GearTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFF0B1326);
    return MaterialApp(
      title: 'Gear Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: surface,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4EDEA3),
          brightness: Brightness.dark,
          surface: surface,
        ),
        useMaterial3: true,
      ),
      home: const DevOverlay(child: DashboardScreen()),
    );
  }
}
