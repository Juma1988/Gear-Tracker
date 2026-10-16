import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/brand_mark.dart';

/// Brief animated handoff between the native launch window and the Dashboard.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.child});

  final Widget child;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _displayDuration = Duration(milliseconds: 900);
  static const _rotationDuration = Duration(milliseconds: 1600);

  late final AnimationController _rotationController;
  Timer? _displayTimer;
  bool _showChild = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: _rotationDuration,
    )..repeat();
    _displayTimer = Timer(_displayDuration, () {
      if (!mounted) return;
      _rotationController.stop();
      setState(() => _showChild = true);
    });
  }

  @override
  void dispose() {
    _displayTimer?.cancel();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showChild) return widget.child;

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final gear = BrandMark(size: 96);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF080E20),
        body: Center(
          child: Semantics(
            label: 'Loading GearTracker',
            liveRegion: true,
            child: reduceMotion
                ? gear
                : AnimatedBuilder(
                    key: const Key('splash-gear-rotation'),
                    animation: _rotationController,
                    child: gear,
                    builder: (context, child) => Transform.rotate(
                      angle: _rotationController.value * math.pi * 2,
                      child: child,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
