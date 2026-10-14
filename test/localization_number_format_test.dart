import 'package:app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _l10n = AppLocalizations(Locale('en'));
const _numbers = DefaultMaterialLocalizations();

/// Locks the F21 contract: user-facing numeric copy receives numbers already
/// formatted by [MaterialLocalizations], so large values group correctly.
void main() {
  test('groups kilometer ranges in completion range copy', () {
    expect(
      _l10n.enterCompletionKmRange(
        _numbers.formatDecimal(74850),
        _numbers.formatDecimal(76000),
      ),
      'Enter a km from 74,850 to 76,000.',
    );
    expect(
      _l10n.completionKmHelperText(
        _numbers.formatDecimal(74850),
        _numbers.formatDecimal(76000),
      ),
      'Must be 74,850–76,000 km.',
    );
  });

  test('groups large day counts in shelf-life copy', () {
    expect(_l10n.checkIn(_numbers.formatDecimal(1095)), 'Check in 1,095 days');
    expect(
      _l10n.checkOverdueBy(_numbers.formatDecimal(42)),
      'Check overdue by 42 days',
    );
  });

  test('groups the odometer validation bound', () {
    expect(
      _l10n.enterOdometerRange(
        _numbers.formatDecimal(0),
        _numbers.formatDecimal(999999),
      ),
      'Enter a value between 0 and 999,999',
    );
  });
}
