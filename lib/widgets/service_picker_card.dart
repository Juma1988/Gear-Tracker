import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_tokens.dart';

// Note: Presents one selectable service type without using dashboard health-card semantics.
class ServicePickerCard extends StatelessWidget {
  const ServicePickerCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.trailing,
    this.compact = false,
    this.accentColor,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  /// Optional visible action (for example an overflow menu) rendered inside
  /// the card, outside the tap region and its merged semantics.
  final Widget? trailing;
  final bool compact;

  /// Optional accent for cards that need a distinct visual treatment.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent =
        accentColor ?? (isSelected ? colors.primary : colors.onSurfaceVariant);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      enabled: true,
      selected: isSelected,
      container: true,
      explicitChildNodes: true,
      label: isSelected ? l10n.selectedLabel(title) : title,
      hint: isSelected ? l10n.editServiceHint : l10n.openServiceDetailsHint,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            border: Border.all(
              color: accent.withValues(alpha: isSelected ? .7 : .35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: InkWell(
                    onTap: onTap,
                    onLongPress: onLongPress,
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                    focusColor: accent.withValues(alpha: .18),
                    hoverColor: accent.withValues(alpha: .08),
                    child: Padding(
                      padding: EdgeInsetsDirectional.symmetric(
                        horizontal: compact ? 8 : 12,
                        vertical: compact ? 8 : 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: compact
                                ? AppTokens.pickerIconBadgeSize - 6
                                : AppTokens.pickerIconBadgeSize,
                            height: compact
                                ? AppTokens.pickerIconBadgeSize - 6
                                : AppTokens.pickerIconBadgeSize,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusSm,
                              ),
                              border: Border.all(
                                color: accent.withValues(alpha: .3),
                              ),
                            ),
                            child: Icon(
                              icon,
                              color: accent,
                              size: compact
                                  ? AppTokens.pickerIconGlyphSize - 2
                                  : AppTokens.pickerIconGlyphSize,
                            ),
                          ),
                          SizedBox(width: compact ? 8 : 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: AppTokens.sectionTitleStyle),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle!,
                                    style: AppTokens.bodyStyle.copyWith(
                                      fontSize: 12,
                                      color: colors.onSurfaceVariant,
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle, color: colors.primary)
                          else if (trailing == null)
                            Icon(Icons.chevron_right, color: accent),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
