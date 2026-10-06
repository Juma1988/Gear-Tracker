import 'package:flutter/material.dart';

import '../models/valuables.dart';

class AppBar extends StatelessWidget {
  const AppBar({super.key, required this.onSettings, required this.onVehicle});

  final VoidCallback onSettings;
  final VoidCallback onVehicle;

  @override
  Widget build(BuildContext context) => Container(
    height: 80,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: const BoxDecoration(
      color: surfaceLowest,
      boxShadow: [
        BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 1)),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.directions_car_filled,
            color: Color(0xFF003824),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'GEAR TRACKER',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: onVehicle,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '2022 Golf GTI',
                      style: TextStyle(
                        fontSize: 11,
                        color: muted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    Icon(Icons.unfold_more, size: 15, color: outline),
                  ],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onSettings,
          tooltip: 'Settings',
          style: IconButton.styleFrom(backgroundColor: surfaceHigh),
          icon: const Icon(Icons.add, color: onSurface),
        ),
      ],
    ),
  );
}
