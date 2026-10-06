import 'package:flutter/material.dart';

class OdometerDigit extends StatelessWidget {
  const OdometerDigit({super.key, required this.digit, required this.active});

  final String digit;
  final bool active;

  static const _surfaceLowest = Color(0xFF060E20);
  static const _onSurface = Color(0xFFDAE2FD);
  static const _primary = Color(0xFF4EDEA3);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 5),
    width: 43,
    height: 64,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: _surfaceLowest,
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: const Color(0xFF3C4A42)),
    ),
    child: Text(
      digit,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: active ? _primary : _onSurface,
      ),
    ),
  );
}
