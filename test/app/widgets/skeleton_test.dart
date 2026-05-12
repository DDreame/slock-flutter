import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/shimmer_box.dart';
import 'package:slock_app/app/widgets/skeleton_card.dart';
import 'package:slock_app/app/widgets/skeleton_list_item.dart';

// ---------------------------------------------------------------------------
// #489: Shared Skeleton Component Tests
//
// Invariant verified:
// INV-UX-SKELETON-1: First frame must show skeleton/shimmer, never blank.
//
// Covers:
// - ShimmerBox: dimensions, animation, theme, border radius
// - SkeletonListItem: structure (avatar + text lines), custom height
// - SkeletonCard: structure (card + content lines), custom dimensions
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  Widget buildApp({
    ThemeData? theme,
    required Widget child,
  }) {
    return MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );
  }

  // -----------------------------------------------------------------------
  // ShimmerBox
  // -----------------------------------------------------------------------
  group('ShimmerBox', () {
    testWidgets('renders with specified width and height', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: const ShimmerBox(width: 120, height: 16),
        ),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('shimmer-box')),
      );
      expect(container.constraints?.maxWidth, 120);
      expect(container.constraints?.maxHeight, 16);
    });

    testWidgets('uses default border radius from SkeletonTokens', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          child: const ShimmerBox(width: 100, height: 12),
        ),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('shimmer-box')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(
        decoration.borderRadius,
        BorderRadius.circular(SkeletonTokens.borderRadius),
      );
    });

    testWidgets('accepts custom border radius', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: const ShimmerBox(width: 40, height: 40, borderRadius: 20),
        ),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('shimmer-box')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(20));
    });

    testWidgets('shows shimmer on first frame (INV-UX-SKELETON-1)', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          child: const ShimmerBox(width: 100, height: 12),
        ),
      );
      // Single pump — first frame must render the shimmer, never blank.
      await tester.pump();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('shimmer-box')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.gradient, isA<LinearGradient>(),
          reason: 'INV-UX-SKELETON-1: shimmer gradient must be visible '
              'on the very first frame');
    });

    testWidgets('gradient changes across animation pumps', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: const ShimmerBox(width: 100, height: 12),
        ),
      );
      await tester.pump();

      LinearGradient getGradient() {
        final container = tester.widget<Container>(
          find.byKey(const ValueKey('shimmer-box')),
        );
        final decoration = container.decoration as BoxDecoration;
        return decoration.gradient! as LinearGradient;
      }

      final initialStops = getGradient().stops;

      // Advance by half the shimmer duration.
      await tester.pump(SkeletonTokens.shimmerDuration ~/ 2);

      final midStops = getGradient().stops;
      expect(midStops, isNot(equals(initialStops)),
          reason: 'Shimmer gradient stops must change during animation');
    });

    testWidgets('uses surfaceAlt base color in light theme', (tester) async {
      await tester.pumpWidget(
        buildApp(
          theme: AppTheme.light,
          child: const ShimmerBox(width: 100, height: 12),
        ),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('shimmer-box')),
      );
      final decoration = container.decoration as BoxDecoration;
      final gradient = decoration.gradient! as LinearGradient;

      // First and last gradient colors should be the surfaceAlt base.
      expect(gradient.colors.first, AppColors.light.surfaceAlt);
      expect(gradient.colors.last, AppColors.light.surfaceAlt);
      // Middle highlight should be surface.
      expect(gradient.colors[1], AppColors.light.surface);
    });

    testWidgets('uses dark theme colors when dark theme is active', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          theme: AppTheme.dark,
          child: const ShimmerBox(width: 100, height: 12),
        ),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('shimmer-box')),
      );
      final decoration = container.decoration as BoxDecoration;
      final gradient = decoration.gradient! as LinearGradient;

      expect(gradient.colors.first, AppColors.dark.surfaceAlt);
      expect(gradient.colors.last, AppColors.dark.surfaceAlt);
      expect(gradient.colors[1], AppColors.dark.surface);
    });
  });

  // -----------------------------------------------------------------------
  // SkeletonListItem
  // -----------------------------------------------------------------------
  group('SkeletonListItem', () {
    testWidgets('renders avatar placeholder and text lines', (tester) async {
      await tester.pumpWidget(
        buildApp(child: const SkeletonListItem()),
      );
      await tester.pump();

      // Root container.
      expect(
        find.byKey(const ValueKey('skeleton-list-item')),
        findsOneWidget,
      );

      // Avatar placeholder (circular ShimmerBox).
      expect(
        find.byKey(const ValueKey('skeleton-list-item-avatar')),
        findsOneWidget,
      );

      // Text line placeholders.
      expect(
        find.byKey(const ValueKey('skeleton-list-item-line-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('skeleton-list-item-line-2')),
        findsOneWidget,
      );
    });

    testWidgets('avatar uses circular border radius', (tester) async {
      await tester.pumpWidget(
        buildApp(child: const SkeletonListItem()),
      );
      await tester.pump();

      // The avatar ShimmerBox should have circular border radius
      // (avatarSize / 2 = 20).
      final avatarWidget = tester.widget<ShimmerBox>(
        find.byKey(const ValueKey('skeleton-list-item-avatar')),
      );
      expect(avatarWidget.width, SkeletonTokens.avatarSize);
      expect(avatarWidget.height, SkeletonTokens.avatarSize);
      expect(avatarWidget.borderRadius, SkeletonTokens.avatarSize / 2);
    });

    testWidgets('uses default height from SkeletonTokens', (tester) async {
      await tester.pumpWidget(
        buildApp(child: const SkeletonListItem()),
      );
      await tester.pump();

      final sizedBox = tester.widget<SizedBox>(
        find.byKey(const ValueKey('skeleton-list-item')),
      );
      expect(sizedBox.height, SkeletonTokens.listItemHeight);
    });

    testWidgets('accepts custom height', (tester) async {
      await tester.pumpWidget(
        buildApp(child: const SkeletonListItem(height: 72)),
      );
      await tester.pump();

      final sizedBox = tester.widget<SizedBox>(
        find.byKey(const ValueKey('skeleton-list-item')),
      );
      expect(sizedBox.height, 72);
    });

    testWidgets('shows content on first frame (INV-UX-SKELETON-1)', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(child: const SkeletonListItem()),
      );
      await tester.pump();

      // All structural elements must be present on the first frame.
      expect(
        find.byKey(const ValueKey('skeleton-list-item')),
        findsOneWidget,
        reason: 'INV-UX-SKELETON-1: skeleton list item must render '
            'on the very first frame',
      );
      expect(
        find.byKey(const ValueKey('skeleton-list-item-avatar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('skeleton-list-item-line-1')),
        findsOneWidget,
      );
    });
  });

  // -----------------------------------------------------------------------
  // SkeletonCard
  // -----------------------------------------------------------------------
  group('SkeletonCard', () {
    testWidgets('renders card container with content lines', (tester) async {
      await tester.pumpWidget(
        buildApp(child: const SkeletonCard()),
      );
      await tester.pump();

      // Root card container.
      expect(
        find.byKey(const ValueKey('skeleton-card')),
        findsOneWidget,
      );

      // Content line placeholders.
      expect(
        find.byKey(const ValueKey('skeleton-card-line-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('skeleton-card-line-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('skeleton-card-line-3')),
        findsOneWidget,
      );
    });

    testWidgets('card has correct border radius and border', (tester) async {
      await tester.pumpWidget(
        buildApp(child: const SkeletonCard()),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('skeleton-card')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(
        decoration.borderRadius,
        BorderRadius.circular(SkeletonTokens.cardBorderRadius),
      );
      expect(decoration.border, isNotNull);
    });

    testWidgets('card uses surface color in light theme', (tester) async {
      await tester.pumpWidget(
        buildApp(
          theme: AppTheme.light,
          child: const SkeletonCard(),
        ),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('skeleton-card')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.light.surface);
    });

    testWidgets('card uses dark theme colors', (tester) async {
      await tester.pumpWidget(
        buildApp(
          theme: AppTheme.dark,
          child: const SkeletonCard(),
        ),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('skeleton-card')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.dark.surface);
      // Border should use dark border color.
      final border = decoration.border as Border;
      expect(border.top.color, AppColors.dark.border);
    });

    testWidgets('accepts custom width', (tester) async {
      await tester.pumpWidget(
        buildApp(child: const SkeletonCard(width: 300)),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('skeleton-card')),
      );
      expect(container.constraints?.maxWidth, 300);
    });

    testWidgets('accepts custom height', (tester) async {
      await tester.pumpWidget(
        buildApp(child: const SkeletonCard(height: 200)),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('skeleton-card')),
      );
      expect(container.constraints?.maxHeight, 200);
    });

    testWidgets('shows content on first frame (INV-UX-SKELETON-1)', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(child: const SkeletonCard()),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('skeleton-card')),
        findsOneWidget,
        reason: 'INV-UX-SKELETON-1: skeleton card must render '
            'on the very first frame',
      );
      expect(
        find.byKey(const ValueKey('skeleton-card-line-1')),
        findsOneWidget,
      );
    });
  });
}
