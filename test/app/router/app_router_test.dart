import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/app/router/app_router.dart';
import 'package:slock_app/app/router/pending_deep_link_provider.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
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
      '/threads/:threadId/replies',
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
  });

  group('deep link preservation', () {
    testWidgets('captures conversation deep link and restores after bootstrap',
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

      router.go('/servers/server-1/channels/general');
      await tester.pump();

      expect(
        container.read(pendingDeepLinkProvider),
        '/servers/server-1/channels/general',
      );

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'p');
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

      router.go('/servers/server-1/dms/dm-alice');
      await tester.pump();

      expect(
        container.read(pendingDeepLinkProvider),
        '/servers/server-1/dms/dm-alice',
      );

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'p');
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

    testWidgets(
        'cleared deep link does not redirect again on subsequent navigation',
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

      router.go('/servers/server-1/channels/general');
      await tester.pump();

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'p');
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

    testWidgets('invalid pending deep link is consumed and falls back to /home',
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

      router.go('/servers/nonexistent/channels/missing');
      await tester.pump();

      expect(
        container.read(pendingDeepLinkProvider),
        '/servers/nonexistent/channels/missing',
      );

      await container
          .read(sessionStoreProvider.notifier)
          .login(email: 'a@b.com', password: 'p');
      container.read(appReadyProvider.notifier).state = true;
      await tester.pumpAndSettle();

      expect(container.read(pendingDeepLinkProvider), isNull);
      expect(
        container.read(serverSelectionStoreProvider).selectedServerId,
        'nonexistent',
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
