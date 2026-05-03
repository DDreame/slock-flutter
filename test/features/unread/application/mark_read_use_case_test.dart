import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/scope/channel_scope_id.dart';
import 'package:slock_app/core/scope/direct_message_scope_id.dart';
import 'package:slock_app/core/scope/server_scope_id.dart';
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
}
