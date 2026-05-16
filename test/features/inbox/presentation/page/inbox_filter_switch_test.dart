import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/inbox/presentation/page/inbox_page.dart';

// ---------------------------------------------------------------------------
// #510: Projection SWR filter-switch 盲区修复 — Phase A (test-only)
//
// Tests for filter-switch loading state behavior in InboxStore + InboxPage.
//
// BUG 1 mechanism:
//   InboxStore.load() does NOT clear items on filter switch →
//   stale items remain → items.isEmpty is false → skeleton guard fails →
//   content branch renders with 0 projections (inboxProjectionProvider
//   returns [] when status != success) → BLANK PAGE.
//
// Tests 1-2 skip: true until Phase B fixes InboxStore.load() to clear
// items on filter switch + InboxPage to show skeleton correctly.
// Test 4 passes on current codebase (happy-path filter switch).
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // 1. InboxStore: filter switch must clear stale items during loading
  //
  // Phase B: InboxStore.load() must clear items when filter changes
  //          so that items.isEmpty == true → skeleton guard works.
  // -----------------------------------------------------------------------
  test(
    'InboxStore: filter switch clears items and sets loading status',
    () async {
      final repo = _ControllableInboxRepository();
      final container = ProviderContainer(overrides: [
        inboxRepositoryProvider.overrideWithValue(repo),
        activeServerScopeIdProvider
            .overrideWithValue(const ServerScopeId('server-1')),
      ]);
      addTearDown(container.dispose);

      // Initial load with unread filter.
      repo.queueResponse(InboxResponse(
        items: [
          _makeItem(channelId: 'ch-1', unread: 3),
          _makeItem(channelId: 'ch-2', unread: 1),
        ],
        totalCount: 2,
        totalUnreadCount: 4,
        hasMore: false,
      ));

      await container
          .read(inboxStoreProvider.notifier)
          .load(filter: InboxFilter.unread);

      // Verify initial state is loaded.
      final initial = container.read(inboxStoreProvider);
      expect(initial.status, InboxStatus.success);
      expect(initial.items, hasLength(2));
      expect(initial.filter, InboxFilter.unread);

      // Block the next fetch (filter-switch load).
      final completer = repo.blockNextFetch();

      // Start filter switch — don't await so we can inspect mid-load state.
      // The synchronous part of load() sets state before the first await.
      unawaited(
        container.read(inboxStoreProvider.notifier).setFilter(InboxFilter.all),
      );

      // Mid-loading: status must be loading AND items must be cleared.
      // Currently FAILS: items retain stale data from previous filter.
      final midLoad = container.read(inboxStoreProvider);
      expect(midLoad.status, InboxStatus.loading,
          reason: 'Status must be loading during filter-switch fetch');
      expect(midLoad.filter, InboxFilter.all,
          reason: 'Filter must be updated to new value');
      expect(midLoad.items, isEmpty,
          reason: 'Items must be cleared on filter switch so skeleton guard '
              'works (currently stale items remain — BUG 1)');

      // Complete the request so test teardown works cleanly.
      completer.complete(const InboxResponse(
        items: [],
        totalCount: 0,
        totalUnreadCount: 0,
        hasMore: false,
      ));
      await Future<void>.delayed(Duration.zero);
    },
  );

  // -----------------------------------------------------------------------
  // 2. InboxPage: skeleton visible during filter-switch loading
  //
  // Phase B: InboxPage._buildBody must show skeleton when status == loading
  //          and projections/items are empty (not blank, not spinner).
  // -----------------------------------------------------------------------
  testWidgets(
    'InboxPage: skeleton visible during filter-switch loading',
    (tester) async {
      final repo = _ControllableInboxRepository();
      // Initial load: succeeds immediately with 1 unread item.
      repo.queueResponse(InboxResponse(
        items: [
          _makeItem(channelId: 'ch-1', unread: 3, senderName: 'Alice'),
        ],
        totalCount: 1,
        totalUnreadCount: 3,
        hasMore: false,
      ));

      await tester.pumpWidget(_buildInboxApp(repo));
      await tester.pumpAndSettle();

      // Verify initial load succeeded — item visible.
      expect(find.byKey(const ValueKey('inbox-item-ch-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('inbox-skeleton')), findsNothing,
          reason: 'Skeleton must NOT be visible after successful load');

      // Block the next fetch (filter-switch load).
      final completer = repo.blockNextFetch();

      // Tap "All" filter tab to trigger filter switch.
      await tester.tap(find.byKey(const ValueKey('inbox-filter-all')));
      await tester.pump(); // Process filter-switch state change.

      // During filter-switch loading: skeleton must be visible.
      // Currently FAILS: blank page because stale items prevent skeleton
      // guard (items.isEmpty == false) but projections are empty (provider
      // guard returns [] when status != success).
      expect(
        find.byKey(const ValueKey('inbox-skeleton')),
        findsOneWidget,
        reason: 'Skeleton must be visible during filter-switch loading '
            '(currently shows blank page — BUG 1)',
      );
      expect(
        find.byKey(const ValueKey('inbox-item-ch-1')),
        findsNothing,
        reason: 'Stale items from previous filter must not be visible '
            'during filter switch',
      );

      // Complete the request so pumpAndSettle can finish.
      completer.complete(const InboxResponse(
        items: [],
        totalCount: 0,
        totalUnreadCount: 0,
        hasMore: false,
      ));
      await tester.pumpAndSettle();
    },
  );

  // -----------------------------------------------------------------------
  // 4. InboxPage: filter switch completes with correct filtered items
  //
  // Happy-path test — passes on current codebase.
  // Verifies items update correctly when filter switch completes.
  // -----------------------------------------------------------------------
  testWidgets(
    'InboxPage: filter switch completes with correct filtered items',
    (tester) async {
      final repo = _FilterAwareInboxRepository();
      repo.allItems = [
        _makeItem(
          channelId: 'ch-1',
          channelName: '#general',
          unread: 3,
          senderName: 'Alice',
          preview: 'Hello',
        ),
        _makeItem(
          channelId: 'ch-2',
          channelName: '#random',
          unread: 0,
          senderName: 'Bob',
          preview: 'Old msg',
        ),
      ];
      repo.totalUnreadCount = 3;

      await tester.pumpWidget(_buildInboxApp(repo));
      await tester.pumpAndSettle();

      // Default filter is Unread — only unread items visible.
      expect(find.byKey(const ValueKey('inbox-item-ch-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('inbox-item-ch-2')), findsNothing,
          reason: 'Read item must NOT be visible in Unread filter');

      // Switch to All filter.
      await tester.tap(find.byKey(const ValueKey('inbox-filter-all')));
      await tester.pumpAndSettle();

      // Both items visible in All filter.
      expect(find.byKey(const ValueKey('inbox-item-ch-1')), findsOneWidget,
          reason: 'Unread item must be visible in All filter');
      expect(find.byKey(const ValueKey('inbox-item-ch-2')), findsOneWidget,
          reason: 'Read item must also be visible in All filter');

      // Switch back to Unread filter.
      await tester.tap(find.byKey(const ValueKey('inbox-filter-unread')));
      await tester.pumpAndSettle();

      // Only unread items visible again.
      expect(find.byKey(const ValueKey('inbox-item-ch-1')), findsOneWidget,
          reason: 'Unread item must be visible after switching back');
      expect(find.byKey(const ValueKey('inbox-item-ch-2')), findsNothing,
          reason: 'Read item must NOT be visible after switching back');
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildInboxApp(InboxRepository repo, {ThemeData? theme}) {
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
  String channelName = 'Channel',
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
// Controllable repository — Completer-based blocking for mid-load assertions.
//
// Usage: queueResponse() for immediate calls, blockNextFetch() to get a
// Completer that blocks fetchInbox until completed by the test.
// ---------------------------------------------------------------------------

class _ControllableInboxRepository implements InboxRepository {
  final List<InboxResponse> _responses = [];
  Completer<InboxResponse>? _blockingCompleter;
  int _fetchCount = 0;

  void queueResponse(InboxResponse response) {
    _responses.add(response);
  }

  Completer<InboxResponse> blockNextFetch() {
    _blockingCompleter = Completer<InboxResponse>();
    return _blockingCompleter!;
  }

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    final index = _fetchCount++;
    if (index < _responses.length) {
      return _responses[index];
    }
    if (_blockingCompleter != null && !_blockingCompleter!.isCompleted) {
      return _blockingCompleter!.future;
    }
    return const InboxResponse(
      items: [],
      totalCount: 0,
      totalUnreadCount: 0,
      hasMore: false,
    );
  }

  @override
  Future<void> markItemRead(ServerScopeId serverId,
      {required String channelId}) async {}

  @override
  Future<void> markItemDone(ServerScopeId serverId,
      {required String channelId}) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}
}

// ---------------------------------------------------------------------------
// Filter-aware repository — simulates server-side filtering.
// Used for happy-path test 4.
// ---------------------------------------------------------------------------

class _FilterAwareInboxRepository implements InboxRepository {
  List<InboxItem> allItems = [];
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
        totalCount: allItems.length,
        totalUnreadCount: totalUnreadCount,
        hasMore: false,
      );
    }
    final filtered = switch (filter) {
      InboxFilter.unread => allItems.where((i) => i.unreadCount > 0).toList(),
      InboxFilter.mentions => allItems.where((i) => i.isMentioned).toList(),
      InboxFilter.dms =>
        allItems.where((i) => i.kind == InboxItemKind.dm).toList(),
      InboxFilter.all => allItems,
    };
    return InboxResponse(
      items: filtered,
      totalCount: filtered.length,
      totalUnreadCount: totalUnreadCount > 0 ? totalUnreadCount : _calcUnread(),
      hasMore: false,
    );
  }

  @override
  Future<void> markItemRead(ServerScopeId serverId,
      {required String channelId}) async {}

  @override
  Future<void> markItemDone(ServerScopeId serverId,
      {required String channelId}) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}

  int _calcUnread() => allItems.fold(0, (sum, item) => sum + item.unreadCount);
}
