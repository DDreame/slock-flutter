import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/settings/presentation/page/settings_page.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  testWidgets(
    'settings page navigates to profile, billing, and release notes',
    (tester) async {
      final sessionStore = _FakeSessionStore();
      final notificationStore = _FakeNotificationStore();
      final router = _buildRouter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWith(() => sessionStore),
            notificationStoreProvider.overrideWith(() => notificationStore),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('settings-my-profile')));
      await tester.pumpAndSettle();
      expect(find.text('profile-route'), findsOneWidget);

      router.go('/settings');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('settings-billing')));
      await tester.pumpAndSettle();
      expect(find.text('billing-route'), findsOneWidget);

      router.go('/settings');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('settings-release-notes')));
      await tester.pumpAndSettle();
      expect(find.text('release-notes-route'), findsOneWidget);
    },
  );

  testWidgets('settings page updates notifications and logs out', (
    tester,
  ) async {
    final sessionStore = _FakeSessionStore();
    final notificationStore = _FakeNotificationStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStoreProvider.overrideWith(() => sessionStore),
          notificationStoreProvider.overrideWith(() => notificationStore),
        ],
        child: MaterialApp.router(routerConfig: _buildRouter()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('settings-notification-action')),
    );
    await tester.pumpAndSettle();

    expect(notificationStore.requestPermissionCount, 1);
    expect(notificationStore.refreshTokenCount, 1);

    await tester.tap(find.byKey(const ValueKey('settings-logout')));
    await tester.pumpAndSettle();

    expect(sessionStore.loggedOut, isTrue);
    expect(find.text('login-route'), findsOneWidget);
  });
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) =>
            const Scaffold(body: Text('profile-route')),
      ),
      GoRoute(
        path: '/billing',
        builder: (context, state) =>
            const Scaffold(body: Text('billing-route')),
      ),
      GoRoute(
        path: '/release-notes',
        builder: (context, state) =>
            const Scaffold(body: Text('release-notes-route')),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Scaffold(body: Text('login-route')),
      ),
    ],
  );
}

class _FakeSessionStore extends SessionStore {
  var loggedOut = false;

  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-123',
        displayName: 'Alice',
        token: 'token',
      );

  @override
  Future<void> logout() async {
    loggedOut = true;
    state = const SessionState(status: AuthStatus.unauthenticated);
  }
}

class _FakeNotificationStore extends NotificationStore {
  var requestPermissionCount = 0;
  var refreshTokenCount = 0;

  @override
  NotificationState build() => const NotificationState(
        permissionStatus: NotificationPermissionStatus.unknown,
      );

  @override
  Future<void> requestPermission() async {
    requestPermissionCount += 1;
    state = state.copyWith(
      permissionStatus: NotificationPermissionStatus.granted,
    );
  }

  @override
  Future<void> refreshToken({String? platform}) async {
    refreshTokenCount += 1;
    state = state.copyWith(
      pushToken: 'push-token',
      pushTokenPlatform: platform,
      pushTokenUpdatedAt: DateTime.utc(2026, 4, 22),
    );
  }
}
