// ---------------------------------------------------------------------------
// #495: Navigation linearization tests
//
// Invariants verified:
// INV-NAV-LINEAR-1: Back from detail page returns to parent tab
// INV-NAV-LINEAR-2: Mid-session deep link pushes onto stack, pop returns
// INV-NAV-LINEAR-3: Tab switch does not push to navigation stack
// INV-NAV-LINEAR-4: StatefulShellRoute with 5 per-tab branches
// INV-NAV-LINEAR-5: Push from home → detail → pop returns to home
// INV-NAV-LINEAR-6: Mid-session deep-link push preserves stack (pop returns)
// INV-NAV-LINEAR-7: New GoRouter routes for pinned & file preview
// INV-NAV-LINEAR-8: PopScope on key detail pages for empty-stack fallback
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
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;
import 'package:shared_preferences/shared_preferences.dart';

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
  SharedPreferences? prefs,
}) {
  final container = ProviderContainer(
    overrides: [
      if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
      secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
      authRepositoryProvider.overrideWithValue(const FakeAuthRepository()),
      splashControllerProvider.overrideWith(() => _StallingSplashController()),
      homeListStoreProvider.overrideWith(() => _TestHomeListStore()),
      ...extraOverrides,
    ],
  );
  return (container: container, router: container.read(appRouterProvider));
}

/// Logs in, sets appReady, pumps the router widget, and settles on /home.
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
  // Use pump() instead of pumpAndSettle() — the StatefulShellRoute
  // keeps all tab branches built simultaneously, and some may contain
  // perpetual animations (CircularProgressIndicator) that prevent
  // pumpAndSettle from returning.
  await _pumpNavigation(tester);
}

/// Helper: pump a few frames to let the router settle after navigation.
/// Detail pages (channels, DMs, threads) have perpetual animations
/// (CircularProgressIndicator) that prevent pumpAndSettle from returning.
Future<void> _pumpNavigation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('Navigation linearization (#495)', () {
    // -------------------------------------------------------------------
    // INV-NAV-LINEAR-1: Push channel → pop → returns to /home
    // -------------------------------------------------------------------
    testWidgets(
      'push from home to channel detail → pop returns to home '
      '(INV-NAV-LINEAR-1)',
      (tester) async {
        final setup = _createAuthenticatedRouter(prefs: prefs);
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

        // Push to a channel detail page.
        setup.router.push('/servers/s1/channels/ch1');
        // Use pump() — detail pages have perpetual loading animations.
        await _pumpNavigation(tester);

        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/servers/s1/channels/ch1',
        );

        // Pop (simulates back button).
        setup.router.pop();
        await _pumpNavigation(tester);

        // Should return to /home (the previous location), not exit.
        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/home',
        );
      },
    );

    // -------------------------------------------------------------------
    // INV-NAV-LINEAR-2: Mid-session deep link pushes onto stack
    // -------------------------------------------------------------------
    testWidgets(
      'mid-session deep link pushes onto stack — pop returns to previous '
      '(INV-NAV-LINEAR-2)',
      (tester) async {
        final setup = _createAuthenticatedRouter(
          prefs: prefs,
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
        await _pumpNavigation(tester);

        // Simulate a mid-session deep link arriving for a conversation.
        setup.container.read(pendingDeepLinkProvider.notifier).state =
            '/servers/s1/channels/deep-ch';
        // Extra pump for addPostFrameCallback + navigation settle.
        await _pumpNavigation(tester);
        await _pumpNavigation(tester);

        // Deep link navigates to the target page via push.
        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/servers/s1/channels/deep-ch',
        );
        // Pending link is consumed.
        expect(setup.container.read(pendingDeepLinkProvider), isNull);
        // Stack should be poppable (pushed, not replaced).
        expect(setup.router.canPop(), isTrue,
            reason: 'Deep-link push must leave stack poppable');

        // Pop should return to previous screen (/home).
        setup.router.pop();
        await _pumpNavigation(tester);
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
        final setup = _createAuthenticatedRouter(prefs: prefs);
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

        // Switch to channels tab.
        setup.router.go('/channels');
        await _pumpNavigation(tester);
        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/channels',
        );

        // Switch to DMs tab.
        setup.router.go('/dms');
        await _pumpNavigation(tester);
        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/dms',
        );

        // Switch to agents tab.
        setup.router.go('/agents');
        await _pumpNavigation(tester);
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
      '(INV-NAV-LINEAR-4)',
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
    // INV-NAV-LINEAR-5: Push DM detail → pop → returns to /home
    // -------------------------------------------------------------------
    testWidgets(
      'push from home to DM detail → pop returns to home '
      '(INV-NAV-LINEAR-5)',
      (tester) async {
        final setup = _createAuthenticatedRouter(prefs: prefs);
        addTearDown(setup.container.dispose);
        await _pumpAuthenticated(
          tester,
          container: setup.container,
          router: setup.router,
        );

        setup.router.push('/servers/s1/dms/dm1');
        await _pumpNavigation(tester);
        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/servers/s1/dms/dm1',
        );

        setup.router.pop();
        await _pumpNavigation(tester);
        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/home',
        );
      },
    );

    // -------------------------------------------------------------------
    // INV-NAV-LINEAR-6: Push thread → pop → returns to inbox
    // -------------------------------------------------------------------
    testWidgets(
      'push from inbox to thread replies → pop returns to inbox '
      '(INV-NAV-LINEAR-6)',
      (tester) async {
        final setup = _createAuthenticatedRouter(prefs: prefs);
        addTearDown(setup.container.dispose);
        await _pumpAuthenticated(
          tester,
          container: setup.container,
          router: setup.router,
        );

        // Navigate to inbox tab.
        setup.router.go('/inbox');
        await _pumpNavigation(tester);

        // Push a thread replies page.
        setup.router.push('/servers/s1/threads/t1/replies?channelId=ch1');
        await _pumpNavigation(tester);

        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/servers/s1/threads/t1/replies',
        );

        // Pop should return to inbox.
        setup.router.pop();
        await _pumpNavigation(tester);
        expect(
          setup.router.routeInformationProvider.value.uri.path,
          '/inbox',
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
    // INV-NAV-LINEAR-8: canPop is true after push, false on shell root
    // -------------------------------------------------------------------
    testWidgets(
      'canPop is true after push from shell root, false on tab switch '
      '(INV-NAV-LINEAR-8)',
      (tester) async {
        final setup = _createAuthenticatedRouter(prefs: prefs);
        addTearDown(setup.container.dispose);
        await _pumpAuthenticated(
          tester,
          container: setup.container,
          router: setup.router,
        );

        // On /home — canPop should be false (shell root).
        expect(setup.router.canPop(), isFalse,
            reason: 'Shell root must not be poppable');

        // Push a detail page — canPop should become true.
        setup.router.push('/servers/s1/channels/ch1');
        await _pumpNavigation(tester);
        expect(setup.router.canPop(), isTrue,
            reason: 'Pushed page must be poppable');

        // Pop back — canPop should be false again.
        setup.router.pop();
        await _pumpNavigation(tester);
        expect(setup.router.canPop(), isFalse,
            reason: 'After pop back to shell root, must not be poppable');

        // Switch to agents tab via go — canPop should remain false.
        setup.router.go('/agents');
        await _pumpNavigation(tester);
        expect(setup.router.canPop(), isFalse,
            reason: 'Tab switch via go must not make stack poppable');
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
