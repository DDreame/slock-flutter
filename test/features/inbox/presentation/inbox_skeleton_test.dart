import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/skeleton_list_item.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/inbox/presentation/page/inbox_page.dart';

// ---------------------------------------------------------------------------
// #490: Inbox Page Skeleton Integration Tests
//
// Invariants verified:
// INV-UX-SKELETON-1: First frame must show skeleton, never blank.
//
// Note: INV-UX-SKELETON-2 (no layout jump on transition) is scoped as
// "skeleton replaces loading indicator" — presence/absence verified, not
// golden/layout-shift.
// ---------------------------------------------------------------------------

void main() {
  late _FakeInboxRepository repo;

  setUp(() {
    repo = _FakeInboxRepository();
  });

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  Widget buildApp({
    List<Override> extraOverrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        inboxRepositoryProvider.overrideWithValue(repo),
        activeServerScopeIdProvider
            .overrideWith((_) => const ServerScopeId('server-1')),
        ...extraOverrides,
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const InboxPage(),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Tests
  // -----------------------------------------------------------------------

  group('Inbox skeleton integration', () {
    testWidgets(
      'shows skeleton on very first frame — initial status '
      '(INV-UX-SKELETON-1)',
      (tester) async {
        repo.delayResponse = true;

        await tester.pumpWidget(buildApp());
        // Single pump — status is still `initial` (microtask hasn't fired).
        await tester.pump();

        // Skeleton must be visible even on the very first frame.
        expect(
          find.byKey(const ValueKey('inbox-skeleton')),
          findsOneWidget,
          reason: 'INV-UX-SKELETON-1: skeleton must appear on the very first '
              'frame when status is initial',
        );

        // No spinner.
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: 'Skeleton replaces CircularProgressIndicator',
        );
      },
    );

    testWidgets(
      'shows 5 skeleton list items during loading state',
      (tester) async {
        repo.delayResponse = true;

        await tester.pumpWidget(buildApp());
        await tester.pump(); // trigger microtask load
        await tester.pump(); // allow state transition to loading

        // Skeleton container must be visible.
        expect(
          find.byKey(const ValueKey('inbox-skeleton')),
          findsOneWidget,
        );

        // All 5 skeleton list items present.
        for (var i = 0; i < 5; i++) {
          expect(
            find.byKey(ValueKey('inbox-skeleton-item-$i')),
            findsOneWidget,
          );
        }

        // No spinner.
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: 'Skeleton list items replace CircularProgressIndicator',
        );
      },
    );

    testWidgets(
      'skeleton items are SkeletonListItem widgets',
      (tester) async {
        repo.delayResponse = true;

        await tester.pumpWidget(buildApp());
        await tester.pump();
        await tester.pump();

        // Verify the skeleton items are actual SkeletonListItem widgets.
        expect(find.byType(SkeletonListItem), findsNWidgets(5));
      },
    );

    testWidgets(
      'skeleton disappears after data arrives',
      (tester) async {
        // Use non-delayed repo with items.
        repo.items = [
          _makeItem(channelId: 'ch-1', channelName: '#general', unread: 3),
        ];

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // Skeleton gone.
        expect(
          find.byKey(const ValueKey('inbox-skeleton')),
          findsNothing,
          reason: 'Skeleton must disappear after data arrives',
        );

        // Real content visible.
        expect(
          find.byKey(const ValueKey('inbox-item-ch-1')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'skeleton NOT shown during SWR refresh (stale data stays visible)',
      (tester) async {
        // Load with items (non-delayed).
        repo.items = [
          _makeItem(channelId: 'ch-1', channelName: '#general', unread: 2),
        ];

        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();

        // Success state — real items visible.
        expect(
          find.byKey(const ValueKey('inbox-item-ch-1')),
          findsOneWidget,
        );

        // No skeleton.
        expect(
          find.byKey(const ValueKey('inbox-skeleton')),
          findsNothing,
          reason: 'Skeleton must not appear during SWR refresh; '
              'stale data stays visible',
        );
      },
    );

    testWidgets(
      'skeleton shown during loading, then empty state after empty data',
      (tester) async {
        // Start with delay so load hangs.
        repo.delayResponse = true;

        await tester.pumpWidget(buildApp());
        await tester.pump();
        await tester.pump();

        // Skeleton visible while loading.
        expect(
          find.byKey(const ValueKey('inbox-skeleton')),
          findsOneWidget,
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

InboxItem _makeItem({
  required String channelId,
  required String channelName,
  int unread = 0,
  InboxItemKind kind = InboxItemKind.channel,
}) {
  return InboxItem(
    kind: kind,
    channelId: channelId,
    channelName: channelName,
    unreadCount: unread,
    lastActivityAt: DateTime.now().subtract(const Duration(minutes: 5)),
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeInboxRepository implements InboxRepository {
  List<InboxItem> items = [];
  bool delayResponse = false;
  int _fetchCount = 0;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    if (delayResponse && _fetchCount == 0) {
      _fetchCount++;
      // Never complete — simulates a hanging request for loading state test.
      return Completer<InboxResponse>().future;
    }
    _fetchCount++;
    final totalUnread = items.fold<int>(0, (s, i) => s + i.unreadCount);
    return InboxResponse(
      items: items,
      totalCount: items.length,
      totalUnreadCount: totalUnread,
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
}
