import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_tokens.dart';

// Note: Announces and displays the current odometer before service editing.
class CurrentOdometerLabel extends StatelessWidget {
  const CurrentOdometerLabel({super.key, required this.odometer});

  final int odometer;

  @override
  Widget build(BuildContext context) {
    final distance = MaterialLocalizations.of(context).formatDecimal(odometer);
    final label = AppLocalizations.of(context).currentOdometer(distance);
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Text(
          label,
          style: AppTokens.bodyStyle.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
