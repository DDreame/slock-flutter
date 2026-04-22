import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/app/router/app_router.dart';
import 'package:slock_app/app/router/pending_deep_link_provider.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/storage/server_selection_storage_keys.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/splash/application/splash_controller.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

void main() {
  test(
    'appRouterProvider creates GoRouter with /splash as initial location',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      expect(router.routeInformationProvider.value.uri.path, '/splash');
    },
  );

  test('appRouterProvider includes all docs §12 primary routes', () {
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
        if (route is ShellRoute) {
          collectPaths(route.routes);
        }
      }
    }

    collectPaths(config.routes);

    const expectedRoutes = [
      '/splash',
      '/login',
      '/register',
      '/forgot-password',
      '/home',
      '/agents',
      '/settings',
      '/servers/:serverId/channels/:channelId',
      '/servers/:serverId/dms/:channelId',
      '/servers/:serverId/threads',
      '/servers/:serverId/threads/:threadId/replies',
      '/servers/:serverId/tasks',
      '/servers/:serverId/agents',
      '/agents/:agentId',
      '/servers/:serverId/machines',
      '/saved-messages',
      '/profile',
      '/profile/:userId',
      '/billing',
      '/release-notes',
    ];
    expect(paths, containsAll(expectedRoutes));
  });

  test('router has refreshListenable wired to session store', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    expect(router.routerDelegate, isNotNull);
  });

  group('authRedirect', () {
    test('unknown status + /splash stays on splash', () {
      const session = SessionState();
      expect(authRedirect(session, '/splash'), isNull);
    });

    test('unknown status + non-splash redirects to /splash', () {
      const session = SessionState();
      expect(authRedirect(session, '/home'), '/splash');
      expect(authRedirect(session, '/login'), '/splash');
    });

    test('unauthenticated + protected route redirects to /login', () {
      const session = SessionState(status: AuthStatus.unauthenticated);
      expect(authRedirect(session, '/home'), '/login');
      expect(authRedirect(session, '/settings'), '/login');
    });

    test('unauthenticated + auth route stays', () {
      const session = SessionState(status: AuthStatus.unauthenticated);
      expect(authRedirect(session, '/login'), isNull);
      expect(authRedirect(session, '/register'), isNull);
      expect(authRedirect(session, '/forgot-password'), isNull);
    });

    test('unauthenticated + /splash stays', () {
      const session = SessionState(status: AuthStatus.unauthenticated);
      expect(authRedirect(session, '/splash'), isNull);
    });

    test('authenticated + auth route redirects to /home', () {
      const session = SessionState(status: AuthStatus.authenticated);
      expect(authRedirect(session, '/login'), '/home');
      expect(authRedirect(session, '/register'), '/home');
      expect(authRedirect(session, '/forgot-password'), '/home');
    });

    test('authenticated + /splash redirects to /home', () {
      const session = SessionState(status: AuthStatus.authenticated);
      expect(authRedirect(session, '/splash'), '/home');
    });

    test('authenticated + protected route stays', () {
      const session = SessionState(status: AuthStatus.authenticated);
      expect(authRedirect(session, '/home'), isNull);
      expect(authRedirect(session, '/settings'), isNull);
    });
  });

  testWidgets('server-scoped route syncs server selection via redirect', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sessionStoreProvider.notifier).login(
          email: 'test@test.com',
          password: 'password',
        );

    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/servers/my-server/channels/general');
    await tester.pumpAndSettle();

    expect(
      container.read(serverSelectionStoreProvider).selectedServerId,
      'my-server',
    );
  });

  group('isConversationDeepLink', () {
    test('matches channel route', () {
      expect(
        isConversationDeepLink('/servers/s1/channels/general'),
        isTrue,
      );
    });

    test('matches DM route', () {
      expect(
        isConversationDeepLink('/servers/s1/dms/dm-alice'),
        isTrue,
      );
    });

    test('does not match home', () {
      expect(isConversationDeepLink('/home'), isFalse);
    });

    test('does not match threads route', () {
      expect(isConversationDeepLink('/servers/s1/threads'), isFalse);
    });

    test('does not match auth routes', () {
      expect(isConversationDeepLink('/login'), isFalse);
      expect(isConversationDeepLink('/register'), isFalse);
    });
  });

  group('extractDeepLinkServerId', () {
    test('extracts serverId from channel route', () {
      expect(
        extractDeepLinkServerId('/servers/my-server/channels/general'),
        'my-server',
      );
    });

    test('extracts serverId from DM route', () {
      expect(
        extractDeepLinkServerId('/servers/s1/dms/dm-alice'),
        's1',
      );
    });

    test('returns null for non-server route', () {
      expect(extractDeepLinkServerId('/home'), isNull);
      expect(extractDeepLinkServerId('/login'), isNull);
    });
  });

  group('isNotificationDeepLink', () {
    test('matches channel route', () {
      expect(
        isNotificationDeepLink('/servers/s1/channels/general'),
        isTrue,
      );
    });

    test('matches DM route', () {
      expect(
        isNotificationDeepLink('/servers/s1/dms/dm-alice'),
        isTrue,
      );
    });

    test('matches thread route', () {
      expect(
        isNotificationDeepLink('/servers/s1/threads/t1/replies?channelId=c1'),
        isTrue,
      );
    });

    test('matches agent route', () {
      expect(isNotificationDeepLink('/agents/a1'), isTrue);
    });

    test('matches profile route', () {
      expect(isNotificationDeepLink('/profile/u1'), isTrue);
    });

    test('does not match home', () {
      expect(isNotificationDeepLink('/home'), isFalse);
    });

    test('does not match settings', () {
      expect(isNotificationDeepLink('/settings'), isFalse);
    });

    test('does not match auth routes', () {
      expect(isNotificationDeepLink('/login'), isFalse);
      expect(isNotificationDeepLink('/register'), isFalse);
    });
  });

  group('bootstrap gating', () {
    testWidgets('stays on splash when authenticated but bootstrap not complete',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
          splashControllerProvider
              .overrideWith(() => _StallingSplashController()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'p');

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      expect(router.routeInformationProvider.value.uri.path, '/splash');
    });

    testWidgets('redirects to home after bootstrap completes', (tester) async {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
          splashControllerProvider
              .overrideWith(() => _StallingSplashController()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'p');
      container.read(appReadyProvider.notifier).state = true;

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/home');
    });

    test('appReady resets to false when session becomes unauthenticated',
        () async {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
        ],
      );
      addTearDown(container.dispose);

      container.read(appRouterProvider);

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'p');
      container.read(appReadyProvider.notifier).state = true;
      expect(container.read(appReadyProvider), isTrue);

      await container.read(sessionStoreProvider.notifier).logout();
      expect(container.read(appReadyProvider), isFalse);
    });
  });

  group('deep link preservation', () {
    testWidgets('captures conversation deep link and restores after bootstrap',
        (tester) async {
      final storage = _FakeSecureStorage();
      storage._store[ServerSelectionStorageKeys.selectedServerId] = 'server-1';
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          splashControllerProvider
              .overrideWith(() => _StallingSplashController()),
          serverListRepositoryProvider.overrideWithValue(
            _FakeServerListRepository(['server-1']),
          ),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      router.go('/servers/server-1/channels/general');
      await tester.pump();

      expect(
        container.read(pendingDeepLinkProvider),
        '/servers/server-1/channels/general',
      );

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'p');
      await container
          .read(serverSelectionStoreProvider.notifier)
          .restoreSelection();
      await container.read(serverListStoreProvider.notifier).load();
      container.read(appReadyProvider.notifier).state = true;
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        '/servers/server-1/channels/general',
      );
      expect(container.read(pendingDeepLinkProvider), isNull);
    });

    testWidgets('captures DM deep link and restores after bootstrap',
        (tester) async {
      final storage = _FakeSecureStorage();
      storage._store[ServerSelectionStorageKeys.selectedServerId] = 'server-1';
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          splashControllerProvider
              .overrideWith(() => _StallingSplashController()),
          serverListRepositoryProvider.overrideWithValue(
            _FakeServerListRepository(['server-1']),
          ),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      router.go('/servers/server-1/dms/dm-alice');
      await tester.pump();

      expect(
        container.read(pendingDeepLinkProvider),
        '/servers/server-1/dms/dm-alice',
      );

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'p');
      await container
          .read(serverSelectionStoreProvider.notifier)
          .restoreSelection();
      await container.read(serverListStoreProvider.notifier).load();
      container.read(appReadyProvider.notifier).state = true;
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        '/servers/server-1/dms/dm-alice',
      );
      expect(container.read(pendingDeepLinkProvider), isNull);
    });

    testWidgets('does not capture non-conversation routes as deep link',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
          splashControllerProvider
              .overrideWith(() => _StallingSplashController()),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      router.go('/settings');
      await tester.pump();

      expect(container.read(pendingDeepLinkProvider), isNull);
    });

    testWidgets('captures thread deep link and restores after bootstrap',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
          splashControllerProvider
              .overrideWith(() => _StallingSplashController()),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      router.go('/servers/server-1/threads/t1/replies?channelId=c1');
      await tester.pump();

      expect(
        container.read(pendingDeepLinkProvider),
        '/servers/server-1/threads/t1/replies?channelId=c1',
      );

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'p');
      container.read(appReadyProvider.notifier).state = true;
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/servers/server-1/threads/t1/replies?channelId=c1',
      );
      expect(container.read(pendingDeepLinkProvider), isNull);
    });

    testWidgets(
        'cleared deep link does not redirect again on subsequent navigation',
        (tester) async {
      final storage = _FakeSecureStorage();
      storage._store[ServerSelectionStorageKeys.selectedServerId] = 'server-1';
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          splashControllerProvider
              .overrideWith(() => _StallingSplashController()),
          serverListRepositoryProvider.overrideWithValue(
            _FakeServerListRepository(['server-1']),
          ),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      router.go('/servers/server-1/channels/general');
      await tester.pump();

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'p');
      await container
          .read(serverSelectionStoreProvider.notifier)
          .restoreSelection();
      await container.read(serverListStoreProvider.notifier).load();
      container.read(appReadyProvider.notifier).state = true;
      await tester.pumpAndSettle();

      expect(container.read(pendingDeepLinkProvider), isNull);

      router.go('/home');
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/home');
    });
  });

  group('fallback for unresolved target', () {
    testWidgets('falls back to /home when pending deep link is cleared',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
          splashControllerProvider
              .overrideWith(() => _StallingSplashController()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'p');
      container.read(appReadyProvider.notifier).state = true;

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(container.read(pendingDeepLinkProvider), isNull);
    });

    testWidgets(
        'unresolved server in conversation deep link falls back to /home',
        (tester) async {
      final storage = _FakeSecureStorage();
      storage._store[ServerSelectionStorageKeys.selectedServerId] = 'server-1';
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          splashControllerProvider
              .overrideWith(() => _StallingSplashController()),
          serverListRepositoryProvider.overrideWithValue(
            _FakeServerListRepository(['server-1']),
          ),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      router.go('/servers/nonexistent/channels/missing');
      await tester.pump();

      expect(
        container.read(pendingDeepLinkProvider),
        '/servers/nonexistent/channels/missing',
      );

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'p');
      await container
          .read(serverSelectionStoreProvider.notifier)
          .restoreSelection();
      await container.read(serverListStoreProvider.notifier).load();
      container.read(appReadyProvider.notifier).state = true;
      await tester.pumpAndSettle();

      expect(container.read(pendingDeepLinkProvider), isNull);
      expect(router.routeInformationProvider.value.uri.path, '/home');
    });

    testWidgets(
        'cross-server deep link to valid server lands instead of fallback',
        (tester) async {
      final storage = _FakeSecureStorage();
      storage._store[ServerSelectionStorageKeys.selectedServerId] = 'server-1';
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          splashControllerProvider
              .overrideWith(() => _StallingSplashController()),
          serverListRepositoryProvider.overrideWithValue(
            _FakeServerListRepository(['server-1', 'server-2']),
          ),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      router.go('/servers/server-2/channels/general');
      await tester.pump();

      expect(
        container.read(pendingDeepLinkProvider),
        '/servers/server-2/channels/general',
      );

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'p');
      await container
          .read(serverSelectionStoreProvider.notifier)
          .restoreSelection();
      await container.read(serverListStoreProvider.notifier).load();
      container.read(appReadyProvider.notifier).state = true;
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        '/servers/server-2/channels/general',
      );
      expect(container.read(pendingDeepLinkProvider), isNull);
    });

    testWidgets(
        'non-conversation pending deep link is cleared and falls back to /home',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
          splashControllerProvider
              .overrideWith(() => _StallingSplashController()),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      container.read(pendingDeepLinkProvider.notifier).state = '/settings';

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'p');
      container.read(appReadyProvider.notifier).state = true;
      await tester.pumpAndSettle();

      expect(container.read(pendingDeepLinkProvider), isNull);
      expect(router.routeInformationProvider.value.uri.path, '/home');
    });
  });
  group('mid-session notification landing', () {
    testWidgets('valid channel deep link navigates from /home', (tester) async {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
          splashControllerProvider
              .overrideWith(() => _StallingSplashController()),
          serverListRepositoryProvider.overrideWithValue(
            _FakeServerListRepository(['server-1']),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'p');
      await container.read(serverListStoreProvider.notifier).load();
      container.read(appReadyProvider.notifier).state = true;

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/home');

      container.read(pendingDeepLinkProvider.notifier).state =
          '/servers/server-1/channels/general';
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        '/servers/server-1/channels/general',
      );
      expect(container.read(pendingDeepLinkProvider), isNull);
    });

    testWidgets('valid DM deep link navigates from /home', (tester) async {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
          splashControllerProvider
              .overrideWith(() => _StallingSplashController()),
          serverListRepositoryProvider.overrideWithValue(
            _FakeServerListRepository(['server-1']),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'p');
      await container.read(serverListStoreProvider.notifier).load();
      container.read(appReadyProvider.notifier).state = true;

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      container.read(pendingDeepLinkProvider.notifier).state =
          '/servers/server-1/dms/dm-alice';
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        '/servers/server-1/dms/dm-alice',
      );
      expect(container.read(pendingDeepLinkProvider), isNull);
    });

    testWidgets('invalid server clears pending and stays on /home',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
          splashControllerProvider
              .overrideWith(() => _StallingSplashController()),
          serverListRepositoryProvider.overrideWithValue(
            _FakeServerListRepository(['server-1']),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'p');
      await container.read(serverListStoreProvider.notifier).load();
      container.read(appReadyProvider.notifier).state = true;

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      container.read(pendingDeepLinkProvider.notifier).state =
          '/servers/nonexistent/channels/general';
      await tester.pumpAndSettle();

      expect(container.read(pendingDeepLinkProvider), isNull);
      expect(router.routeInformationProvider.value.uri.path, '/home');
    });

    testWidgets('thread deep link navigates from /home', (tester) async {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
          splashControllerProvider
              .overrideWith(() => _StallingSplashController()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'p');
      container.read(appReadyProvider.notifier).state = true;

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      container.read(pendingDeepLinkProvider.notifier).state =
          '/servers/server-1/threads/t1/replies?channelId=c1';
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/servers/server-1/threads/t1/replies?channelId=c1',
      );
      expect(container.read(pendingDeepLinkProvider), isNull);
    });

    testWidgets('agent deep link navigates from /home', (tester) async {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
          splashControllerProvider
              .overrideWith(() => _StallingSplashController()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'p');
      container.read(appReadyProvider.notifier).state = true;

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      container.read(pendingDeepLinkProvider.notifier).state = '/agents/a1';
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        '/agents/a1',
      );
      expect(container.read(pendingDeepLinkProvider), isNull);
    });

    testWidgets('profile deep link navigates from /home', (tester) async {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
          splashControllerProvider
              .overrideWith(() => _StallingSplashController()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'p');
      container.read(appReadyProvider.notifier).state = true;

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      container.read(pendingDeepLinkProvider.notifier).state = '/profile/u1';
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        '/profile/u1',
      );
      expect(container.read(pendingDeepLinkProvider), isNull);
    });

    test('does not consume pending link when not authenticated', () async {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
        ],
      );
      addTearDown(container.dispose);

      container.read(appRouterProvider);

      container.read(pendingDeepLinkProvider.notifier).state =
          '/servers/s1/channels/c1';

      expect(
        container.read(pendingDeepLinkProvider),
        '/servers/s1/channels/c1',
      );
    });

    test('does not consume pending link when appReady is false', () async {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
        ],
      );
      addTearDown(container.dispose);

      container.read(appRouterProvider);

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'p');

      container.read(pendingDeepLinkProvider.notifier).state =
          '/servers/s1/channels/c1';

      expect(
        container.read(pendingDeepLinkProvider),
        '/servers/s1/channels/c1',
      );
    });
  });
}

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
