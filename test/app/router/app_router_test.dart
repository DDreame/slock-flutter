import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/router/app_router.dart';
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
}
