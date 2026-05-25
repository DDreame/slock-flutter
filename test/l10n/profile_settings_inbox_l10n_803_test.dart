// =============================================================================
// #803 Phase A — L10n Sweep: Profile + Settings + Inbox
//
// Invariants verified:
// 1. profile/settings/inbox-prefixed ARB keys are symmetric across EN, ZH, ES
// 2. All profile/settings/inbox-prefixed keys have non-empty values
// 3. SettingsPage renders without crash in ZH locale
// 4. ProfileEditPage renders without crash in ZH locale
// 5. ProfilePage (self) renders without crash in ZH locale
// =============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/profile/presentation/page/profile_edit_page.dart';
import 'package:slock_app/features/profile/presentation/page/profile_page.dart';
import 'package:slock_app/features/settings/presentation/page/settings_page.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';
import 'package:slock_app/stores/biometric/biometric_store.dart';
import 'package:slock_app/features/profile/application/profile_edit_store.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'test-user',
        displayName: 'Test User',
      );
}

class _FakeNotificationStore extends NotificationStore {
  @override
  NotificationState build() => const NotificationState();
}

class _FakeThemeModeStore extends ThemeModeStore {
  @override
  ThemeModeState build() => const ThemeModeState();
}

class _FakeBiometricStore extends BiometricStore {
  @override
  BiometricState build() => const BiometricState();
}

class _FakeProfileEditStore extends ProfileEditStore {
  @override
  ProfileEditState build() => const ProfileEditState();
}

void main() {
  // ---------------------------------------------------------------------------
  // ARB key parity
  // ---------------------------------------------------------------------------
  group('Profile/Settings/Inbox ARB key parity', () {
    late Map<String, dynamic> enArb;
    late Map<String, dynamic> zhArb;
    late Map<String, dynamic> esArb;

    setUpAll(() {
      final enFile = File('lib/l10n/app_en.arb');
      final zhFile = File('lib/l10n/app_zh.arb');
      final esFile = File('lib/l10n/app_es.arb');
      expect(enFile.existsSync(), isTrue);
      expect(zhFile.existsSync(), isTrue);
      expect(esFile.existsSync(), isTrue);
      enArb = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
      zhArb = jsonDecode(zhFile.readAsStringSync()) as Map<String, dynamic>;
      esArb = jsonDecode(esFile.readAsStringSync()) as Map<String, dynamic>;
    });

    test(
      'profile/settings/inbox-prefixed keys are symmetric across EN, ZH, ES '
      '(INV-803-PARITY-1)',
      () {
        bool isTarget(String k) =>
            k.startsWith('profile') ||
            k.startsWith('settings') ||
            k.startsWith('inbox');

        final enKeys =
            enArb.keys.where((k) => !k.startsWith('@') && isTarget(k)).toSet();
        final zhKeys =
            zhArb.keys.where((k) => !k.startsWith('@') && isTarget(k)).toSet();
        final esKeys =
            esArb.keys.where((k) => !k.startsWith('@') && isTarget(k)).toSet();

        final enOnlyZh = enKeys.difference(zhKeys);
        final zhOnlyEn = zhKeys.difference(enKeys);
        final enOnlyEs = enKeys.difference(esKeys);
        final esOnlyEn = esKeys.difference(enKeys);

        expect(enOnlyZh, isEmpty, reason: 'EN keys missing from ZH: $enOnlyZh');
        expect(zhOnlyEn, isEmpty, reason: 'ZH keys missing from EN: $zhOnlyEn');
        expect(enOnlyEs, isEmpty, reason: 'EN keys missing from ES: $enOnlyEs');
        expect(esOnlyEn, isEmpty, reason: 'ES keys missing from EN: $esOnlyEn');
      },
    );

    test(
      'all profile/settings/inbox-prefixed keys have non-empty values',
      () {
        bool isTarget(String k) =>
            k.startsWith('profile') ||
            k.startsWith('settings') ||
            k.startsWith('inbox');

        for (final entry in enArb.entries) {
          if (entry.key.startsWith('@') || !isTarget(entry.key)) continue;
          expect(entry.value, isNotEmpty,
              reason: 'EN key "${entry.key}" is empty');
        }
        for (final entry in zhArb.entries) {
          if (entry.key.startsWith('@') || !isTarget(entry.key)) continue;
          expect(entry.value, isNotEmpty,
              reason: 'ZH key "${entry.key}" is empty');
        }
        for (final entry in esArb.entries) {
          if (entry.key.startsWith('@') || !isTarget(entry.key)) continue;
          expect(entry.value, isNotEmpty,
              reason: 'ES key "${entry.key}" is empty');
        }
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Locale render — SettingsPage
  // ---------------------------------------------------------------------------
  group('SettingsPage locale render', () {
    testWidgets(
      'SettingsPage renders without crash in ZH locale (INV-803-RENDER-1)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionStoreProvider.overrideWith(_FakeSessionStore.new),
              notificationStoreProvider
                  .overrideWith(_FakeNotificationStore.new),
              themeModeStoreProvider.overrideWith(_FakeThemeModeStore.new),
              biometricStoreProvider.overrideWith(_FakeBiometricStore.new),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const SettingsPage(),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Locale render — ProfileEditPage
  // ---------------------------------------------------------------------------
  group('ProfileEditPage locale render', () {
    testWidgets(
      'ProfileEditPage renders without crash in ZH locale (INV-803-RENDER-2)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionStoreProvider.overrideWith(_FakeSessionStore.new),
              profileEditStoreProvider.overrideWith(_FakeProfileEditStore.new),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const ProfileEditPage(),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Locale render — ProfilePage (self)
  // ---------------------------------------------------------------------------
  group('ProfilePage locale render', () {
    testWidgets(
      'ProfilePage (self) renders without crash in ZH locale (INV-803-RENDER-3)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionStoreProvider.overrideWith(_FakeSessionStore.new),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const ProfilePage(),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
