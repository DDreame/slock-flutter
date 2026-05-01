import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';

void main() {
  group('AppTheme.light', () {
    late ThemeData theme;

    setUpAll(() {
      theme = AppTheme.light;
    });

    test('builds without exception', () {
      expect(theme, isNotNull);
    });

    test('has light brightness', () {
      expect(theme.brightness, Brightness.light);
    });

    test('registers AppColors extension', () {
      final colors = theme.extension<AppColors>();
      expect(colors, isNotNull);
      expect(colors!.primary, AppColors.light.primary);
    });

    test('scaffold background matches token', () {
      expect(
        theme.scaffoldBackgroundColor,
        AppColors.light.background,
      );
    });

    test('colorScheme.error matches token', () {
      expect(
        theme.colorScheme.error,
        AppColors.light.error,
      );
    });

    test('colorScheme.errorContainer matches token', () {
      expect(
        theme.colorScheme.errorContainer,
        AppColors.light.errorContainer,
      );
    });

    test('colorScheme.onErrorContainer matches token', () {
      expect(
        theme.colorScheme.onErrorContainer,
        AppColors.light.onErrorContainer,
      );
    });

    test('colorScheme.primaryContainer matches primaryLight', () {
      expect(
        theme.colorScheme.primaryContainer,
        AppColors.light.primaryLight,
      );
    });

    test('colorScheme.secondary matches agentAccent', () {
      expect(
        theme.colorScheme.secondary,
        AppColors.light.agentAccent,
      );
    });

    test('AppBar elevation is zero', () {
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
    });

    test('Card elevation is zero with transparent shadow', () {
      expect(theme.cardTheme.elevation, 0);
      expect(theme.cardTheme.shadowColor, Colors.transparent);
    });

    test('Dialog elevation is zero', () {
      expect(theme.dialogTheme.elevation, 0);
    });

    test('BottomSheet elevation is zero', () {
      expect(theme.bottomSheetTheme.elevation, 0);
    });

    test('FAB elevation is zero', () {
      expect(
        theme.floatingActionButtonTheme.elevation,
        0,
      );
    });

    test('ColorScheme shadow is transparent', () {
      expect(theme.colorScheme.shadow, Colors.transparent);
    });

    test('SnackBar elevation is zero', () {
      expect(theme.snackBarTheme.elevation, 0);
    });

    test('NavigationBar elevation is zero', () {
      expect(theme.navigationBarTheme.elevation, 0);
    });
  });

  group('AppTheme.dark', () {
    late ThemeData theme;

    setUpAll(() {
      theme = AppTheme.dark;
    });

    test('builds without exception', () {
      expect(theme, isNotNull);
    });

    test('has dark brightness', () {
      expect(theme.brightness, Brightness.dark);
    });

    test('registers AppColors extension', () {
      final colors = theme.extension<AppColors>();
      expect(colors, isNotNull);
      expect(colors!.primary, AppColors.dark.primary);
    });

    test('scaffold background matches token', () {
      expect(
        theme.scaffoldBackgroundColor,
        AppColors.dark.background,
      );
    });

    test('colorScheme.error matches token', () {
      expect(
        theme.colorScheme.error,
        AppColors.dark.error,
      );
    });

    test('colorScheme.errorContainer matches token', () {
      expect(
        theme.colorScheme.errorContainer,
        AppColors.dark.errorContainer,
      );
    });

    test('colorScheme.onErrorContainer matches token', () {
      expect(
        theme.colorScheme.onErrorContainer,
        AppColors.dark.onErrorContainer,
      );
    });

    test('colorScheme.primaryContainer matches primaryLight', () {
      expect(
        theme.colorScheme.primaryContainer,
        AppColors.dark.primaryLight,
      );
    });

    test('colorScheme.secondary matches agentAccent', () {
      expect(
        theme.colorScheme.secondary,
        AppColors.dark.agentAccent,
      );
    });

    test('AppBar elevation is zero', () {
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
    });

    test('Card elevation is zero with transparent shadow', () {
      expect(theme.cardTheme.elevation, 0);
      expect(theme.cardTheme.shadowColor, Colors.transparent);
    });

    test('Dialog elevation is zero', () {
      expect(theme.dialogTheme.elevation, 0);
    });

    test('ColorScheme shadow is transparent', () {
      expect(theme.colorScheme.shadow, Colors.transparent);
    });
  });
}
