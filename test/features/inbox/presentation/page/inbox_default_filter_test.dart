import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/inbox/presentation/page/inbox_page.dart';
import 'package:slock_app/l10n/l10n.dart';

// ---------------------------------------------------------------------------
// #511: Inbox 默认 Filter Race Fix — Phase A (test-only)
//
// BUG: Home page _InboxUnreadSection.initState() calls load() with default
// filter=all → InboxStore status becomes success. When user navigates to
// InboxPage, its initState guard `if (state.status == InboxStatus.initial)`
// fails → setFilter(InboxFilter.unread) never fires → Inbox shows "All"
// instead of "Unread".
//
// Invariants:
//   INV-FILTER-RACE-1: User's first open of Inbox tab must show
//                       InboxFilter.unread regardless of Home pre-load.
//   INV-FILTER-RACE-2: setFilter() must not depend on status == initial
//                       guard; leaving and re-opening Inbox must reset
//                       to unread.
//
// Tests 1 & 3: skip: true until Phase B fixes InboxPage.initState.
// Test 2: passes on current codebase (cold start, status == initial).
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // 1. Home pre-loaded → open InboxPage → activeFilter must be unread
  //
  // Simulates: Home page loaded inbox with filter=all (default) →
  // status == success → user taps Inbox tab → InboxPage opens.
  //
  // Phase B must fix InboxPage.initState to always call
  // setFilter(InboxFilter.unread) regardless of current status.
  // -----------------------------------------------------------------------
  testWidgets(
    'InboxPage: Home pre-loaded (status=success, filter=all) → '
    'activeFilter must be unread (INV-FILTER-RACE-1)',
    (tester) async {
      final repo = _FakeInboxRepository();
      repo.items = [
        _makeItem(channelId: 'ch-1', unread: 3),
        _makeItem(channelId: 'ch-2', unread: 1),
      ];

      // Pre-populate InboxStore: simulate Home page calling load()
      // with default filter=all, reaching status=success.
      final container = ProviderContainer(overrides: [
        inboxRepositoryProvider.overrideWithValue(repo),
        activeServerScopeIdProvider
            .overrideWithValue(const ServerScopeId('server-1')),
        homeNowProvider.overrideWith((ref) => Stream.value(DateTime.now())),
      ]);
      addTearDown(container.dispose);

      // Home's _InboxUnreadSection calls load() with no filter (defaults
      // to InboxFilter.all). Wait for it to complete.
      await container.read(inboxStoreProvider.notifier).load();

      // Verify pre-load state: status=success, filter=all.
      final preLoad = container.read(inboxStoreProvider);
      expect(preLoad.status, InboxStatus.success,
          reason: 'Pre-load must reach success');
      expect(preLoad.filter, InboxFilter.all,
          reason: 'Home pre-loads with default filter=all');
      expect(preLoad.items, hasLength(2));

      // Mount InboxPage using the pre-populated container.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const InboxPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // After InboxPage.initState, filter must be unread — not all.
      // Currently FAILS: initState guard (status == initial) is false,
      // so setFilter(unread) never fires → filter stays all.
      final afterMount = container.read(inboxStoreProvider);
      expect(afterMount.filter, InboxFilter.unread,
          reason: 'InboxPage must set filter to unread on open, '
              'even when Home already pre-loaded with filter=all '
              '(INV-FILTER-RACE-1)');
    },
  );

  // -----------------------------------------------------------------------
  // 2. Cold start → open InboxPage → activeFilter must be unread
  //
  // Passes on current codebase: status == initial → guard passes →
  // setFilter(unread) fires correctly.
  // -----------------------------------------------------------------------
  testWidgets(
    'InboxPage: cold start (status=initial) → activeFilter is unread',
    (tester) async {
      final repo = _FakeInboxRepository();
      repo.items = [
        _makeItem(channelId: 'ch-1', unread: 5),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inboxRepositoryProvider.overrideWithValue(repo),
            activeServerScopeIdProvider
                .overrideWith((_) => const ServerScopeId('server-1')),
            homeNowProvider.overrideWith((ref) => Stream.value(DateTime.now())),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const InboxPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // InboxPage page must be visible.
      expect(find.byKey(const ValueKey('inbox-page')), findsOneWidget);

      // Filter must be unread (the default for Inbox).
      // Verify by checking the Unread tab is selected: the InboxPage
      // initState calls setFilter(unread) via microtask.
      // We verify through the store state via a container read.
      // Since we used ProviderScope, access via ProviderScope.containerOf.
      final element = tester.element(find.byType(InboxPage));
      final container = ProviderScope.containerOf(element);
      final state = container.read(inboxStoreProvider);
      expect(state.filter, InboxFilter.unread,
          reason: 'Cold start must default to unread filter');
      expect(state.status, InboxStatus.success,
          reason: 'Load must have completed');
    },
  );

  // -----------------------------------------------------------------------
  // 3. User manual switch → leave → re-open → filter resets to unread
  //
  // Simulates: User opens Inbox (filter=unread) → switches to All →
  // navigates away → re-opens InboxPage → filter must reset to unread.
  //
  // Phase B must ensure re-opening InboxPage always resets to unread,
  // not preserving the previously selected filter.
  // -----------------------------------------------------------------------
  testWidgets(
    'InboxPage: user switches filter → leave → re-open → '
    'filter resets to unread (INV-FILTER-RACE-2)',
    (tester) async {
      final repo = _FakeInboxRepository();
      repo.items = [
        _makeItem(channelId: 'ch-1', unread: 3),
        _makeItem(channelId: 'ch-2', unread: 0),
      ];

      // Pre-populate with unread filter (simulates first InboxPage open).
      final container = ProviderContainer(overrides: [
        inboxRepositoryProvider.overrideWithValue(repo),
        activeServerScopeIdProvider
            .overrideWithValue(const ServerScopeId('server-1')),
        homeNowProvider.overrideWith((ref) => Stream.value(DateTime.now())),
      ]);
      addTearDown(container.dispose);

      // Simulate first open: InboxPage sets filter=unread.
      await container
          .read(inboxStoreProvider.notifier)
          .setFilter(InboxFilter.unread);
      expect(container.read(inboxStoreProvider).filter, InboxFilter.unread);

      // User switches to All filter.
      await container
          .read(inboxStoreProvider.notifier)
          .setFilter(InboxFilter.all);
      expect(container.read(inboxStoreProvider).filter, InboxFilter.all,
          reason: 'User switched to All');

      // User leaves InboxPage. State persists in store (filter=all).
      // Now re-open InboxPage with the same container.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const InboxPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // After re-opening, filter must reset to unread.
      // Currently FAILS: InboxPage.initState guard sees status == success
      // (not initial) → setFilter(unread) never fires → filter stays all.
      final afterReopen = container.read(inboxStoreProvider);
      expect(afterReopen.filter, InboxFilter.unread,
          reason: 'Re-opening InboxPage must reset filter to unread, '
              'not preserve user\'s previous selection '
              '(INV-FILTER-RACE-2)');
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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
// Fake repository — immediate responses for straightforward assertions.
// ---------------------------------------------------------------------------

class _FakeInboxRepository implements InboxRepository {
  List<InboxItem> items = [];

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
        totalUnreadCount: _calcUnread(),
        hasMore: false,
      );
    }
    // Filter-aware: return only matching items based on filter.
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
      totalUnreadCount: _calcUnread(),
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

  @override
  Future<void> markItemReadAt(
    ServerScopeId serverId, {
    required String channelId,
    required int seq,
  }) async {}

  int _calcUnread() => items.fold(0, (sum, item) => sum + item.unreadCount);
}
