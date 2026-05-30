import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/scope/channel_scope_id.dart';
import 'package:slock_app/core/scope/direct_message_scope_id.dart';
import 'package:slock_app/core/scope/server_scope_id.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/application/inbox_unread_count_provider.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/unread/application/mark_read_use_case.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';

class _RecordingInboxRepository implements InboxRepository {
  final List<({String method, String channelId})> calls = [];

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
  }) async {
    calls.add((method: 'markItemRead', channelId: channelId));
  }

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    calls.add((method: 'markItemDone', channelId: channelId));
  }

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {
    calls.add((method: 'markAllRead', channelId: ''));
  }

  @override
  Future<void> markItemReadAt(
    ServerScopeId serverId, {
    required String channelId,
    required int seq,
  }) async {}
}

/// Fake HomeListStore that returns a fixed state.
class _FakeHomeListStore extends HomeListStore {
  _FakeHomeListStore(this._initial);
  final HomeListState _initial;

  @override
  HomeListState build() => _initial;
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

  late _RecordingInboxRepository inboxRepo;

  setUp(() {
    inboxRepo = _RecordingInboxRepository();
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        inboxRepositoryProvider.overrideWithValue(inboxRepo),
        activeServerScopeIdProvider.overrideWithValue(server1),
        homeListStoreProvider.overrideWith(
          () => _FakeHomeListStore(
            HomeListState(
              status: HomeListStatus.success,
              channels: [
                const HomeChannelSummary(
                  scopeId: channelGeneral,
                  name: 'general',
                ),
              ],
              directMessages: [
                const HomeDirectMessageSummary(
                  scopeId: dmAlice,
                  title: 'Alice',
                ),
              ],
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('markChannelReadUseCaseProvider', () {
    test('clears projection unread badge immediately', () async {
      final container = createContainer();
      await container.read(inboxStoreProvider.notifier).load();

      // Before mark-read: projection shows unread count.
      expect(
        container
            .read(unreadSourceProjectionProvider)
            .channelUnreadCount(channelGeneral),
        5,
      );

      container.read(markChannelReadUseCaseProvider)(channelGeneral);
      await Future<void>.delayed(Duration.zero);

      // After mark-read: projection shows zero.
      expect(
        container
            .read(unreadSourceProjectionProvider)
            .channelUnreadCount(channelGeneral),
        0,
      );
    });

    test('fires canonical /read-all via InboxStore', () async {
      final container = createContainer();
      await container.read(inboxStoreProvider.notifier).load();

      container.read(markChannelReadUseCaseProvider)(channelGeneral);
      await Future<void>.delayed(Duration.zero);

      expect(inboxRepo.calls, hasLength(1));
      expect(inboxRepo.calls.single.method, 'markItemRead');
      expect(inboxRepo.calls.single.channelId, 'ch-general');
    });
  });

  group('markDmReadUseCaseProvider', () {
    test('clears projection DM unread badge immediately', () async {
      final container = createContainer();
      await container.read(inboxStoreProvider.notifier).load();

      expect(
        container.read(unreadSourceProjectionProvider).dmUnreadCount(dmAlice),
        3,
      );

      container.read(markDmReadUseCaseProvider)(dmAlice);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(unreadSourceProjectionProvider).dmUnreadCount(dmAlice),
        0,
      );
    });

    test('fires canonical /read-all via InboxStore', () async {
      final container = createContainer();
      await container.read(inboxStoreProvider.notifier).load();

      container.read(markDmReadUseCaseProvider)(dmAlice);
      await Future<void>.delayed(Duration.zero);

      expect(inboxRepo.calls, hasLength(1));
      expect(inboxRepo.calls.single.method, 'markItemRead');
      expect(inboxRepo.calls.single.channelId, 'dm-alice');
    });
  });

  group('Inbox badge integration (regression)', () {
    test('markChannelRead drops inbox-backed channel badge count immediately',
        () async {
      final container = createContainer();
      await container.read(inboxStoreProvider.notifier).load();

      expect(
        container.read(inboxStoreProvider).status,
        InboxStatus.success,
      );
      expect(container.read(inboxChannelUnreadTotalProvider), 5);

      container.read(markChannelReadUseCaseProvider)(channelGeneral);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(inboxChannelUnreadTotalProvider), 0);
      final item = container
          .read(inboxStoreProvider)
          .items
          .firstWhere((i) => i.channelId == 'ch-general');
      expect(item.unreadCount, 0);
    });

    test('markDmRead drops inbox-backed DM badge count immediately', () async {
      final container = createContainer();
      await container.read(inboxStoreProvider.notifier).load();

      expect(container.read(inboxDmUnreadTotalProvider), 3);

      container.read(markDmReadUseCaseProvider)(dmAlice);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(inboxDmUnreadTotalProvider), 0);
      final item = container
          .read(inboxStoreProvider)
          .items
          .firstWhere((i) => i.channelId == 'dm-alice');
      expect(item.unreadCount, 0);
    });
  });
}
