import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/inbox/presentation/page/inbox_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  late _FakeInboxRepository repo;

  setUp(() {
    repo = _FakeInboxRepository();
  });

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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const InboxPage(),
      ),
    );
  }

  group('InboxPage', () {
    testWidgets('shows skeleton loading state initially', (tester) async {
      repo.delayResponse = true;
      await tester.pumpWidget(buildApp());
      await tester.pump(); // trigger microtask load
      await tester.pump(); // allow state transition

      expect(find.byKey(const ValueKey('inbox-skeleton')), findsOneWidget);
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'Skeleton replaces spinner',
      );
    });

    testWidgets('shows items after load', (tester) async {
      repo.items = [
        _makeItem(channelId: 'ch-1', channelName: '#general', unread: 3),
        _makeItem(
            channelId: 'dm-1',
            channelName: 'Alice',
            kind: InboxItemKind.dm,
            unread: 1),
      ];

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('inbox-page')), findsOneWidget);
      expect(find.byKey(const ValueKey('inbox-item-ch-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('inbox-item-dm-1')), findsOneWidget);
      expect(find.text('#general'), findsOneWidget);
      expect(find.text('Alice'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows empty state when no items', (tester) async {
      repo.items = [];
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('inbox-empty')), findsOneWidget);
      expect(find.text('All caught up!'), findsOneWidget);
    });

    testWidgets('shows error state with retry on failure', (tester) async {
      repo.shouldFail = true;
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('inbox-error')), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('filter tabs switch between All and Unread', (tester) async {
      repo.items = [
        _makeItem(channelId: 'ch-1', channelName: '#general', unread: 2),
        _makeItem(channelId: 'ch-2', channelName: '#random', unread: 0),
      ];

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Both items visible in All filter
      expect(find.byKey(const ValueKey('inbox-item-ch-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('inbox-item-ch-2')), findsOneWidget);

      // Tap Unread filter
      await tester.tap(find.byKey(const ValueKey('inbox-filter-unread')));
      await tester.pumpAndSettle();

      // repo.lastFilter should be 'unread'
      expect(repo.lastFilter, InboxFilter.unread);
    });

    testWidgets('long-press mark read clears unread badge', (tester) async {
      repo.items = [
        _makeItem(channelId: 'ch-1', channelName: '#general', unread: 5),
      ];

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Switch to All filter so item stays after mark-read
      // (default is Unread, which removes read items optimistically).
      await tester.tap(find.byKey(const ValueKey('inbox-filter-all')));
      await tester.pumpAndSettle();

      // Badge visible before action.
      expect(find.byKey(const ValueKey('inbox-unread-badge-ch-1')),
          findsOneWidget);

      // Long-press opens action sheet, tap "Mark Read".
      await tester.longPress(
        find.byKey(const ValueKey('inbox-item-ch-1')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('inbox-action-mark-read')));
      await tester.pumpAndSettle();

      // Item stays in the list but unread badge is gone (optimistic zeroing).
      expect(find.byKey(const ValueKey('inbox-item-ch-1')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('inbox-unread-badge-ch-1')), findsNothing);
    });

    testWidgets('mark all read button visible when unread items exist',
        (tester) async {
      repo.items = [
        _makeItem(channelId: 'ch-1', channelName: '#general', unread: 3),
      ];
      repo.totalUnreadCount = 3;

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('inbox-mark-all-read')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('inbox-mark-all-read')));
      await tester.pumpAndSettle();

      // Button disappears because totalUnreadCount drops to 0 (optimistic).
      expect(find.byKey(const ValueKey('inbox-mark-all-read')), findsNothing);
    });

    testWidgets('mark all read button hidden when no unread', (tester) async {
      repo.items = [
        _makeItem(channelId: 'ch-1', channelName: '#general', unread: 0),
      ];
      repo.totalUnreadCount = 0;

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('inbox-mark-all-read')), findsNothing);
    });

    testWidgets('unread badge shows count on item', (tester) async {
      repo.items = [
        _makeItem(channelId: 'ch-1', channelName: '#general', unread: 42),
      ];

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('inbox-unread-badge-ch-1')),
          findsOneWidget);
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('unread badge shows 99+ for large counts', (tester) async {
      repo.items = [
        _makeItem(channelId: 'ch-1', channelName: '#general', unread: 150),
      ];

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('shows sender name and preview', (tester) async {
      repo.items = [
        _makeItem(
          channelId: 'ch-1',
          channelName: '#general',
          unread: 1,
          senderName: 'Bob',
          preview: 'Hey, check this out!',
        ),
      ];

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Hey, check this out!'), findsOneWidget);
    });

    testWidgets('shows latestActivityPreview over preview when both present',
        (tester) async {
      repo.items = [
        _makeItem(
          channelId: 'ch-1',
          channelName: '#general',
          unread: 1,
          senderName: 'Bob',
          preview: 'Old message',
          latestActivityPreview: 'Latest activity text',
        ),
      ];

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Latest activity text'), findsOneWidget);
      expect(find.text('Old message'), findsNothing);
    });

    testWidgets('pagination loads more on scroll to bottom', (tester) async {
      repo.items = List.generate(
        10,
        (i) =>
            _makeItem(channelId: 'ch-$i', channelName: 'Channel $i', unread: i),
      );
      repo.hasMore = true;

      await tester.pumpWidget(buildApp());
      // Use pump() — pumpAndSettle won't complete because of the loading
      // spinner at the bottom (CircularProgressIndicator animates forever).
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('inbox-list-view')), findsOneWidget);

      // Scroll to bottom
      await tester.drag(
        find.byKey(const ValueKey('inbox-list-view')),
        const Offset(0, -2000),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repo.loadMoreCalled, isTrue);
    });

    // -----------------------------------------------------------------------
    // Regression: mentions-filter mark-read removes item (#509)
    // -----------------------------------------------------------------------
    testWidgets('mark read in mentions filter removes item from list',
        (tester) async {
      repo.items = [
        _makeItem(
          channelId: 'ch-1',
          channelName: '#general',
          unread: 3,
          isMentioned: true,
        ),
      ];
      repo.totalUnreadCount = 3;

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Switch to @Mentions filter.
      await tester.tap(find.byKey(const ValueKey('inbox-filter-mentions')));
      await tester.pumpAndSettle();

      // Item visible before action.
      expect(find.byKey(const ValueKey('inbox-item-ch-1')), findsOneWidget);

      // Long-press → Mark Read.
      await tester.longPress(find.byKey(const ValueKey('inbox-item-ch-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('inbox-action-mark-read')));
      await tester.pumpAndSettle();

      // Item removed from list (mentions filter removes read items).
      expect(
        find.byKey(const ValueKey('inbox-item-ch-1')),
        findsNothing,
        reason: 'Mark-read in mentions filter must remove item from list',
      );
    });

    // -----------------------------------------------------------------------
    // Regression: mentions-filter mark-all-read empties list (#509)
    // -----------------------------------------------------------------------
    testWidgets('mark all read in mentions filter empties list',
        (tester) async {
      repo.items = [
        _makeItem(
          channelId: 'ch-1',
          channelName: '#general',
          unread: 2,
          isMentioned: true,
        ),
        _makeItem(
          channelId: 'ch-2',
          channelName: '#random',
          unread: 1,
          isMentioned: true,
        ),
      ];
      repo.totalUnreadCount = 3;

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Switch to @Mentions filter.
      await tester.tap(find.byKey(const ValueKey('inbox-filter-mentions')));
      await tester.pumpAndSettle();

      // Both items visible before action.
      expect(find.byKey(const ValueKey('inbox-item-ch-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('inbox-item-ch-2')), findsOneWidget);

      // Tap mark-all-read.
      await tester.tap(find.byKey(const ValueKey('inbox-mark-all-read')));
      await tester.pumpAndSettle();

      // List emptied (mentions filter removes all read items).
      expect(
        find.byKey(const ValueKey('inbox-item-ch-1')),
        findsNothing,
        reason: 'Mark-all-read in mentions filter must remove all items',
      );
      expect(
        find.byKey(const ValueKey('inbox-item-ch-2')),
        findsNothing,
        reason: 'Mark-all-read in mentions filter must remove all items',
      );
    });
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
  String? senderName,
  String? preview,
  String? latestActivityPreview,
  bool isMentioned = false,
}) {
  return InboxItem(
    kind: kind,
    channelId: channelId,
    channelName: channelName,
    unreadCount: unread,
    senderName: senderName,
    preview: preview,
    latestActivityPreview: latestActivityPreview,
    isMentioned: isMentioned,
    lastActivityAt: DateTime.now().subtract(const Duration(minutes: 5)),
  );
}

// ---------------------------------------------------------------------------
// Migration: mock-call → state-based assertions (#478)
//
// Removed markedDoneIds, markedReadIds, markAllReadCalled tracking fields.
// Tests now assert UI outcomes (item disappears, badge clears, button hides)
// instead of verifying repository call bookkeeping.
//
// Retained: lastFilter (filter tab test), loadMoreCalled (pagination test).
// These remain because the UI-observable outcome (filtered list, loaded items)
// depends on a re-fetch whose result is indistinguishable from the initial
// load in a widget test without call tracking.
// ---------------------------------------------------------------------------

class _FakeInboxRepository implements InboxRepository {
  List<InboxItem> items = [];
  bool shouldFail = false;
  bool delayResponse = false;
  bool hasMore = false;
  int totalUnreadCount = 0;
  InboxFilter? lastFilter;
  bool loadMoreCalled = false;
  int _fetchCount = 0;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    lastFilter = filter;
    if (delayResponse && _fetchCount == 0) {
      _fetchCount++;
      // Never complete — simulates a hanging request for loading state test
      return Completer<InboxResponse>().future;
    }
    if (shouldFail) {
      throw const UnknownFailure(message: 'Network error');
    }
    if (offset > 0) {
      loadMoreCalled = true;
      return InboxResponse(
        items: const [],
        totalCount: items.length,
        totalUnreadCount: totalUnreadCount,
        hasMore: false,
      );
    }
    _fetchCount++;
    return InboxResponse(
      items: items,
      totalCount: items.length,
      totalUnreadCount: totalUnreadCount > 0 ? totalUnreadCount : _calcUnread(),
      hasMore: hasMore,
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
