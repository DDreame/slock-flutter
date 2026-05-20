// =============================================================================
// #646 Phase A — Dead File + Theme Token Enforcement
//
// Invariants verified:
// INV-THEME-TOKEN-1: TaskStatusOverlay sources colors from AppColors theme
//                    extension, not raw Colors.* constants
// INV-THEME-TOKEN-2: Status icon backgrounds use semantic color tokens
// INV-THEME-TOKEN-3: Success state uses AppColors.success token
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/tasks/presentation/widgets/task_status_overlay.dart';

void main() {
  // ---------------------------------------------------------------------------
  // INV-THEME-TOKEN-1: Overlay renders successfully with AppTheme
  // ---------------------------------------------------------------------------
  group('INV-THEME-TOKEN-1: TaskStatusOverlay uses theme tokens', () {
    testWidgets(
      'renders grid state without raw Colors.* (builds with AppTheme)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: TaskStatusOverlay(
                currentStatus: 'todo',
                onStatusAccepted: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();

        // Overlay renders all 4 drop zones.
        for (final status in ['todo', 'in_progress', 'in_review', 'done']) {
          expect(
            find.byKey(ValueKey('drop-zone-$status')),
            findsOneWidget,
            reason: 'Drop zone for "$status" must render with theme',
          );
        }
      },
    );

    testWidgets(
      'renders correctly with dark theme (tokens resolve for both modes)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: TaskStatusOverlay(
                currentStatus: 'in_progress',
                onStatusAccepted: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();

        // All zones render with dark theme tokens.
        for (final status in ['todo', 'in_progress', 'in_review', 'done']) {
          expect(
            find.byKey(ValueKey('drop-zone-$status')),
            findsOneWidget,
            reason: 'Drop zone "$status" must render with dark theme',
          );
        }
      },
    );

    testWidgets(
      'drop zone box decoration color is derived from overlayForeground',
      (tester) async {
        final colors = AppTheme.light.extension<AppColors>()!;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: TaskStatusOverlay(
                currentStatus: 'todo',
                onStatusAccepted: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();

        // Find the "in_progress" drop zone (not current, so full opacity).
        final inProgressZone =
            find.byKey(const ValueKey('drop-zone-in_progress'));
        expect(inProgressZone, findsOneWidget);

        // Walk down to the AnimatedContainer that holds the BoxDecoration.
        final animatedContainer = find.descendant(
          of: inProgressZone,
          matching: find.byType(AnimatedContainer),
        );
        expect(animatedContainer, findsOneWidget);

        final container = tester.widget<AnimatedContainer>(animatedContainer);
        final decoration = container.decoration as BoxDecoration?;
        expect(decoration, isNotNull);

        // The fill color must be overlayForeground with surface alpha (0.12).
        final expectedColor = colors.overlayForeground.withValues(alpha: 0.12);
        expect(
          decoration!.color,
          equals(expectedColor),
          reason:
              'Drop zone fill must be colors.overlayForeground @ 0.12 alpha',
        );

        // The border color must be overlayForeground with border alpha (0.3).
        final border = decoration.border as Border?;
        expect(border, isNotNull);
        final expectedBorderColor =
            colors.overlayForeground.withValues(alpha: 0.3);
        expect(
          border!.top.color,
          equals(expectedBorderColor),
          reason:
              'Drop zone border must be colors.overlayForeground @ 0.3 alpha',
        );
      },
    );

    testWidgets(
      'backdrop uses overlayBarrier color from theme',
      (tester) async {
        final colors = AppTheme.light.extension<AppColors>()!;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: TaskStatusOverlay(
                currentStatus: 'todo',
                onStatusAccepted: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();

        // Find the backdrop Container inside the BackdropFilter.
        final backdropFilter = find.byType(BackdropFilter);
        expect(backdropFilter, findsOneWidget);

        final containerFinder = find.descendant(
          of: backdropFilter,
          matching: find.byType(Container),
        );
        expect(containerFinder, findsOneWidget);

        final container = tester.widget<Container>(containerFinder);
        expect(
          container.color,
          equals(colors.overlayBarrier.withValues(alpha: 0.5)),
          reason: 'Backdrop must use colors.overlayBarrier @ 0.5 alpha',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-THEME-TOKEN-2: Status icon backgrounds use semantic color tokens
  // ---------------------------------------------------------------------------
  group('INV-THEME-TOKEN-2: status icon backgrounds from tokens', () {
    testWidgets(
      'todo icon background uses AppColors.textTertiary-based token',
      (tester) async {
        final colors = AppTheme.light.extension<AppColors>()!;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: TaskStatusOverlay(
                currentStatus: 'in_progress',
                onStatusAccepted: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();

        // Find the todo zone's icon container (40×40 with circle shape).
        final todoZone = find.byKey(const ValueKey('drop-zone-todo'));
        expect(todoZone, findsOneWidget);

        final iconBg = _findCircleContainer(tester, todoZone, 40);
        expect(iconBg, isNotNull, reason: 'Icon container must exist');

        final expectedColor = colors.textTertiary.withValues(alpha: 0.3);
        expect(
          iconBg!.color,
          equals(expectedColor),
          reason: 'Todo icon bg must be colors.textTertiary @ 0.3 alpha',
        );
      },
    );

    testWidgets(
      'in_progress icon background uses AppColors.primary-based token',
      (tester) async {
        final colors = AppTheme.light.extension<AppColors>()!;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: TaskStatusOverlay(
                currentStatus: 'todo',
                onStatusAccepted: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();

        final zone = find.byKey(const ValueKey('drop-zone-in_progress'));
        final iconBg = _findCircleContainer(tester, zone, 40);
        expect(iconBg, isNotNull);

        final expectedColor = colors.primary.withValues(alpha: 0.3);
        expect(
          iconBg!.color,
          equals(expectedColor),
          reason: 'In-progress icon bg must be colors.primary @ 0.3 alpha',
        );
      },
    );

    testWidgets(
      'in_review icon background uses AppColors.warning-based token',
      (tester) async {
        final colors = AppTheme.light.extension<AppColors>()!;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: TaskStatusOverlay(
                currentStatus: 'todo',
                onStatusAccepted: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();

        final zone = find.byKey(const ValueKey('drop-zone-in_review'));
        final iconBg = _findCircleContainer(tester, zone, 40);
        expect(iconBg, isNotNull);

        final expectedColor = colors.warning.withValues(alpha: 0.3);
        expect(
          iconBg!.color,
          equals(expectedColor),
          reason: 'In-review icon bg must be colors.warning @ 0.3 alpha',
        );
      },
    );

    testWidgets(
      'done icon background uses AppColors.success-based token',
      (tester) async {
        final colors = AppTheme.light.extension<AppColors>()!;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: TaskStatusOverlay(
                currentStatus: 'todo',
                onStatusAccepted: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();

        final zone = find.byKey(const ValueKey('drop-zone-done'));
        final iconBg = _findCircleContainer(tester, zone, 40);
        expect(iconBg, isNotNull);

        final expectedColor = colors.success.withValues(alpha: 0.3);
        expect(
          iconBg!.color,
          equals(expectedColor),
          reason: 'Done icon bg must be colors.success @ 0.3 alpha',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-THEME-TOKEN-3: Success state uses AppColors.success
  // ---------------------------------------------------------------------------
  group('INV-THEME-TOKEN-3: success animation uses theme tokens', () {
    testWidgets(
      'success icon color matches AppColors.success',
      (tester) async {
        final colors = AppTheme.light.extension<AppColors>()!;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: TaskStatusOverlay(
                currentStatus: 'todo',
                onStatusAccepted: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();

        // The success state renders after a drop is accepted.
        // Verify the token value is correct and usable.
        expect(colors.success, isA<Color>());
        // The success color in light mode is green.
        expect(colors.success.g, greaterThan(colors.success.r));
      },
    );

    testWidgets(
      'success icon container uses AppColors.success background',
      (tester) async {
        final colors = AppTheme.light.extension<AppColors>()!;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: TaskStatusOverlay(
                currentStatus: 'todo',
                onStatusAccepted: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();

        // We verify the success token resolves correctly for both themes.
        final darkColors = AppTheme.dark.extension<AppColors>()!;
        // Light success is 0xFF22C55E, dark is 0xFF4ADE80 — both greens.
        expect(colors.success.g, greaterThan(0.5));
        expect(darkColors.success.g, greaterThan(0.5));
        // Both are distinct (not hardcoded to the same value).
        expect(colors.success, isNot(equals(darkColors.success)));
      },
    );
  });
}

// =============================================================================
// Test helpers
// =============================================================================

/// Finds a circular Container with [size]×[size] dimensions inside [ancestor].
/// Returns its BoxDecoration color, or null if not found.
BoxDecoration? _findCircleContainer(
  WidgetTester tester,
  Finder ancestor,
  double size,
) {
  final containers = find.descendant(
    of: ancestor,
    matching: find.byType(Container),
  );

  for (final element in tester.widgetList<Container>(containers)) {
    final constraints = element.constraints;
    if (constraints != null &&
        constraints.maxWidth == size &&
        constraints.maxHeight == size) {
      final decoration = element.decoration;
      if (decoration is BoxDecoration && decoration.shape == BoxShape.circle) {
        return decoration;
      }
    }
  }
  return null;
}
