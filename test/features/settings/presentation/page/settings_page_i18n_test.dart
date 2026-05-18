// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/scope/server_scope_id.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/settings/presentation/page/settings_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/biometric/biometric_store.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

// ---------------------------------------------------------------------------
// #563 Phase A — Settings Page i18n (test-only)
//
// Verifies that SettingsPage text comes from AppLocalizations (l10n)
// rather than hardcoded English strings.
//
// SettingsPage has 38 hardcoded English strings across 10 sections.
// Only the Base URL tile currently uses l10n.
//
// Phase B will:
//   1. Add 38 new ARB keys (settingsTitle, settingsAccountSection, ...)
//   2. Replace all hardcoded strings in settings_page.dart with l10n calls
//   3. Un-skip all 26 tests
//
// Phase A — all tests skip: true.
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // Group 1 — Section headers use l10n (T1-T9)
  // =========================================================================
  group('Section headers use l10n', () {
    testWidgets(
      'AppBar title from l10n (T1)',
      skip: true,
      (tester) async {
        // Production: AppBar(title: const Text('Settings'))
        // Phase B: AppBar(title: Text(l10n.settingsTitle))
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Settings'),
          ),
          findsOneWidget,
          reason: 'AppBar title must use l10n.settingsTitle',
        );
      },
    );

    testWidgets(
      'Account section header from l10n (T2)',
      skip: true,
      (tester) async {
        // Production: Text('Account', key: ValueKey('settings-section-account'))
        // Phase B: Text(l10n.settingsAccountSection, ...)
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        final header = find.byKey(const ValueKey('settings-section-account'));
        expect(header, findsOneWidget);
        expect(
          find.descendant(of: header, matching: find.text('Account')),
          findsOneWidget,
          reason: 'Account section header must use l10n.settingsAccountSection',
        );
      },
    );

    testWidgets(
      'Workspace section header from l10n (T3)',
      skip: true,
      (tester) async {
        // Production: Text('Workspace', key: ValueKey('settings-section-workspace'))
        // Phase B: Text(l10n.settingsWorkspaceSection, ...)
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        final header = find.byKey(const ValueKey('settings-section-workspace'));
        expect(header, findsOneWidget);
        expect(
          find.descendant(of: header, matching: find.text('Workspace')),
          findsOneWidget,
          reason:
              'Workspace section header must use l10n.settingsWorkspaceSection',
        );
      },
    );

    testWidgets(
      'Notifications section header from l10n (T4)',
      skip: true,
      (tester) async {
        // Production: Text('Notifications', key: ValueKey('settings-section-notifications'))
        // Phase B: Text(l10n.settingsNotificationsSection, ...)
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        final header =
            find.byKey(const ValueKey('settings-section-notifications'));
        expect(header, findsOneWidget);
        expect(
          find.descendant(of: header, matching: find.text('Notifications')),
          findsOneWidget,
          reason:
              'Notifications section header must use l10n.settingsNotificationsSection',
        );
      },
    );

    testWidgets(
      'Appearance section header from l10n (T5)',
      skip: true,
      (tester) async {
        // Production: Text('Appearance', key: ValueKey('settings-section-appearance'))
        // Phase B: Text(l10n.settingsAppearanceSection, ...)
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        final header =
            find.byKey(const ValueKey('settings-section-appearance'));
        expect(header, findsOneWidget);
        expect(
          find.descendant(of: header, matching: find.text('Appearance')),
          findsOneWidget,
          reason:
              'Appearance section header must use l10n.settingsAppearanceSection',
        );
      },
    );

    testWidgets(
      'Language section header from l10n (T6)',
      skip: true,
      (tester) async {
        // Production: Text('Language', key: ValueKey('settings-section-language'))
        // Phase B: Text(l10n.settingsLanguageSection, ...)
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        final header = find.byKey(const ValueKey('settings-section-language'));
        expect(header, findsOneWidget);
        expect(
          find.descendant(of: header, matching: find.text('Language')),
          findsOneWidget,
          reason:
              'Language section header must use l10n.settingsLanguageSection',
        );
      },
    );

    testWidgets(
      'Security section header from l10n (T7)',
      skip: true,
      (tester) async {
        // Security section only renders when biometric hardware is available.
        // Production: Text('Security', key: ValueKey('settings-section-security'))
        // Phase B: Text(l10n.settingsSecuritySection, ...)
        await tester.pumpWidget(_buildApp(biometricAvailable: true));
        await tester.pumpAndSettle();

        // Scroll to Security section (it may be below the fold).
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('settings-section-security')),
          200,
        );
        await tester.pumpAndSettle();

        final header = find.byKey(const ValueKey('settings-section-security'));
        expect(header, findsOneWidget);
        expect(
          find.descendant(of: header, matching: find.text('Security')),
          findsOneWidget,
          reason:
              'Security section header must use l10n.settingsSecuritySection',
        );
      },
    );

    testWidgets(
      'More section header from l10n (T8)',
      skip: true,
      (tester) async {
        // Production: Text('More', key: ValueKey('settings-section-more'))
        // Phase B: Text(l10n.settingsMoreSection, ...)
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('settings-section-more')),
          200,
        );
        await tester.pumpAndSettle();

        final header = find.byKey(const ValueKey('settings-section-more'));
        expect(header, findsOneWidget);
        expect(
          find.descendant(of: header, matching: find.text('More')),
          findsOneWidget,
          reason: 'More section header must use l10n.settingsMoreSection',
        );
      },
    );

    testWidgets(
      'Danger Zone section header from l10n (T9)',
      skip: true,
      (tester) async {
        // Production: Text('Danger Zone', key: ValueKey('settings-section-danger'))
        // Phase B: Text(l10n.settingsDangerZoneSection, ...)
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('settings-section-danger')),
          200,
        );
        await tester.pumpAndSettle();

        final header = find.byKey(const ValueKey('settings-section-danger'));
        expect(header, findsOneWidget);
        expect(
          find.descendant(of: header, matching: find.text('Danger Zone')),
          findsOneWidget,
          reason:
              'Danger Zone section header must use l10n.settingsDangerZoneSection',
        );
      },
    );
  });

  // =========================================================================
  // Group 2 — Tile titles + subtitles use l10n (T10-T23)
  // =========================================================================
  group('Tile titles and subtitles use l10n', () {
    testWidgets(
      'My Profile tile title from l10n (T10)',
      skip: true,
      (tester) async {
        // Production: title: 'My Profile' in _SettingsTile
        // Phase B: title: l10n.settingsMyProfileTitle
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        final tile = find.byKey(const ValueKey('settings-my-profile'));
        expect(tile, findsOneWidget);
        expect(
          find.descendant(of: tile, matching: find.text('My Profile')),
          findsOneWidget,
          reason: 'My Profile tile title must use l10n.settingsMyProfileTitle',
        );
      },
    );

    testWidgets(
      'My Profile tile subtitle from l10n (T11)',
      skip: true,
      (tester) async {
        // Production: subtitle: 'Review your current account details.'
        // Phase B: subtitle: l10n.settingsMyProfileSubtitle
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        final subtitle =
            find.byKey(const ValueKey('settings-my-profile-subtitle'));
        expect(subtitle, findsOneWidget);
        expect(
          find.descendant(
            of: subtitle,
            matching: find.text('Review your current account details.'),
          ),
          findsOneWidget,
          reason: 'My Profile subtitle must use l10n.settingsMyProfileSubtitle',
        );
      },
    );

    testWidgets(
      'Members tile title from l10n (T12)',
      skip: true,
      (tester) async {
        // Production: title: 'Members'
        // Phase B: title: l10n.settingsMembersTitle
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        final tile = find.byKey(const ValueKey('settings-members'));
        expect(tile, findsOneWidget);
        expect(
          find.descendant(of: tile, matching: find.text('Members')),
          findsOneWidget,
          reason: 'Members tile title must use l10n.settingsMembersTitle',
        );
      },
    );

    testWidgets(
      'Members tile subtitle from l10n (T13)',
      skip: true,
      (tester) async {
        // Production: subtitle: 'View and manage workspace members.'
        // Phase B: subtitle: l10n.settingsMembersSubtitle
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        final tile = find.byKey(const ValueKey('settings-members'));
        expect(tile, findsOneWidget);
        expect(
          find.descendant(
            of: tile,
            matching: find.text('View and manage workspace members.'),
          ),
          findsOneWidget,
          reason: 'Members subtitle must use l10n.settingsMembersSubtitle',
        );
      },
    );

    testWidgets(
      'Notification Settings tile from l10n (T14)',
      skip: true,
      (tester) async {
        // Production: title: 'Notification Settings'
        // Phase B: title: l10n.settingsNotificationSettingsTitle
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        final tile = find.byKey(const ValueKey('settings-notification-link'));
        expect(tile, findsOneWidget);
        expect(
          find.descendant(
            of: tile,
            matching: find.text('Notification Settings'),
          ),
          findsOneWidget,
          reason:
              'Notification Settings tile must use l10n.settingsNotificationSettingsTitle',
        );
      },
    );

    testWidgets(
      'Theme tile title from l10n (T15)',
      skip: true,
      (tester) async {
        // Production: title: 'Theme'
        // Phase B: title: l10n.settingsThemeTitle
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        final tile = find.byKey(const ValueKey('settings-appearance-link'));
        expect(tile, findsOneWidget);
        expect(
          find.descendant(of: tile, matching: find.text('Theme')),
          findsOneWidget,
          reason: 'Theme tile title must use l10n.settingsThemeTitle',
        );
      },
    );

    testWidgets(
      'Translation tile title from l10n (T16)',
      skip: true,
      (tester) async {
        // Production: title: 'Translation'
        // Phase B: title: l10n.settingsTranslationTitle
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('settings-translation-link')),
          200,
        );
        await tester.pumpAndSettle();

        final tile = find.byKey(const ValueKey('settings-translation-link'));
        expect(tile, findsOneWidget);
        expect(
          find.descendant(of: tile, matching: find.text('Translation')),
          findsOneWidget,
          reason:
              'Translation tile title must use l10n.settingsTranslationTitle',
        );
      },
    );

    testWidgets(
      'Translation tile subtitle from l10n (T17)',
      skip: true,
      (tester) async {
        // Production: subtitle: 'Preferred language and translation mode.'
        // Phase B: subtitle: l10n.settingsTranslationSubtitle
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('settings-translation-link')),
          200,
        );
        await tester.pumpAndSettle();

        final tile = find.byKey(const ValueKey('settings-translation-link'));
        expect(tile, findsOneWidget);
        expect(
          find.descendant(
            of: tile,
            matching: find.text('Preferred language and translation mode.'),
          ),
          findsOneWidget,
          reason:
              'Translation subtitle must use l10n.settingsTranslationSubtitle',
        );
      },
    );

    testWidgets(
      'Biometric Lock tile from l10n (T18)',
      skip: true,
      (tester) async {
        // Security section only visible when biometric hardware available.
        // Production: title: 'Biometric Lock'
        // Phase B: title: l10n.settingsBiometricLockTitle
        await tester.pumpWidget(_buildApp(biometricAvailable: true));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('settings-biometric-toggle')),
          200,
        );
        await tester.pumpAndSettle();

        final tile = find.byKey(const ValueKey('settings-biometric-toggle'));
        expect(tile, findsOneWidget);
        expect(
          find.descendant(of: tile, matching: find.text('Biometric Lock')),
          findsOneWidget,
          reason:
              'Biometric Lock tile must use l10n.settingsBiometricLockTitle',
        );
      },
    );

    testWidgets(
      'Biometric Lock enabled subtitle from l10n (T19)',
      skip: true,
      (tester) async {
        // Production: subtitle: 'Enabled — unlock with biometrics after inactivity'
        // Phase B: subtitle: l10n.settingsBiometricLockEnabled
        await tester.pumpWidget(
          _buildApp(biometricAvailable: true, biometricEnabled: true),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('settings-biometric-toggle')),
          200,
        );
        await tester.pumpAndSettle();

        final tile = find.byKey(const ValueKey('settings-biometric-toggle'));
        expect(tile, findsOneWidget);
        expect(
          find.descendant(
            of: tile,
            matching: find.text(
              'Enabled — unlock with biometrics after inactivity',
            ),
          ),
          findsOneWidget,
          reason:
              'Biometric enabled subtitle must use l10n.settingsBiometricLockEnabled',
        );
      },
    );

    testWidgets(
      'Billing tile from l10n (T20)',
      skip: true,
      (tester) async {
        // Production: title: 'Billing', subtitle: 'Review your current subscription summary.'
        // Phase B: title: l10n.settingsBillingTitle, subtitle: l10n.settingsBillingSubtitle
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('settings-billing')),
          200,
        );
        await tester.pumpAndSettle();

        final tile = find.byKey(const ValueKey('settings-billing'));
        expect(tile, findsOneWidget);
        expect(
          find.descendant(of: tile, matching: find.text('Billing')),
          findsOneWidget,
          reason: 'Billing tile title must use l10n.settingsBillingTitle',
        );
        expect(
          find.descendant(
            of: tile,
            matching: find.text('Review your current subscription summary.'),
          ),
          findsOneWidget,
          reason: 'Billing subtitle must use l10n.settingsBillingSubtitle',
        );
      },
    );

    testWidgets(
      'Release Notes tile from l10n (T21)',
      skip: true,
      (tester) async {
        // Production: title: 'Release Notes', subtitle: 'See the latest packaged product updates.'
        // Phase B: title: l10n.settingsReleaseNotesTitle, subtitle: l10n.settingsReleaseNotesSubtitle
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('settings-release-notes')),
          200,
        );
        await tester.pumpAndSettle();

        final tile = find.byKey(const ValueKey('settings-release-notes'));
        expect(tile, findsOneWidget);
        expect(
          find.descendant(of: tile, matching: find.text('Release Notes')),
          findsOneWidget,
          reason:
              'Release Notes tile title must use l10n.settingsReleaseNotesTitle',
        );
        expect(
          find.descendant(
            of: tile,
            matching: find.text(
              'See the latest packaged product updates.',
            ),
          ),
          findsOneWidget,
          reason:
              'Release Notes subtitle must use l10n.settingsReleaseNotesSubtitle',
        );
      },
    );

    testWidgets(
      'Diagnostics tile from l10n (T22)',
      skip: true,
      (tester) async {
        // Production: title: 'Diagnostics', subtitle: 'View and export diagnostic logs.'
        // Phase B: title: l10n.settingsDiagnosticsTitle, subtitle: l10n.settingsDiagnosticsSubtitle
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('settings-diagnostics')),
          200,
        );
        await tester.pumpAndSettle();

        final tile = find.byKey(const ValueKey('settings-diagnostics'));
        expect(tile, findsOneWidget);
        expect(
          find.descendant(of: tile, matching: find.text('Diagnostics')),
          findsOneWidget,
          reason:
              'Diagnostics tile title must use l10n.settingsDiagnosticsTitle',
        );
        expect(
          find.descendant(
            of: tile,
            matching: find.text('View and export diagnostic logs.'),
          ),
          findsOneWidget,
          reason:
              'Diagnostics subtitle must use l10n.settingsDiagnosticsSubtitle',
        );
      },
    );

    testWidgets(
      'Log Out tile from l10n (T23)',
      skip: true,
      (tester) async {
        // Production: title: 'Log Out', subtitle: 'Sign out of this device.'
        // Phase B: title: l10n.settingsLogOutTitle, subtitle: l10n.settingsLogOutSubtitle
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('settings-logout')),
          200,
        );
        await tester.pumpAndSettle();

        final tile = find.byKey(const ValueKey('settings-logout'));
        expect(tile, findsOneWidget);
        expect(
          find.descendant(of: tile, matching: find.text('Log Out')),
          findsOneWidget,
          reason: 'Log Out tile title must use l10n.settingsLogOutTitle',
        );
        expect(
          find.descendant(
            of: tile,
            matching: find.text('Sign out of this device.'),
          ),
          findsOneWidget,
          reason: 'Log Out subtitle must use l10n.settingsLogOutSubtitle',
        );
      },
    );
  });

  // =========================================================================
  // Group 3 — Dialog + misc (T24-T26)
  // =========================================================================
  group('Dialog and misc use l10n', () {
    testWidgets(
      'Logout dialog uses l10n (T24)',
      skip: true,
      (tester) async {
        // Tap Log Out → dialog appears with 4 strings.
        // Production:
        //   title: 'Log out?'
        //   content: 'You will be signed out of this device.'
        //   cancel: 'Cancel'
        //   confirm: 'Log out'
        // Phase B:
        //   title: l10n.settingsLogOutDialogTitle
        //   content: l10n.settingsLogOutDialogContent
        //   cancel: l10n.settingsLogOutDialogCancel
        //   confirm: l10n.settingsLogOutDialogConfirm
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('settings-logout')),
          200,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('settings-logout')));
        await tester.pumpAndSettle();

        // Dialog must be visible.
        expect(
          find.byKey(const ValueKey('logout-confirmation-dialog')),
          findsOneWidget,
          reason: 'Logout confirmation dialog must appear',
        );

        // Dialog title.
        expect(
          find.text('Log out?'),
          findsOneWidget,
          reason: 'Dialog title must use l10n.settingsLogOutDialogTitle',
        );

        // Dialog content.
        expect(
          find.text('You will be signed out of this device.'),
          findsOneWidget,
          reason: 'Dialog content must use l10n.settingsLogOutDialogContent',
        );

        // Cancel button.
        expect(
          find.byKey(const ValueKey('logout-cancel')),
          findsOneWidget,
          reason: 'Cancel button must be present',
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('logout-cancel')),
            matching: find.text('Cancel'),
          ),
          findsOneWidget,
          reason: 'Cancel button text must use l10n.settingsLogOutDialogCancel',
        );

        // Confirm button.
        expect(
          find.byKey(const ValueKey('logout-confirm')),
          findsOneWidget,
          reason: 'Confirm button must be present',
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('logout-confirm')),
            matching: find.text('Log out'),
          ),
          findsOneWidget,
          reason:
              'Confirm button text must use l10n.settingsLogOutDialogConfirm',
        );
      },
    );

    testWidgets(
      'Profile card fallbacks from l10n (T25)',
      skip: true,
      (tester) async {
        // When session.displayName is null, the profile card shows
        // fallback strings.
        // Production:
        //   title: 'Signed in'
        //   subtitle: 'Account details unavailable'
        // Phase B:
        //   title: l10n.settingsSignedInFallback
        //   subtitle: l10n.settingsAccountUnavailable
        await tester.pumpWidget(_buildApp(nullDisplayName: true));
        await tester.pumpAndSettle();

        final header = find.byKey(const ValueKey('settings-account-header'));
        expect(header, findsOneWidget);

        expect(
          find.descendant(of: header, matching: find.text('Signed in')),
          findsOneWidget,
          reason: 'Fallback title must use l10n.settingsSignedInFallback when '
              'displayName is null',
        );
        expect(
          find.descendant(
            of: header,
            matching: find.text('Account details unavailable'),
          ),
          findsOneWidget,
          reason: 'Fallback subtitle must use l10n.settingsAccountUnavailable '
              'when displayName is null',
        );
      },
    );

    testWidgets(
      'Notification permission summary from l10n (T26)',
      skip: true,
      (tester) async {
        // The notification tile subtitle shows a permission summary
        // with hardcoded status labels.
        // Production: 'Granted', 'Denied', 'Provisional', 'Not requested'
        // Phase B:
        //   l10n.settingsNotificationGranted
        //   l10n.settingsNotificationDenied
        //   l10n.settingsNotificationProvisional
        //   l10n.settingsNotificationNotRequested
        //
        // Test each permission status label appears correctly.
        // Default state uses NotificationPermissionStatus.unknown → 'Not requested'.
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        // Default permission is unknown → 'Not requested'.
        expect(
          find.textContaining('Not requested'),
          findsOneWidget,
          reason:
              'Permission unknown must show l10n.settingsNotificationNotRequested',
        );

        // Rebuild with granted permission.
        await tester.pumpWidget(
          _buildApp(
            notificationPermission: NotificationPermissionStatus.granted,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Granted'),
          findsOneWidget,
          reason:
              'Permission granted must show l10n.settingsNotificationGranted',
        );

        // Rebuild with denied permission.
        await tester.pumpWidget(
          _buildApp(
            notificationPermission: NotificationPermissionStatus.denied,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Denied'),
          findsOneWidget,
          reason: 'Permission denied must show l10n.settingsNotificationDenied',
        );

        // Rebuild with provisional permission.
        await tester.pumpWidget(
          _buildApp(
            notificationPermission: NotificationPermissionStatus.provisional,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Provisional'),
          findsOneWidget,
          reason:
              'Permission provisional must show l10n.settingsNotificationProvisional',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildApp({
  bool biometricAvailable = false,
  bool biometricEnabled = false,
  bool nullDisplayName = false,
  NotificationPermissionStatus notificationPermission =
      NotificationPermissionStatus.unknown,
}) {
  return ProviderScope(
    overrides: [
      sessionStoreProvider.overrideWith(
        () => nullDisplayName
            ? _NullDisplayNameSessionStore()
            : _FakeSessionStore(),
      ),
      notificationStoreProvider.overrideWith(
        () => _FakeNotificationStore(permission: notificationPermission),
      ),
      activeServerScopeIdProvider.overrideWithValue(
        const ServerScopeId('server-1'),
      ),
      biometricStoreProvider.overrideWith(
        () => _FakeBiometricStore(
          available: biometricAvailable,
          enabled: biometricEnabled,
        ),
      ),
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

/// Session store with null displayName to test fallback strings.
class _NullDisplayNameSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-1',
        displayName: null,
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
  });

  final NotificationPermissionStatus permission;

  @override
  NotificationState build() => NotificationState(
        permissionStatus: permission,
      );

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> refreshToken({String? platform}) async {}
}

class _FakeBiometricStore extends BiometricStore {
  _FakeBiometricStore({
    required this.available,
    required this.enabled,
  });

  final bool available;
  final bool enabled;

  @override
  BiometricState build() => BiometricState(
        availability: available
            ? BiometricAvailability.available
            : BiometricAvailability.unavailable,
        enabled: enabled,
      );
}
