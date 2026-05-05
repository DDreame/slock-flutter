import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';

void main() {
  ProviderContainer createContainer({
    required FakeInboxRepository repository,
    ServerScopeId? activeServerId = const ServerScopeId('server-1'),
    bool noActiveServer = false,
  }) {
    return ProviderContainer(
      overrides: [
        inboxRepositoryProvider.overrideWithValue(repository),
        activeServerScopeIdProvider
            .overrideWithValue(noActiveServer ? null : activeServerId),
      ],
    );
  }

  group('InboxStore.load', () {
    test('fetches first page and updates state to success', () async {
      final repo = FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              channelName: 'general',
              unreadCount: 5,
            ),
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-1',
              channelName: 'Bob',
              unreadCount: 2,
            ),
          ],
          totalCount: 2,
          totalUnreadCount: 7,
          hasMore: false,
        ),
      );
      final container = createContainer(repository: repo);
      addTearDown(container.dispose);

      final store = container.read(inboxStoreProvider.notifier);
      await store.load();

      final state = container.read(inboxStoreProvider);
      expect(state.status, InboxStatus.success);
      expect(state.items, hasLength(2));
      expect(state.totalCount, 2);
      expect(state.totalUnreadCount, 7);
      expect(state.hasMore, isFalse);
      expect(state.offset, 2);
    });

    test('sets status to loading then success', () async {
      final repo = FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [],
          totalCount: 0,
          totalUnreadCount: 0,
          hasMore: false,
        ),
      );
      final container = createContainer(repository: repo);
      addTearDown(container.dispose);

      final states = <InboxStatus>[];
      container.listen(
        inboxStoreProvider.select((s) => s.status),
        (_, next) => states.add(next),
      );

      await container.read(inboxStoreProvider.notifier).load();

      expect(states, [InboxStatus.loading, InboxStatus.success]);
    });

    test('sets status to failure on AppFailure', () async {
      final repo = FakeInboxRepository(
        fetchFailure: const NetworkFailure(message: 'offline'),
      );
      final container = createContainer(repository: repo);
      addTearDown(container.dispose);

      await container.read(inboxStoreProvider.notifier).load();

      final state = container.read(inboxStoreProvider);
      expect(state.status, InboxStatus.failure);
      expect(state.failure, isA<NetworkFailure>());
    });

    test('passes filter parameter to repository', () async {
      final repo = FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [],
          totalCount: 0,
          totalUnreadCount: 0,
          hasMore: false,
        ),
      );
      final container = createContainer(repository: repo);
      addTearDown(container.dispose);

      await container
          .read(inboxStoreProvider.notifier)
          .load(filter: InboxFilter.unread);

      expect(repo.lastFetchFilter, InboxFilter.unread);
      expect(
        container.read(inboxStoreProvider).filter,
        InboxFilter.unread,
      );
    });

    test('returns empty success when no active server', () async {
      final repo = FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [],
          totalCount: 0,
          totalUnreadCount: 0,
          hasMore: false,
        ),
      );
      final container = createContainer(
        repository: repo,
        noActiveServer: true,
      );
      addTearDown(container.dispose);

      await container.read(inboxStoreProvider.notifier).load();

      final state = container.read(inboxStoreProvider);
      expect(state.status, InboxStatus.success);
      expect(state.items, isEmpty);
      expect(repo.fetchCallCount, 0);
    });
  });

  group('InboxStore.loadMore', () {
    test('appends next page items', () async {
      final repo = FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              unreadCount: 3,
            ),
          ],
          totalCount: 2,
          totalUnreadCount: 5,
          hasMore: true,
        ),
      );
      final container = createContainer(repository: repo);
      addTearDown(container.dispose);

      // Load first page
      await container.read(inboxStoreProvider.notifier).load();
      expect(container.read(inboxStoreProvider).items, hasLength(1));

      // Prepare second page response
      repo.fetchResponse = const InboxResponse(
        items: [
          InboxItem(
            kind: InboxItemKind.dm,
            channelId: 'dm-1',
            unreadCount: 2,
          ),
        ],
        totalCount: 2,
        totalUnreadCount: 5,
        hasMore: false,
      );

      await container.read(inboxStoreProvider.notifier).loadMore();

      final state = container.read(inboxStoreProvider);
      expect(state.items, hasLength(2));
      expect(state.items[0].channelId, 'ch-1');
      expect(state.items[1].channelId, 'dm-1');
      expect(state.hasMore, isFalse);
      expect(state.offset, 2);
    });

    test('does nothing when hasMore is false', () async {
      final repo = FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              unreadCount: 1,
            ),
          ],
          totalCount: 1,
          totalUnreadCount: 1,
          hasMore: false,
        ),
      );
      final container = createContainer(repository: repo);
      addTearDown(container.dispose);

      await container.read(inboxStoreProvider.notifier).load();
      final callsBefore = repo.fetchCallCount;

      await container.read(inboxStoreProvider.notifier).loadMore();

      expect(repo.fetchCallCount, callsBefore);
    });

    test('passes correct offset for pagination', () async {
      final repo = FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [
            InboxItem(
                kind: InboxItemKind.channel, channelId: 'ch-1', unreadCount: 1),
            InboxItem(
                kind: InboxItemKind.channel, channelId: 'ch-2', unreadCount: 1),
          ],
          totalCount: 4,
          totalUnreadCount: 4,
          hasMore: true,
        ),
      );
      final container = createContainer(repository: repo);
      addTearDown(container.dispose);

      await container.read(inboxStoreProvider.notifier).load();

      repo.fetchResponse = const InboxResponse(
        items: [
          InboxItem(
              kind: InboxItemKind.channel, channelId: 'ch-3', unreadCount: 1),
          InboxItem(
              kind: InboxItemKind.channel, channelId: 'ch-4', unreadCount: 1),
        ],
        totalCount: 4,
        totalUnreadCount: 4,
        hasMore: false,
      );

      await container.read(inboxStoreProvider.notifier).loadMore();

      expect(repo.lastFetchOffset, 2);
    });
  });

  group('InboxStore.setFilter', () {
    test('reloads with new filter', () async {
      final repo = FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              unreadCount: 5,
            ),
          ],
          totalCount: 1,
          totalUnreadCount: 5,
          hasMore: false,
        ),
      );
      final container = createContainer(repository: repo);
      addTearDown(container.dispose);

      await container.read(inboxStoreProvider.notifier).load();
      expect(container.read(inboxStoreProvider).filter, InboxFilter.all);

      repo.fetchResponse = const InboxResponse(
        items: [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-1',
            unreadCount: 5,
          ),
        ],
        totalCount: 1,
        totalUnreadCount: 5,
        hasMore: false,
      );

      await container
          .read(inboxStoreProvider.notifier)
          .setFilter(InboxFilter.unread);

      expect(container.read(inboxStoreProvider).filter, InboxFilter.unread);
      expect(repo.lastFetchFilter, InboxFilter.unread);
      expect(repo.lastFetchOffset, 0);
    });
  });

  group('InboxStore.markRead', () {
    test('optimistically zeros unreadCount for target item', () async {
      final repo = FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              channelName: 'general',
              unreadCount: 5,
            ),
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-1',
              channelName: 'Bob',
              unreadCount: 2,
            ),
          ],
          totalCount: 2,
          totalUnreadCount: 7,
          hasMore: false,
        ),
      );
      final container = createContainer(repository: repo);
      addTearDown(container.dispose);

      await container.read(inboxStoreProvider.notifier).load();
      await container
          .read(inboxStoreProvider.notifier)
          .markRead(channelId: 'ch-1');

      final state = container.read(inboxStoreProvider);
      final ch1 = state.items.firstWhere((i) => i.channelId == 'ch-1');
      expect(ch1.unreadCount, 0);
      expect(state.totalUnreadCount, 2); // 7 - 5
    });

    test('calls repository markItemRead', () async {
      final repo = FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              unreadCount: 3,
            ),
          ],
          totalCount: 1,
          totalUnreadCount: 3,
          hasMore: false,
        ),
      );
      final container = createContainer(repository: repo);
      addTearDown(container.dispose);

      await container.read(inboxStoreProvider.notifier).load();
      await container
          .read(inboxStoreProvider.notifier)
          .markRead(channelId: 'ch-1');

      expect(repo.lastMarkReadChannelId, 'ch-1');
    });
  });

  group('InboxStore.markDone', () {
    test('optimistically removes item from list', () async {
      final repo = FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              unreadCount: 5,
            ),
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-1',
              unreadCount: 2,
            ),
          ],
          totalCount: 2,
          totalUnreadCount: 7,
          hasMore: false,
        ),
      );
      final container = createContainer(repository: repo);
      addTearDown(container.dispose);

      await container.read(inboxStoreProvider.notifier).load();
      await container
          .read(inboxStoreProvider.notifier)
          .markDone(channelId: 'ch-1');

      final state = container.read(inboxStoreProvider);
      expect(state.items, hasLength(1));
      expect(state.items.first.channelId, 'dm-1');
      expect(state.totalCount, 1);
      expect(state.totalUnreadCount, 2); // 7 - 5
    });

    test('calls repository markItemDone', () async {
      final repo = FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              unreadCount: 3,
            ),
          ],
          totalCount: 1,
          totalUnreadCount: 3,
          hasMore: false,
        ),
      );
      final container = createContainer(repository: repo);
      addTearDown(container.dispose);

      await container.read(inboxStoreProvider.notifier).load();
      await container
          .read(inboxStoreProvider.notifier)
          .markDone(channelId: 'ch-1');

      expect(repo.lastMarkDoneChannelId, 'ch-1');
    });
  });

  group('InboxStore.markAllRead', () {
    test('optimistically zeros all unread counts', () async {
      final repo = FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              unreadCount: 5,
            ),
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-1',
              unreadCount: 2,
            ),
          ],
          totalCount: 2,
          totalUnreadCount: 7,
          hasMore: false,
        ),
      );
      final container = createContainer(repository: repo);
      addTearDown(container.dispose);

      await container.read(inboxStoreProvider.notifier).load();
      await container.read(inboxStoreProvider.notifier).markAllRead();

      final state = container.read(inboxStoreProvider);
      expect(state.totalUnreadCount, 0);
      for (final item in state.items) {
        expect(item.unreadCount, 0);
      }
    });

    test('calls repository markAllRead', () async {
      final repo = FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              unreadCount: 3,
            ),
          ],
          totalCount: 1,
          totalUnreadCount: 3,
          hasMore: false,
        ),
      );
      final container = createContainer(repository: repo);
      addTearDown(container.dispose);

      await container.read(inboxStoreProvider.notifier).load();
      await container.read(inboxStoreProvider.notifier).markAllRead();

      expect(repo.markAllReadCalled, isTrue);
    });
  });

  group('InboxStore.refresh', () {
    test('reloads first page preserving current filter', () async {
      final repo = FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              unreadCount: 5,
            ),
          ],
          totalCount: 1,
          totalUnreadCount: 5,
          hasMore: false,
        ),
      );
      final container = createContainer(repository: repo);
      addTearDown(container.dispose);

      // Set filter to unread first
      await container
          .read(inboxStoreProvider.notifier)
          .load(filter: InboxFilter.unread);
      final callsBefore = repo.fetchCallCount;

      await container.read(inboxStoreProvider.notifier).refresh();

      expect(repo.fetchCallCount, callsBefore + 1);
      expect(repo.lastFetchFilter, InboxFilter.unread);
      expect(repo.lastFetchOffset, 0);
    });
  });

  group('InboxState.visibleUnreadCount', () {
    test('counts items with unreadCount > 0', () {
      const state = InboxState(
        status: InboxStatus.success,
        items: [
          InboxItem(
              kind: InboxItemKind.channel, channelId: 'ch-1', unreadCount: 5),
          InboxItem(
              kind: InboxItemKind.channel, channelId: 'ch-2', unreadCount: 0),
          InboxItem(kind: InboxItemKind.dm, channelId: 'dm-1', unreadCount: 2),
        ],
      );

      expect(state.visibleUnreadCount, 2);
    });
  });
}

class FakeInboxRepository implements InboxRepository {
  FakeInboxRepository({
    InboxResponse? fetchResponse,
    AppFailure? fetchFailure,
  })  : fetchResponse = fetchResponse ??
            const InboxResponse(
              items: [],
              totalCount: 0,
              totalUnreadCount: 0,
              hasMore: false,
            ),
        _fetchFailure = fetchFailure;

  InboxResponse fetchResponse;
  final AppFailure? _fetchFailure;

  int fetchCallCount = 0;
  InboxFilter? lastFetchFilter;
  int? lastFetchOffset;
  int? lastFetchLimit;

  String? lastMarkReadChannelId;
  String? lastMarkDoneChannelId;
  bool markAllReadCalled = false;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    fetchCallCount++;
    lastFetchFilter = filter;
    lastFetchOffset = offset;
    lastFetchLimit = limit;
    if (_fetchFailure != null) throw _fetchFailure;
    return fetchResponse;
  }

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    lastMarkReadChannelId = channelId;
  }

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    lastMarkDoneChannelId = channelId;
  }

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {
    markAllReadCalled = true;
  }
}
