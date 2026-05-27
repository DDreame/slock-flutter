// =============================================================================
// #837 — ARB Cleanup Load-Bearing Tests
//
// Invariants verified (all use ZH locale — if anyone re-introduces dead enum
// title/description fields with English strings, these tests stay GREEN because
// they prove the PRESENTATION layer uses l10n, not enum fields):
//
// INV-837-SETTINGS-1: AppearanceSettingsPage renders ZH theme titles from l10n
// INV-837-SETTINGS-2: NotificationSettingsPage renders ZH notification pref
//                     titles from l10n
// =============================================================================

// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/settings/data/notification_preference.dart';
import 'package:slock_app/features/settings/presentation/page/appearance_settings_page.dart';
import 'package:slock_app/features/settings/presentation/page/notification_settings_page.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

void main() {
  // ---------------------------------------------------------------------------
  // INV-837-SETTINGS-1: AppearanceSettingsPage uses l10n for theme titles
  // ---------------------------------------------------------------------------
  group('INV-837-SETTINGS-1: AppearanceSettingsPage theme l10n', () {
    testWidgets(
      'shows ZH theme titles (跟随系统, 浅色, 深色), not English',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              themeModeStoreProvider.overrideWith(() => _FixedThemeModeStore()),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const AppearanceSettingsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // ZH titles from l10n switch expression must render.
        expect(find.text('跟随系统'), findsOneWidget);
        expect(find.text('浅色'), findsOneWidget);
        expect(find.text('深色'), findsOneWidget);

        // Dead English enum titles must NOT appear.
        expect(find.text('Follow System'), findsNothing);
        expect(find.text('Light'), findsNothing);
        expect(find.text('Dark'), findsNothing);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-837-SETTINGS-2: NotificationSettingsPage uses l10n for pref titles
  // ---------------------------------------------------------------------------
  group('INV-837-SETTINGS-2: NotificationSettingsPage pref l10n', () {
    testWidgets(
      'shows ZH notification pref titles (所有消息, 仅提及和私信, 静音), not English',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationStoreProvider
                  .overrideWith(() => _FixedNotificationStore()),
              diagnosticsCollectorProvider
                  .overrideWithValue(DiagnosticsCollector()),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const NotificationSettingsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // ZH titles from l10n switch expression must render.
        expect(find.text('所有消息'), findsOneWidget);
        expect(find.text('仅提及和私信'), findsOneWidget);
        expect(find.text('静音'), findsOneWidget);

        // Dead English enum titles must NOT appear.
        expect(find.text('All Messages'), findsNothing);
        expect(find.text('Mentions & DMs Only'), findsNothing);
        expect(find.text('Mute'), findsNothing);
      },
    );
  });
}

/// Fixed theme mode store that returns default (system) preference.
class _FixedThemeModeStore extends ThemeModeStore {
  @override
  ThemeModeState build() => const ThemeModeState();
}

/// Fixed notification store that returns default state with all permission
/// fields set so the page renders fully.
class _FixedNotificationStore extends NotificationStore {
  @override
  NotificationState build() => const NotificationState(
        permissionStatus: NotificationPermissionStatus.granted,
        notificationPreference: NotificationPreference.all,
      );
}
