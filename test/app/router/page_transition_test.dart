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
///
/// Each entry maps a route path to its concrete test URI and pathParameters,
/// so pageBuilder(...) can be called without throwing on missing params.
const _pushTargetRoutes = <_RouteTestSpec>[
  _RouteTestSpec(
    path: '/servers/:serverId/channels/:channelId',
    testUri: '/servers/s1/channels/ch1',
    pathParameters: {'serverId': 's1', 'channelId': 'ch1'},
  ),
  _RouteTestSpec(
    path: '/servers/:serverId/channels/:channelId/members',
    testUri: '/servers/s1/channels/ch1/members',
    pathParameters: {'serverId': 's1', 'channelId': 'ch1'},
  ),
  _RouteTestSpec(
    path: '/servers/:serverId/channels/:channelId/pinned',
    testUri: '/servers/s1/channels/ch1/pinned',
    pathParameters: {'serverId': 's1', 'channelId': 'ch1'},
  ),
  _RouteTestSpec(
    path: '/servers/:serverId/channels/:channelId/files',
    testUri: '/servers/s1/channels/ch1/files',
    pathParameters: {'serverId': 's1', 'channelId': 'ch1'},
  ),
  _RouteTestSpec(
    path: '/servers/:serverId/dms/:channelId',
    testUri: '/servers/s1/dms/dm1',
    pathParameters: {'serverId': 's1', 'channelId': 'dm1'},
  ),
  _RouteTestSpec(
    path: '/servers/:serverId/threads/:threadId/replies',
    testUri: '/servers/s1/threads/t1/replies?channelId=ch1',
    pathParameters: {'serverId': 's1', 'threadId': 't1'},
  ),
  _RouteTestSpec(
    path: '/servers/:serverId/tasks',
    testUri: '/servers/s1/tasks',
    pathParameters: {'serverId': 's1'},
  ),
  _RouteTestSpec(
    path: '/servers/:serverId/search',
    testUri: '/servers/s1/search',
    pathParameters: {'serverId': 's1'},
  ),
  _RouteTestSpec(
    path: '/settings',
    testUri: '/settings',
    pathParameters: {},
  ),
  _RouteTestSpec(
    path: '/profile',
    testUri: '/profile',
    pathParameters: {},
  ),
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

/// Creates a GoRouterState with concrete pathParameters and URI
/// suitable for calling route.pageBuilder without missing-param errors.
GoRouterState _makeTestState(_RouteTestSpec spec) {
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
    uri: Uri.parse(spec.testUri),
    matchedLocation: spec.testUri.split('?').first,
    fullPath: spec.path,
    pathParameters: spec.pathParameters,
    pageKey: ValueKey<String>(spec.testUri),
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
    skip: false,
    (tester) async {
      // Need tester.pumpWidget for a valid BuildContext.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(SizedBox));

      final container = _createContainer();
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      final routes = router.configuration.routes;

      for (final spec in _pushTargetRoutes) {
        final route = _findRoute(routes, spec.path);
        expect(route, isNotNull,
            reason: 'Route ${spec.path} must exist in production router');
        expect(route!.pageBuilder, isNotNull,
            reason: 'Route ${spec.path} must use pageBuilder (not builder) '
                '(INV-TRANSITION-1)');

        // Call pageBuilder and verify the returned page type + duration.
        final state = _makeTestState(spec);
        final page = route.pageBuilder!(context, state);
        expect(page, isA<CustomTransitionPage>(),
            reason: 'Route ${spec.path} pageBuilder must return '
                'CustomTransitionPage (INV-TRANSITION-1)');

        final customPage = page as CustomTransitionPage;
        expect(customPage.transitionDuration, greaterThan(Duration.zero),
            reason: 'Route ${spec.path} must have transitionDuration > 0 '
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
    skip: false,
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(SizedBox));

      final container = _createContainer();
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      final routes = router.configuration.routes;

      // Representative subset for pop assertions.
      const popTargetSpecs = [
        _RouteTestSpec(
          path: '/servers/:serverId/channels/:channelId',
          testUri: '/servers/s1/channels/ch1',
          pathParameters: {'serverId': 's1', 'channelId': 'ch1'},
        ),
        _RouteTestSpec(
          path: '/servers/:serverId/dms/:channelId',
          testUri: '/servers/s1/dms/dm1',
          pathParameters: {'serverId': 's1', 'channelId': 'dm1'},
        ),
        _RouteTestSpec(
          path: '/servers/:serverId/threads/:threadId/replies',
          testUri: '/servers/s1/threads/t1/replies?channelId=ch1',
          pathParameters: {'serverId': 's1', 'threadId': 't1'},
        ),
        _RouteTestSpec(
          path: '/settings',
          testUri: '/settings',
          pathParameters: {},
        ),
        _RouteTestSpec(
          path: '/profile',
          testUri: '/profile',
          pathParameters: {},
        ),
      ];

      for (final spec in popTargetSpecs) {
        final route = _findRoute(routes, spec.path);
        expect(route, isNotNull,
            reason: 'Route ${spec.path} must exist in production router');
        expect(route!.pageBuilder, isNotNull,
            reason: 'Route ${spec.path} must use pageBuilder (not builder) '
                '(INV-TRANSITION-2)');

        final state = _makeTestState(spec);
        final page = route.pageBuilder!(context, state);
        expect(page, isA<CustomTransitionPage>(),
            reason: 'Route ${spec.path} pageBuilder must return '
                'CustomTransitionPage (INV-TRANSITION-2)');

        final customPage = page as CustomTransitionPage;
        expect(
          customPage.reverseTransitionDuration,
          greaterThan(Duration.zero),
          reason: 'Route ${spec.path} must have '
              'reverseTransitionDuration > 0 '
              'for animated pop (INV-TRANSITION-2)',
        );
      }
    },
  );
}

// ---------------------------------------------------------------------------
// Route test specification — maps a route path to concrete test parameters
// so pageBuilder can be called with valid pathParameters/uri.
// ---------------------------------------------------------------------------

class _RouteTestSpec {
  const _RouteTestSpec({
    required this.path,
    required this.testUri,
    required this.pathParameters,
  });

  /// The GoRoute path pattern (e.g. '/servers/:serverId/channels/:channelId').
  final String path;

  /// Concrete URI for constructing GoRouterState
  /// (e.g. '/servers/s1/channels/ch1').
  final String testUri;

  /// Concrete path parameters matching the route's :param placeholders.
  final Map<String, String> pathParameters;
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
  HomeListState build() => HomeListState();
}
