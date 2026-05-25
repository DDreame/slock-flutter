import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/inbox/application/conversation_projection.dart';
import 'package:slock_app/features/inbox/presentation/widgets/inbox_item_tile.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/presentation/page/workspace_settings_page.dart';
import 'package:slock_app/features/settings/data/notification_preference.dart';
import 'package:slock_app/features/settings/presentation/page/notification_settings_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';

// ---------------------------------------------------------------------------
// #811: Locale-Aware Date Formatting — Phase A
//
// Verifies that all 3 surfaces render dates using locale-aware formatting
// instead of hardcoded ISO / US-centric patterns.
//
// Invariants:
//   INV-811-DATE-1: WorkspaceSettings renders locale-aware created date
//   INV-811-DATE-2: InboxItemTile renders locale-aware date for >7-day items
//   INV-811-DATE-3: NotificationSettings renders locale-aware push token date
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() => initializeDateFormatting());

  // -------------------------------------------------------------------------
  // 1. INV-811-DATE-1: WorkspaceSettings shows locale-aware date
  // -------------------------------------------------------------------------
  testWidgets(
    'workspace settings renders locale-formatted created date in ZH '
    '(INV-811-DATE-1)',
    (tester) async {
      final createdAt = DateTime(2026, 1, 15);
      final expectedZh = DateFormat.yMMMd('zh').format(createdAt);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverListStoreProvider.overrideWith(() {
              return _FakeServerListStore(
                ServerListState(
                  status: ServerListStatus.success,
                  servers: [
                    ServerSummary(
                      id: 'server-1',
                      name: 'My Workspace',
                      slug: 'my-workspace',
                      role: 'owner',
                      createdAt: createdAt,
                    ),
                  ],
                ),
              );
            }),
          ],
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: WorkspaceSettingsPage(serverId: 'server-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must NOT show hardcoded ISO format
      expect(
        find.text('2026-01-15'),
        findsNothing,
        reason: 'INV-811-DATE-1: Must not show hardcoded ISO date format',
      );

      // Must show locale-aware formatted date
      expect(
        find.text(expectedZh),
        findsOneWidget,
        reason:
            'INV-811-DATE-1: Must show ZH locale-formatted date: $expectedZh',
      );
    },
  );

  // -------------------------------------------------------------------------
  // 2. INV-811-DATE-2: InboxItemTile shows locale-aware date for old items
  // -------------------------------------------------------------------------
  testWidgets(
    'inbox item tile renders locale-formatted date for >7 day items in ZH '
    '(INV-811-DATE-2)',
    (tester) async {
      // 30 days ago — should trigger the date-format branch (not relative)
      final oldTime = DateTime.now().subtract(const Duration(days: 30));
      final expectedZh = DateFormat.MMMd('zh').format(oldTime);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: InboxItemTile(
              projection: ConversationProjection(
                kind: ConversationProjectionKind.channel,
                id: 'channel:ch-old',
                title: '#archive',
                previewText: 'Old message',
                unreadCount: 1,
                senderName: 'Alice',
                lastActivityAt: oldTime,
                channelId: 'ch-old',
              ),
              isMentioned: false,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must NOT show US-centric M/d format
      final usCentric = '${oldTime.month}/${oldTime.day}';
      expect(
        find.text(usCentric),
        findsNothing,
        reason: 'INV-811-DATE-2: Must not show US-centric M/d date format',
      );

      // Must show locale-aware formatted date
      expect(
        find.text(expectedZh),
        findsOneWidget,
        reason:
            'INV-811-DATE-2: Must show ZH locale-formatted date: $expectedZh',
      );
    },
  );

  // -------------------------------------------------------------------------
  // 3. INV-811-DATE-3: NotificationSettings shows locale-aware date
  // -------------------------------------------------------------------------
  testWidgets(
    'notification settings renders locale-formatted push token date in ZH '
    '(INV-811-DATE-3)',
    (tester) async {
      final tokenDate = DateTime(2026, 4, 25, 14, 30);
      final expectedZh = DateFormat.yMMMd('zh').add_Hm().format(tokenDate);

      final store = _FakeNotificationStore(
        initialState: NotificationState(
          permissionStatus: NotificationPermissionStatus.granted,
          pushToken: 'abcdefghijklmnopqrstuvwxyz1234567890',
          pushTokenPlatform: 'android',
          pushTokenUpdatedAt: tokenDate,
        ),
      );
      final diagnostics = DiagnosticsCollector();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationStoreProvider.overrideWith(() => store),
            diagnosticsCollectorProvider.overrideWithValue(diagnostics),
          ],
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NotificationSettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must NOT show raw ISO-8601 string
      expect(
        find.textContaining(tokenDate.toIso8601String()),
        findsNothing,
        reason: 'INV-811-DATE-3: Must not show raw ISO-8601 timestamp',
      );

      // Must show locale-aware formatted date somewhere in the subtitle
      expect(
        find.textContaining(expectedZh),
        findsWidgets,
        reason: 'INV-811-DATE-3: Must show ZH locale-formatted date+time: '
            '$expectedZh',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeServerListStore extends ServerListStore {
  _FakeServerListStore(this._state);

  final ServerListState _state;

  @override
  ServerListState build() => _state;

  @override
  Future<void> retry() async {}

  @override
  Future<ServerSummary> createServer(String name) async {
    return const ServerSummary(id: 'fake', name: 'fake');
  }

  @override
  Future<AcceptInviteResult> acceptInvite(String code) async {
    return const AcceptInviteResult(serverId: 'fake');
  }

  @override
  Future<ServerSummary?> renameServer(String id, String name) async {
    return null;
  }

  @override
  Future<void> deleteServer(String id) async {}

  @override
  Future<void> leaveServer(String id) async {}
}

class _FakeNotificationStore extends NotificationStore {
  _FakeNotificationStore({NotificationState? initialState})
      : _initialState = initialState;

  final NotificationState? _initialState;

  @override
  NotificationState build() => _initialState ?? const NotificationState();

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> refreshToken({String? platform}) async {}

  @override
  Future<void> setNotificationPreference(
    NotificationPreference preference,
  ) async {}
}
