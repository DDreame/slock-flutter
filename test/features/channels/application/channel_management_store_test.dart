import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_management_store.dart';
import 'package:slock_app/features/channels/data/channel_management_repository.dart';
import 'package:slock_app/features/channels/data/channel_management_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';

void main() {
  test('createChannel refreshes home list and returns created id', () async {
    final homeRepository = _FakeHomeRepository();
    final channelRepository = _FakeChannelManagementRepository(
      createdChannelId: 'channel-2',
    );
    final container = ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(
          const ServerScopeId('server-1'),
        ),
        homeRepositoryProvider.overrideWithValue(homeRepository),
        channelManagementRepositoryProvider
            .overrideWithValue(channelRepository),
        sidebarOrderRepositoryProvider
            .overrideWithValue(const _FakeSidebarOrderRepository()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(homeListStoreProvider.notifier).load();
    expect(homeRepository.loadCalls, 1);

    final channelId = await container
        .read(channelManagementStoreProvider.notifier)
        .createChannel(
          'support',
          serverId: const ServerScopeId('server-1'),
        );

    expect(channelId, 'channel-2');
    expect(channelRepository.createdNames, ['support']);
    expect(
        channelRepository.createdServerIds, [const ServerScopeId('server-1')]);
    expect(homeRepository.loadCalls, 2);
  });

  test('createChannel shares in-flight mutation for rapid duplicate calls',
      () async {
    final createCompleter = Completer<String>();
    final homeRepository = _FakeHomeRepository();
    final channelRepository = _FakeChannelManagementRepository(
      createCompleter: createCompleter,
    );
    final container = ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(
          const ServerScopeId('server-1'),
        ),
        homeRepositoryProvider.overrideWithValue(homeRepository),
        channelManagementRepositoryProvider
            .overrideWithValue(channelRepository),
        sidebarOrderRepositoryProvider
            .overrideWithValue(const _FakeSidebarOrderRepository()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(homeListStoreProvider.notifier).load();

    final store = container.read(channelManagementStoreProvider.notifier);
    final first = store.createChannel(
      'support',
      serverId: const ServerScopeId('server-1'),
    );
    final second = store.createChannel(
      'support',
      serverId: const ServerScopeId('server-1'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(channelRepository.createdNames, ['support']);
    createCompleter.complete('channel-2');
    final results = await Future.wait([first, second]);

    expect(results, ['channel-2', 'channel-2']);
    expect(channelRepository.createdNames, ['support']);
    expect(homeRepository.loadCalls, 2);
  });

  test('createChannel does not share in-flight mutation for different requests',
      () async {
    final supportCompleter = Completer<String>();
    final opsCompleter = Completer<String>();
    final homeRepository = _FakeHomeRepository();
    final channelRepository = _FakeChannelManagementRepository(
      createCompletersByName: {
        'support': supportCompleter,
        'ops': opsCompleter,
      },
    );
    final container = ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(
          const ServerScopeId('server-1'),
        ),
        homeRepositoryProvider.overrideWithValue(homeRepository),
        channelManagementRepositoryProvider
            .overrideWithValue(channelRepository),
        sidebarOrderRepositoryProvider
            .overrideWithValue(const _FakeSidebarOrderRepository()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(homeListStoreProvider.notifier).load();

    final store = container.read(channelManagementStoreProvider.notifier);
    final support = store.createChannel(
      'support',
      serverId: const ServerScopeId('server-1'),
    );
    final ops = store.createChannel(
      'ops',
      serverId: const ServerScopeId('server-1'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(channelRepository.createdNames, ['support', 'ops']);
    supportCompleter.complete('support-channel-id');
    opsCompleter.complete('ops-channel-id');
    final results = await Future.wait([support, ops]);

    expect(results, ['support-channel-id', 'ops-channel-id']);
    expect(homeRepository.loadCalls, 3);
  });

  test('rename/delete/leave refresh the workspace snapshot after success',
      () async {
    final homeRepository = _FakeHomeRepository();
    final channelRepository = _FakeChannelManagementRepository();
    final container = ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(
          const ServerScopeId('server-1'),
        ),
        homeRepositoryProvider.overrideWithValue(homeRepository),
        channelManagementRepositoryProvider
            .overrideWithValue(channelRepository),
        sidebarOrderRepositoryProvider
            .overrideWithValue(const _FakeSidebarOrderRepository()),
      ],
    );
    addTearDown(container.dispose);

    const scopeId = ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    );

    await container.read(homeListStoreProvider.notifier).load();
    expect(homeRepository.loadCalls, 1);

    await container
        .read(channelManagementStoreProvider.notifier)
        .renameChannel(scopeId, name: 'general-updated');
    await container
        .read(channelManagementStoreProvider.notifier)
        .deleteChannel(scopeId);
    await container.read(channelManagementStoreProvider.notifier).leaveChannel(
          scopeId,
        );

    expect(channelRepository.updatedChannels, [('general', 'general-updated')]);
    expect(channelRepository.deletedChannelIds, ['general']);
    expect(channelRepository.leftChannelIds, ['general']);
    expect(homeRepository.loadCalls, 4);
  });
}

class _FakeHomeRepository implements HomeRepository {
  int loadCalls = 0;

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async {
    return null;
  }

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    loadCalls += 1;
    return HomeWorkspaceSnapshot(
      serverId: serverId,
      channels: const [
        HomeChannelSummary(
          scopeId: ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'general',
          ),
          name: 'general',
        ),
      ],
      directMessages: const [],
    );
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

class _FakeChannelManagementRepository implements ChannelManagementRepository {
  _FakeChannelManagementRepository({
    this.createdChannelId = 'new-channel-id',
    this.createCompleter,
    this.createCompletersByName = const <String, Completer<String>>{},
  });

  final String createdChannelId;
  final Completer<String>? createCompleter;
  final Map<String, Completer<String>> createCompletersByName;
  final List<String> createdNames = [];
  final List<ServerScopeId> createdServerIds = [];
  final List<(String, String)> updatedChannels = [];
  final List<String> deletedChannelIds = [];
  final List<String> leftChannelIds = [];

  @override
  Future<String> createChannel(
    ServerScopeId serverId, {
    required String name,
    String? description,
    bool? isPrivate,
  }) async {
    createdServerIds.add(serverId);
    createdNames.add(name);
    final namedCompleter = createCompletersByName[name];
    if (namedCompleter != null) {
      return namedCompleter.future;
    }
    final completer = createCompleter;
    if (completer != null) {
      return completer.future;
    }
    return createdChannelId;
  }

  @override
  Future<void> updateChannel(
    ServerScopeId serverId, {
    required String channelId,
    required String name,
  }) async {
    updatedChannels.add((channelId, name));
  }

  @override
  Future<void> deleteChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    deletedChannelIds.add(channelId);
  }

  @override
  Future<void> leaveChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    leftChannelIds.add(channelId);
  }
}

class _FakeSidebarOrderRepository implements SidebarOrderRepository {
  const _FakeSidebarOrderRepository();

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async {
    return const SidebarOrder();
  }

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {}
}
