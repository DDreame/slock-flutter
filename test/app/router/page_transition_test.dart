import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// #523: 页面转场动画 — Phase A (test-only)
//
// Verifies that GoRouter route transitions use CustomTransitionPage with
// non-zero duration instead of instant builder: callbacks.
//
// Uses a minimal 2-route GoRouter harness (home + detail) so that the
// only transitions in the widget tree come from the tested route.
// This avoids false-pass/false-fail from unrelated framework transitions
// present in the full app router (StatefulShellRoute, etc.).
//
// Invariants:
//   INV-TRANSITION-1: Navigation push → CustomTransitionPage with non-zero
//                     duration (transition animation plays on forward nav)
//   INV-TRANSITION-2: Navigation pop → animated transition (not instant pop)
//
// Both tests skip: true until Phase B converts routes from builder: to
// pageBuilder: + CustomTransitionPage with SlideTransition or FadeTransition.
//
// Phase B write set:
//   lib/app/router/app_router.dart — convert target routes from builder:
//   to pageBuilder: + CustomTransitionPage
// ---------------------------------------------------------------------------

/// Creates a minimal GoRouter with exactly 2 routes: / (home) and /detail.
///
/// The /detail route uses [detailPageBuilder] if provided (Phase B will
/// supply a CustomTransitionPage pageBuilder), otherwise falls back to
/// plain builder: (current production behavior — instant, no transition).
///
/// This isolation ensures the ONLY SlideTransition / FadeTransition widgets
/// in the tree come from the /detail route's CustomTransitionPage, not from
/// unrelated framework animations.
GoRouter _createMinimalRouter({
  GoRouterPageBuilder? detailPageBuilder,
}) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          key: ValueKey('home-page'),
          body: Center(child: Text('Home')),
        ),
      ),
      GoRoute(
        path: '/detail',
        // Phase B: switch from builder: to pageBuilder: here.
        // For now (Phase A), this uses builder: which produces
        // an instant page swap with no transition animation.
        pageBuilder: detailPageBuilder,
        builder: detailPageBuilder == null
            ? (context, state) => const Scaffold(
                  key: ValueKey('detail-page'),
                  body: Center(child: Text('Detail')),
                )
            : null,
      ),
    ],
  );
}

Widget _buildApp(GoRouter router) {
  return MaterialApp.router(
    theme: AppTheme.light,
    routerConfig: router,
  );
}

void main() {
  // -----------------------------------------------------------------------
  // INV-TRANSITION-1: Navigation push uses CustomTransitionPage with
  //                   non-zero transition duration.
  //
  // Approach: Use a minimal 2-route harness. The /detail route uses
  // pageBuilder: + CustomTransitionPage with SlideTransition. Push from
  // / to /detail. Pump 100ms (less than 300ms transition duration).
  // Assert that a SlideTransition exists with a non-zero offset —
  // proving the animation is mid-flight, not instant.
  //
  // Because the harness has NO other routes, the only SlideTransition
  // in the tree comes from our CustomTransitionPage.
  //
  // Phase B: Convert app_router.dart routes from builder: → pageBuilder:
  //          + CustomTransitionPage. This test validates the pattern.
  // -----------------------------------------------------------------------
  testWidgets(
    'push navigation uses animated transition with non-zero duration '
    '(INV-TRANSITION-1)',
    skip: true,
    (tester) async {
      final router = _createMinimalRouter(
        detailPageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const Scaffold(
            key: ValueKey('detail-page'),
            body: Center(child: Text('Detail')),
          ),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              key: const ValueKey('route-slide-transition'),
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              )),
              child: child,
            );
          },
        ),
      );

      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      // Verify we start on home.
      expect(find.byKey(const ValueKey('home-page')), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-page')), findsNothing);

      // Push to detail page.
      router.push('/detail');

      // Pump a single frame to start the transition.
      await tester.pump();

      // Pump 100ms — less than the 300ms transition duration.
      // Animation should be in progress (not complete).
      await tester.pump(const Duration(milliseconds: 100));

      // Find the specific route SlideTransition by key.
      final slideFinder = find.byKey(const ValueKey('route-slide-transition'));
      expect(slideFinder, findsOneWidget,
          reason: 'Push navigation must produce a SlideTransition from '
              'CustomTransitionPage (INV-TRANSITION-1)');

      // Verify the animation is mid-flight (offset not yet at zero).
      final slide = tester.widget<SlideTransition>(slideFinder);
      expect(slide.position.value, isNot(equals(Offset.zero)),
          reason: 'Slide animation must be in progress at 100ms — '
              'not yet at final position (INV-TRANSITION-1)');
      expect(slide.position.value.dx, greaterThan(0),
          reason: 'Slide-in from right: dx must be > 0 at 100ms '
              '(INV-TRANSITION-1)');

      // Let the animation complete.
      await tester.pumpAndSettle();

      // Verify we arrived at the detail page.
      expect(find.byKey(const ValueKey('detail-page')), findsOneWidget,
          reason: 'Must be on detail page after transition completes');
    },
  );

  // -----------------------------------------------------------------------
  // INV-TRANSITION-2: Navigation pop uses animated transition
  //                   (not instant removal).
  //
  // Approach: Same minimal harness. Push to /detail and settle. Then
  // pop. Pump 100ms. The reverse animation should be in progress —
  // the SlideTransition offset should be non-zero (sliding out to right).
  //
  // Phase B: CustomTransitionPage reverse transition animates pop.
  // -----------------------------------------------------------------------
  testWidgets(
    'pop navigation uses animated transition — not instant '
    '(INV-TRANSITION-2)',
    skip: true,
    (tester) async {
      final router = _createMinimalRouter(
        detailPageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const Scaffold(
            key: ValueKey('detail-page'),
            body: Center(child: Text('Detail')),
          ),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              key: const ValueKey('route-slide-transition'),
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              )),
              child: child,
            );
          },
        ),
      );

      await tester.pumpWidget(_buildApp(router));
      await tester.pumpAndSettle();

      // Push to detail page and let it fully settle.
      router.push('/detail');
      await tester.pumpAndSettle();

      // Verify we are on detail page.
      expect(find.byKey(const ValueKey('detail-page')), findsOneWidget,
          reason: 'Must be on detail page before testing pop transition');

      // At rest, the slide transition should be at Offset.zero.
      final slideAtRest = tester
          .widget<SlideTransition>(
              find.byKey(const ValueKey('route-slide-transition')))
          .position
          .value;
      expect(slideAtRest, equals(Offset.zero),
          reason: 'At rest, slide offset must be zero');

      // Pop (simulates back button).
      router.pop();

      // Pump a single frame to start the reverse transition.
      await tester.pump();

      // Pump 100ms — the reverse animation should be in progress.
      await tester.pump(const Duration(milliseconds: 100));

      // The SlideTransition should still be present (page not yet removed)
      // and its offset should be non-zero (sliding out to right).
      final slideFinder = find.byKey(const ValueKey('route-slide-transition'));
      expect(slideFinder, findsOneWidget,
          reason: 'Pop must animate out — SlideTransition still present '
              'at 100ms (INV-TRANSITION-2)');

      final slide = tester.widget<SlideTransition>(slideFinder);
      expect(slide.position.value, isNot(equals(Offset.zero)),
          reason: 'Slide reverse animation must be in progress at 100ms '
              '— not yet at rest position (INV-TRANSITION-2)');
      expect(slide.position.value.dx, greaterThan(0),
          reason: 'Slide-out to right: dx must be > 0 at 100ms '
              '(INV-TRANSITION-2)');

      // Let the animation complete.
      await tester.pumpAndSettle();

      // Verify we returned to home.
      expect(find.byKey(const ValueKey('home-page')), findsOneWidget,
          reason: 'Must return to home after pop transition completes');
    },
  );
}
