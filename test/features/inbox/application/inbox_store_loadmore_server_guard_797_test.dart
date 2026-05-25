// =============================================================================
// #797 — InboxStore.loadMore Stale-Server Guard
//
// Root cause: loadMore() captures serverId before await but does NOT verify
// the server is still active after the await completes. If the user switches
// servers during pagination, old-server items are merged into new-server state.
//
// Invariants verified:
//   INV-797-1: loadMore() discards response when server changes during await
//   INV-797-2: loadMore() still appends correctly when server is unchanged
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';

import '../../../support/support.dart';

void main() {
  group('#797 — InboxStore.loadMore stale-server guard', () {
    // -------------------------------------------------------------------------
    // INV-797-1: stale response discarded on server switch
    // -------------------------------------------------------------------------
    test(
      'loadMore discards response when server changes during await '
      '(INV-797-1)',
      () async {
        final loadMoreCompleter = Completer<InboxResponse>();
        final repo = _CompleterInboxRepository(
          loadMoreCompleter: loadMoreCompleter,
        );

        final container = ProviderContainer(overrides: [
          secureStorageProvider.overrideWithValue(FakeSecureStorage()),
          inboxRepositoryProvider.overrideWithValue(repo),
        ]);
        addTearDown(container.dispose);

        // Keep provider alive.
        final sub = container.listen(inboxStoreProvider, (_, __) {});
        addTearDown(sub.close);

        // Select server A and load first page.
        await container
            .read(serverSelectionStoreProvider.notifier)
            .selectServer('server-a');

        // Allow auto-load microtask to fire.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Verify initial load succeeded (server A, page 1).
        expect(container.read(inboxStoreProvider).status, InboxStatus.success);
        expect(container.read(inboxStoreProvider).items, hasLength(1));
        expect(
          container.read(inboxStoreProvider).items.first.channelId,
          'ch-a1',
        );
        expect(container.read(inboxStoreProvider).hasMore, isTrue);

        // Trigger loadMore — this will block on loadMoreCompleter.
        final loadMoreFuture =
            container.read(inboxStoreProvider.notifier).loadMore();

        // Switch to server B WHILE loadMore is in-flight.
        // This triggers build() re-invocation → state resets.
        repo.immediateResponse = const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-b1',
              channelName: 'Bob',
              unreadCount: 2,
            ),
          ],
          totalCount: 1,
          totalUnreadCount: 2,
          hasMore: false,
        );

        await container
            .read(serverSelectionStoreProvider.notifier)
            .selectServer('server-b');

        // Allow auto-load microtask for server B to fire.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Now complete the old loadMore request with server-A page-2 data.
        loadMoreCompleter.complete(const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-a-stale',
              channelName: 'stale-channel',
              unreadCount: 99,
            ),
          ],
          totalCount: 2,
          totalUnreadCount: 99,
          hasMore: false,
        ));

        await loadMoreFuture;

        // Verify: stale server-A items must NOT appear in current state.
        final finalState = container.read(inboxStoreProvider);
        final allChannelIds = finalState.items.map((i) => i.channelId).toList();
        expect(allChannelIds, isNot(contains('ch-a-stale')),
            reason: 'Stale loadMore response from server A must be discarded');

        // The state should reflect server B only.
        expect(allChannelIds, contains('dm-b1'));
      },
    );

    // -------------------------------------------------------------------------
    // INV-797-2: loadMore still works normally when server unchanged
    // -------------------------------------------------------------------------
    test(
      'loadMore appends items correctly when server is unchanged '
      '(INV-797-2)',
      () async {
        final loadMoreCompleter = Completer<InboxResponse>();
        final repo = _CompleterInboxRepository(
          loadMoreCompleter: loadMoreCompleter,
        );

        final container = ProviderContainer(overrides: [
          secureStorageProvider.overrideWithValue(FakeSecureStorage()),
          inboxRepositoryProvider.overrideWithValue(repo),
        ]);
        addTearDown(container.dispose);

        final sub = container.listen(inboxStoreProvider, (_, __) {});
        addTearDown(sub.close);

        // Select server A and load first page.
        await container
            .read(serverSelectionStoreProvider.notifier)
            .selectServer('server-a');

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(container.read(inboxStoreProvider).status, InboxStatus.success);
        expect(container.read(inboxStoreProvider).items, hasLength(1));
        expect(container.read(inboxStoreProvider).hasMore, isTrue);

        // Trigger loadMore — this will block on loadMoreCompleter.
        final loadMoreFuture =
            container.read(inboxStoreProvider.notifier).loadMore();

        // Complete the loadMore with page 2 data (same server).
        loadMoreCompleter.complete(const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-a2',
              channelName: 'page-2-channel',
              unreadCount: 3,
            ),
          ],
          totalCount: 2,
          totalUnreadCount: 6,
          hasMore: false,
        ));

        await loadMoreFuture;

        // Verify: page 2 items are correctly appended.
        final finalState = container.read(inboxStoreProvider);
        expect(finalState.items, hasLength(2));
        expect(finalState.items[0].channelId, 'ch-a1');
        expect(finalState.items[1].channelId, 'ch-a2');
        expect(finalState.hasMore, isFalse);
      },
    );
  });
}

// =============================================================================
// Fakes
// =============================================================================

/// Inbox repository that uses a [Completer] for loadMore (offset > 0) calls,
/// while returning immediate responses for initial load (offset == 0).
class _CompleterInboxRepository implements InboxRepository {
  _CompleterInboxRepository({required this.loadMoreCompleter});

  final Completer<InboxResponse> loadMoreCompleter;

  /// Response used for initial loads (offset == 0) and after server switch.
  InboxResponse? immediateResponse;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) {
    if (offset > 0) {
      // Pagination call — delay via completer.
      return loadMoreCompleter.future;
    }

    // Initial load — return immediately.
    final immediate = immediateResponse;
    if (immediate != null) return Future.value(immediate);

    // Default first page: 1 item, hasMore = true.
    return Future.value(const InboxResponse(
      items: [
        InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-a1',
          channelName: 'general-a',
          unreadCount: 3,
        ),
      ],
      totalCount: 2,
      totalUnreadCount: 6,
      hasMore: true,
    ));
  }

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}
}
