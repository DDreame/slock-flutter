import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/channels/application/channel_management_store.dart';
import 'package:slock_app/features/channels/application/channel_management_state.dart';
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

  test('createChannel completion after disposal does not read disposed refs',
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

    final sub = container.listen(channelManagementStoreProvider, (_, __) {});
    final future = container
        .read(channelManagementStoreProvider.notifier)
        .createChannel('support', serverId: const ServerScopeId('server-1'));
    await Future<void>.delayed(Duration.zero);

    sub.close();
    container.dispose();
    createCompleter.complete('support-channel-id');

    await expectLater(future, completion('support-channel-id'));
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

  // -------------------------------------------------------------------------
  // #737 — Emergency Stop/Resume All Agents
  // -------------------------------------------------------------------------

  test('stopAllAgents calls repository and completes', () async {
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

    await container.read(homeListStoreProvider.notifier).load();

    const scopeId = ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    );

    await container
        .read(channelManagementStoreProvider.notifier)
        .stopAllAgents(scopeId);

    expect(channelRepository.stoppedAllAgentsChannelIds, ['general'],
        reason: '#737: stopAllAgents must call repo with channelId');
  });

  test('resumeAllAgents calls repository and completes', () async {
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

    await container.read(homeListStoreProvider.notifier).load();

    const scopeId = ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    );

    await container
        .read(channelManagementStoreProvider.notifier)
        .resumeAllAgents(scopeId);

    expect(channelRepository.resumedAllAgentsChannelIds, ['general'],
        reason: '#737: resumeAllAgents must call repo with channelId');
  });

  test('stopAllAgents concurrent call is dropped and returns false', () async {
    final completer = Completer<void>();
    final homeRepository = _FakeHomeRepository();
    final channelRepository = _FakeChannelManagementRepository(
      stopAllCompleter: completer,
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

    const scopeId = ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    );

    final store = container.read(channelManagementStoreProvider.notifier);
    final first = store.stopAllAgents(scopeId);
    final second = store.stopAllAgents(scopeId);

    // Second call should return false immediately (re-entrancy guard).
    final secondResult = await second;
    expect(secondResult, isFalse,
        reason: '#738: re-entrancy guard must return false to caller');
    expect(channelRepository.stoppedAllAgentsChannelIds, hasLength(1),
        reason: '#738: concurrent stopAllAgents must be dropped');

    completer.complete();
    final firstResult = await first;
    expect(firstResult, isTrue, reason: '#738: completed op must return true');
  });

  test(
      'concurrent op on different channel returns false when store is busy '
      '(state clobber prevention)', () async {
    final completer = Completer<void>();
    final homeRepository = _FakeHomeRepository();
    final channelRepository = _FakeChannelManagementRepository(
      stopAllCompleter: completer,
    );
    final agentsRepository = _FakeAgentsRepository();
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
        agentsRepositoryProvider.overrideWithValue(agentsRepository),
        agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
      ],
    );
    addTearDown(container.dispose);

    await container.read(homeListStoreProvider.notifier).load();

    // Keep provider alive across awaits (autoDispose GC prevention).
    final sub = container.listen(channelManagementStoreProvider, (_, __) {});

    const scopeA = ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'channel-a',
    );
    const scopeB = ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'channel-b',
    );

    final store = container.read(channelManagementStoreProvider.notifier);

    // Start op on channel A (held by completer).
    final opA = store.stopAllAgents(scopeA);
    await Future<void>.delayed(Duration.zero);

    // State should show channel A's operation.
    final midState = container.read(channelManagementStoreProvider);
    expect(midState.isBusy, isTrue);
    expect(midState.channelId, 'channel-a');
    expect(midState.activeAction, ChannelManagementAction.stopAgents);

    // Attempt op on channel B — should be rejected because store is busy.
    final opB = store.resumeAllAgents(scopeB);
    final bResult = await opB;
    expect(bResult, isFalse,
        reason: '#738: concurrent op on different channel must be rejected');

    // Channel A's state must still be intact.
    final afterState = container.read(channelManagementStoreProvider);
    expect(afterState.channelId, 'channel-a',
        reason: '#738: first op state must not be clobbered');
    expect(afterState.activeAction, ChannelManagementAction.stopAgents);

    // Complete the first op.
    completer.complete();
    final aResult = await opA;
    expect(aResult, isTrue);

    // State should be cleared after completion.
    final finalState = container.read(channelManagementStoreProvider);
    expect(finalState.isBusy, isFalse);

    sub.close();
  });

  test('stopAllAgents refreshes agents store after success', () async {
    final homeRepository = _FakeHomeRepository();
    final channelRepository = _FakeChannelManagementRepository();
    final agentsRepository = _FakeAgentsRepository();
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
        agentsRepositoryProvider.overrideWithValue(agentsRepository),
        agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
      ],
    );
    addTearDown(container.dispose);

    await container.read(homeListStoreProvider.notifier).load();

    const scopeId = ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    );

    final callsBefore = agentsRepository.listAgentsCalls;

    await container
        .read(channelManagementStoreProvider.notifier)
        .stopAllAgents(scopeId);

    expect(agentsRepository.listAgentsCalls, callsBefore + 1,
        reason: '#737: stopAllAgents must refresh agents store after success');
  });

  test('resumeAllAgents refreshes agents store after success', () async {
    final homeRepository = _FakeHomeRepository();
    final channelRepository = _FakeChannelManagementRepository();
    final agentsRepository = _FakeAgentsRepository();
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
        agentsRepositoryProvider.overrideWithValue(agentsRepository),
        agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
      ],
    );
    addTearDown(container.dispose);

    await container.read(homeListStoreProvider.notifier).load();

    const scopeId = ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    );

    final callsBefore = agentsRepository.listAgentsCalls;

    await container
        .read(channelManagementStoreProvider.notifier)
        .resumeAllAgents(scopeId);

    expect(agentsRepository.listAgentsCalls, callsBefore + 1,
        reason:
            '#737: resumeAllAgents must refresh agents store after success');
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
    this.stopAllCompleter,
  });

  final String createdChannelId;
  final Completer<String>? createCompleter;
  final Map<String, Completer<String>> createCompletersByName;
  final Completer<void>? stopAllCompleter;
  final List<String> createdNames = [];
  final List<ServerScopeId> createdServerIds = [];
  final List<(String, String?)> updatedChannels = [];
  final List<String> deletedChannelIds = [];
  final List<String> leftChannelIds = [];
  final List<String> stoppedAllAgentsChannelIds = [];
  final List<String> resumedAllAgentsChannelIds = [];

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
    String? name,
    String? description,
    bool? isPrivate,
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
  Future<void> joinChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> leaveChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    leftChannelIds.add(channelId);
  }

  @override
  Future<void> stopAllAgents(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    stoppedAllAgentsChannelIds.add(channelId);
    if (stopAllCompleter != null) {
      await stopAllCompleter!.future;
    }
  }

  @override
  Future<void> resumeAllAgents(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    resumedAllAgentsChannelIds.add(channelId);
  }

  @override
  Future<void> archiveChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> unarchiveChannel(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}
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

class _FakeAgentsRepository implements AgentsRepository {
  int listAgentsCalls = 0;

  @override
  Future<List<AgentItem>> listAgents() async {
    listAgentsCalls++;
    return const [];
  }

  @override
  Future<void> startAgent(String agentId) async {}

  @override
  Future<void> stopAgent(String agentId) async {}

  @override
  Future<void> resetAgent(String agentId, {required String mode}) async {}

  @override
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  }) async =>
      const [];
}
