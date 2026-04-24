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
        .createChannel('support');

    expect(channelId, 'channel-2');
    expect(channelRepository.createdNames, ['support']);
    expect(homeRepository.loadCalls, 2);
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
  _FakeChannelManagementRepository({this.createdChannelId});

  final String? createdChannelId;
  final List<String> createdNames = [];
  final List<(String, String)> updatedChannels = [];
  final List<String> deletedChannelIds = [];
  final List<String> leftChannelIds = [];

  @override
  Future<String?> createChannel(
    ServerScopeId serverId, {
    required String name,
  }) async {
    createdNames.add(name);
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
