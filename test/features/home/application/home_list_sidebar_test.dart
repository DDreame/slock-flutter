import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';

void main() {
  group('sidebar order application', () {
    test('load applies channel order from sidebar order', () async {
      final container = _buildContainer(
        sidebarOrder: const SidebarOrder(
          channelOrder: ['random', 'general'],
        ),
      );
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();
      final state = container.read(homeListStoreProvider);

      expect(state.status, HomeListStatus.success);
      expect(state.channels.map((c) => c.name).toList(), ['random', 'general']);
    });

    test('load applies DM order from sidebar order', () async {
      final container = _buildContainer(
        sidebarOrder: const SidebarOrder(
          dmOrder: ['dm-bob', 'dm-alice'],
        ),
      );
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();
      final state = container.read(homeListStoreProvider);

      expect(
          state.directMessages.map((d) => d.title).toList(), ['Bob', 'Alice']);
    });

    test('load separates pinned channels from unpinned', () async {
      final container = _buildContainer(
        sidebarOrder: const SidebarOrder(
          pinnedChannelIds: ['general'],
          pinnedOrder: ['general'],
        ),
      );
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();
      final state = container.read(homeListStoreProvider);

      expect(state.pinnedChannels.length, 1);
      expect(state.pinnedChannels.first.name, 'general');
      expect(state.channels.length, 1);
      expect(state.channels.first.name, 'random');
    });

    test('pinned channels are ordered by pinnedOrder', () async {
      final container = _buildContainer(
        sidebarOrder: const SidebarOrder(
          pinnedChannelIds: ['general', 'random'],
          pinnedOrder: ['random', 'general'],
        ),
      );
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();
      final state = container.read(homeListStoreProvider);

      expect(
        state.pinnedChannels.map((c) => c.name).toList(),
        ['random', 'general'],
      );
      expect(state.channels, isEmpty);
    });

    test('load hides DMs in hiddenDmIds', () async {
      final container = _buildContainer(
        sidebarOrder: const SidebarOrder(
          hiddenDmIds: ['dm-alice'],
        ),
      );
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();
      final state = container.read(homeListStoreProvider);

      expect(state.directMessages.length, 1);
      expect(state.directMessages.first.title, 'Bob');
      expect(state.hiddenDirectMessages.length, 1);
      expect(state.hiddenDirectMessages.first.title, 'Alice');
    });

    test('addDirectMessage respects hidden filter', () async {
      final container = _buildContainer(
        sidebarOrder: const SidebarOrder(
          hiddenDmIds: ['dm-new'],
        ),
      );
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();
      container.read(homeListStoreProvider.notifier).addDirectMessage(
            const HomeDirectMessageSummary(
              scopeId: DirectMessageScopeId(
                serverId: ServerScopeId('server-1'),
                value: 'dm-new',
              ),
              title: 'New Hidden',
            ),
          );

      final state = container.read(homeListStoreProvider);
      expect(state.directMessages.every((d) => d.title != 'New Hidden'), true);
      expect(
        state.hiddenDirectMessages.any((d) => d.title == 'New Hidden'),
        true,
      );
    });

    test('sidebar order failure falls back to default order', () async {
      final container = _buildContainer(
        sidebarOrderFailure: const ServerFailure(
          message: 'Not found',
          statusCode: 404,
        ),
      );
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();
      final state = container.read(homeListStoreProvider);

      expect(state.status, HomeListStatus.success);
      expect(state.channels.length, 2);
      expect(state.directMessages.length, 2);
      expect(state.pinnedChannels, isEmpty);
      expect(state.hiddenDirectMessages, isEmpty);
    });
  });

  group('pinChannel', () {
    test('optimistically pins a channel and patches API', () async {
      final sidebarRepo = _FakeSidebarOrderRepository();
      final container = _buildContainer(sidebarOrderRepository: sidebarRepo);
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();
      expect(container.read(homeListStoreProvider).pinnedChannels, isEmpty);

      await container.read(homeListStoreProvider.notifier).pinChannel(
            const ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'general',
            ),
          );

      final state = container.read(homeListStoreProvider);
      expect(state.pinnedChannels.length, 1);
      expect(state.pinnedChannels.first.name, 'general');
      expect(state.channels.length, 1);
      expect(state.channels.first.name, 'random');
      expect(sidebarRepo.patchCalls, 1);
    });

    test('reverts on API failure', () async {
      final sidebarRepo = _FakeSidebarOrderRepository(
        updateFailure: const ServerFailure(
          message: 'Failed',
          statusCode: 500,
        ),
      );
      final container = _buildContainer(sidebarOrderRepository: sidebarRepo);
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();
      await container.read(homeListStoreProvider.notifier).pinChannel(
            const ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'general',
            ),
          );

      final state = container.read(homeListStoreProvider);
      expect(state.pinnedChannels, isEmpty);
      expect(state.channels.length, 2);
    });
  });

  group('unpinChannel', () {
    test('optimistically unpins a channel and patches API', () async {
      final sidebarRepo = _FakeSidebarOrderRepository(
        sidebarOrder: const SidebarOrder(
          pinnedChannelIds: ['general'],
          pinnedOrder: ['general'],
        ),
      );
      final container = _buildContainer(sidebarOrderRepository: sidebarRepo);
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();
      expect(container.read(homeListStoreProvider).pinnedChannels.length, 1);

      await container.read(homeListStoreProvider.notifier).unpinChannel(
            const ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'general',
            ),
          );

      final state = container.read(homeListStoreProvider);
      expect(state.pinnedChannels, isEmpty);
      expect(state.channels.length, 2);
      expect(sidebarRepo.patchCalls, 1);
    });
  });

  group('pinDirectMessage', () {
    test('optimistically pins a DM and patches API', () async {
      final sidebarRepo = _FakeSidebarOrderRepository();
      final container = _buildContainer(sidebarOrderRepository: sidebarRepo);
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();
      expect(
          container.read(homeListStoreProvider).pinnedDirectMessages, isEmpty);

      await container.read(homeListStoreProvider.notifier).pinDirectMessage(
            const DirectMessageScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'dm-alice',
            ),
          );

      final state = container.read(homeListStoreProvider);
      expect(state.pinnedDirectMessages.length, 1);
      expect(state.pinnedDirectMessages.first.title, 'Alice');
      expect(state.directMessages.length, 1);
      expect(state.directMessages.first.title, 'Bob');
      expect(state.pinnedConversationOrder, ['dm-alice']);
      expect(sidebarRepo.patchCalls, 1);
    });
  });

  group('moveChannel', () {
    test('updates channel order and patches API', () async {
      final sidebarRepo = _FakeSidebarOrderRepository();
      final container = _buildContainer(sidebarOrderRepository: sidebarRepo);
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();

      await container.read(homeListStoreProvider.notifier).moveChannel(
            const ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'random',
            ),
            moveUp: true,
          );

      final state = container.read(homeListStoreProvider);
      expect(state.channels.map((channel) => channel.name).toList(), [
        'random',
        'general',
      ]);
      expect(sidebarRepo.patchCalls, 1);
    });
  });

  group('moveChannel rollback', () {
    test('failed concurrent persist does not clobber later reorder', () async {
      final firstPersist = Completer<void>();
      final secondPersist = Completer<void>();
      final sidebarRepo = _FakeSidebarOrderRepository(
        updateCompleters: [firstPersist, secondPersist],
        failingUpdateCallIndexes: const {1},
      );
      final container = _buildContainer(
        snapshot: _threeChannelSnapshot,
        sidebarOrderRepository: sidebarRepo,
      );
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();
      final store = container.read(homeListStoreProvider.notifier);

      final firstMove = store.moveChannel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'beta',
        ),
        moveUp: true,
      );
      await Future<void>.delayed(Duration.zero);
      final secondMove = store.moveChannel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'gamma',
        ),
        moveUp: true,
      );
      await Future<void>.delayed(Duration.zero);

      firstPersist.complete();
      await firstMove;
      secondPersist.complete();
      await secondMove;

      final state = container.read(homeListStoreProvider);
      expect(
        state.channels.map((channel) => channel.name).toList(),
        ['Beta', 'Gamma', 'Alpha'],
      );
      expect(sidebarRepo.patchCalls, 2);
    });
  });

  group('moveDirectMessage', () {
    test('updates direct message order and patches API', () async {
      final sidebarRepo = _FakeSidebarOrderRepository();
      final container = _buildContainer(sidebarOrderRepository: sidebarRepo);
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();

      await container.read(homeListStoreProvider.notifier).moveDirectMessage(
            const DirectMessageScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'dm-bob',
            ),
            moveUp: true,
          );

      final state = container.read(homeListStoreProvider);
      expect(
        state.directMessages.map((dm) => dm.title).toList(),
        ['Bob', 'Alice'],
      );
      expect(sidebarRepo.patchCalls, 1);
    });
  });

  group('movePinnedConversation', () {
    test('reorders pinned conversations without disturbing pins', () async {
      final sidebarRepo = _FakeSidebarOrderRepository(
        sidebarOrder: const SidebarOrder(
          pinnedChannelIds: ['general', 'dm-alice'],
          pinnedOrder: ['general', 'dm-alice'],
        ),
      );
      final container = _buildContainer(sidebarOrderRepository: sidebarRepo);
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();

      await container
          .read(homeListStoreProvider.notifier)
          .movePinnedConversation(
            const ServerScopeId('server-1'),
            'dm-alice',
            moveUp: true,
          );

      final state = container.read(homeListStoreProvider);
      expect(state.pinnedConversationOrder, ['dm-alice', 'general']);
      expect(sidebarRepo.patchCalls, 1);
    });
  });

  group('hideDm', () {
    test('optimistically hides a DM and patches API', () async {
      final sidebarRepo = _FakeSidebarOrderRepository();
      final container = _buildContainer(sidebarOrderRepository: sidebarRepo);
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();
      expect(container.read(homeListStoreProvider).directMessages.length, 2);

      await container.read(homeListStoreProvider.notifier).hideDm(
            const DirectMessageScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'dm-alice',
            ),
          );

      final state = container.read(homeListStoreProvider);
      expect(state.directMessages.length, 1);
      expect(state.directMessages.first.title, 'Bob');
      expect(state.hiddenDirectMessages.length, 1);
      expect(state.hiddenDirectMessages.first.title, 'Alice');
      expect(sidebarRepo.patchCalls, 1);
    });

    test('reverts on API failure', () async {
      final sidebarRepo = _FakeSidebarOrderRepository(
        updateFailure: const ServerFailure(
          message: 'Failed',
          statusCode: 500,
        ),
      );
      final container = _buildContainer(sidebarOrderRepository: sidebarRepo);
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();
      await container.read(homeListStoreProvider.notifier).hideDm(
            const DirectMessageScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'dm-alice',
            ),
          );

      final state = container.read(homeListStoreProvider);
      expect(state.directMessages.length, 2);
      expect(state.hiddenDirectMessages, isEmpty);
    });

    test('closing a pinned DM removes it from pinned conversations', () async {
      final sidebarRepo = _FakeSidebarOrderRepository(
        sidebarOrder: const SidebarOrder(
          pinnedChannelIds: ['dm-alice'],
          pinnedOrder: ['dm-alice'],
        ),
      );
      final container = _buildContainer(sidebarOrderRepository: sidebarRepo);
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();

      await container.read(homeListStoreProvider.notifier).hideDm(
            const DirectMessageScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'dm-alice',
            ),
          );

      final state = container.read(homeListStoreProvider);
      expect(state.pinnedDirectMessages, isEmpty);
      expect(state.hiddenDirectMessages.map((dm) => dm.title).toList(), [
        'Alice',
      ]);
      expect(state.pinnedConversationOrder, isEmpty);
      expect(sidebarRepo.patchCalls, 1);
    });
  });

  group('unhideDm', () {
    test('optimistically unhides a DM and patches API', () async {
      final sidebarRepo = _FakeSidebarOrderRepository(
        sidebarOrder: const SidebarOrder(
          hiddenDmIds: ['dm-alice'],
        ),
      );
      final container = _buildContainer(sidebarOrderRepository: sidebarRepo);
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();
      expect(container.read(homeListStoreProvider).directMessages.length, 1);

      await container.read(homeListStoreProvider.notifier).unhideDm(
            const DirectMessageScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'dm-alice',
            ),
          );

      final state = container.read(homeListStoreProvider);
      expect(state.directMessages.length, 2);
      expect(state.hiddenDirectMessages, isEmpty);
      expect(sidebarRepo.patchCalls, 1);
    });
  });
}

const _threeChannelSnapshot = HomeWorkspaceSnapshot(
  serverId: ServerScopeId('server-1'),
  channels: [
    HomeChannelSummary(
      scopeId: ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'alpha',
      ),
      name: 'Alpha',
    ),
    HomeChannelSummary(
      scopeId: ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'beta',
      ),
      name: 'Beta',
    ),
    HomeChannelSummary(
      scopeId: ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'gamma',
      ),
      name: 'Gamma',
    ),
  ],
  directMessages: [],
);

const _sampleSnapshot = HomeWorkspaceSnapshot(
  serverId: ServerScopeId('server-1'),
  channels: [
    HomeChannelSummary(
      scopeId: ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'general',
      ),
      name: 'general',
    ),
    HomeChannelSummary(
      scopeId: ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'random',
      ),
      name: 'random',
    ),
  ],
  directMessages: [
    HomeDirectMessageSummary(
      scopeId: DirectMessageScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'dm-alice',
      ),
      title: 'Alice',
    ),
    HomeDirectMessageSummary(
      scopeId: DirectMessageScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'dm-bob',
      ),
      title: 'Bob',
    ),
  ],
);

ProviderContainer _buildContainer({
  HomeWorkspaceSnapshot snapshot = _sampleSnapshot,
  SidebarOrder sidebarOrder = const SidebarOrder(),
  AppFailure? sidebarOrderFailure,
  _FakeSidebarOrderRepository? sidebarOrderRepository,
}) {
  final sidebarRepo = sidebarOrderRepository ??
      _FakeSidebarOrderRepository(
        sidebarOrder: sidebarOrder,
        loadFailure: sidebarOrderFailure,
      );
  return ProviderContainer(
    overrides: [
      activeServerScopeIdProvider.overrideWithValue(
        const ServerScopeId('server-1'),
      ),
      homeRepositoryProvider.overrideWithValue(
        _FakeHomeRepository(snapshot),
      ),
      sidebarOrderRepositoryProvider.overrideWithValue(sidebarRepo),
    ],
  );
}

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository(this.snapshot);

  final HomeWorkspaceSnapshot snapshot;

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async {
    return null;
  }

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    return snapshot;
  }

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async {
    return summary;
  }

  @override
  Future<void> persistConversationActivity({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
    required DateTime activityAt,
  }) async {}

  @override
  Future<void> persistConversationPreviewUpdate({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
  }) async {}
}

class _FakeSidebarOrderRepository implements SidebarOrderRepository {
  _FakeSidebarOrderRepository({
    this.sidebarOrder = const SidebarOrder(),
    this.loadFailure,
    this.updateFailure,
    this.updateCompleters = const [],
    this.failingUpdateCallIndexes = const {},
  });

  final SidebarOrder sidebarOrder;
  final AppFailure? loadFailure;
  final AppFailure? updateFailure;
  final List<Completer<void>> updateCompleters;
  final Set<int> failingUpdateCallIndexes;
  int patchCalls = 0;

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async {
    if (loadFailure != null) throw loadFailure!;
    return sidebarOrder;
  }

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {
    patchCalls++;
    final completerIndex = patchCalls - 1;
    if (completerIndex < updateCompleters.length) {
      await updateCompleters[completerIndex].future;
    }
    if (updateFailure != null ||
        failingUpdateCallIndexes.contains(patchCalls)) {
      throw updateFailure ??
          const ServerFailure(message: 'Failed', statusCode: 500);
    }
  }
}
