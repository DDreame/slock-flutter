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
import 'package:slock_app/core/storage/secure_storage.dart';
import 'package:slock_app/core/telemetry/crash_marker_service.dart';
import 'package:slock_app/core/telemetry/crash_recovery_dialog.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/members/application/member_list_state.dart';
import 'package:slock_app/features/members/application/member_list_store.dart';
import 'package:slock_app/features/members/application/members_realtime_binding.dart';
import 'package:slock_app/features/members/presentation/page/members_page.dart';
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

class _FakeMemberListStoreFailure extends MemberListStore {
  @override
  MemberListState build() => MemberListState(
        status: MemberListStatus.failure,
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
  Future<void> write({required String key, required String value}) async {}

  @override
  Future<void> delete({required String key}) async {}
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

        // Negative: old English enum field values must NOT appear.
        expect(find.text('All Messages'), findsNothing);
        expect(find.text('Mentions & DMs Only'), findsNothing);
        expect(find.text('Mute'), findsNothing);

        // Positive: ZH l10n strings must be present.
        expect(find.text('所有消息'), findsOneWidget);
        expect(find.text('仅提及和私信'), findsOneWidget);
        expect(find.text('静音'), findsOneWidget);
        // Page title from l10n.
        expect(find.text('通知设置'), findsOneWidget);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // MembersPage — l10n error state strings render in ZH
  // ---------------------------------------------------------------------------
  group('MembersPage locale render', () {
    testWidgets(
      'renders error state strings from l10n in ZH (INV-808-RENDER-2)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              memberListStoreProvider
                  .overrideWith(() => _FakeMemberListStoreFailure()),
              membersRealtimeBindingProvider.overrideWith((ref) {}),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MembersPage(serverId: 'srv-1'),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        // Positive: ZH l10n error state strings must be present.
        expect(find.text('成员'), findsOneWidget); // page title
        expect(find.text('成员不可用'), findsOneWidget); // error title
        expect(find.text('目前无法加载工作区成员。'), findsOneWidget); // error msg
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

        // Negative: old English hardcoded strings must NOT appear.
        expect(find.text('Something went wrong'), findsNothing);
        expect(find.text('Export Diagnostics'), findsNothing);

        // Positive: ZH l10n strings must be present.
        expect(find.text('应用已恢复'), findsOneWidget);
        expect(find.text('继续'), findsOneWidget);
        expect(find.text('导出诊断日志'), findsOneWidget);
      },
    );
  });
}
