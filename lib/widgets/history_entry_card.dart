import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/service_history_entry.dart';
import '../theme/app_tokens.dart';

// Note: Displays one completed service record in the history list.
class HistoryEntryCard extends StatelessWidget {
  const HistoryEntryCard({super.key, required this.entry});

  final ServiceHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final completedOdometer = entry.completedOdometer == null
        ? null
        : localizations.formatDecimal(entry.completedOdometer!);
    final interval = entry.newIntervalKm == null
        ? null
        : localizations.formatDecimal(entry.newIntervalKm!);
    final date = localizations.formatMediumDate(entry.completedAt);
    final note = entry.newNote.trim();
    return Semantics(
      container: true,
      label:
          '${entry.serviceName}${completedOdometer == null ? '' : ', ${l10n.completedAtValue(completedOdometer)}'} ${l10n.onDate(date)}${interval == null ? '' : ', ${l10n.nextIntervalValue(interval)}'}${note.isEmpty ? '' : ', ${l10n.historyNote(note)}'}',
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: colors.outline.withValues(alpha: .35)),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 132,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: AppTokens.serviceIconBadgeSize,
                        height: AppTokens.serviceIconBadgeSize,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: .14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.history,
                          color: colors.primary,
                          size: AppTokens.serviceIconGlyphSize,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entry.serviceName,
                          style: AppTokens.cardTitleStyle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.completedOnDate(date),
                    style: AppTokens.headingStyle,
                  ),
                  if (completedOdometer != null || interval != null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (completedOdometer != null)
                          _HistoryMetric(
                            text: l10n.completedAtKm(completedOdometer),
                          ),
                        if (interval != null)
                          _HistoryMetric(
                            text: l10n.nextIntervalLine(interval),
                            color: colors.primary,
                          ),
                      ],
                    ),
                  ],
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                      ),
                      child: Text(
                        l10n.historyNote(note),
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryMetric extends StatelessWidget {
  const _HistoryMetric({required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: (color ?? Theme.of(context).colorScheme.onSurfaceVariant)
          .withValues(alpha: .1),
      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: AppTokens.fontSizeBody,
        fontWeight: AppTokens.fontWeightSemiBold,
      ),
    ),
  );
}
