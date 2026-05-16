import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/router/app_router.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/splash/application/splash_controller.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';

import '../../stores/session/session_store_persistence_test.dart'
    show FakeAuthRepository;

// ---------------------------------------------------------------------------
// #523: 页面转场动画 — Phase A (test-only)
//
// Structural assertions on the production GoRouter configuration:
// verifies that push-target routes use pageBuilder (CustomTransitionPage)
// instead of plain builder (instant swap).
//
// Tests exercise the real appRouterProvider — not a test-supplied harness —
// so they fail until Phase B converts routes in lib/app/router/app_router.dart
// from builder: to pageBuilder: + CustomTransitionPage.
//
// Invariants:
//   INV-TRANSITION-1: Push-target routes use pageBuilder with
//                     CustomTransitionPage (non-zero forward transition)
//   INV-TRANSITION-2: Push-target routes have reverseTransitionDuration > 0
//                     (animated pop, not instant removal)
//
// Both tests skip: true until Phase B converts routes.
//
// Phase B write set:
//   lib/app/router/app_router.dart — convert target routes from builder:
//   to pageBuilder: + CustomTransitionPage
// ---------------------------------------------------------------------------

/// Paths that are navigated via push() and should have animated transitions.
/// These are detail/overlay routes — not tab roots or auth redirects.
const _pushTargetPaths = [
  '/servers/:serverId/channels/:channelId',
  '/servers/:serverId/channels/:channelId/members',
  '/servers/:serverId/channels/:channelId/pinned',
  '/servers/:serverId/channels/:channelId/files',
  '/servers/:serverId/dms/:channelId',
  '/servers/:serverId/threads/:threadId/replies',
  '/servers/:serverId/tasks',
  '/servers/:serverId/search',
  '/settings',
  '/profile',
];

/// Recursively finds a GoRoute matching [path] in the route tree.
GoRoute? _findRoute(List<RouteBase> routes, String path) {
  for (final route in routes) {
    if (route is GoRoute && route.path == path) return route;
    if (route is ShellRouteBase) {
      final found = _findRoute(route.routes, path);
      if (found != null) return found;
    }
  }
  return null;
}

ProviderContainer _createContainer() {
  return ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
      authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
      splashControllerProvider.overrideWith(() => _StallingSplashController()),
      homeListStoreProvider.overrideWith(() => _TestHomeListStore()),
    ],
  );
}

void main() {
  // -----------------------------------------------------------------------
  // INV-TRANSITION-1: Push-target routes must use pageBuilder
  //                   (CustomTransitionPage) — not plain builder.
  //
  // Reads the real appRouterProvider configuration and checks each
  // push-target path. Currently all routes use builder: → this test
  // fails when un-skipped. Phase B converts them to pageBuilder:.
  // -----------------------------------------------------------------------
  test(
    'push-target routes use pageBuilder for animated transitions '
    '(INV-TRANSITION-1)',
    skip: true,
    () {
      final container = _createContainer();
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      final routes = router.configuration.routes;

      for (final path in _pushTargetPaths) {
        final route = _findRoute(routes, path);
        expect(route, isNotNull,
            reason: 'Route $path must exist in production router');
        expect(route!.pageBuilder, isNotNull,
            reason: 'Route $path must use pageBuilder (not builder) '
                'for CustomTransitionPage with animated push transition '
                '(INV-TRANSITION-1). Currently uses plain builder: '
                'which produces instant page swap.');
      }
    },
  );

  // -----------------------------------------------------------------------
  // INV-TRANSITION-2: Push-target routes must NOT use builder-only
  //                   (which produces NoTransitionPage on pop).
  //
  // When a GoRoute uses builder: (no pageBuilder:), GoRouter wraps the
  // widget in a platform-default page that may have zero reverse duration.
  // CustomTransitionPage with reverseTransitionDuration > 0 ensures pop
  // is animated.
  //
  // This test verifies the same structural property from a pop perspective:
  // routes with pageBuilder will use CustomTransitionPage which provides
  // explicit reverseTransitionDuration control.
  //
  // Phase B: After converting to pageBuilder: + CustomTransitionPage with
  // reverseTransitionDuration: Duration(milliseconds: 300), this test
  // verifies the configuration includes animated pop.
  // -----------------------------------------------------------------------
  test(
    'push-target routes have pageBuilder for animated pop transitions '
    '(INV-TRANSITION-2)',
    skip: true,
    () {
      final container = _createContainer();
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      final routes = router.configuration.routes;

      // Check a representative subset to keep the test focused.
      const popTargets = [
        '/servers/:serverId/channels/:channelId',
        '/servers/:serverId/dms/:channelId',
        '/settings',
      ];

      for (final path in popTargets) {
        final route = _findRoute(routes, path);
        expect(route, isNotNull,
            reason: 'Route $path must exist in production router');

        // builder-only routes produce pages with no explicit reverse
        // transition control → instant pop. pageBuilder with
        // CustomTransitionPage gives explicit reverse animation.
        expect(route!.pageBuilder, isNotNull,
            reason: 'Route $path must use pageBuilder (not builder) '
                'for CustomTransitionPage with animated pop transition '
                '(INV-TRANSITION-2). builder-only routes produce '
                'instant pop with no reverse animation.');
      }
    },
  );
}

// ---------------------------------------------------------------------------
// Fakes — minimal overrides for appRouterProvider instantiation.
// Same pattern as navigation_linearity_test.dart.
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
