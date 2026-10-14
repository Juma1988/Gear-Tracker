import 'package:flutter/material.dart';

import 'app_tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData classic() => _build(
    surface: const Color(0xFF0B1326),
    surfaceContainer: const Color(0xFF131B2E),
    surfaceLowest: const Color(0xFF060E20),
    primary: const Color(0xFF4EDEA3),
  );

  static ThemeData telemetry() => _build(
    surface: const Color(0xFF171D29),
    surfaceContainer: const Color(0xFF222A38),
    surfaceLowest: const Color(0xFF111722),
    primary: const Color(0xFF00E5FF),
  );

  static ThemeData _build({
    required Color surface,
    required Color surfaceContainer,
    required Color surfaceLowest,
    required Color primary,
  }) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.dark,
          surface: surface,
        ).copyWith(
          primary: primary,
          surface: surface,
          surfaceContainer: surfaceContainer,
          surfaceContainerHighest: const Color(0xFF131B2E),
          surfaceContainerLowest: surfaceLowest,
          onSurface: const Color(0xFFDFE2EE),
          onSurfaceVariant: const Color(0xFFBAC9CC),
          outline: const Color(0xFF849396),
          tertiary: const Color(0xFFFFB95F),
          error: const Color(0xFFFFB4AB),
        );
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      useMaterial3: true,
      cardTheme: CardThemeData(
        color: surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusInput),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
      ),
    );
  }
}
