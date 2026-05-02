import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/section_card.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:slock_app/features/settings/presentation/page/settings_page.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  Widget buildApp({_FakeSessionStore? sessionStore}) {
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
        sessionStoreProvider
            .overrideWith(() => sessionStore ?? _FakeSessionStore()),
        notificationStoreProvider.overrideWith(() => _FakeNotificationStore()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
      ),
    );
  }

  group('Z3 token adoption', () {
    testWidgets('account header uses ProfileAvatar with display name', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Account header should use ProfileAvatar instead of plain icon
      expect(
        find.byKey(const ValueKey('settings-account-header')),
        findsOneWidget,
      );
      expect(find.byType(ProfileAvatar), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('settings groups use SectionCard instead of raw Card', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Should use SectionCard for grouped settings
      expect(find.byType(SectionCard), findsWidgets);
      // Raw Card should no longer appear
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('section headers use AppColors.text from theme extension', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Find the "Account" section header
      final accountHeader = tester.widget<Text>(
        find.byKey(const ValueKey('settings-section-account')),
      );
      expect(accountHeader.style?.color, AppColors.light.text);
    });

    testWidgets('list tile subtitles use AppColors.textSecondary', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // The "My Profile" subtitle should use textSecondary
      final subtitle = tester.widget<Text>(
        find.byKey(const ValueKey('settings-my-profile-subtitle')),
      );
      expect(subtitle.style?.color, AppColors.light.textSecondary);
    });

    testWidgets('logout confirmation uses destructive AppColors tokens', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-logout')),
        200,
      );
      await tester.tap(find.byKey(const ValueKey('settings-logout')));
      await tester.pumpAndSettle();

      final confirmButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('logout-confirm')),
      );
      expect(
        confirmButton.style?.backgroundColor?.resolve(<WidgetState>{}),
        AppColors.light.errorContainer,
      );
      expect(
        confirmButton.style?.foregroundColor?.resolve(<WidgetState>{}),
        AppColors.light.onErrorContainer,
      );
    });

    testWidgets('dark theme applies AppColors.dark tokens throughout', (
      tester,
    ) async {
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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
            notificationStoreProvider
                .overrideWith(() => _FakeNotificationStore()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.dark,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final accountHeader = tester.widget<Text>(
        find.byKey(const ValueKey('settings-section-account')),
      );
      expect(accountHeader.style?.color, AppColors.dark.text);
    });

    testWidgets('chevron icons use AppColors.textTertiary', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Chevrons on nav tiles should use textTertiary
      final chevronIcon = tester.widget<Icon>(
        find.byKey(const ValueKey('settings-my-profile-chevron')),
      );
      expect(chevronIcon.color, AppColors.light.textTertiary);
    });

    testWidgets('Workspace section renders Members and Roles tiles', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-section-workspace')),
        200,
      );
      expect(
        find.byKey(const ValueKey('settings-section-workspace')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('settings-members')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('settings-roles')),
        findsOneWidget,
      );
    });

    testWidgets('Danger Zone section has error-colored header and Log Out tile',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-section-danger')),
        200,
      );
      final dangerHeader = tester.widget<Text>(
        find.byKey(const ValueKey('settings-section-danger')),
      );
      expect(dangerHeader.style?.color, AppColors.light.error);

      // Log Out tile is below the header — scroll it into view.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-logout')),
        200,
      );
      expect(
        find.byKey(const ValueKey('settings-logout')),
        findsOneWidget,
      );
    });
  });
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
