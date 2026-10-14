import 'package:flutter/material.dart';

/// The single GearTracker brand mark used inside the app.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .2),
        child: Image.asset(
          'tool/icon_master.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
