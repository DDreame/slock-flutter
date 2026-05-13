import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';

void main() {
  const serverId = ServerScopeId('server-1');
  const snapshot = HomeWorkspaceSnapshot(
    serverId: serverId,
    channels: [
      HomeChannelSummary(
        scopeId: ChannelScopeId(serverId: serverId, value: 'general'),
        name: 'general',
      ),
    ],
    directMessages: [
      HomeDirectMessageSummary(
        scopeId: DirectMessageScopeId(serverId: serverId, value: 'dm-1'),
        title: 'Alice',
      ),
    ],
  );

  ProviderContainer createContainer({
    HomeWorkspaceSnapshot? workspaceSnapshot,
    AppFailure? refreshFailure,
    Completer<HomeWorkspaceSnapshot>? workspaceCompleter,
    Completer<List<AgentItem>>? agentsCompleter,
  }) {
    final repo = workspaceCompleter != null
        ? _DelayedHomeRepository(
            workspaceCompleter,
            initialSnapshot: workspaceSnapshot,
          )
        : _FakeHomeRepository(
            snapshot: workspaceSnapshot ?? snapshot,
            refreshFailure: refreshFailure,
          );

    return ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(serverId),
        homeRepositoryProvider.overrideWithValue(repo),
        sidebarOrderRepositoryProvider
            .overrideWithValue(const _FakeSidebarOrderRepository()),
        agentsRepositoryProvider.overrideWithValue(
          agentsCompleter != null
              ? _DelayedAgentsRepository(agentsCompleter)
              : const _FakeAgentsRepository(),
        ),
        tasksRepositoryProvider.overrideWithValue(const _FakeTasksRepository()),
        threadRepositoryProvider
            .overrideWithValue(const _FakeThreadRepository()),
        homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
      ],
    );
  }

  group('HomeListStore.refresh() — SWR regression', () {
    test('keeps existing channels and DMs visible during refresh', () async {
      final workspaceCompleter = Completer<HomeWorkspaceSnapshot>();
      final container = createContainer(
        workspaceCompleter: workspaceCompleter,
      );
      addTearDown(container.dispose);

      // First: load initial data.
      workspaceCompleter.complete(snapshot);
      await container.read(homeListStoreProvider.notifier).load();
      expect(container.read(homeListStoreProvider).channels, hasLength(1));
      expect(
        container.read(homeListStoreProvider).directMessages,
        hasLength(1),
      );

      // Now trigger refresh with a controllable repo.
      container.dispose();

      final repo = _ControllableHomeRepository();
      final container2 = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(serverId),
          homeRepositoryProvider.overrideWithValue(repo),
          sidebarOrderRepositoryProvider
              .overrideWithValue(const _FakeSidebarOrderRepository()),
          agentsRepositoryProvider
              .overrideWithValue(const _FakeAgentsRepository()),
          tasksRepositoryProvider
              .overrideWithValue(const _FakeTasksRepository()),
          threadRepositoryProvider
              .overrideWithValue(const _FakeThreadRepository()),
          homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
        ],
      );
      addTearDown(container2.dispose);

      // Load initial data synchronously.
      repo.nextWorkspace = snapshot;
      await container2.read(homeListStoreProvider.notifier).load();

      final preRefreshState = container2.read(homeListStoreProvider);
      expect(preRefreshState.status, HomeListStatus.success);
      expect(preRefreshState.channels, hasLength(1));

      // Start refresh but don't complete it yet.
      final refreshCompleter2 = Completer<HomeWorkspaceSnapshot>();
      repo.workspaceCompleter = refreshCompleter2;

      final refreshFuture =
          container2.read(homeListStoreProvider.notifier).refresh();

      // Mid-flight: data is still visible.
      final midState = container2.read(homeListStoreProvider);
      expect(midState.status, HomeListStatus.success);
      expect(midState.channels, hasLength(1),
          reason: 'Existing channels must stay visible during refresh');
      expect(midState.directMessages, hasLength(1),
          reason: 'Existing DMs must stay visible during refresh');
      expect(midState.isRefreshing, isTrue,
          reason: 'isRefreshing must be true during refresh');

      // Complete refresh.
      refreshCompleter2.complete(snapshot);
      await refreshFuture;

      final postState = container2.read(homeListStoreProvider);
      expect(postState.isRefreshing, isFalse);
      expect(postState.status, HomeListStatus.success);
    });

    test('sets isRefreshing=true during refresh, false after', () async {
      final repo = _ControllableHomeRepository();
      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(serverId),
          homeRepositoryProvider.overrideWithValue(repo),
          sidebarOrderRepositoryProvider
              .overrideWithValue(const _FakeSidebarOrderRepository()),
          agentsRepositoryProvider
              .overrideWithValue(const _FakeAgentsRepository()),
          tasksRepositoryProvider
              .overrideWithValue(const _FakeTasksRepository()),
          threadRepositoryProvider
              .overrideWithValue(const _FakeThreadRepository()),
          homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
        ],
      );
      addTearDown(container.dispose);

      // Load initial data.
      repo.nextWorkspace = snapshot;
      await container.read(homeListStoreProvider.notifier).load();
      expect(container.read(homeListStoreProvider).isRefreshing, isFalse);

      // Start refresh.
      final completer = Completer<HomeWorkspaceSnapshot>();
      repo.workspaceCompleter = completer;
      final future = container.read(homeListStoreProvider.notifier).refresh();

      expect(container.read(homeListStoreProvider).isRefreshing, isTrue,
          reason: 'isRefreshing must be true while refresh is in flight');

      completer.complete(snapshot);
      await future;

      expect(container.read(homeListStoreProvider).isRefreshing, isFalse,
          reason: 'isRefreshing must be false after refresh completes');
    });

    test('keeps data visible on refresh failure (SWR resilience)', () async {
      final repo = _ControllableHomeRepository();
      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(serverId),
          homeRepositoryProvider.overrideWithValue(repo),
          sidebarOrderRepositoryProvider
              .overrideWithValue(const _FakeSidebarOrderRepository()),
          agentsRepositoryProvider
              .overrideWithValue(const _FakeAgentsRepository()),
          tasksRepositoryProvider
              .overrideWithValue(const _FakeTasksRepository()),
          threadRepositoryProvider
              .overrideWithValue(const _FakeThreadRepository()),
          homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
        ],
      );
      addTearDown(container.dispose);

      // Load initial data.
      repo.nextWorkspace = snapshot;
      await container.read(homeListStoreProvider.notifier).load();
      expect(container.read(homeListStoreProvider).channels, hasLength(1));

      // Refresh with failure.
      final completer = Completer<HomeWorkspaceSnapshot>();
      repo.workspaceCompleter = completer;
      final future = container.read(homeListStoreProvider.notifier).refresh();

      completer.completeError(
        const ServerFailure(message: 'Server error', statusCode: 500),
      );
      await future;

      final state = container.read(homeListStoreProvider);
      expect(state.status, HomeListStatus.success,
          reason: 'Status must stay success after refresh failure');
      expect(state.channels, hasLength(1),
          reason: 'Channels must be preserved on refresh failure');
      expect(state.directMessages, hasLength(1),
          reason: 'DMs must be preserved on refresh failure');
      expect(state.isRefreshing, isFalse,
          reason: 'isRefreshing must clear on failure');
      // INV-NET-DEGRADE-1: failure must be surfaced, not silently dropped.
      expect(state.failure, isNotNull,
          reason: 'INV-NET-DEGRADE-1: failure must be set so UI can '
              'show error feedback');
      expect(state.failure, isA<ServerFailure>());
    });

    test('falls back to load() when no prior data exists', () async {
      final repo = _ControllableHomeRepository();
      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(serverId),
          homeRepositoryProvider.overrideWithValue(repo),
          sidebarOrderRepositoryProvider
              .overrideWithValue(const _FakeSidebarOrderRepository()),
          agentsRepositoryProvider
              .overrideWithValue(const _FakeAgentsRepository()),
          tasksRepositoryProvider
              .overrideWithValue(const _FakeTasksRepository()),
          threadRepositoryProvider
              .overrideWithValue(const _FakeThreadRepository()),
          homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
        ],
      );
      addTearDown(container.dispose);

      // Don't load first — call refresh directly on initial state.
      repo.nextWorkspace = snapshot;
      await container.read(homeListStoreProvider.notifier).refresh();

      final state = container.read(homeListStoreProvider);
      expect(state.status, HomeListStatus.success,
          reason: 'refresh() with no prior data should fall back to load()');
      expect(state.channels, hasLength(1));
    });

    test(
      'Tier 1/Tier 2: success emitted before supplemental completes',
      () async {
        final agentsCompleter = Completer<List<AgentItem>>();
        final repo = _ControllableHomeRepository();
        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider.overrideWithValue(serverId),
            homeRepositoryProvider.overrideWithValue(repo),
            sidebarOrderRepositoryProvider
                .overrideWithValue(const _FakeSidebarOrderRepository()),
            agentsRepositoryProvider
                .overrideWithValue(_DelayedAgentsRepository(agentsCompleter)),
            tasksRepositoryProvider
                .overrideWithValue(const _FakeTasksRepository()),
            threadRepositoryProvider
                .overrideWithValue(const _FakeThreadRepository()),
            homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
          ],
        );
        addTearDown(container.dispose);

        // Load with agents still pending.
        repo.nextWorkspace = snapshot;
        await container.read(homeListStoreProvider.notifier).load();

        // Success should be emitted even though agents haven't completed.
        final state = container.read(homeListStoreProvider);
        expect(state.status, HomeListStatus.success,
            reason: 'Tier 1 completion should emit success');
        expect(state.channels, hasLength(1));

        // Now complete agents.
        agentsCompleter.complete(const [
          AgentItem(
            id: 'agent-1',
            name: 'bot',
            displayName: 'Bot',
            model: 'test',
            runtime: 'test',
            status: 'active',
            activity: 'idle',
          ),
        ]);

        // Allow microtasks to flush.
        await Future.delayed(Duration.zero);

        final updatedState = container.read(homeListStoreProvider);
        expect(updatedState.agents, hasLength(1),
            reason: 'Agents should merge in after Tier 2 completes');
      },
    );

    test(
      'disposal guard: supplemental callbacks no-op after container disposal',
      () async {
        final agentsCompleter = Completer<List<AgentItem>>();
        final repo = _ControllableHomeRepository();
        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider.overrideWithValue(serverId),
            homeRepositoryProvider.overrideWithValue(repo),
            sidebarOrderRepositoryProvider
                .overrideWithValue(const _FakeSidebarOrderRepository()),
            agentsRepositoryProvider
                .overrideWithValue(_DelayedAgentsRepository(agentsCompleter)),
            tasksRepositoryProvider
                .overrideWithValue(const _FakeTasksRepository()),
            threadRepositoryProvider
                .overrideWithValue(const _FakeThreadRepository()),
            homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
          ],
        );

        // Load — workspace completes, but agents are still pending.
        repo.nextWorkspace = snapshot;
        await container.read(homeListStoreProvider.notifier).load();
        expect(container.read(homeListStoreProvider).status,
            HomeListStatus.success);

        // Dispose the container while agents are still pending.
        container.dispose();

        // Complete agents AFTER disposal — must not throw StateError.
        agentsCompleter.complete(const [
          AgentItem(
            id: 'agent-1',
            name: 'bot',
            displayName: 'Bot',
            model: 'test',
            runtime: 'test',
            status: 'active',
            activity: 'idle',
          ),
        ]);

        // Allow microtasks to flush — should not throw.
        await Future.delayed(Duration.zero);
      },
    );

    test(
      'RequestCoordinator dedup: concurrent same-reason refreshes share future',
      () async {
        final repo = _ControllableHomeRepository();
        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider.overrideWithValue(serverId),
            homeRepositoryProvider.overrideWithValue(repo),
            sidebarOrderRepositoryProvider
                .overrideWithValue(const _FakeSidebarOrderRepository()),
            agentsRepositoryProvider
                .overrideWithValue(const _FakeAgentsRepository()),
            tasksRepositoryProvider
                .overrideWithValue(const _FakeTasksRepository()),
            threadRepositoryProvider
                .overrideWithValue(const _FakeThreadRepository()),
            homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
          ],
        );
        addTearDown(container.dispose);

        // Load initial data.
        repo.nextWorkspace = snapshot;
        await container.read(homeListStoreProvider.notifier).load();

        // Start two concurrent refreshes with same reason.
        final completer = Completer<HomeWorkspaceSnapshot>();
        repo.workspaceCompleter = completer;
        repo.loadCount = 0;

        final notifier = container.read(homeListStoreProvider.notifier);
        final f1 = notifier.refresh(reason: 'reconnect');
        final f2 = notifier.refresh(reason: 'reconnect');

        completer.complete(snapshot);
        await Future.wait([f1, f2]);

        expect(repo.loadCount, 1,
            reason:
                'Same-reason concurrent refreshes must share a single request');
      },
    );

    test(
      'RequestCoordinator: different-reason refreshes run concurrently',
      () async {
        final repo = _ControllableHomeRepository();
        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider.overrideWithValue(serverId),
            homeRepositoryProvider.overrideWithValue(repo),
            sidebarOrderRepositoryProvider
                .overrideWithValue(const _FakeSidebarOrderRepository()),
            agentsRepositoryProvider
                .overrideWithValue(const _FakeAgentsRepository()),
            tasksRepositoryProvider
                .overrideWithValue(const _FakeTasksRepository()),
            threadRepositoryProvider
                .overrideWithValue(const _FakeThreadRepository()),
            homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
          ],
        );
        addTearDown(container.dispose);

        // Load initial data.
        repo.nextWorkspace = snapshot;
        await container.read(homeListStoreProvider.notifier).load();

        // Start two refreshes with different reasons.
        // Each will create its own completer inside the repo.
        repo.useAutoComplete = true;
        repo.loadCount = 0;

        final notifier = container.read(homeListStoreProvider.notifier);
        final f1 = notifier.refresh(reason: 'pullToRefresh');
        final f2 = notifier.refresh(reason: 'reconnect');

        await Future.wait([f1, f2]);

        expect(repo.loadCount, 2,
            reason: 'Different-reason refreshes must execute independently');
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Home repository with controllable workspace loading.
class _ControllableHomeRepository implements HomeRepository {
  HomeWorkspaceSnapshot? nextWorkspace;
  Completer<HomeWorkspaceSnapshot>? workspaceCompleter;
  int loadCount = 0;
  bool useAutoComplete = false;

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async =>
      null;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    loadCount++;
    if (workspaceCompleter != null) {
      final completer = workspaceCompleter!;
      // If useAutoComplete, create a fresh completer for the next call
      // but complete the current one immediately.
      if (useAutoComplete) {
        workspaceCompleter = Completer<HomeWorkspaceSnapshot>();
        return nextWorkspace!;
      }
      return completer.future;
    }
    return nextWorkspace!;
  }

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async =>
      summary;

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

class _DelayedHomeRepository implements HomeRepository {
  _DelayedHomeRepository(
    this.completer, {
    this.initialSnapshot,
  });

  final Completer<HomeWorkspaceSnapshot> completer;
  final HomeWorkspaceSnapshot? initialSnapshot;

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async =>
      null;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) {
    return completer.future;
  }

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async =>
      summary;

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

class _FakeHomeRepository implements HomeRepository {
  _FakeHomeRepository({this.snapshot, this.refreshFailure});

  final HomeWorkspaceSnapshot? snapshot;
  final AppFailure? refreshFailure;

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async =>
      null;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    if (refreshFailure != null) throw refreshFailure!;
    return snapshot!;
  }

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async =>
      summary;

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
  const _FakeSidebarOrderRepository();

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async =>
      const SidebarOrder();

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {}
}

class _FakeAgentsRepository implements AgentsRepository {
  const _FakeAgentsRepository();

  @override
  Future<List<AgentItem>> listAgents() async => const [];

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

class _DelayedAgentsRepository implements AgentsRepository {
  _DelayedAgentsRepository(this.completer);
  final Completer<List<AgentItem>> completer;

  @override
  Future<List<AgentItem>> listAgents() => completer.future;

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

class _FakeTasksRepository implements TasksRepository {
  const _FakeTasksRepository();

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async =>
      const [];

  @override
  Future<List<TaskItem>> createTasks(
    ServerScopeId serverId, {
    required String channelId,
    required List<String> titles,
  }) async =>
      const [];

  @override
  Future<TaskItem> updateTaskStatus(
    ServerScopeId serverId, {
    required String taskId,
    required String status,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async {}

  @override
  Future<TaskItem> claimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) =>
      throw UnimplementedError();

  @override
  Future<TaskItem> unclaimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) =>
      throw UnimplementedError();

  @override
  Future<TaskItem> convertMessageToTask(
    ServerScopeId serverId, {
    required String messageId,
  }) =>
      throw UnimplementedError();
}

class _FakeThreadRepository implements ThreadRepository {
  const _FakeThreadRepository();

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
    ServerScopeId serverId,
  ) async =>
      const [];

  @override
  Future<ResolvedThreadChannel> resolveThread(ThreadRouteTarget target) =>
      throw UnimplementedError();

  @override
  Future<void> followThread(ThreadRouteTarget target) async {}

  @override
  Future<void> markThreadDone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}

  @override
  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}
}
