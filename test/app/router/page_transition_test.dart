import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
// Verifies that push-target GoRoute definitions in the real appRouterProvider
// use pageBuilder → CustomTransitionPage with non-zero transition durations.
//
// Tests exercise the real appRouterProvider — not a test-supplied harness.
// They call each route's pageBuilder and verify:
//   1. pageBuilder != null (not plain builder:)
//   2. Returned page is CustomTransitionPage
//   3. transitionDuration > Duration.zero (INV-TRANSITION-1)
//   4. reverseTransitionDuration > Duration.zero (INV-TRANSITION-2)
//
// Currently all routes use builder: (0 pageBuilder:), so tests fail when
// un-skipped. Phase B converts them to pageBuilder: + CustomTransitionPage.
//
// Invariants:
//   INV-TRANSITION-1: Push-target routes → CustomTransitionPage with
//                     transitionDuration > 0 (animated forward push)
//   INV-TRANSITION-2: Push-target routes → CustomTransitionPage with
//                     reverseTransitionDuration > 0 (animated pop)
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

/// Minimal ValueListenable wrapper for RouteConfiguration construction.
/// Needed to create GoRouterState for calling pageBuilder.
class _ConstantRoutingConfig extends ValueListenable<RoutingConfig> {
  const _ConstantRoutingConfig(this.value);
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
  @override
  final RoutingConfig value;
}

/// Creates a minimal GoRouterState suitable for calling route.pageBuilder.
GoRouterState _makeTestState(String path) {
  final configuration = RouteConfiguration(
    _ConstantRoutingConfig(
      RoutingConfig(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const SizedBox(),
          ),
        ],
      ),
    ),
    navigatorKey: GlobalKey<NavigatorState>(),
  );
  return GoRouterState(
    configuration,
    uri: Uri.parse(path),
    matchedLocation: path,
    fullPath: path,
    pathParameters: const {},
    pageKey: ValueKey<String>(path),
  );
}

void main() {
  // -----------------------------------------------------------------------
  // INV-TRANSITION-1: Push-target routes produce CustomTransitionPage with
  //                   transitionDuration > Duration.zero.
  //
  // For each push-target path:
  //   1. Find the GoRoute in the real appRouterProvider configuration
  //   2. Assert pageBuilder is not null (not plain builder:)
  //   3. Call pageBuilder and assert the returned page is CustomTransitionPage
  //   4. Assert transitionDuration > Duration.zero
  //
  // Currently FAILS: all routes use builder: (pageBuilder is null).
  // Phase B converts them to pageBuilder: + CustomTransitionPage.
  // -----------------------------------------------------------------------
  testWidgets(
    'push-target routes use CustomTransitionPage with non-zero '
    'transitionDuration (INV-TRANSITION-1)',
    skip: true,
    (tester) async {
      // Need tester.pumpWidget for a valid BuildContext.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(SizedBox));

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
                '(INV-TRANSITION-1)');

        // Call pageBuilder and verify the returned page type + duration.
        final state = _makeTestState(path);
        final page = route.pageBuilder!(context, state);
        expect(page, isA<CustomTransitionPage>(),
            reason: 'Route $path pageBuilder must return '
                'CustomTransitionPage (INV-TRANSITION-1)');

        final customPage = page as CustomTransitionPage;
        expect(customPage.transitionDuration, greaterThan(Duration.zero),
            reason: 'Route $path must have transitionDuration > 0 '
                'for animated push (INV-TRANSITION-1)');
      }
    },
  );

  // -----------------------------------------------------------------------
  // INV-TRANSITION-2: Push-target routes produce CustomTransitionPage with
  //                   reverseTransitionDuration > Duration.zero.
  //
  // Same structural check as INV-TRANSITION-1 but focused on reverse
  // (pop) animation. CustomTransitionPage with reverseTransitionDuration > 0
  // ensures pop is animated, not instant.
  //
  // Currently FAILS: all routes use builder: (pageBuilder is null).
  // Phase B converts them to pageBuilder: + CustomTransitionPage.
  // -----------------------------------------------------------------------
  testWidgets(
    'push-target routes use CustomTransitionPage with non-zero '
    'reverseTransitionDuration (INV-TRANSITION-2)',
    skip: true,
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(SizedBox));

      final container = _createContainer();
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      final routes = router.configuration.routes;

      // Representative subset for pop assertions.
      const popTargets = [
        '/servers/:serverId/channels/:channelId',
        '/servers/:serverId/dms/:channelId',
        '/servers/:serverId/threads/:threadId/replies',
        '/settings',
        '/profile',
      ];

      for (final path in popTargets) {
        final route = _findRoute(routes, path);
        expect(route, isNotNull,
            reason: 'Route $path must exist in production router');
        expect(route!.pageBuilder, isNotNull,
            reason: 'Route $path must use pageBuilder (not builder) '
                '(INV-TRANSITION-2)');

        final state = _makeTestState(path);
        final page = route.pageBuilder!(context, state);
        expect(page, isA<CustomTransitionPage>(),
            reason: 'Route $path pageBuilder must return '
                'CustomTransitionPage (INV-TRANSITION-2)');

        final customPage = page as CustomTransitionPage;
        expect(
          customPage.reverseTransitionDuration,
          greaterThan(Duration.zero),
          reason: 'Route $path must have reverseTransitionDuration > 0 '
              'for animated pop (INV-TRANSITION-2)',
        );
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
