import 'package:flutter/material.dart';

enum AppStatusTone { neutral, info, success, warning, error }

@immutable
class AppStatusColors {
  const AppStatusColors({
    required this.foreground,
    required this.container,
    required this.onContainer,
  });

  final Color foreground;
  final Color container;
  final Color onContainer;
}

AppStatusColors appStatusColors(ColorScheme scheme, AppStatusTone tone) {
  return switch (tone) {
    AppStatusTone.neutral => AppStatusColors(
        foreground: scheme.outline,
        container: scheme.surfaceContainerHighest,
        onContainer: scheme.onSurfaceVariant,
      ),
    AppStatusTone.info => AppStatusColors(
        foreground: scheme.primary,
        container: scheme.primaryContainer,
        onContainer: scheme.onPrimaryContainer,
      ),
    AppStatusTone.success => AppStatusColors(
        foreground: scheme.secondary,
        container: scheme.secondaryContainer,
        onContainer: scheme.onSecondaryContainer,
      ),
    AppStatusTone.warning => AppStatusColors(
        foreground: scheme.tertiary,
        container: scheme.tertiaryContainer,
        onContainer: scheme.onTertiaryContainer,
      ),
    AppStatusTone.error => AppStatusColors(
        foreground: scheme.error,
        container: scheme.errorContainer,
        onContainer: scheme.onErrorContainer,
      ),
  };
}

ButtonStyle appDestructiveFilledButtonStyle(ColorScheme scheme) {
  return FilledButton.styleFrom(
    backgroundColor: scheme.errorContainer,
    foregroundColor: scheme.onErrorContainer,
  );
}
