import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/app/router/app_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/splash/application/splash_controller.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';

import '../../stores/session/session_store_persistence_test.dart'
    show FakeAuthRepository;

// ---------------------------------------------------------------------------
// #523: 页面转场动画 — Phase A (test-only)
//
// Verifies that GoRouter route transitions use CustomTransitionPage with
// non-zero duration instead of instant builder: callbacks.
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

Widget _buildRouterApp(GoRouter router) {
  return MaterialApp.router(
    theme: AppTheme.light,
    routerConfig: router,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
  );
}

({ProviderContainer container, GoRouter router}) _createAuthenticatedRouter() {
  final container = ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
      authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
      splashControllerProvider.overrideWith(() => _StallingSplashController()),
      homeListStoreProvider.overrideWith(() => _TestHomeListStore()),
    ],
  );
  return (container: container, router: container.read(appRouterProvider));
}

Future<void> _pumpAuthenticated(
  WidgetTester tester, {
  required ProviderContainer container,
  required GoRouter router,
}) async {
  await container
      .read(sessionStoreProvider.notifier)
      .login(email: 'test@test.com', password: 'password');
  container.read(appReadyProvider.notifier).state = true;

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: _buildRouterApp(router),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  // -----------------------------------------------------------------------
  // INV-TRANSITION-1: Navigation push uses CustomTransitionPage with
  //                   non-zero transition duration.
  //
  // Approach: Push a detail route (e.g. /servers/s1/channels/ch1) from
  // /home. Pump a partial duration (e.g. 150ms). If a transition animation
  // is in progress, the destination page will be partially visible (its
  // opacity or position is mid-animation). We verify the transition is
  // NOT instant by checking that after a partial pump the animation has
  // not yet fully settled — i.e. pumping to settle takes additional frames.
  //
  // Phase B: Convert routes from builder: → pageBuilder: +
  //          CustomTransitionPage with SlideTransition or FadeTransition.
  // -----------------------------------------------------------------------
  testWidgets(
    'push navigation uses animated transition with non-zero duration '
    '(INV-TRANSITION-1)',
    skip: true,
    (tester) async {
      final setup = _createAuthenticatedRouter();
      addTearDown(setup.container.dispose);
      await _pumpAuthenticated(
        tester,
        container: setup.container,
        router: setup.router,
      );

      // Verify we start on /home.
      expect(
        setup.router.routeInformationProvider.value.uri.path,
        '/home',
        reason: 'Must start on /home after authenticated pump',
      );

      // Push to a detail page.
      setup.router.push('/servers/s1/channels/ch1');

      // Pump a single frame to start the transition.
      await tester.pump();

      // Pump a partial duration — less than typical transition (300ms).
      // If the route uses CustomTransitionPage with duration > 0,
      // the animation should still be in progress at 100ms.
      await tester.pump(const Duration(milliseconds: 100));

      // Find the transition animation controller. When using
      // CustomTransitionPage, GoRouter wraps the page in a
      // transition widget. We look for any active Animation<double>
      // that is NOT at its final value (1.0 for forward).
      //
      // Strategy: look for a SlideTransition or FadeTransition widget.
      // At least one must be present and its animation must not be
      // completed (value < 1.0) at 100ms into a 300ms transition.
      final slideTransitions = find.byType(SlideTransition);
      final fadeTransitions = find.byType(FadeTransition);

      final hasAnimatingTransition = slideTransitions.evaluate().isNotEmpty ||
          fadeTransitions.evaluate().isNotEmpty;

      expect(hasAnimatingTransition, isTrue,
          reason: 'Push navigation must produce a SlideTransition or '
              'FadeTransition from CustomTransitionPage '
              '(INV-TRANSITION-1)');

      // Verify the animation is still in progress (not completed).
      if (slideTransitions.evaluate().isNotEmpty) {
        final slide = tester.widget<SlideTransition>(slideTransitions.first);
        expect(slide.position.value, isNot(equals(Offset.zero)),
            reason: 'Slide animation must be in progress at 100ms — '
                'not yet at final position (INV-TRANSITION-1)');
      } else if (fadeTransitions.evaluate().isNotEmpty) {
        final fade = tester.widget<FadeTransition>(fadeTransitions.first);
        expect(fade.opacity.value, lessThan(1.0),
            reason: 'Fade animation must be in progress at 100ms — '
                'not yet fully opaque (INV-TRANSITION-1)');
      }

      // Let the animation complete.
      await tester.pumpAndSettle();

      // Verify we arrived at the detail page.
      expect(
        setup.router.routeInformationProvider.value.uri.path,
        '/servers/s1/channels/ch1',
        reason: 'Must be on detail page after transition completes',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-TRANSITION-2: Navigation pop uses animated transition
  //                   (not instant removal).
  //
  // Approach: Navigate to detail page, let it settle, then pop. Pump a
  // partial duration. If pop is animated, the outgoing page should still
  // be mid-transition (SlideTransition or FadeTransition with animation
  // in progress). Verify it's not instant by checking for active
  // transition widgets after partial pump.
  //
  // Phase B: Same CustomTransitionPage setup ensures pop also animates
  //          (reverse of the push transition).
  // -----------------------------------------------------------------------
  testWidgets(
    'pop navigation uses animated transition — not instant '
    '(INV-TRANSITION-2)',
    skip: true,
    (tester) async {
      final setup = _createAuthenticatedRouter();
      addTearDown(setup.container.dispose);
      await _pumpAuthenticated(
        tester,
        container: setup.container,
        router: setup.router,
      );

      // Push to a detail page and let it fully settle.
      setup.router.push('/servers/s1/channels/ch1');
      await tester.pumpAndSettle();

      expect(
        setup.router.routeInformationProvider.value.uri.path,
        '/servers/s1/channels/ch1',
        reason: 'Must be on detail page before testing pop transition',
      );

      // Pop (simulates back button).
      setup.router.pop();

      // Pump a single frame to start the reverse transition.
      await tester.pump();

      // Pump a partial duration — the reverse animation should be
      // in progress.
      await tester.pump(const Duration(milliseconds: 100));

      // Look for active transition widgets mid-animation.
      final slideTransitions = find.byType(SlideTransition);
      final fadeTransitions = find.byType(FadeTransition);

      final hasAnimatingTransition = slideTransitions.evaluate().isNotEmpty ||
          fadeTransitions.evaluate().isNotEmpty;

      expect(hasAnimatingTransition, isTrue,
          reason: 'Pop navigation must produce a SlideTransition or '
              'FadeTransition — not instant removal '
              '(INV-TRANSITION-2)');

      // Verify the reverse animation is in progress.
      if (slideTransitions.evaluate().isNotEmpty) {
        final slide = tester.widget<SlideTransition>(slideTransitions.first);
        expect(slide.position.value, isNot(equals(Offset.zero)),
            reason: 'Slide reverse animation must be in progress at '
                '100ms — not yet at rest position (INV-TRANSITION-2)');
      } else if (fadeTransitions.evaluate().isNotEmpty) {
        final fade = tester.widget<FadeTransition>(fadeTransitions.first);
        expect(fade.opacity.value, greaterThan(0.0),
            reason: 'Fade reverse animation must be in progress at '
                '100ms — not yet fully transparent (INV-TRANSITION-2)');
        expect(fade.opacity.value, lessThan(1.0),
            reason: 'Fade reverse animation must not be at full '
                'opacity (INV-TRANSITION-2)');
      }

      // Let the animation complete.
      await tester.pumpAndSettle();

      // Verify we returned to /home.
      expect(
        setup.router.routeInformationProvider.value.uri.path,
        '/home',
        reason: 'Must return to /home after pop transition completes',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Fakes — same pattern as navigation_linearity_test.dart
// ---------------------------------------------------------------------------

class _StallingSplashController extends SplashController {
  @override
  Future<void> build() => Completer<void>().future;
}

class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }
}

class _TestHomeListStore extends HomeListStore {
  @override
  HomeListState build() => const HomeListState();
}
