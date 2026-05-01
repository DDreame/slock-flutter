import 'package:flutter/material.dart';

/// Design-system color tokens for the Slock app.
///
/// Registered as a [ThemeExtension] so widgets can access tokens via
/// `Theme.of(context).extension<AppColors>()!`.
///
/// All values come from the Z3/Z2 design spec (Phase 1).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.primary,
    required this.primaryLight,
    required this.primaryForeground,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.success,
    required this.warning,
    required this.error,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.agentAccent,
    required this.agentLight,
  });

  /// Light-mode token set.
  static const light = AppColors(
    background: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF5F5F5),
    primary: Color(0xFF6366F1),
    primaryLight: Color(0xFFEEF2FF),
    primaryForeground: Color(0xFFFFFFFF),
    text: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF6B7280),
    textTertiary: Color(0xFF9CA3AF),
    border: Color(0xFFF0F0F0),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFFB91C1C),
    agentAccent: Color(0xFF8B5CF6),
    agentLight: Color(0xFFF5F3FF),
  );

  /// Dark-mode token set.
  static const dark = AppColors(
    background: Color(0xFF0A0A0A),
    surface: Color(0xFF141414),
    surfaceAlt: Color(0xFF1C1C1C),
    primary: Color(0xFF818CF8),
    primaryLight: Color(0xFF1E1B4B),
    primaryForeground: Color(0xFF1A1A1A),
    text: Color(0xFFF0F0F0),
    textSecondary: Color(0xFF9CA3AF),
    textTertiary: Color(0xFF6B7280),
    border: Color(0xFF262626),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFF87171),
    errorContainer: Color(0xFF7F1D1D),
    onErrorContainer: Color(0xFFFCA5A5),
    agentAccent: Color(0xFFA78BFA),
    agentLight: Color(0xFF1E1533),
  );

  /// Main page/scaffold background.
  final Color background;

  /// Card / elevated surface background.
  final Color surface;

  /// Alternative surface (e.g. input fields, list separators).
  final Color surfaceAlt;

  /// Primary accent (buttons, links, active states).
  final Color primary;

  /// Lighter primary tint (selected row backgrounds, subtle highlights).
  final Color primaryLight;

  /// Text color on primary backgrounds.
  final Color primaryForeground;

  /// Default text color.
  final Color text;

  /// Secondary / muted text color.
  final Color textSecondary;

  /// Tertiary / placeholder text color.
  final Color textTertiary;

  /// Subtle border / divider color.
  final Color border;

  /// Success state color (online indicators, confirmations).
  final Color success;

  /// Warning state color (thinking indicators, caution).
  final Color warning;

  /// Error state color (error indicators, destructive actions).
  final Color error;

  /// Error container background (error banners, destructive dialogs).
  final Color errorContainer;

  /// Text color on error container backgrounds.
  final Color onErrorContainer;

  /// Agent accent color (agent badges, working indicators).
  final Color agentAccent;

  /// Agent light background (agent bubble tint, agent cards).
  final Color agentLight;

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? primary,
    Color? primaryLight,
    Color? primaryForeground,
    Color? text,
    Color? textSecondary,
    Color? textTertiary,
    Color? border,
    Color? success,
    Color? warning,
    Color? error,
    Color? errorContainer,
    Color? onErrorContainer,
    Color? agentAccent,
    Color? agentLight,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      primaryForeground: primaryForeground ?? this.primaryForeground,
      text: text ?? this.text,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      border: border ?? this.border,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      errorContainer: errorContainer ?? this.errorContainer,
      onErrorContainer: onErrorContainer ?? this.onErrorContainer,
      agentAccent: agentAccent ?? this.agentAccent,
      agentLight: agentLight ?? this.agentLight,
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
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryForeground:
          Color.lerp(primaryForeground, other.primaryForeground, t)!,
      text: Color.lerp(text, other.text, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
      onErrorContainer:
          Color.lerp(onErrorContainer, other.onErrorContainer, t)!,
      agentAccent: Color.lerp(agentAccent, other.agentAccent, t)!,
      agentLight: Color.lerp(agentLight, other.agentLight, t)!,
    );
  }
}
