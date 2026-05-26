// =============================================================================
// #818 — Settings Page L10n bypass fix
//
// Verifies that ThemePreference and NotificationPreference subtitles on
// SettingsPage use localized strings (via l10n switch expressions) instead
// of the raw English `.title` enum field.
//
// Strategy: render with Chinese locale and assert the Chinese l10n text
// appears for theme preference subtitle and notification filter subtitle.
// =============================================================================

// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/scope/server_scope_id.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/settings/data/notification_preference.dart';
import 'package:slock_app/features/settings/data/theme_preference.dart';
import 'package:slock_app/features/settings/presentation/page/settings_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/l10n/app_localizations_provider.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/biometric/biometric_store.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

/// Chinese l10n instance used by assertions.
final AppLocalizations _zhL10n = lookupAppLocalizations(const Locale('zh'));

void main() {
  group('Settings page L10n bypass fix (#818)', () {
    testWidgets(
      'theme subtitle uses localized text for system preference',
      (tester) async {
        await tester.pumpWidget(_buildApp(
          themePreference: ThemePreference.system,
        ));
        await tester.pumpAndSettle();

        final subtitle =
            find.byKey(const ValueKey('settings-appearance-subtitle'));
        expect(subtitle, findsOneWidget);

        // Should show Chinese "跟随系统" not English "Follow System".
        expect(
          find.text(_zhL10n.settingsThemeSystemTitle),
          findsOneWidget,
          reason: 'Theme subtitle must use l10n.settingsThemeSystemTitle '
              '(expected: "${_zhL10n.settingsThemeSystemTitle}", '
              'NOT raw enum "Follow System")',
        );
      },
    );

    testWidgets(
      'theme subtitle uses localized text for light preference',
      (tester) async {
        await tester.pumpWidget(_buildApp(
          themePreference: ThemePreference.light,
        ));
        await tester.pumpAndSettle();

        expect(
          find.text(_zhL10n.settingsThemeLightTitle),
          findsOneWidget,
          reason: 'Theme subtitle must use l10n.settingsThemeLightTitle '
              '(expected: "${_zhL10n.settingsThemeLightTitle}")',
        );
      },
    );

    testWidgets(
      'theme subtitle uses localized text for dark preference',
      (tester) async {
        await tester.pumpWidget(_buildApp(
          themePreference: ThemePreference.dark,
        ));
        await tester.pumpAndSettle();

        expect(
          find.text(_zhL10n.settingsThemeDarkTitle),
          findsOneWidget,
          reason: 'Theme subtitle must use l10n.settingsThemeDarkTitle '
              '(expected: "${_zhL10n.settingsThemeDarkTitle}")',
        );
      },
    );

    testWidgets(
      'notification subtitle uses localized filter for "all" preference',
      (tester) async {
        await tester.pumpWidget(_buildApp(
          notificationPermission: NotificationPermissionStatus.granted,
          notificationPreference: NotificationPreference.all,
        ));
        await tester.pumpAndSettle();

        // Notification summary format: "$permission · $filter"
        // We verify the filter portion uses l10n.
        expect(
          find.textContaining(_zhL10n.notificationPrefAllTitle),
          findsOneWidget,
          reason: 'Notification filter must use l10n.notificationPrefAllTitle '
              '(expected: "${_zhL10n.notificationPrefAllTitle}", '
              'NOT raw enum "All Messages")',
        );
      },
    );

    testWidgets(
      'notification subtitle uses localized filter for "mentions" preference',
      (tester) async {
        await tester.pumpWidget(_buildApp(
          notificationPermission: NotificationPermissionStatus.granted,
          notificationPreference: NotificationPreference.mentionsOnly,
        ));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(_zhL10n.notificationPrefMentionsTitle),
          findsOneWidget,
          reason:
              'Notification filter must use l10n.notificationPrefMentionsTitle '
              '(expected: "${_zhL10n.notificationPrefMentionsTitle}")',
        );
      },
    );

    testWidgets(
      'notification subtitle uses localized filter for "mute" preference',
      (tester) async {
        await tester.pumpWidget(_buildApp(
          notificationPermission: NotificationPermissionStatus.granted,
          notificationPreference: NotificationPreference.mute,
        ));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(_zhL10n.notificationPrefMuteTitle),
          findsOneWidget,
          reason: 'Notification filter must use l10n.notificationPrefMuteTitle '
              '(expected: "${_zhL10n.notificationPrefMuteTitle}")',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

Widget _buildApp({
  ThemePreference themePreference = ThemePreference.system,
  NotificationPermissionStatus notificationPermission =
      NotificationPermissionStatus.unknown,
  NotificationPreference notificationPreference = NotificationPreference.all,
}) {
  return ProviderScope(
    overrides: [
      sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      notificationStoreProvider.overrideWith(
        () => _FakeNotificationStore(
          permission: notificationPermission,
          preference: notificationPreference,
        ),
      ),
      activeServerScopeIdProvider.overrideWithValue(
        const ServerScopeId('server-1'),
      ),
      biometricStoreProvider.overrideWith(
        () => _FakeBiometricStore(),
      ),
      themeModeStoreProvider.overrideWith(
        () => _FakeThemeModeStore(preference: themePreference),
      ),
      appLocalizationsProvider.overrideWithValue(
        lookupAppLocalizations(const Locale('zh')),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: _buildRouter(),
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    ),
  );
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsPage(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (_, __) =>
            const Scaffold(body: Text('notification-settings-route')),
      ),
      GoRoute(
        path: '/settings/appearance',
        builder: (_, __) => const Scaffold(body: Text('appearance-route')),
      ),
      GoRoute(
        path: '/settings/translation',
        builder: (_, __) => const Scaffold(body: Text('translation-route')),
      ),
      GoRoute(
        path: '/settings/diagnostics',
        builder: (_, __) => const Scaffold(body: Text('diagnostics-route')),
      ),
      GoRoute(
        path: '/settings/base-url',
        builder: (_, __) => const Scaffold(body: Text('base-url-route')),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const Scaffold(body: Text('profile-route')),
      ),
      GoRoute(
        path: '/billing',
        builder: (_, __) => const Scaffold(body: Text('billing-route')),
      ),
      GoRoute(
        path: '/release-notes',
        builder: (_, __) => const Scaffold(body: Text('release-notes-route')),
      ),
      GoRoute(
        path: '/servers/:serverId/members',
        builder: (_, __) => const Scaffold(body: Text('members-route')),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: Text('login-route')),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-1',
        displayName: 'Alice',
        token: 'test-token',
      );

  @override
  Future<void> logout() async {
    state = const SessionState(status: AuthStatus.unauthenticated);
  }
}

class _FakeNotificationStore extends NotificationStore {
  _FakeNotificationStore({
    this.permission = NotificationPermissionStatus.unknown,
    this.preference = NotificationPreference.all,
  });

  final NotificationPermissionStatus permission;
  final NotificationPreference preference;

  @override
  NotificationState build() => NotificationState(
        permissionStatus: permission,
        notificationPreference: preference,
      );

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> refreshToken({String? platform}) async {}
}

class _FakeBiometricStore extends BiometricStore {
  @override
  BiometricState build() => const BiometricState(
        availability: BiometricAvailability.unavailable,
        enabled: false,
      );
}

class _FakeThemeModeStore extends ThemeModeStore {
  _FakeThemeModeStore({required this.preference});

  final ThemePreference preference;

  @override
  ThemeModeState build() => ThemeModeState(preference: preference);
}
