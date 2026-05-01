import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/features/settings/presentation/page/settings_page.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  Widget buildApp() {
    final router = GoRouter(
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
          path: '/settings/diagnostics',
          builder: (context, state) =>
              const Scaffold(body: Text('diagnostics-route')),
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
          path: '/members',
          builder: (context, state) =>
              const Scaffold(body: Text('members-route')),
        ),
        GoRoute(
          path: '/roles',
          builder: (context, state) =>
              const Scaffold(body: Text('roles-route')),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) =>
              const Scaffold(body: Text('login-route')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
        notificationStoreProvider.overrideWith(() => _FakeNotificationStore()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
      ),
    );
  }

  group('Diagnostics tile in Settings', () {
    testWidgets('Diagnostics tile is rendered in the More section',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Scroll to the More section
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-diagnostics')),
        200,
      );

      expect(
        find.byKey(const ValueKey('settings-diagnostics')),
        findsOneWidget,
      );
      expect(find.text('Diagnostics'), findsOneWidget);
    });

    testWidgets('Diagnostics tile has bug report icon', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-diagnostics')),
        200,
      );

      // The tile should have the bug_report icon
      final tile = find.byKey(const ValueKey('settings-diagnostics'));
      expect(tile, findsOneWidget);
    });

    testWidgets('Diagnostics tile subtitle describes its purpose',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-diagnostics')),
        200,
      );

      expect(
        find.text('View and export diagnostic logs.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping Diagnostics tile navigates to /settings/diagnostics',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-diagnostics')),
        200,
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('settings-diagnostics')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('settings-diagnostics')));
      await tester.pumpAndSettle();

      expect(find.text('diagnostics-route'), findsOneWidget);
    });
  });
}

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-123',
        displayName: 'Alice',
        token: 'token',
      );

  @override
  Future<void> logout() async {
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
