import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';

void main() {
  group('AppColors light tokens match Z3 spec', () {
    test('background is #FAFAFA', () {
      expect(AppColors.light.background, const Color(0xFFFAFAFA));
    });

    test('surface is #FFFFFF', () {
      expect(AppColors.light.surface, const Color(0xFFFFFFFF));
    });

    test('surfaceAlt is #F5F5F5', () {
      expect(AppColors.light.surfaceAlt, const Color(0xFFF5F5F5));
    });

    test('primary is #6366F1', () {
      expect(AppColors.light.primary, const Color(0xFF6366F1));
    });

    test('primaryLight is #EEF2FF', () {
      expect(AppColors.light.primaryLight, const Color(0xFFEEF2FF));
    });

    test('primaryForeground is white', () {
      expect(
        AppColors.light.primaryForeground,
        const Color(0xFFFFFFFF),
      );
    });

    test('text is #1A1A1A', () {
      expect(AppColors.light.text, const Color(0xFF1A1A1A));
    });

    test('textSecondary is #6B7280', () {
      expect(
        AppColors.light.textSecondary,
        const Color(0xFF6B7280),
      );
    });

    test('textTertiary is #9CA3AF', () {
      expect(
        AppColors.light.textTertiary,
        const Color(0xFF9CA3AF),
      );
    });

    test('border is #F0F0F0', () {
      expect(AppColors.light.border, const Color(0xFFF0F0F0));
    });

    test('success is #22C55E', () {
      expect(AppColors.light.success, const Color(0xFF22C55E));
    });

    test('warning is #F59E0B', () {
      expect(AppColors.light.warning, const Color(0xFFF59E0B));
    });

    test('error is #EF4444', () {
      expect(AppColors.light.error, const Color(0xFFEF4444));
    });

    test('agentAccent is #8B5CF6', () {
      expect(
        AppColors.light.agentAccent,
        const Color(0xFF8B5CF6),
      );
    });

    test('agentLight is #F5F3FF', () {
      expect(AppColors.light.agentLight, const Color(0xFFF5F3FF));
    });
  });

  group('AppColors dark tokens match Z3 spec', () {
    test('background is #0A0A0A', () {
      expect(AppColors.dark.background, const Color(0xFF0A0A0A));
    });

    test('surface is #141414', () {
      expect(AppColors.dark.surface, const Color(0xFF141414));
    });

    test('surfaceAlt is #1C1C1C', () {
      expect(AppColors.dark.surfaceAlt, const Color(0xFF1C1C1C));
    });

    test('primary is #818CF8', () {
      expect(AppColors.dark.primary, const Color(0xFF818CF8));
    });

    test('primaryLight is #1E1B4B', () {
      expect(AppColors.dark.primaryLight, const Color(0xFF1E1B4B));
    });

    test('primaryForeground is #1A1A1A', () {
      expect(
        AppColors.dark.primaryForeground,
        const Color(0xFF1A1A1A),
      );
    });

    test('text is #F0F0F0', () {
      expect(AppColors.dark.text, const Color(0xFFF0F0F0));
    });

    test('textSecondary is #9CA3AF', () {
      expect(
        AppColors.dark.textSecondary,
        const Color(0xFF9CA3AF),
      );
    });

    test('textTertiary is #6B7280', () {
      expect(
        AppColors.dark.textTertiary,
        const Color(0xFF6B7280),
      );
    });

    test('border is #262626', () {
      expect(AppColors.dark.border, const Color(0xFF262626));
    });

    test('success is #4ADE80', () {
      expect(AppColors.dark.success, const Color(0xFF4ADE80));
    });

    test('warning is #FBBF24', () {
      expect(AppColors.dark.warning, const Color(0xFFFBBF24));
    });

    test('error is #F87171', () {
      expect(AppColors.dark.error, const Color(0xFFF87171));
    });

    test('agentAccent is #A78BFA', () {
      expect(
        AppColors.dark.agentAccent,
        const Color(0xFFA78BFA),
      );
    });

    test('agentLight is #1E1533', () {
      expect(AppColors.dark.agentLight, const Color(0xFF1E1533));
    });
  });

  group('AppColors lerp', () {
    test('lerp at t=0 returns start', () {
      final result = AppColors.light.lerp(AppColors.dark, 0);
      expect(result.background, AppColors.light.background);
      expect(result.primary, AppColors.light.primary);
      expect(result.text, AppColors.light.text);
      expect(result.success, AppColors.light.success);
      expect(result.agentAccent, AppColors.light.agentAccent);
    });

    test('lerp at t=1 returns end', () {
      final result = AppColors.light.lerp(AppColors.dark, 1);
      expect(result.background, AppColors.dark.background);
      expect(result.primary, AppColors.dark.primary);
      expect(result.text, AppColors.dark.text);
      expect(result.error, AppColors.dark.error);
      expect(result.agentLight, AppColors.dark.agentLight);
    });

    test('lerp at t=0.5 returns intermediate', () {
      final result = AppColors.light.lerp(AppColors.dark, 0.5);
      final expectedBg = Color.lerp(
        AppColors.light.background,
        AppColors.dark.background,
        0.5,
      );
      final expectedPrimary = Color.lerp(
        AppColors.light.primary,
        AppColors.dark.primary,
        0.5,
      );
      final expectedSuccess = Color.lerp(
        AppColors.light.success,
        AppColors.dark.success,
        0.5,
      );
      expect(result.background, expectedBg);
      expect(result.primary, expectedPrimary);
      expect(result.success, expectedSuccess);
    });

    test('lerp with null returns this', () {
      final result = AppColors.light.lerp(null, 0.5);
      expect(result.background, AppColors.light.background);
      expect(result.primary, AppColors.light.primary);
    });
  });

  group('AppColors copyWith', () {
    test('overrides single token', () {
      const override = Color(0xFFFF0000);
      final result = AppColors.light.copyWith(primary: override);
      expect(result.primary, override);
      // Other tokens unchanged.
      expect(result.background, AppColors.light.background);
      expect(result.surface, AppColors.light.surface);
      expect(result.text, AppColors.light.text);
      expect(result.border, AppColors.light.border);
      expect(result.success, AppColors.light.success);
      expect(result.agentAccent, AppColors.light.agentAccent);
    });

    test('no arguments returns identical values', () {
      final result = AppColors.light.copyWith();
      expect(result.background, AppColors.light.background);
      expect(result.surface, AppColors.light.surface);
      expect(result.surfaceAlt, AppColors.light.surfaceAlt);
      expect(result.primary, AppColors.light.primary);
      expect(result.primaryLight, AppColors.light.primaryLight);
      expect(
        result.primaryForeground,
        AppColors.light.primaryForeground,
      );
      expect(result.text, AppColors.light.text);
      expect(
        result.textSecondary,
        AppColors.light.textSecondary,
      );
      expect(
        result.textTertiary,
        AppColors.light.textTertiary,
      );
      expect(result.border, AppColors.light.border);
      expect(result.success, AppColors.light.success);
      expect(result.warning, AppColors.light.warning);
      expect(result.error, AppColors.light.error);
      expect(
        result.agentAccent,
        AppColors.light.agentAccent,
      );
      expect(result.agentLight, AppColors.light.agentLight);
    });
  });
}
