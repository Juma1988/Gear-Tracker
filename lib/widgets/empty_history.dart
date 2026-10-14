import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_tokens.dart';

// Note: Presents the accessible empty state when no service history exists.
class EmptyHistory extends StatelessWidget {
  const EmptyHistory({
    super.key,
    required this.title,
    this.serviceName,
  });

  final String title;
  final String? serviceName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceXxl),
          child: Semantics(
            header: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history, size: 48, color: colors.primary),
                const SizedBox(height: 16),
                Text(
                  l10n.noServiceHistoryYet,
                  style: AppTokens.screenTitleStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  serviceName == null
                      ? l10n.completedServiceUpdatesWillAppear
                      : l10n.completedServiceUpdatesWillAppearFor(serviceName!),
                  style: TextStyle(color: colors.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
