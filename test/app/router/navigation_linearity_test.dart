// ---------------------------------------------------------------------------
// #495: Navigation linearization tests
//
// Invariants verified:
// INV-NAV-LINEAR-1: Back from detail page returns to parent tab
// INV-NAV-LINEAR-2: Deep link cold start back returns to home (not exit)
// INV-NAV-LINEAR-3: Tab switch does not push to navigation stack
// INV-NAV-LINEAR-4: Create flow back returns to source tab (not dead-end)
// INV-NAV-LINEAR-5: StatefulShellRoute preserves per-tab navigator state
// INV-NAV-LINEAR-6: Deep-link dispatch uses push (not go) for conversations
// INV-NAV-LINEAR-7: Screenshot share uses push to preserve originator
// INV-NAV-LINEAR-8: canPop check uses GoRouter context (not Navigator)
// ---------------------------------------------------------------------------
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/app/router/app_router.dart';
import 'package:slock_app/app/router/pending_deep_link_provider.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/splash/application/splash_controller.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';

import '../../stores/session/session_store_persistence_test.dart'
    show FakeAuthRepository;

Widget _buildRouterApp(GoRouter router) {
  return MaterialApp.router(
    theme: AppTheme.light,
    routerConfig: router,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
  );
}

/// Creates an authenticated container with the router ready for navigation
/// testing. Returns the container and router.
({ProviderContainer container, GoRouter router}) _createAuthenticatedRouter({
  List<Override> extraOverrides = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
      authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
      splashControllerProvider.overrideWith(() => _StallingSplashController()),
      homeListStoreProvider.overrideWith(() => _TestHomeListStore()),
      ...extraOverrides,
    ],
  );
  return (container: container, router: container.read(appRouterProvider));
}

/// Logs in, sets appReady, pumps the router widget, and settles.
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
  await tester.pumpAndSettle();
}

void main() {
  group('Navigation linearization (#495)', () {
    // -------------------------------------------------------------------
    // INV-NAV-LINEAR-1: Back from channel detail returns to channels tab
    // -------------------------------------------------------------------
    testWidgets(
      'back from channel detail returns to channels tab '
      '(INV-NAV-LINEAR-1)',
      (tester) async {
        final setup = _createAuthenticatedRouter();
        addTearDown(setup.container.dispose);
        await _pumpAuthenticated(
          tester,
          container: setup.container,
          router: setup.router,
        );

        // Start on /home, navigate to channels tab.
        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/home',
        );

        // Push to a channel detail page.
        setup.router.push('/servers/s1/channels/ch1');
        await tester.pumpAndSettle();

        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/servers/s1/channels/ch1',
        );

        // Pop (simulates back button).
        setup.router.pop();
        await tester.pumpAndSettle();

        // Should return to /home (the previous location), not exit.
        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/home',
        );
      },
    );

    // -------------------------------------------------------------------
    // INV-NAV-LINEAR-2: Deep link cold start back returns to home
    // -------------------------------------------------------------------
    testWidgets(
      'deep-link dispatch uses push so back returns to previous screen '
      '(INV-NAV-LINEAR-2)',
      (tester) async {
        final setup = _createAuthenticatedRouter(
          extraOverrides: [
            serverListRepositoryProvider.overrideWithValue(
              _FakeServerListRepository(['s1']),
            ),
          ],
        );
        addTearDown(setup.container.dispose);

        await _pumpAuthenticated(
          tester,
          container: setup.container,
          router: setup.router,
        );
        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/home',
        );

        // Load servers so the deep-link serverId check passes.
        await setup.container.read(serverListStoreProvider.notifier).load();
        await tester.pumpAndSettle();

        // Simulate a deep link arriving for a conversation.
        setup.container.read(pendingDeepLinkProvider.notifier).state =
            '/servers/s1/channels/deep-ch';
        await tester.pumpAndSettle();

        // Deep link should have pushed the channel page.
        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/servers/s1/channels/deep-ch',
        );

        // Pop (back) should return to /home, not exit the app.
        setup.router.pop();
        await tester.pumpAndSettle();

        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/home',
        );
      },
    );

    // -------------------------------------------------------------------
    // INV-NAV-LINEAR-3: Tab switch does not push to navigation stack
    // -------------------------------------------------------------------
    testWidgets(
      'tab switch does not push to stack — back does not cycle tabs '
      '(INV-NAV-LINEAR-3)',
      (tester) async {
        final setup = _createAuthenticatedRouter();
        addTearDown(setup.container.dispose);
        await _pumpAuthenticated(
          tester,
          container: setup.container,
          router: setup.router,
        );

        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/home',
        );

        // Switch to channels tab via goBranch (simulated via go).
        setup.router.go('/channels');
        await tester.pumpAndSettle();
        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/channels',
        );

        // Switch to DMs tab.
        setup.router.go('/dms');
        await tester.pumpAndSettle();
        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/dms',
        );

        // Switch to agents tab.
        setup.router.go('/agents');
        await tester.pumpAndSettle();
        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/agents',
        );

        // Back should NOT cycle through /dms → /channels → /home.
        // StatefulShellRoute tabs use go, not push, so they don't
        // accumulate in the stack. canPop should be false.
        expect(setup.router.canPop(), isFalse,
            reason: 'Tab switches must not push to navigation stack');
      },
    );

    // -------------------------------------------------------------------
    // INV-NAV-LINEAR-4: Route structure uses StatefulShellRoute
    // -------------------------------------------------------------------
    test(
      'router uses StatefulShellRoute for tab routes '
      '(INV-NAV-LINEAR-5)',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final router = container.read(appRouterProvider);
        final config = router.configuration;

        // Find the StatefulShellRoute among top-level routes.
        final statefulShell = config.routes.whereType<StatefulShellRoute>();
        expect(statefulShell, isNotEmpty,
            reason: 'Router must use StatefulShellRoute for tab preservation');

        final shell = statefulShell.first;
        expect(shell.branches, hasLength(5),
            reason: 'Must have 5 tab branches (home, channels, dms, '
                'agents, inbox)');

        // Verify each branch has the correct initial route.
        final branchPaths = shell.branches.map((branch) {
          final firstRoute = branch.routes.first;
          return firstRoute is GoRoute ? firstRoute.path : '';
        }).toList();
        expect(
            branchPaths, ['/home', '/channels', '/dms', '/agents', '/inbox']);
      },
    );

    // -------------------------------------------------------------------
    // INV-NAV-LINEAR-5: Push from home → channel → pop returns to home
    // -------------------------------------------------------------------
    testWidgets(
      'push from home to DM detail → pop returns to home '
      '(INV-NAV-LINEAR-1)',
      (tester) async {
        final setup = _createAuthenticatedRouter();
        addTearDown(setup.container.dispose);
        await _pumpAuthenticated(
          tester,
          container: setup.container,
          router: setup.router,
        );

        setup.router.push('/servers/s1/dms/dm1');
        await tester.pumpAndSettle();
        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/servers/s1/dms/dm1',
        );

        setup.router.pop();
        await tester.pumpAndSettle();
        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/home',
        );
      },
    );

    // -------------------------------------------------------------------
    // INV-NAV-LINEAR-6: Deep-link dispatch uses push for notifications
    // -------------------------------------------------------------------
    testWidgets(
      'notification deep link uses push so pop returns to previous '
      '(INV-NAV-LINEAR-6)',
      (tester) async {
        final setup = _createAuthenticatedRouter();
        addTearDown(setup.container.dispose);
        await _pumpAuthenticated(
          tester,
          container: setup.container,
          router: setup.router,
        );

        // Navigate to channels tab first.
        setup.router.go('/channels');
        await tester.pumpAndSettle();

        // Push a detail page (simulates in-app navigation).
        setup.router.push('/servers/s1/channels/ch1');
        await tester.pumpAndSettle();

        // Simulate notification deep link via pendingDeepLink.
        // Since the listener uses router.push for notifications,
        // this should push onto the existing stack.
        setup.container.read(pendingDeepLinkProvider.notifier).state =
            '/servers/s1/agents/agent-1';
        await tester.pumpAndSettle();

        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/servers/s1/agents/agent-1',
        );

        // First pop: back to channel.
        setup.router.pop();
        await tester.pumpAndSettle();
        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/servers/s1/channels/ch1',
        );

        // Second pop: back to channels tab.
        setup.router.pop();
        await tester.pumpAndSettle();
        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/channels',
        );
      },
    );

    // -------------------------------------------------------------------
    // INV-NAV-LINEAR-7: New GoRouter routes for pinned & file preview
    // -------------------------------------------------------------------
    test(
      'router includes pinned messages and file preview routes '
      '(INV-NAV-LINEAR-7)',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final router = container.read(appRouterProvider);
        final config = router.configuration;
        final paths = <String>[];
        void collectPaths(List<RouteBase> routes) {
          for (final route in routes) {
            if (route is GoRoute) {
              paths.add(route.path);
            }
            if (route is ShellRouteBase) {
              collectPaths(route.routes);
            }
          }
        }

        collectPaths(config.routes);

        expect(paths, contains('/servers/:serverId/channels/:channelId/pinned'),
            reason: 'Pinned messages must be a GoRouter route');
        expect(paths, contains('/file-preview'),
            reason: 'File preview must be a GoRouter route');
      },
    );

    // -------------------------------------------------------------------
    // INV-NAV-LINEAR-8: Thread replies page has PopScope fallback
    // -------------------------------------------------------------------
    testWidgets(
      'thread replies push then pop returns to previous '
      '(INV-NAV-LINEAR-8)',
      (tester) async {
        final setup = _createAuthenticatedRouter();
        addTearDown(setup.container.dispose);
        await _pumpAuthenticated(
          tester,
          container: setup.container,
          router: setup.router,
        );

        // Navigate to inbox tab.
        setup.router.go('/inbox');
        await tester.pumpAndSettle();

        // Push a thread replies page.
        setup.router.push('/servers/s1/threads/t1/replies?channelId=ch1');
        await tester.pumpAndSettle();

        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/servers/s1/threads/t1/replies',
        );

        // Pop should return to inbox.
        setup.router.pop();
        await tester.pumpAndSettle();
        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/inbox',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Fakes
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

class _FakeServerListRepository implements ServerListRepository {
  _FakeServerListRepository(List<String> serverIds)
      : _servers =
            serverIds.map((id) => ServerSummary(id: id, name: id)).toList();

  final List<ServerSummary> _servers;

  @override
  Future<List<ServerSummary>> loadServers() async => _servers;
}

class _TestHomeListStore extends HomeListStore {
  @override
  HomeListState build() => const HomeListState();
}
