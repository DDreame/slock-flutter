import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/status_glow_ring.dart';

void main() {
  group('StatusGlowRing', () {
    testWidgets('online state renders green ring', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: StatusGlowRing(
                status: GlowRingStatus.online,
                size: 48,
                child: Icon(Icons.person),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('status-glow-ring')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);

      // Border color should be success (green)
      final border = decoration.border as Border;
      expect(border.top.color, AppColors.light.success);
    });

    testWidgets('thinking state renders yellow/warning ring', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: StatusGlowRing(
                status: GlowRingStatus.thinking,
                size: 48,
                child: Icon(Icons.person),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('status-glow-ring')),
      );
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, AppColors.light.warning);
    });

    testWidgets('working state renders primary (blue-purple) ring', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: StatusGlowRing(
                status: GlowRingStatus.working,
                size: 48,
                child: Icon(Icons.person),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('status-glow-ring')),
      );
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, AppColors.light.primary);
    });

    testWidgets('error state renders red ring', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: StatusGlowRing(
                status: GlowRingStatus.error,
                size: 48,
                child: Icon(Icons.person),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('status-glow-ring')),
      );
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, AppColors.light.error);
    });

    testWidgets('offline state renders gray ring with low opacity', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: StatusGlowRing(
                status: GlowRingStatus.offline,
                size: 48,
                child: Icon(Icons.person),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Offline uses low opacity wrapper
      final opacity = tester.widget<Opacity>(
        find.byKey(const ValueKey('status-glow-ring-opacity')),
      );
      expect(opacity.opacity, GlowRingTokens.offlineOpacity);

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('status-glow-ring')),
      );
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, AppColors.light.textTertiary);
    });

    testWidgets('active states animate glow intensity across pumps (breathing)',
        (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: StatusGlowRing(
                status: GlowRingStatus.online,
                size: 48,
                child: Icon(Icons.person),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Capture initial glow alpha
      BoxDecoration getDecoration() {
        final container = tester.widget<Container>(
          find.byKey(const ValueKey('status-glow-ring')),
        );
        return container.decoration as BoxDecoration;
      }

      final initialShadow = getDecoration().boxShadow!.first;
      final initialAlpha = initialShadow.color.a;

      // Advance animation by half the breathing duration
      await tester.pump(GlowRingTokens.breathDuration ~/ 2);

      final midShadow = getDecoration().boxShadow!.first;
      final midAlpha = midShadow.color.a;

      // Alpha should have changed during the animation
      expect(midAlpha, isNot(equals(initialAlpha)));
    });

    testWidgets('offline state has no box shadow and no animation', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: StatusGlowRing(
                status: GlowRingStatus.offline,
                size: 48,
                child: Icon(Icons.person),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('status-glow-ring')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.boxShadow, isNull);

      // Advance time — decoration should remain unchanged (no animation)
      await tester.pump(const Duration(seconds: 1));
      final containerAfter = tester.widget<Container>(
        find.byKey(const ValueKey('status-glow-ring')),
      );
      final decorationAfter = containerAfter.decoration as BoxDecoration;
      expect(decorationAfter.boxShadow, isNull);
    });

    testWidgets('respects custom size parameter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: StatusGlowRing(
                status: GlowRingStatus.online,
                size: 64,
                child: Icon(Icons.person),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final sizedBox = tester.widget<SizedBox>(
        find.byKey(const ValueKey('status-glow-ring-size')),
      );
      expect(sizedBox.width, 64);
      expect(sizedBox.height, 64);
    });

    testWidgets('child widget is rendered inside the ring', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: StatusGlowRing(
                status: GlowRingStatus.online,
                size: 48,
                child: Icon(Icons.person, key: ValueKey('inner-icon')),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('inner-icon')), findsOneWidget);
    });

    testWidgets('dark theme uses correct colors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: Center(
              child: StatusGlowRing(
                status: GlowRingStatus.working,
                size: 48,
                child: Icon(Icons.person),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('status-glow-ring')),
      );
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, AppColors.dark.primary);
    });

    testWidgets('uses GlowRingTokens for border width', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: StatusGlowRing(
                status: GlowRingStatus.online,
                size: 48,
                child: Icon(Icons.person),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('status-glow-ring')),
      );
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.width, GlowRingTokens.borderWidth);
    });
  });
}
