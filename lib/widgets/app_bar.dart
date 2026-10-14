import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/maintenance_health.dart';
import '../theme/app_tokens.dart';
import 'brand_mark.dart';

class AppBar extends StatefulWidget {
  const AppBar({
    super.key,
    this.vehicleName = '2022 Golf GTI',
    required this.onSettings,
    required this.onVehicle,
    this.onAdd,
    this.status = ServiceStatus.excellent,
  });

  final String vehicleName;
  final VoidCallback onSettings;
  final VoidCallback onVehicle;
  final VoidCallback? onAdd;
  final ServiceStatus status;

  @override
  State<AppBar> createState() => _AppBarState();
}

class _AppBarState extends State<AppBar> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: .45),
            blurRadius: 8,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
            const BrandMark(size: AppTokens.headerMarkSize),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'GEAR TRACKER',
                        style: AppTokens.wordmarkStyle,
                      ),
                    ],
                  ),
                  Semantics(
                    button: true,
                    label: l10n.selectVehicle,
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: widget.onVehicle,
                      child: Wrap(
                        alignment: WrapAlignment.start,
                        children: [
                          Text(
                            widget.vehicleName.toUpperCase(),
                            style: AppTokens.labelStyle.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: AppTokens.fontWeightSemiBold,
                              letterSpacing: AppTokens.letterSpacingWide,
                            ),
                          ),
                          Icon(
                            Icons.unfold_more,
                            size: 15,
                            color: colors.outline,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _HeaderAction(
              onPressed: widget.onAdd,
              tooltip: l10n.addService,
              icon: Icons.add,
              emphasized: true,
            ),
            const SizedBox(width: 4),
            _HeaderAction(
              onPressed: widget.onSettings,
              tooltip: l10n.settingsTitle,
              icon: Icons.settings_outlined,
            ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.onPressed,
    required this.tooltip,
    required this.icon,
    this.emphasized = false,
  });

  final VoidCallback? onPressed;
  final String tooltip;
  final IconData icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: tooltip,
      child: Semantics(
        container: true,
        child: SizedBox(
          width: AppTokens.tapTargetSize,
          height: AppTokens.tapTargetSize,
          child: IconButton(
            onPressed: onPressed,
            tooltip: tooltip,
            style: emphasized
                ? IconButton.styleFrom(
                    backgroundColor: colors.surfaceContainerHigh,
                  )
                : null,
            icon: Icon(icon, color: colors.onSurface),
          ),
        ),
      ),
    );
  }
}
