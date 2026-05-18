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
import 'package:slock_app/l10n/app_localizations_provider.dart';
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
// Strategy: render with Chinese locale and assert the Chinese l10n text
// appears. Since production currently uses hardcoded English, these
// assertions will fail until Phase B replaces hardcoded strings with
// l10n calls — therefore all tests are skip: true.
//
// Phase B will:
//   1. Replace all 38 hardcoded strings in settings_page.dart with l10n calls
//   2. Un-skip all 26 tests
//
// Phase B — all tests active (skip removed).
// ---------------------------------------------------------------------------

/// Chinese l10n instance used by all assertions.
final AppLocalizations _zhL10n = lookupAppLocalizations(const Locale('zh'));

void main() {
  // =========================================================================
  // Group 1 — Section headers use l10n (T1-T9)
  // =========================================================================
  group('Section headers use l10n', () {
    testWidgets(
      'AppBar title from l10n (T1)',
      (tester) async {
        // Production: AppBar(title: const Text('Settings'))
        // Phase B: AppBar(title: Text(l10n.settingsTitle))
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text(_zhL10n.settingsTitle),
          ),
          findsOneWidget,
          reason: 'AppBar title must use l10n.settingsTitle '
              '(expected: "${_zhL10n.settingsTitle}")',
        );
      },
    );

    testWidgets(
      'Account section header from l10n (T2)',
      (tester) async {
        // Production: Text('Account', key: ValueKey('settings-section-account'))
        // Phase B: Text(l10n.settingsAccountSection, ...)
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        final header = find.byKey(const ValueKey('settings-section-account'));
        expect(header, findsOneWidget);
        expect(
          find.descendant(
            of: header,
            matching: find.text(_zhL10n.settingsAccountSection),
          ),
          findsOneWidget,
          reason: 'Account section header must use l10n.settingsAccountSection '
              '(expected: "${_zhL10n.settingsAccountSection}")',
        );
      },
    );

    testWidgets(
      'Workspace section header from l10n (T3)',
      (tester) async {
        // Production: Text('Workspace', key: ValueKey('settings-section-workspace'))
        // Phase B: Text(l10n.settingsWorkspaceSection, ...)
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        final header = find.byKey(const ValueKey('settings-section-workspace'));
        expect(header, findsOneWidget);
        expect(
          find.descendant(
            of: header,
            matching: find.text(_zhL10n.settingsWorkspaceSection),
          ),
          findsOneWidget,
          reason:
              'Workspace section header must use l10n.settingsWorkspaceSection '
              '(expected: "${_zhL10n.settingsWorkspaceSection}")',
        );
      },
    );

    testWidgets(
      'Notifications section header from l10n (T4)',
      (tester) async {
        // Production: Text('Notifications', key: ValueKey('settings-section-notifications'))
        // Phase B: Text(l10n.settingsNotificationsSection, ...)
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        final header =
            find.byKey(const ValueKey('settings-section-notifications'));
        expect(header, findsOneWidget);
        expect(
          find.descendant(
            of: header,
            matching: find.text(_zhL10n.settingsNotificationsSection),
          ),
          findsOneWidget,
          reason:
              'Notifications section header must use l10n.settingsNotificationsSection '
              '(expected: "${_zhL10n.settingsNotificationsSection}")',
        );
      },
    );

    testWidgets(
      'Appearance section header from l10n (T5)',
      (tester) async {
        // Production: Text('Appearance', key: ValueKey('settings-section-appearance'))
        // Phase B: Text(l10n.settingsAppearanceSection, ...)
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        final header =
            find.byKey(const ValueKey('settings-section-appearance'));
        expect(header, findsOneWidget);
        expect(
          find.descendant(
            of: header,
            matching: find.text(_zhL10n.settingsAppearanceSection),
          ),
          findsOneWidget,
          reason:
              'Appearance section header must use l10n.settingsAppearanceSection '
              '(expected: "${_zhL10n.settingsAppearanceSection}")',
        );
      },
    );

    testWidgets(
      'Language section header from l10n (T6)',
      (tester) async {
        // Production: Text('Language', key: ValueKey('settings-section-language'))
        // Phase B: Text(l10n.settingsLanguageSection, ...)
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        final header = find.byKey(const ValueKey('settings-section-language'));
        expect(header, findsOneWidget);
        expect(
          find.descendant(
            of: header,
            matching: find.text(_zhL10n.settingsLanguageSection),
          ),
          findsOneWidget,
          reason:
              'Language section header must use l10n.settingsLanguageSection '
              '(expected: "${_zhL10n.settingsLanguageSection}")',
        );
      },
    );

    testWidgets(
      'Security section header from l10n (T7)',
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
          find.descendant(
            of: header,
            matching: find.text(_zhL10n.settingsSecuritySection),
          ),
          findsOneWidget,
          reason:
              'Security section header must use l10n.settingsSecuritySection '
              '(expected: "${_zhL10n.settingsSecuritySection}")',
        );
      },
    );

    testWidgets(
      'More section header from l10n (T8)',
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
          find.descendant(
            of: header,
            matching: find.text(_zhL10n.settingsMoreSection),
          ),
          findsOneWidget,
          reason: 'More section header must use l10n.settingsMoreSection '
              '(expected: "${_zhL10n.settingsMoreSection}")',
        );
      },
    );

    testWidgets(
      'Danger Zone section header from l10n (T9)',
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
          find.descendant(
            of: header,
            matching: find.text(_zhL10n.settingsDangerZoneSection),
          ),
          findsOneWidget,
          reason:
              'Danger Zone section header must use l10n.settingsDangerZoneSection '
              '(expected: "${_zhL10n.settingsDangerZoneSection}")',
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
      (tester) async {
        // Production: title: 'My Profile' in _SettingsTile
        // Phase B: title: l10n.settingsMyProfileTitle
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        final tile = find.byKey(const ValueKey('settings-my-profile'));
        expect(tile, findsOneWidget);
        expect(
          find.descendant(
            of: tile,
            matching: find.text(_zhL10n.settingsMyProfileTitle),
          ),
          findsOneWidget,
          reason: 'My Profile tile title must use l10n.settingsMyProfileTitle '
              '(expected: "${_zhL10n.settingsMyProfileTitle}")',
        );
      },
    );

    testWidgets(
      'My Profile tile subtitle from l10n (T11)',
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
            matching: find.text(_zhL10n.settingsMyProfileSubtitle),
          ),
          findsOneWidget,
          reason: 'My Profile subtitle must use l10n.settingsMyProfileSubtitle '
              '(expected: "${_zhL10n.settingsMyProfileSubtitle}")',
        );
      },
    );

    testWidgets(
      'Members tile title from l10n (T12)',
      (tester) async {
        // Production: title: 'Members'
        // Phase B: title: l10n.settingsMembersTitle
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        final tile = find.byKey(const ValueKey('settings-members'));
        expect(tile, findsOneWidget);
        expect(
          find.descendant(
            of: tile,
            matching: find.text(_zhL10n.settingsMembersTitle),
          ),
          findsOneWidget,
          reason: 'Members tile title must use l10n.settingsMembersTitle '
              '(expected: "${_zhL10n.settingsMembersTitle}")',
        );
      },
    );

    testWidgets(
      'Members tile subtitle from l10n (T13)',
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
            matching: find.text(_zhL10n.settingsMembersSubtitle),
          ),
          findsOneWidget,
          reason: 'Members subtitle must use l10n.settingsMembersSubtitle '
              '(expected: "${_zhL10n.settingsMembersSubtitle}")',
        );
      },
    );

    testWidgets(
      'Notification Settings tile from l10n (T14)',
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
            matching: find.text(_zhL10n.settingsNotificationSettingsTitle),
          ),
          findsOneWidget,
          reason:
              'Notification Settings tile must use l10n.settingsNotificationSettingsTitle '
              '(expected: "${_zhL10n.settingsNotificationSettingsTitle}")',
        );
      },
    );

    testWidgets(
      'Theme tile title from l10n (T15)',
      (tester) async {
        // Production: title: 'Theme'
        // Phase B: title: l10n.settingsThemeTitle
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        final tile = find.byKey(const ValueKey('settings-appearance-link'));
        expect(tile, findsOneWidget);
        expect(
          find.descendant(
            of: tile,
            matching: find.text(_zhL10n.settingsThemeTitle),
          ),
          findsOneWidget,
          reason: 'Theme tile title must use l10n.settingsThemeTitle '
              '(expected: "${_zhL10n.settingsThemeTitle}")',
        );
      },
    );

    testWidgets(
      'Translation tile title from l10n (T16)',
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
          find.descendant(
            of: tile,
            matching: find.text(_zhL10n.settingsTranslationTitle),
          ),
          findsOneWidget,
          reason:
              'Translation tile title must use l10n.settingsTranslationTitle '
              '(expected: "${_zhL10n.settingsTranslationTitle}")',
        );
      },
    );

    testWidgets(
      'Translation tile subtitle from l10n (T17)',
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
            matching: find.text(_zhL10n.settingsTranslationSubtitle),
          ),
          findsOneWidget,
          reason:
              'Translation subtitle must use l10n.settingsTranslationSubtitle '
              '(expected: "${_zhL10n.settingsTranslationSubtitle}")',
        );
      },
    );

    testWidgets(
      'Biometric Lock tile from l10n (T18)',
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
          find.descendant(
            of: tile,
            matching: find.text(_zhL10n.settingsBiometricLockTitle),
          ),
          findsOneWidget,
          reason:
              'Biometric Lock tile must use l10n.settingsBiometricLockTitle '
              '(expected: "${_zhL10n.settingsBiometricLockTitle}")',
        );
      },
    );

    testWidgets(
      'Biometric Lock enabled subtitle from l10n (T19)',
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
            matching: find.text(_zhL10n.settingsBiometricLockEnabled),
          ),
          findsOneWidget,
          reason:
              'Biometric enabled subtitle must use l10n.settingsBiometricLockEnabled '
              '(expected: "${_zhL10n.settingsBiometricLockEnabled}")',
        );
      },
    );

    testWidgets(
      'Billing tile from l10n (T20)',
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
          find.descendant(
            of: tile,
            matching: find.text(_zhL10n.settingsBillingTitle),
          ),
          findsOneWidget,
          reason: 'Billing tile title must use l10n.settingsBillingTitle '
              '(expected: "${_zhL10n.settingsBillingTitle}")',
        );
        expect(
          find.descendant(
            of: tile,
            matching: find.text(_zhL10n.settingsBillingSubtitle),
          ),
          findsOneWidget,
          reason: 'Billing subtitle must use l10n.settingsBillingSubtitle '
              '(expected: "${_zhL10n.settingsBillingSubtitle}")',
        );
      },
    );

    testWidgets(
      'Release Notes tile from l10n (T21)',
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
          find.descendant(
            of: tile,
            matching: find.text(_zhL10n.settingsReleaseNotesTitle),
          ),
          findsOneWidget,
          reason:
              'Release Notes tile title must use l10n.settingsReleaseNotesTitle '
              '(expected: "${_zhL10n.settingsReleaseNotesTitle}")',
        );
        expect(
          find.descendant(
            of: tile,
            matching: find.text(_zhL10n.settingsReleaseNotesSubtitle),
          ),
          findsOneWidget,
          reason:
              'Release Notes subtitle must use l10n.settingsReleaseNotesSubtitle '
              '(expected: "${_zhL10n.settingsReleaseNotesSubtitle}")',
        );
      },
    );

    testWidgets(
      'Diagnostics tile from l10n (T22)',
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
          find.descendant(
            of: tile,
            matching: find.text(_zhL10n.settingsDiagnosticsTitle),
          ),
          findsOneWidget,
          reason:
              'Diagnostics tile title must use l10n.settingsDiagnosticsTitle '
              '(expected: "${_zhL10n.settingsDiagnosticsTitle}")',
        );
        expect(
          find.descendant(
            of: tile,
            matching: find.text(_zhL10n.settingsDiagnosticsSubtitle),
          ),
          findsOneWidget,
          reason:
              'Diagnostics subtitle must use l10n.settingsDiagnosticsSubtitle '
              '(expected: "${_zhL10n.settingsDiagnosticsSubtitle}")',
        );
      },
    );

    testWidgets(
      'Log Out tile from l10n (T23)',
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
          find.descendant(
            of: tile,
            matching: find.text(_zhL10n.settingsLogOutTitle),
          ),
          findsOneWidget,
          reason: 'Log Out tile title must use l10n.settingsLogOutTitle '
              '(expected: "${_zhL10n.settingsLogOutTitle}")',
        );
        expect(
          find.descendant(
            of: tile,
            matching: find.text(_zhL10n.settingsLogOutSubtitle),
          ),
          findsOneWidget,
          reason: 'Log Out subtitle must use l10n.settingsLogOutSubtitle '
              '(expected: "${_zhL10n.settingsLogOutSubtitle}")',
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
      (tester) async {
        // Tap Log Out -> dialog appears with 4 strings.
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
          find.text(_zhL10n.settingsLogOutDialogTitle),
          findsOneWidget,
          reason: 'Dialog title must use l10n.settingsLogOutDialogTitle '
              '(expected: "${_zhL10n.settingsLogOutDialogTitle}")',
        );

        // Dialog content.
        expect(
          find.text(_zhL10n.settingsLogOutDialogContent),
          findsOneWidget,
          reason: 'Dialog content must use l10n.settingsLogOutDialogContent '
              '(expected: "${_zhL10n.settingsLogOutDialogContent}")',
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
            matching: find.text(_zhL10n.settingsLogOutDialogCancel),
          ),
          findsOneWidget,
          reason: 'Cancel button text must use l10n.settingsLogOutDialogCancel '
              '(expected: "${_zhL10n.settingsLogOutDialogCancel}")',
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
            matching: find.text(_zhL10n.settingsLogOutDialogConfirm),
          ),
          findsOneWidget,
          reason:
              'Confirm button text must use l10n.settingsLogOutDialogConfirm '
              '(expected: "${_zhL10n.settingsLogOutDialogConfirm}")',
        );
      },
    );

    testWidgets(
      'Profile card fallbacks from l10n (T25)',
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
          find.descendant(
            of: header,
            matching: find.text(_zhL10n.settingsSignedInFallback),
          ),
          findsOneWidget,
          reason: 'Fallback title must use l10n.settingsSignedInFallback when '
              'displayName is null '
              '(expected: "${_zhL10n.settingsSignedInFallback}")',
        );
        expect(
          find.descendant(
            of: header,
            matching: find.text(_zhL10n.settingsAccountUnavailable),
          ),
          findsOneWidget,
          reason: 'Fallback subtitle must use l10n.settingsAccountUnavailable '
              'when displayName is null '
              '(expected: "${_zhL10n.settingsAccountUnavailable}")',
        );
      },
    );

    // T26 — Split into individual tests per permission status.
    // Riverpod 2.6.1 ProviderScope.updateOverrides does not invalidate
    // NotifierProvider.overrideWith within a single testWidgets, so each
    // state needs its own fresh ProviderScope (separate testWidgets).
    testWidgets(
      'Notification permission unknown from l10n (T26a)',
      (tester) async {
        await tester.pumpWidget(_buildApp());
        await tester.pumpAndSettle();

        expect(
          find.textContaining(_zhL10n.settingsNotificationNotRequested),
          findsOneWidget,
          reason:
              'Permission unknown must show l10n.settingsNotificationNotRequested '
              '(expected: "${_zhL10n.settingsNotificationNotRequested}")',
        );
      },
    );

    testWidgets(
      'Notification permission granted from l10n (T26b)',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(
            notificationPermission: NotificationPermissionStatus.granted,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining(_zhL10n.settingsNotificationGranted),
          findsOneWidget,
          reason:
              'Permission granted must show l10n.settingsNotificationGranted '
              '(expected: "${_zhL10n.settingsNotificationGranted}")',
        );
      },
    );

    testWidgets(
      'Notification permission denied from l10n (T26c)',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(
            notificationPermission: NotificationPermissionStatus.denied,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining(_zhL10n.settingsNotificationDenied),
          findsOneWidget,
          reason: 'Permission denied must show l10n.settingsNotificationDenied '
              '(expected: "${_zhL10n.settingsNotificationDenied}")',
        );
      },
    );

    testWidgets(
      'Notification permission provisional from l10n (T26d)',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(
            notificationPermission: NotificationPermissionStatus.provisional,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining(_zhL10n.settingsNotificationProvisional),
          findsOneWidget,
          reason:
              'Permission provisional must show l10n.settingsNotificationProvisional '
              '(expected: "${_zhL10n.settingsNotificationProvisional}")',
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
