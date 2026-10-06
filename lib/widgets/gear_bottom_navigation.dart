import 'package:flutter/material.dart';

import '../models/app_navigation_destination.dart';

class GearBottomNavigation extends StatelessWidget {
  const GearBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _surfaceLowest = Color(0xFF060E20);
  static const _muted = Color(0xFFBBCABF);
  static const _primary = Color(0xFF4EDEA3);
  static const _destinations = [
    AppNavigationDestination(icon: Icons.speed, label: 'Dashboard'),
    AppNavigationDestination(icon: Icons.history, label: 'History'),
    AppNavigationDestination(icon: Icons.build, label: 'Services'),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      height: 68,
      color: _surfaceLowest,
      child: Row(
        children: [
          for (var index = 0; index < _destinations.length; index++)
            _NavigationButton(
              destination: _destinations[index],
              selected: selectedIndex == index,
              onTap: () => onDestinationSelected(index),
            ),
        ],
      ),
    ),
  );
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppNavigationDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? GearBottomNavigation._primary
        : GearBottomNavigation._muted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(destination.icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(
              destination.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
