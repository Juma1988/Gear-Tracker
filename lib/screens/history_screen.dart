import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/service_history_entry.dart';
import '../widgets/empty_history.dart';
import '../widgets/history_entry_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.history,
    this.serviceId,
    this.serviceName,
  });

  final List<ServiceHistoryEntry> history;
  final String? serviceId;
  final String? serviceName;

  @override
  Widget build(BuildContext context) {
    final entries =
        history
            .where((entry) => serviceId == null || entry.serviceId == serviceId)
            .toList()
          ..sort(
            (a, b) => b.completedAt.compareTo(a.completedAt),
          );
    final l10n = AppLocalizations.of(context);
    final title = serviceName == null
        ? l10n.serviceHistory
        : l10n.historyTitle(serviceName!);
    if (entries.isEmpty) {
      return EmptyHistory(title: title, serviceName: serviceName);
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            HistoryEntryCard(entry: entries[index]),
      ),
    );
  }
}
