import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/scope/channel_scope_id.dart';
import 'package:slock_app/core/scope/direct_message_scope_id.dart';
import 'package:slock_app/core/scope/server_scope_id.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/application/inbox_unread_count_provider.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/unread/application/mark_read_use_case.dart';
import 'package:slock_app/features/unread/data/channel_unread_repository.dart';
import 'package:slock_app/features/unread/data/channel_unread_repository_provider.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';

class _RecordingUnreadRepository implements ChannelUnreadRepository {
  final List<({String method, String id, String serverId})> calls = [];
  bool shouldThrow = false;

  @override
  Future<Map<String, int>> fetchUnreadCounts(
    ServerScopeId serverId,
  ) async {
    return {};
  }

  @override
  Future<void> markChannelRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    calls.add((
      method: 'markChannelRead',
      id: channelId,
      serverId: serverId.value,
    ));
    if (shouldThrow) throw Exception('test error');
  }

  @override
  Future<void> markAllInboxRead(
    ServerScopeId serverId,
  ) async {
    calls.add((
      method: 'markAllInboxRead',
      id: '',
      serverId: serverId.value,
    ));
    if (shouldThrow) throw Exception('test error');
  }
}

void main() {
  const server1 = ServerScopeId('server-1');
  const channelGeneral = ChannelScopeId(
    serverId: server1,
    value: 'ch-general',
  );
  const dmAlice = DirectMessageScopeId(
    serverId: server1,
    value: 'dm-alice',
  );

  late _RecordingUnreadRepository fakeRepo;

  setUp(() {
    fakeRepo = _RecordingUnreadRepository();
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        channelUnreadRepositoryProvider.overrideWithValue(fakeRepo),
        inboxRepositoryProvider.overrideWithValue(_FakeInboxRepository()),
        activeServerScopeIdProvider.overrideWithValue(server1),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('markChannelReadUseCaseProvider', () {
    test('clears local unread and fires server call', () async {
      final container = createContainer();
      container
          .read(channelUnreadStoreProvider.notifier)
          .hydrateChannelUnreads({channelGeneral: 5});

      container.read(markChannelReadUseCaseProvider)(
        channelGeneral,
      );
      await Future<void>.delayed(Duration.zero);

      // Local state cleared immediately.
      expect(
        container
            .read(channelUnreadStoreProvider)
            .channelUnreadCount(channelGeneral),
        0,
      );
      // Server call fired.
      expect(fakeRepo.calls, hasLength(1));
      expect(
        fakeRepo.calls.single.method,
        'markChannelRead',
      );
      expect(fakeRepo.calls.single.id, 'ch-general');
      expect(fakeRepo.calls.single.serverId, 'server-1');
    });

    test('server failure does not crash', () async {
      final container = createContainer();
      container
          .read(channelUnreadStoreProvider.notifier)
          .hydrateChannelUnreads({channelGeneral: 5});
      fakeRepo.shouldThrow = true;

      // Should not throw.
      container.read(markChannelReadUseCaseProvider)(
        channelGeneral,
      );
      await Future<void>.delayed(Duration.zero);

      // Local state still cleared.
      expect(
        container
            .read(channelUnreadStoreProvider)
            .channelUnreadCount(channelGeneral),
        0,
      );
    });
  });

  group('markDmReadUseCaseProvider', () {
    test('clears local DM unread and fires server call', () async {
      final container = createContainer();
      container
          .read(channelUnreadStoreProvider.notifier)
          .hydrateDmUnreads({dmAlice: 3});

      container.read(markDmReadUseCaseProvider)(dmAlice);
      await Future<void>.delayed(Duration.zero);

      // Local state cleared immediately.
      expect(
        container.read(channelUnreadStoreProvider).dmUnreadCount(dmAlice),
        0,
      );
      // Server call fired (DMs are also channels).
      expect(fakeRepo.calls, hasLength(1));
      expect(
        fakeRepo.calls.single.method,
        'markChannelRead',
      );
      expect(fakeRepo.calls.single.id, 'dm-alice');
    });

    test('server failure does not crash', () async {
      final container = createContainer();
      container
          .read(channelUnreadStoreProvider.notifier)
          .hydrateDmUnreads({dmAlice: 3});
      fakeRepo.shouldThrow = true;

      container.read(markDmReadUseCaseProvider)(dmAlice);
      await Future<void>.delayed(Duration.zero);

      // Local state still cleared.
      expect(
        container.read(channelUnreadStoreProvider).dmUnreadCount(dmAlice),
        0,
      );
    });
  });

  group('Inbox badge integration (regression)', () {
    test('markChannelRead drops inbox-backed channel badge count immediately',
        () async {
      final container = createContainer();

      // Load inbox with a channel unread item.
      await container.read(inboxStoreProvider.notifier).load();

      // Verify initial state.
      expect(
        container.read(inboxStoreProvider).status,
        InboxStatus.success,
      );
      expect(container.read(inboxChannelUnreadTotalProvider), 5);

      // Mark the channel as read via use case (simulating channel open).
      container.read(markChannelReadUseCaseProvider)(channelGeneral);
      await Future<void>.delayed(Duration.zero);

      // Inbox badge must reflect the read immediately.
      expect(container.read(inboxChannelUnreadTotalProvider), 0);
      final item = container
          .read(inboxStoreProvider)
          .items
          .firstWhere((i) => i.channelId == 'ch-general');
      expect(item.unreadCount, 0);
    });

    test('markDmRead drops inbox-backed DM badge count immediately', () async {
      final container = createContainer();

      // Load inbox with a DM unread item.
      await container.read(inboxStoreProvider.notifier).load();

      // Verify initial state.
      expect(container.read(inboxDmUnreadTotalProvider), 3);

      // Mark the DM as read via use case (simulating DM open).
      container.read(markDmReadUseCaseProvider)(dmAlice);
      await Future<void>.delayed(Duration.zero);

      // Inbox badge must reflect the read immediately.
      expect(container.read(inboxDmUnreadTotalProvider), 0);
      final item = container
          .read(inboxStoreProvider)
          .items
          .firstWhere((i) => i.channelId == 'dm-alice');
      expect(item.unreadCount, 0);
    });
  });
}

class _FakeInboxRepository implements InboxRepository {
  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    return const InboxResponse(
      items: [
        InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-general',
          channelName: 'general',
          unreadCount: 5,
        ),
        InboxItem(
          kind: InboxItemKind.dm,
          channelId: 'dm-alice',
          channelName: 'Alice',
          unreadCount: 3,
        ),
      ],
      totalCount: 2,
      totalUnreadCount: 8,
      hasMore: false,
    );
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
