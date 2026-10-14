import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/service_item.dart';

class TrackingModeSelector extends StatelessWidget {
  const TrackingModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
    required this.mileageComplete,
    required this.timeComplete,
  });

  final ServiceTrackingMode value;
  final ValueChanged<ServiceTrackingMode> onChanged;
  final bool mileageComplete;
  final bool timeComplete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      label: l10n.trackServiceBy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.trackServiceBy,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ServiceTrackingMode>(
              segments: [
                ButtonSegment<ServiceTrackingMode>(
                  value: ServiceTrackingMode.mileage,
                  label: _label(
                    l10n.trackingModeMileage,
                    complete: mileageComplete,
                    colorScheme: Theme.of(context).colorScheme,
                  ),
                ),
                ButtonSegment<ServiceTrackingMode>(
                  value: ServiceTrackingMode.time,
                  label: _label(
                    l10n.trackingModeTime,
                    complete: timeComplete,
                    colorScheme: Theme.of(context).colorScheme,
                  ),
                ),
                ButtonSegment<ServiceTrackingMode>(
                  value: ServiceTrackingMode.mileageAndTime,
                  label: _label(
                    l10n.trackingModeBoth,
                    complete: mileageComplete && timeComplete,
                    colorScheme: Theme.of(context).colorScheme,
                  ),
                ),
              ],
              selected: {value},
              onSelectionChanged: (selection) => onChanged(selection.first),
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 8),
                ),
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(
    String text, {
    required bool complete,
    required ColorScheme colorScheme,
  }) => Text.rich(
    TextSpan(
      text: text,
      style: TextStyle(
        color: complete ? colorScheme.primary : colorScheme.onSurface,
        fontWeight: complete ? FontWeight.w700 : FontWeight.normal,
      ),
    ),
  );
}
