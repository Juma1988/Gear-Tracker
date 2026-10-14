import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// One command exposed by a [CardActionMenu].
class CardActionMenuAction {
  const CardActionMenuAction({
    required this.value,
    required this.icon,
    required this.label,
    required this.onSelected,
    this.isDestructive = false,
  });

  /// Stable identifier used to route [CardActionMenu.onSelected] callbacks.
  final String value;
  final IconData icon;
  final String label;
  final VoidCallback onSelected;
  final bool isDestructive;
}

/// A visible overflow menu for a card.
///
/// Cards previously exposed editing and removal only through long-press. This
/// surfaces the same actions behind a discoverable, screen-reader reachable
/// button while keeping the tap target at the shared minimum size.
class CardActionMenu extends StatelessWidget {
  const CardActionMenu({
    super.key,
    required this.tooltip,
    required this.actions,
    this.borderRadius,
  });

  final String tooltip;
  final List<CardActionMenuAction> actions;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: tooltip,
      borderRadius: borderRadius,
      onSelected: (value) {
        for (final action in actions) {
          if (action.value == value) {
            action.onSelected();
            return;
          }
        }
      },
      itemBuilder: (context) => [
        for (final action in actions)
          PopupMenuItem<String>(
            value: action.value,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  action.icon,
                  size: AppTokens.serviceIconGlyphSize,
                  color: action.isDestructive
                      ? colors.error
                      : colors.onSurfaceVariant,
                ),
                const SizedBox(width: AppTokens.spaceMd),
                Text(
                  action.label,
                  style: action.isDestructive
                      ? TextStyle(color: colors.error)
                      : null,
                ),
              ],
            ),
          ),
      ],
      child: SizedBox(
        width: AppTokens.tapTargetSize,
        height: AppTokens.tapTargetSize,
        child: Center(
          child: Icon(
            Icons.more_vert,
            size: AppTokens.serviceIconGlyphSize,
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
