import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
// Inbox page-level contract tests — filter tabs, swipe-to-mark-read, empty state.
// Tests 5–6 skip: true until Phase B implements 3-tab filter + swipe-read.
// Test 7 passes on current codebase (empty state already implemented).
//
// Phase B dependencies (data layer, scoped by S2):
//   - inbox_repository.dart: add InboxFilter.mentions (test 5)
//   - inbox_page.dart: 3-tab filter UI + swipe-left mark-read action
//
// Design: Z2 inbox-redesign mockup
//   - 3 filter tabs: Unread (default) | @Mentions | All
//   - Swipe left: mark read (blue reveal + checkmark)
//   - Empty state: icon + "All caught up!" + description
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // 5. Filter tabs switch between Unread, @Mentions, and All
  //
  // Phase B: requires InboxFilter.mentions in inbox_repository.dart
  //          (data-layer widening scoped by S2).
  // -----------------------------------------------------------------------
  testWidgets(
    'filter tabs switch between Unread, Mentions, and All',
    (tester) async {
      final repo = _FakeInboxRepository();
      repo.items = [
        _makeItem(
          channelId: 'ch-1',
          channelName: '#general',
          senderName: 'Alice',
          preview: 'Hello team',
          unread: 3,
        ),
        _makeItem(
          channelId: 'ch-2',
          channelName: '#random',
          senderName: 'Bob',
          preview: 'Check this out',
          unread: 0,
        ),
      ];
      repo.totalUnreadCount = 3;

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      // All 3 filter tabs should be visible.
      expect(
        find.byKey(const ValueKey('inbox-filter-unread')),
        findsOneWidget,
        reason: 'Unread filter tab must be present',
      );
      expect(
        find.byKey(const ValueKey('inbox-filter-mentions')),
        findsOneWidget,
        reason: '@Mentions filter tab must be present',
      );
      expect(
        find.byKey(const ValueKey('inbox-filter-all')),
        findsOneWidget,
        reason: 'All filter tab must be present',
      );

      // Default tab is Unread — only unread items visible.
      expect(
        find.byKey(const ValueKey('inbox-item-ch-1')),
        findsOneWidget,
        reason: 'Unread item must be visible in Unread filter',
      );
      // Regression: read item must NOT be visible in Unread filter.
      expect(
        find.byKey(const ValueKey('inbox-item-ch-2')),
        findsNothing,
        reason: 'Read item must NOT be visible in default Unread filter',
      );

      // Tap "All" filter tab.
      await tester.tap(find.byKey(const ValueKey('inbox-filter-all')));
      await tester.pumpAndSettle();

      // Both items visible in All filter.
      expect(
        find.byKey(const ValueKey('inbox-item-ch-1')),
        findsOneWidget,
        reason: 'Unread item must be visible in All filter',
      );
      expect(
        find.byKey(const ValueKey('inbox-item-ch-2')),
        findsOneWidget,
        reason: 'Read item must also be visible in All filter',
      );

      // Tap "@Mentions" filter tab.
      await tester.tap(find.byKey(const ValueKey('inbox-filter-mentions')));
      await tester.pumpAndSettle();

      // Only @mentioned items should be visible (repo.lastFilter == mentions).
      expect(
        repo.lastFilter,
        'mentions',
        reason: '@Mentions tab must request mentions filter from repository',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 6. Swipe left marks item as read (not done)
  //
  // Tests under All filter so the item stays visible after mark-read
  // (InboxStore removes read items from Unread filter).
  // -----------------------------------------------------------------------
  testWidgets(
    'swipe left on unread item marks it as read',
    (tester) async {
      final repo = _FakeInboxRepository();
      repo.items = [
        _makeItem(
          channelId: 'ch-1',
          channelName: '#general',
          senderName: 'Alice',
          preview: 'New message',
          unread: 4,
        ),
      ];
      repo.totalUnreadCount = 4;

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      // Ensure we are on All filter (default) so item stays after mark-read.
      // Production InboxStore removes read items from Unread filter.
      await tester.tap(find.byKey(const ValueKey('inbox-filter-all')));
      await tester.pumpAndSettle();

      // Unread badge visible before swipe.
      expect(
        find.byKey(const ValueKey('inbox-unread-badge-ch-1')),
        findsOneWidget,
        reason: 'Unread badge must be visible before swipe',
      );

      // Swipe left (endToStart in LTR layout) for mark-read action.
      // Phase B: SwipeActionWrapper will add a left-swipe action
      // for mark-read with blue reveal + checkmark icon.
      await tester.drag(
        find.byKey(const ValueKey('inbox-item-ch-1')),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();

      // Item stays in the list (All filter keeps read items)
      // but unread badge is gone (optimistic zeroing).
      expect(
        find.byKey(const ValueKey('inbox-item-ch-1')),
        findsOneWidget,
        reason: 'Item must stay in list after mark-read swipe (All filter)',
      );
      expect(
        find.byKey(const ValueKey('inbox-unread-badge-ch-1')),
        findsNothing,
        reason: 'Unread badge must be removed after mark-read swipe',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 7. Empty inbox shows "All caught up!" message
  // -----------------------------------------------------------------------
  testWidgets(
    'empty inbox shows all caught up message',
    (tester) async {
      final repo = _FakeInboxRepository();
      repo.items = [];

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      // Empty state container
      expect(
        find.byKey(const ValueKey('inbox-empty')),
        findsOneWidget,
        reason: 'Empty state must be shown when inbox has no items',
      );

      // Title text
      expect(
        find.text('All caught up!'),
        findsOneWidget,
        reason: 'Empty state must show "All caught up!" title',
      );

      // Description text
      expect(
        find.text('No messages in your inbox'),
        findsOneWidget,
        reason: 'Empty state must show description text',
      );

      // Icon
      expect(
        find.byIcon(Icons.inbox_outlined),
        findsOneWidget,
        reason: 'Empty state must show inbox icon',
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
}) {
  return InboxItem(
    kind: kind,
    channelId: channelId,
    channelName: channelName,
    unreadCount: unread,
    senderName: senderName,
    preview: preview,
    lastActivityAt: DateTime.now().subtract(const Duration(minutes: 5)),
  );
}

// ---------------------------------------------------------------------------
// Fake repository
// ---------------------------------------------------------------------------

class _FakeInboxRepository implements InboxRepository {
  List<InboxItem> items = [];
  int totalUnreadCount = 0;
  String? lastFilter;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    lastFilter = filter.queryValue;
    if (offset > 0) {
      return InboxResponse(
        items: const [],
        totalCount: items.length,
        totalUnreadCount: totalUnreadCount,
        hasMore: false,
      );
    }
    // Filter-aware: simulate server-side filtering for unread/mentions/dms.
    final filtered = switch (filter) {
      InboxFilter.unread => items.where((i) => i.unreadCount > 0).toList(),
      InboxFilter.mentions => items.where((i) => i.isMentioned).toList(),
      InboxFilter.dms =>
        items.where((i) => i.kind == InboxItemKind.dm).toList(),
      InboxFilter.all => items,
    };
    return InboxResponse(
      items: filtered,
      totalCount: filtered.length,
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
