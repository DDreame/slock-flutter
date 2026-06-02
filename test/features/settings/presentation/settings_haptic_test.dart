// =============================================================================
// Settings Page — Haptic Preference Tile
//
// Invariants verified:
// INV-HAPTIC-SETTINGS-1: Haptic tile shows current preference subtitle.
// INV-HAPTIC-SETTINGS-2: Tapping tile opens picker, selecting option persists.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/scope/server_scope_id.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/settings/data/haptic_preference.dart';
import 'package:slock_app/features/settings/presentation/page/settings_page.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

void main() {
  // ---------------------------------------------------------------------------
  // INV-HAPTIC-SETTINGS-1: Tile subtitle reflects stored preference
  // ---------------------------------------------------------------------------
  testWidgets(
    'INV-HAPTIC-SETTINGS-1: haptic tile shows current preference',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        hapticPreferenceKey: 'light',
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        _buildApp(prefs: prefs),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-haptic-link')),
        200,
      );
      await tester.pumpAndSettle();

      // Subtitle should show "Light" (English locale).
      expect(
        find.byKey(const ValueKey('settings-haptic-subtitle')),
        findsOneWidget,
      );
      expect(find.text('Light'), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------------------
  // INV-HAPTIC-SETTINGS-2: Picker selection persists
  // ---------------------------------------------------------------------------
  testWidgets(
    'INV-HAPTIC-SETTINGS-2: selecting option in picker persists to prefs',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        hapticPreferenceKey: 'medium',
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        _buildApp(prefs: prefs),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-haptic-link')),
        200,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-haptic-link')));
      await tester.pumpAndSettle();

      // Bottom sheet should show all options.
      expect(find.byKey(const ValueKey('haptic-option-off')), findsOneWidget);
      expect(find.byKey(const ValueKey('haptic-option-light')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('haptic-option-medium')),
        findsOneWidget,
      );

      // Current (medium) should have a check icon.
      final mediumTile = tester.widget<ListTile>(
        find.byKey(const ValueKey('haptic-option-medium')),
      );
      expect(mediumTile.trailing, isNotNull);

      // Select "Off".
      await tester.tap(find.byKey(const ValueKey('haptic-option-off')));
      await tester.pumpAndSettle();

      // Verify persistence.
      expect(prefs.getString(hapticPreferenceKey), 'off');

      // Subtitle should update to "Off".
      expect(find.text('Off'), findsOneWidget);
    },
  );
}

// =============================================================================
// Helpers
// =============================================================================

Widget _buildApp({required SharedPreferences prefs}) {
  final sessionStore = _FakeSessionStore();
  final notificationStore = _FakeNotificationStore();

  return ProviderScope(
    overrides: [
      sessionStoreProvider.overrideWith(() => sessionStore),
      notificationStoreProvider.overrideWith(() => notificationStore),
      activeServerScopeIdProvider
          .overrideWithValue(const ServerScopeId('server-1')),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: _buildRouter(),
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
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) =>
            const Scaffold(body: Text('profile-route')),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) =>
            const Scaffold(body: Text('profile-edit-route')),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Scaffold(body: Text('login-route')),
      ),
    ],
  );
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
  Future<void> requestPermission() async {}

  @override
  Future<void> refreshToken({String? platform}) async {}
}
