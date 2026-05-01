import 'package:flutter/material.dart';

/// Design-system typography tokens for the Slock app.
///
/// Uses the system default font stack (which closely matches Inter
/// metrics on both iOS and Android M3). Text styles are defined
/// relative to the Material 3 type scale but with tighter line
/// heights matching Z3's compact layout philosophy.
abstract final class AppTypography {
  /// Base font family — null uses platform default (San Francisco /
  /// Roboto), which match Inter metrics.
  static const String? fontFamily = null;

  /// Display Large — Hero / splash text.
  static const displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
  );

  /// Display Medium — Page titles.
  static const displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    height: 1.25,
  );

  /// Headline — Section headers, dialog titles.
  static const headline = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// Title — Card titles, list headers.
  static const title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  /// Body — Default paragraph / message text.
  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Body Small — Secondary descriptive text.
  static const bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// Label — Buttons, badges, chips.
  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.35,
  );

  /// Caption — Timestamps, footnotes.
  static const caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.3,
  );

  /// Returns a complete [TextTheme] built from design tokens,
  /// colored with [textColor].
  static TextTheme textTheme(Color textColor) {
    return TextTheme(
      displayLarge: displayLarge.copyWith(color: textColor),
      displayMedium: displayMedium.copyWith(color: textColor),
      headlineMedium: headline.copyWith(color: textColor),
      titleLarge: headline.copyWith(color: textColor),
      titleMedium: title.copyWith(color: textColor),
      titleSmall: title.copyWith(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: body.copyWith(color: textColor, fontSize: 15),
      bodyMedium: body.copyWith(color: textColor),
      bodySmall: bodySmall.copyWith(color: textColor),
      labelLarge: label.copyWith(color: textColor, fontSize: 14),
      labelMedium: label.copyWith(color: textColor),
      labelSmall: caption.copyWith(color: textColor),
    );
  }
}
