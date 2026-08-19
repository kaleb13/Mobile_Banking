import 'package:flutter/material.dart';

/// Centralized typographic scale for the Mobile Banking application.
/// Uses the globally configured Inter font family.
class AppTypography {
  const AppTypography._();

  static const String fontFamily = 'Inter';

  /// Display Large — 28px Bold (-0.5 tracking) for large hero numbers & balances
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );

  /// Heading 1 — 22px Bold (-0.5 tracking) for main screen titles & page headers
  static const TextStyle heading1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  /// Heading 2 — 18px Bold (-0.3 tracking) for section headers & card titles
  static const TextStyle heading2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  /// Title Large — 16px SemiBold (-0.2 tracking) for sub-headers & list titles
  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  /// Title Medium — 15px SemiBold for compact card titles & modal actions
  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  /// Title Small — 13px SemiBold for pills, compact tabs & tags
  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  /// Body Large — 15px Medium for primary body text & input fields
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );

  /// Body Medium — 14px Medium for descriptions & table rows
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  /// Body Small — 12px Regular for hints, secondary metadata & timestamps
  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  /// Caption — 11px Medium (+0.2 tracking) for badges, pill tags & small labels
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  /// Button — 15px Bold for primary & secondary button labels
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );

  /// Currency Large — 24px ExtraBold for center donut charts & total cards
  static const TextStyle currencyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );
}
