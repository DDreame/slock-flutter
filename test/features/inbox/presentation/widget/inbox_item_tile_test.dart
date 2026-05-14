import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/inbox/presentation/page/inbox_page.dart';

// ---------------------------------------------------------------------------
// #509: Inbox page redesign — Phase A (test-only)
//
// InboxItemTile widget contract tests — item anatomy, visual states, @mention.
// All 4 tests skip: true until Phase B implements the redesigned InboxItemTile.
//
// Phase B dependencies (data layer, scoped by S2):
//   - inbox_item.dart: add `isMentioned` field (test 4)
//   - inbox_repository.dart: add InboxFilter.mentions (page test 5)
//
// Invariants:
//   INV-INBOX-REDESIGN-1: Each inbox item shows sender avatar + name + preview + time
//   INV-INBOX-REDESIGN-2: @mention messages have "@you" badge
//   INV-INBOX-REDESIGN-3: Unread items visually distinct (accent bg + left bar + bold)
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // 1. INV-INBOX-REDESIGN-1: item shows sender avatar, name, preview, time
  // -----------------------------------------------------------------------
  testWidgets(
    'inbox item shows sender avatar, name, preview, and time '
    '(INV-INBOX-REDESIGN-1)',
    (tester) async {
      final repo = _FakeInboxRepository();
      repo.items = [
        _makeItem(
          channelId: 'ch-1',
          channelName: '#general',
          senderName: 'Alice',
          preview: 'Hey, check this out!',
          unread: 3,
          lastActivityAt: DateTime(2026, 5, 14, 10, 30),
        ),
      ];
      repo.totalUnreadCount = 3;

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      // Sender avatar (40×40 circle with gradient)
      expect(
        find.byKey(const ValueKey('inbox-tile-avatar-ch-1')),
        findsOneWidget,
        reason: 'INV-INBOX-REDESIGN-1: Item must show sender avatar',
      );

      // Sender name (14px, weight 600+)
      expect(
        find.text('Alice'),
        findsOneWidget,
        reason: 'INV-INBOX-REDESIGN-1: Item must show sender name',
      );

      // Preview text (13px, 2-line clamp)
      expect(
        find.text('Hey, check this out!'),
        findsOneWidget,
        reason: 'INV-INBOX-REDESIGN-1: Item must show preview text',
      );

      // Time display (12px tabular-nums)
      expect(
        find.byKey(const ValueKey('inbox-tile-time-ch-1')),
        findsOneWidget,
        reason: 'INV-INBOX-REDESIGN-1: Item must show activity time',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 2. INV-INBOX-REDESIGN-3: unread item has accent bg + left bar
  // -----------------------------------------------------------------------
  testWidgets(
    'unread item has accent background and left bar indicator '
    '(INV-INBOX-REDESIGN-3)',
    (tester) async {
      final repo = _FakeInboxRepository();
      repo.items = [
        _makeItem(
          channelId: 'ch-1',
          channelName: '#general',
          senderName: 'Bob',
          preview: 'New update available',
          unread: 5,
        ),
      ];
      repo.totalUnreadCount = 5;

      await tester.pumpWidget(_buildApp(repo, theme: AppTheme.dark));
      await tester.pumpAndSettle();

      // Unread indicator container (accent-soft bg + 3px solid left bar)
      final indicator = find.byKey(
        const ValueKey('inbox-tile-unread-indicator-ch-1'),
      );
      expect(
        indicator,
        findsOneWidget,
        reason:
            'INV-INBOX-REDESIGN-3: Unread item must have left bar indicator',
      );

      // Unread count pill (accent bg, white text)
      expect(
        find.byKey(const ValueKey('inbox-tile-count-ch-1')),
        findsOneWidget,
        reason: 'INV-INBOX-REDESIGN-3: Unread item must show count pill',
      );

      // Sender name bold (fontWeight 700 for unread)
      final senderText = tester.widget<Text>(find.text('Bob'));
      expect(
        senderText.style?.fontWeight,
        FontWeight.w700,
        reason: 'INV-INBOX-REDESIGN-3: Unread sender name must be bold (w700)',
      );

      // Time uses accent color for unread
      final timeWidget = tester.widget<Text>(
        find.byKey(const ValueKey('inbox-tile-time-ch-1')),
      );
      expect(
        timeWidget.style?.color,
        AppColors.dark.primary,
        reason: 'INV-INBOX-REDESIGN-3: Unread time must use accent color',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 3. INV-INBOX-REDESIGN-3: read item has no accent + no left bar
  // -----------------------------------------------------------------------
  testWidgets(
    'read item has no accent background and no left bar '
    '(INV-INBOX-REDESIGN-3)',
    (tester) async {
      final repo = _FakeInboxRepository();
      repo.items = [
        _makeItem(
          channelId: 'ch-read',
          channelName: '#random',
          senderName: 'Charlie',
          preview: 'Old message',
          unread: 0,
        ),
      ];

      await tester.pumpWidget(_buildApp(repo, theme: AppTheme.dark));
      await tester.pumpAndSettle();

      // No unread indicator
      expect(
        find.byKey(const ValueKey('inbox-tile-unread-indicator-ch-read')),
        findsNothing,
        reason: 'INV-INBOX-REDESIGN-3: Read item must NOT have left bar',
      );

      // No count pill
      expect(
        find.byKey(const ValueKey('inbox-tile-count-ch-read')),
        findsNothing,
        reason: 'INV-INBOX-REDESIGN-3: Read item must NOT show count pill',
      );

      // Sender name normal weight (500 for read)
      final senderText = tester.widget<Text>(find.text('Charlie'));
      expect(
        senderText.style?.fontWeight,
        FontWeight.w500,
        reason: 'INV-INBOX-REDESIGN-3: Read sender name should be w500',
      );

      // Time uses tertiary color for read
      final timeWidget = tester.widget<Text>(
        find.byKey(const ValueKey('inbox-tile-time-ch-read')),
      );
      expect(
        timeWidget.style?.color,
        AppColors.dark.textTertiary,
        reason: 'INV-INBOX-REDESIGN-3: Read time must use textTertiary color',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 4. INV-INBOX-REDESIGN-2: @mention item shows @you badge
  // -----------------------------------------------------------------------
  testWidgets(
    '@mention item shows @you badge '
    '(INV-INBOX-REDESIGN-2)',
    (tester) async {
      final repo = _FakeInboxRepository();
      repo.items = [
        _makeItem(
          channelId: 'ch-mention',
          channelName: '#engineering',
          senderName: 'Dave',
          preview: 'Can you review this PR?',
          unread: 2,
          isMentioned: true,
          // Phase B added `isMentioned` field to InboxItem
          // (inbox_item.dart, scoped by S2) and propagates it through
          // InboxPage → InboxItemTile.
        ),
      ];
      repo.totalUnreadCount = 2;

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      // @you badge (accent-soft bg, accent text, 10px)
      expect(
        find.byKey(const ValueKey('inbox-tile-mention-badge-ch-mention')),
        findsOneWidget,
        reason: 'INV-INBOX-REDESIGN-2: Mentioned item must show "@you" badge',
      );

      // Badge text content
      expect(
        find.text('@you'),
        findsOneWidget,
        reason: 'INV-INBOX-REDESIGN-2: Badge must display "@you" text',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildApp(_FakeInboxRepository repo, {ThemeData? theme}) {
  return ProviderScope(
    overrides: [
      inboxRepositoryProvider.overrideWithValue(repo),
      activeServerScopeIdProvider
          .overrideWith((_) => const ServerScopeId('server-1')),
    ],
    child: MaterialApp(
      theme: theme ?? AppTheme.light,
      home: const InboxPage(),
    ),
  );
}

InboxItem _makeItem({
  required String channelId,
  required String channelName,
  int unread = 0,
  InboxItemKind kind = InboxItemKind.channel,
  String? senderName,
  String? preview,
  DateTime? lastActivityAt,
  bool isMentioned = false,
}) {
  return InboxItem(
    kind: kind,
    channelId: channelId,
    channelName: channelName,
    unreadCount: unread,
    senderName: senderName,
    preview: preview,
    isMentioned: isMentioned,
    lastActivityAt:
        lastActivityAt ?? DateTime.now().subtract(const Duration(minutes: 5)),
  );
}

// ---------------------------------------------------------------------------
// Fake repository (same pattern as inbox_page_test.dart)
// ---------------------------------------------------------------------------

class _FakeInboxRepository implements InboxRepository {
  List<InboxItem> items = [];
  int totalUnreadCount = 0;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    if (offset > 0) {
      return InboxResponse(
        items: const [],
        totalCount: items.length,
        totalUnreadCount: totalUnreadCount,
        hasMore: false,
      );
    }
    return InboxResponse(
      items: items,
      totalCount: items.length,
      totalUnreadCount: totalUnreadCount > 0 ? totalUnreadCount : _calcUnread(),
      hasMore: false,
    );
  }

  @override
  Future<void> markItemDone(ServerScopeId serverId,
      {required String channelId}) async {}

  @override
  Future<void> markItemRead(ServerScopeId serverId,
      {required String channelId}) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}

  int _calcUnread() => items.fold(0, (sum, item) => sum + item.unreadCount);
}
