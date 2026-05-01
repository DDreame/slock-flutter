import 'package:flutter/material.dart';

/// Design-system color tokens for the Slock app.
///
/// Registered as a [ThemeExtension] so widgets can access tokens via
/// `Theme.of(context).extension<AppColors>()!`.
///
/// All values come from the Z3 design spec (Phase 1).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.primary,
    required this.primaryForeground,
    required this.text,
    required this.textSecondary,
    required this.border,
  });

  /// Light-mode token set.
  static const light = AppColors(
    background: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF5F5F5),
    primary: Color(0xFF6366F1),
    primaryForeground: Color(0xFFFFFFFF),
    text: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF737373),
    border: Color(0xFFF0F0F0),
  );

  /// Dark-mode token set.
  static const dark = AppColors(
    background: Color(0xFF0A0A0A),
    surface: Color(0xFF141414),
    surfaceAlt: Color(0xFF1C1C1C),
    primary: Color(0xFF818CF8),
    primaryForeground: Color(0xFF1A1A1A),
    text: Color(0xFFF0F0F0),
    textSecondary: Color(0xFFA3A3A3),
    border: Color(0xFF262626),
  );

  /// Main page/scaffold background.
  final Color background;

  /// Card / elevated surface background.
  final Color surface;

  /// Alternative surface (e.g. input fields, list separators).
  final Color surfaceAlt;

  /// Primary accent (buttons, links, active states).
  final Color primary;

  /// Text color on primary backgrounds.
  final Color primaryForeground;

  /// Default text color.
  final Color text;

  /// Secondary / muted text color.
  final Color textSecondary;

  /// Subtle border / divider color.
  final Color border;

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? primary,
    Color? primaryForeground,
    Color? text,
    Color? textSecondary,
    Color? border,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      primary: primary ?? this.primary,
      primaryForeground: primaryForeground ?? this.primaryForeground,
      text: text ?? this.text,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryForeground:
          Color.lerp(primaryForeground, other.primaryForeground, t)!,
      text: Color.lerp(text, other.text, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}
