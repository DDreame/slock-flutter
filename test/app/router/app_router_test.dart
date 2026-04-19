import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/router/app_router.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
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
