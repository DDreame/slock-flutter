import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/features/settings/presentation/page/settings_page.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  testWidgets(
    'settings page navigates to profile, billing, release notes, '
    'and notification settings',
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

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-billing')),
        200,
      );
      await tester.tap(find.byKey(const ValueKey('settings-billing')));
      await tester.pumpAndSettle();
      expect(find.text('billing-route'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-release-notes')),
        200,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('settings-release-notes')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-release-notes')));
      await tester.pumpAndSettle();
      expect(find.text('release-notes-route'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-notification-link')),
        200,
      );
      await tester.tap(
        find.byKey(const ValueKey('settings-notification-link')),
      );
      await tester.pumpAndSettle();
      expect(find.text('notification-settings-route'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);
    },
  );

  testWidgets('notification summary shows permission and filter', (
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

    expect(find.textContaining('Not requested'), findsOneWidget);
    expect(find.textContaining('All Messages'), findsOneWidget);
  });

  testWidgets('settings page logs out after confirmation', (tester) async {
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

    await tester.tap(find.byKey(const ValueKey('settings-logout')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('logout-confirmation-dialog')),
      findsOneWidget,
    );
    expect(find.text('Log out?'), findsOneWidget);
    expect(
      find.text('You will be signed out of this device.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('logout-confirm')));
    await tester.pumpAndSettle();

    expect(sessionStore.loggedOut, isTrue);
    expect(find.text('login-route'), findsOneWidget);
  });

  testWidgets('settings page cancel logout keeps user signed in', (
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

    await tester.tap(find.byKey(const ValueKey('settings-logout')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('logout-confirmation-dialog')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('logout-cancel')));
    await tester.pumpAndSettle();

    expect(sessionStore.loggedOut, isFalse);
    expect(find.byType(SettingsPage), findsOneWidget);
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
        path: '/settings/notifications',
        builder: (context, state) =>
            const Scaffold(body: Text('notification-settings-route')),
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
  @override
  NotificationState build() => const NotificationState(
        permissionStatus: NotificationPermissionStatus.unknown,
      );

  @override
  Future<void> requestPermission() async {
    state = state.copyWith(
      permissionStatus: NotificationPermissionStatus.granted,
    );
  }

  @override
  Future<void> refreshToken({String? platform}) async {
    state = state.copyWith(
      pushToken: 'push-token',
      pushTokenPlatform: platform,
      pushTokenUpdatedAt: DateTime.utc(2026, 4, 22),
    );
  }
}
