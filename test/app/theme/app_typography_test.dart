import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_typography.dart';

void main() {
  group('AppTypography constants', () {
    test('displayLarge has expected size and weight', () {
      expect(AppTypography.displayLarge.fontSize, 32);
      expect(AppTypography.displayLarge.fontWeight, FontWeight.w700);
    });

    test('displayMedium has expected size and weight', () {
      expect(AppTypography.displayMedium.fontSize, 28);
      expect(AppTypography.displayMedium.fontWeight, FontWeight.w700);
    });

    test('headline has expected size and weight', () {
      expect(AppTypography.headline.fontSize, 20);
      expect(AppTypography.headline.fontWeight, FontWeight.w600);
    });

    test('title has expected size and weight', () {
      expect(AppTypography.title.fontSize, 16);
      expect(AppTypography.title.fontWeight, FontWeight.w600);
    });

    test('body has expected size and weight', () {
      expect(AppTypography.body.fontSize, 14);
      expect(AppTypography.body.fontWeight, FontWeight.w400);
    });

    test('bodySmall has expected size and weight', () {
      expect(AppTypography.bodySmall.fontSize, 13);
      expect(AppTypography.bodySmall.fontWeight, FontWeight.w400);
    });

    test('label has expected size and weight', () {
      expect(AppTypography.label.fontSize, 12);
      expect(AppTypography.label.fontWeight, FontWeight.w500);
    });

    test('caption has expected size and weight', () {
      expect(AppTypography.caption.fontSize, 11);
      expect(AppTypography.caption.fontWeight, FontWeight.w400);
    });
  });

  group('AppTypography.textTheme', () {
    late TextTheme textTheme;

    setUpAll(() {
      textTheme = AppTypography.textTheme(const Color(0xFF000000));
    });

    test('all M3 slots are non-null', () {
      expect(textTheme.displayLarge, isNotNull);
      expect(textTheme.displayMedium, isNotNull);
      expect(textTheme.headlineMedium, isNotNull);
      expect(textTheme.titleLarge, isNotNull);
      expect(textTheme.titleMedium, isNotNull);
      expect(textTheme.titleSmall, isNotNull);
      expect(textTheme.bodyLarge, isNotNull);
      expect(textTheme.bodyMedium, isNotNull);
      expect(textTheme.bodySmall, isNotNull);
      expect(textTheme.labelLarge, isNotNull);
      expect(textTheme.labelMedium, isNotNull);
      expect(textTheme.labelSmall, isNotNull);
    });

    test('text color is applied to all slots', () {
      const color = Color(0xFF123456);
      final themed = AppTypography.textTheme(color);
      expect(themed.displayLarge!.color, color);
      expect(themed.bodyMedium!.color, color);
      expect(themed.labelSmall!.color, color);
    });

    test('font sizes descend through scale', () {
      expect(
        textTheme.displayLarge!.fontSize!,
        greaterThan(textTheme.displayMedium!.fontSize!),
      );
      expect(
        textTheme.displayMedium!.fontSize!,
        greaterThan(textTheme.headlineMedium!.fontSize!),
      );
      expect(
        textTheme.titleMedium!.fontSize!,
        greaterThan(textTheme.bodyMedium!.fontSize!),
      );
      expect(
        textTheme.bodyMedium!.fontSize!,
        greaterThan(textTheme.bodySmall!.fontSize!),
      );
      expect(
        textTheme.labelMedium!.fontSize!,
        greaterThan(textTheme.labelSmall!.fontSize!),
      );
    });
  });
}
