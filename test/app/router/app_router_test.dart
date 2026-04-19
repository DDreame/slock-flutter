import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  test('appRouterProvider creates GoRouter with /home as initial location', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    expect(router.routeInformationProvider.value.uri.path, '/home');
  });

  test('appRouterProvider includes all primary routes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    final config = router.configuration;
    final paths = <String>[];
    for (final route in config.routes) {
      if (route is GoRoute) {
        paths.add(route.path);
      }
      if (route is ShellRoute) {
        for (final child in route.routes) {
          if (child is GoRoute) {
            paths.add(child.path);
          }
        }
      }
    }
    expect(paths, containsAll([
      '/login',
      '/home',
      '/agents',
      '/settings',
      '/servers/:serverId/channels/:channelId',
      '/servers/:serverId/dms/:channelId',
      '/agents/:agentId',
      '/saved-messages',
      '/profile',
      '/profile/:userId',
      '/release-notes',
    ]));
  });
}
