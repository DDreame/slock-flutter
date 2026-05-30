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
import 'package:slock_app/l10n/l10n.dart';

// ---------------------------------------------------------------------------
// #522: Inbox Filter Enhancement — Phase A (test-only)
//
// 2 tests:
//   INV-FILTER-1: Mentions tab → only @mention items (non-skip, already live)
//   INV-FILTER-2: DMs tab → only DM source items (skip:true until Phase B)
//
// Phase B: Add InboxFilter.dms enum value + UI tab + projection guard.
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // 1. Mentions tab → only @mention items (INV-FILTER-1)
  //
  // The @Mentions tab already exists in production. This test verifies
  // that tapping @Mentions sends the mentions filter to the repository
  // and that only mentioned items are shown.
  // -----------------------------------------------------------------------
  testWidgets(
    'Inbox: Mentions tab filters to only @mention items '
    '(INV-FILTER-1)',
    (tester) async {
      final repo = _FakeInboxRepository();
      repo.items = [
        _makeItem(
          channelId: 'ch-1',
          channelName: '#general',
          senderName: 'Alice',
          preview: 'Hey @you check this',
          unread: 2,
          isMentioned: true,
        ),
        _makeItem(
          channelId: 'ch-2',
          channelName: '#random',
          senderName: 'Bob',
          preview: 'Regular message',
          unread: 1,
          isMentioned: false,
        ),
      ];
      repo.totalUnreadCount = 3;

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      // Default filter is Unread — both items visible (both have unread > 0).
      expect(
        find.byKey(const ValueKey('inbox-item-ch-1')),
        findsOneWidget,
        reason: 'Mentioned item must be visible in default Unread filter',
      );
      expect(
        find.byKey(const ValueKey('inbox-item-ch-2')),
        findsOneWidget,
        reason: 'Non-mentioned item must be visible in Unread filter',
      );

      // Tap @Mentions filter tab.
      await tester.tap(find.byKey(const ValueKey('inbox-filter-mentions')));
      await tester.pumpAndSettle();

      // Repository must receive mentions filter.
      expect(
        repo.lastFilter,
        'mentions',
        reason: '@Mentions tab must send mentions filter to repository '
            '(INV-FILTER-1)',
      );

      // Only mentioned item should be visible.
      expect(
        find.byKey(const ValueKey('inbox-item-ch-1')),
        findsOneWidget,
        reason: 'Mentioned item must be visible in @Mentions filter '
            '(INV-FILTER-1)',
      );
      expect(
        find.byKey(const ValueKey('inbox-item-ch-2')),
        findsNothing,
        reason: 'Non-mentioned item must NOT be visible in @Mentions filter '
            '(INV-FILTER-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // 2. DMs tab → only DM source items (INV-FILTER-2)
  //
  // Phase B: Add InboxFilter.dms enum value, _FilterTab UI entry with
  //   key 'inbox-filter-dms', and projection/repository filtering for
  //   kind == InboxItemKind.dm.
  //
  // skip: true until Phase B adds the DMs filter tab.
  // -----------------------------------------------------------------------
  testWidgets(
    'Inbox: DMs tab filters to only DM source items '
    '(INV-FILTER-2)',
    skip: false,
    (tester) async {
      final repo = _FakeInboxRepository();
      repo.items = [
        _makeItem(
          channelId: 'dm-1',
          channelName: 'Alice',
          senderName: 'Alice',
          preview: 'Hey there',
          unread: 1,
          kind: InboxItemKind.dm,
        ),
        _makeItem(
          channelId: 'ch-1',
          channelName: '#general',
          senderName: 'Bob',
          preview: 'Channel message',
          unread: 2,
          kind: InboxItemKind.channel,
        ),
        _makeItem(
          channelId: 'thread-1',
          channelName: 'Thread reply',
          senderName: 'Charlie',
          preview: 'Thread update',
          unread: 1,
          kind: InboxItemKind.thread,
        ),
      ];
      repo.totalUnreadCount = 4;

      await tester.pumpWidget(_buildApp(repo));
      await tester.pumpAndSettle();

      // DMs filter tab must exist.
      expect(
        find.byKey(const ValueKey('inbox-filter-dms')),
        findsOneWidget,
        reason: 'DMs filter tab must be present (INV-FILTER-2)',
      );

      // Tap DMs filter tab.
      await tester.tap(find.byKey(const ValueKey('inbox-filter-dms')));
      await tester.pumpAndSettle();

      // Repository must receive dms filter.
      expect(
        repo.lastFilter,
        'dms',
        reason: 'DMs tab must send dms filter to repository (INV-FILTER-2)',
      );

      // Only DM item should be visible.
      expect(
        find.byKey(const ValueKey('inbox-item-dm-1')),
        findsOneWidget,
        reason: 'DM item must be visible in DMs filter (INV-FILTER-2)',
      );
      expect(
        find.byKey(const ValueKey('inbox-item-ch-1')),
        findsNothing,
        reason: 'Channel item must NOT be visible in DMs filter '
            '(INV-FILTER-2)',
      );
      expect(
        find.byKey(const ValueKey('inbox-item-thread-1')),
        findsNothing,
        reason: 'Thread item must NOT be visible in DMs filter '
            '(INV-FILTER-2)',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildApp(_FakeInboxRepository repo) {
  return ProviderScope(
    overrides: [
      inboxRepositoryProvider.overrideWithValue(repo),
      activeServerScopeIdProvider
          .overrideWith((_) => const ServerScopeId('server-1')),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}

  @override
  Future<void> markItemReadAt(
    ServerScopeId serverId, {
    required String channelId,
    required int seq,
  }) async {}

  int _calcUnread() => items.fold(0, (sum, item) => sum + item.unreadCount);
}
