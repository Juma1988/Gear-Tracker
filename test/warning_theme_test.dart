import 'package:app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (name, theme) in [
    ('classic', AppTheme.classic()),
    ('telemetry', AppTheme.telemetry()),
  ]) {
    test(
      '$name warning colors are yellow amber and readable at both fills',
      () {
        final colors = theme.colorScheme;
        for (final color in [
          colors.tertiary,
          colors.tertiaryContainer,
          colors.onTertiaryContainer,
        ]) {
          final hsl = HSLColor.fromColor(color);
          expect(hsl.hue, inInclusiveRange(40, 60));
          expect(hsl.saturation, greaterThan(0.5));
        }
        for (final opacity in [0.1, 0.4]) {
          final surface = Color.alphaBlend(
            colors.tertiaryContainer.withValues(alpha: opacity),
            theme.scaffoldBackgroundColor,
          );
          final contrast =
              (colors.onTertiaryContainer.computeLuminance() + 0.05) /
              (surface.computeLuminance() + 0.05);
          expect(contrast, greaterThanOrEqualTo(4.5));
        }
      },
    );
  }
}
