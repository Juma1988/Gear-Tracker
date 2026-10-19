import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_tokens.dart';

/// Static, center-notched navigation matching the app's selected bottom-bar
/// direction. The center add action is a separate FAB in the host Scaffold.
class StaticNotchBottomBar extends StatelessWidget {
  const StaticNotchBottomBar({
    super.key,
    required this.historySelected,
    required this.servicesSelected,
    required this.onHome,
    required this.onHistory,
    required this.fuelSelected,
    required this.onFuel,
    required this.onServices,
  });

  final bool historySelected;
  final bool servicesSelected;
  final VoidCallback onHome;
  final VoidCallback onHistory;
  final bool fuelSelected;
  final VoidCallback onFuel;
  final VoidCallback onServices;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return BottomAppBar(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: colors.surfaceContainer,
      elevation: 8,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _NavigationItem(
                    key: const Key('bottom-nav-home'),
                    label: l10n.dashboardTab,
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home_filled,
                    selected:
                        !historySelected && !fuelSelected && !servicesSelected,
                    onTap: onHome,
                  ),
                ),
                Expanded(
                  child: _NavigationItem(
                    key: const Key('bottom-nav-fuel'),
                    label: l10n.fuelTab,
                    icon: Icons.local_gas_station_outlined,
                    selectedIcon: Icons.local_gas_station,
                    selected: fuelSelected,
                    onTap: onFuel,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 72),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _NavigationItem(
                    key: const Key('bottom-nav-services'),
                    label: l10n.servicesTab,
                    icon: Icons.build_outlined,
                    selectedIcon: Icons.build,
                    selected: servicesSelected,
                    onTap: onServices,
                  ),
                ),
                Expanded(
                  child: _NavigationItem(
                    key: const Key('bottom-nav-history'),
                    label: l10n.overallHistoryTab,
                    icon: Icons.history_outlined,
                    selectedIcon: Icons.history,
                    selected: historySelected,
                    onTap: onHistory,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    super.key,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = selected ? colors.primary : colors.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? selectedIcon : icon, size: 18, color: color),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
