import 'package:flutter/material.dart';

/// Shared design tokens for GearTracker.
///
/// Values mirror the original inline layout constants so visual output is
/// unchanged; use these instead of repeating raw numbers in touched code.
abstract final class AppTokens {
  // Spacing scale.
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;
  static const double spaceXxl = 32;

  // Radius scale.
  static const double radiusXs = 2;
  static const double radiusChip = 3;
  static const double radiusPill = 4;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 24;
  static const double radiusInput = 10;

  // Motion.
  static const Duration savePulse = Duration(milliseconds: 600);

  // --- Typography scale ---

  // Font sizes.
  static const double fontSizeCaption = 10;
  static const double fontSizeLabel = 11;
  static const double fontSizeBody = 12;
  static const double fontSizeSubtitle = 14;
  static const double fontSizeTitle = 16;
  static const double fontSizeHeading = 18;
  static const double fontSizeScreenTitle = 20;
  static const double fontSizeDisplay = 36;

  // Font weights.
  static const FontWeight fontWeightRegular = FontWeight.w400;
  static const FontWeight fontWeightSemiBold = FontWeight.w600;
  static const FontWeight fontWeightBold = FontWeight.w700;

  // Letter spacing.
  static const double letterSpacingTight = -0.5;
  static const double letterSpacingCaps = 0.5;
  static const double letterSpacingWide = 1;

  // Reusable composite text styles.
  static const TextStyle captionStyle = TextStyle(fontSize: fontSizeCaption);
  static const TextStyle labelStyle = TextStyle(fontSize: fontSizeLabel);
  static const TextStyle bodyStyle = TextStyle(fontSize: fontSizeBody);
  static const TextStyle cardTitleStyle = TextStyle(
    fontSize: fontSizeSubtitle,
    fontWeight: fontWeightBold,
  );
  static const TextStyle sectionTitleStyle = TextStyle(
    fontSize: fontSizeTitle,
    fontWeight: fontWeightBold,
  );
  static const TextStyle headingStyle = TextStyle(
    fontSize: fontSizeHeading,
    fontWeight: fontWeightBold,
  );
  static const TextStyle screenTitleStyle = TextStyle(
    fontSize: fontSizeScreenTitle,
    fontWeight: fontWeightBold,
  );
  static const TextStyle displayStyle = TextStyle(
    fontSize: fontSizeDisplay,
    fontWeight: fontWeightBold,
  );
  static const TextStyle wordmarkStyle = TextStyle(
    fontSize: fontSizeScreenTitle,
    fontWeight: fontWeightBold,
    letterSpacing: letterSpacingTight,
  );

  // --- Component tokens ---

  // Status pill / chip.
  static const double pillIconSize = 12;

  // Progress indicators.
  static const double progressBarHeight = 6;
  static const double progressBarThinHeight = 4;

  // Icon badges.
  static const double serviceIconBadgeSize = 32;
  static const double serviceIconGlyphSize = 18;
  static const double pickerIconBadgeSize = 40;
  static const double pickerIconGlyphSize = 22;
  static const double healthCardHeight = 125;

  // Header.
  static const double headerMarkSize = 36;
  static const double headerDotSize = 12;
  static const double headerDotInnerSize = 6;

  // Shared interactive sizing.
  static const double tapTargetSize = 48;

  // Odometer.
  static const double odometerWheelHeight = 64;
}
