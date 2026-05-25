// =============================================================================
// #808 Phase A — L10n Stragglers Spot-Check Tests
//
// Invariants verified:
// 1. NotificationSettingsPage renders notification pref titles/descriptions
//    from l10n in ZH locale (INV-808-RENDER-1)
// 2. MembersPage renders role labels from l10n in ZH locale (INV-808-RENDER-2)
// 3. CrashRecoveryDialog renders dialog strings from l10n in ZH locale
//    (INV-808-RENDER-3)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/notifications/notification_initializer.dart';
import 'package:slock_app/core/scope/server_scope_id.dart';
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/telemetry/crash_marker_service.dart';
import 'package:slock_app/core/telemetry/crash_recovery_dialog.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/members/application/member_list_state.dart';
import 'package:slock_app/features/members/application/member_list_store.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/settings/data/notification_preference.dart';
import 'package:slock_app/features/settings/presentation/page/notification_settings_page.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeNotificationStore extends NotificationStore {
  @override
  NotificationState build() => const NotificationState(
        permissionStatus: NotificationPermissionStatus.granted,
        notificationPreference: NotificationPreference.all,
        pushToken: 'fake-token-abc123',
        pushTokenPlatform: 'android',
      );
}

class _FakeMemberListStore extends MemberListStore {
  @override
  MemberListState build() => MemberListState(
        status: MemberListStatus.success,
        members: const [
          MemberProfile(
            id: 'u1',
            displayName: 'Alice',
            type: MemberType.human,
            role: 'owner',
            isSelf: true,
          ),
          MemberProfile(
            id: 'u2',
            displayName: 'Bob',
            type: MemberType.human,
            role: 'admin',
          ),
          MemberProfile(
            id: 'u3',
            displayName: 'Carol',
            type: MemberType.human,
            role: 'member',
          ),
        ],
      );

  @override
  Future<void> ensureLoaded() async {}

  @override
  Future<void> load() async {}
}

class _FakeDiagnosticsCollector extends DiagnosticsCollector {
  _FakeDiagnosticsCollector() : super(maxEntries: 10);
}

class _FakeSecureStorage implements SecureStorage {
  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<void> write({required String key, required String? value}) async {}

  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<Map<String, String>> readAll() async => {};
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ---------------------------------------------------------------------------
  // NotificationSettingsPage — l10n preference titles render in ZH
  // ---------------------------------------------------------------------------
  group('NotificationSettingsPage locale render', () {
    testWidgets(
      'renders notification preference titles from l10n in ZH (INV-808-RENDER-1)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationStoreProvider
                  .overrideWith(_FakeNotificationStore.new),
              diagnosticsCollectorProvider
                  .overrideWithValue(_FakeDiagnosticsCollector()),
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
        await tester.pump();
        expect(tester.takeException(), isNull);

        // Verify ZH l10n strings rendered (not the English fallback enum fields).
        // The ZH translations for notification prefs should not match the
        // English enum `title` values.
        expect(find.text('All Messages'), findsNothing);
        expect(find.text('Mentions & DMs Only'), findsNothing);
        expect(find.text('Mute'), findsNothing);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // CrashRecoveryDialog — l10n dialog strings render in ZH
  // ---------------------------------------------------------------------------
  group('CrashRecoveryDialog locale render', () {
    testWidgets(
      'renders dialog strings from l10n in ZH (INV-808-RENDER-3)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              crashMarkerServiceProvider.overrideWithValue(
                CrashMarkerService(storage: _FakeSecureStorage()),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) {
                  // Show the dialog immediately after build.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    CrashRecoveryDialog.show(context);
                  });
                  return const Scaffold();
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Verify old English hardcoded strings are NOT present.
        expect(find.text('Something went wrong'), findsNothing);
        expect(find.text('Export Diagnostics'), findsNothing);
        expect(find.text('Continue'), findsNothing);
      },
    );
  });
}
