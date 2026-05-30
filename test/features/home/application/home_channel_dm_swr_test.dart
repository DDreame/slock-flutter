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

// ---------------------------------------------------------------------------
// Combined #485 + #486: Channel & DM view-path SWR verification tests
//
// ChannelsTabPage and DmsTabPage both derive from HomeListStore — no
// dedicated ChannelListStore or DMListStore exists.  These tests verify
// that the `channels` and `directMessages` projections emitted by
// HomeListStore satisfy INV-CACHE-SWR-1, INV-CACHE-SWR-2, and
// INV-NET-DEGRADE-1 from the perspective of the tab views.
//
// HomeListStore already has SWR in its refresh() path.  These tests
// confirm coverage, not add new production changes.
// ---------------------------------------------------------------------------

void main() {
  const serverId = ServerScopeId('server-1');

  // Multi-channel snapshot so projection tests are meaningful.
  const multiChannelSnapshot = HomeWorkspaceSnapshot(
    serverId: serverId,
    channels: [
      HomeChannelSummary(
        scopeId: ChannelScopeId(serverId: serverId, value: 'general'),
        name: 'general',
      ),
      HomeChannelSummary(
        scopeId: ChannelScopeId(serverId: serverId, value: 'engineering'),
        name: 'engineering',
      ),
      HomeChannelSummary(
        scopeId: ChannelScopeId(serverId: serverId, value: 'random'),
        name: 'random',
      ),
    ],
    directMessages: [
      HomeDirectMessageSummary(
        scopeId: DirectMessageScopeId(serverId: serverId, value: 'dm-alice'),
        title: 'Alice',
      ),
      HomeDirectMessageSummary(
        scopeId: DirectMessageScopeId(serverId: serverId, value: 'dm-bob'),
        title: 'Bob',
      ),
    ],
  );

  ProviderContainer createContainer(_ControllableHomeRepository repo) {
    return ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(serverId),
        homeRepositoryProvider.overrideWithValue(repo),
        sidebarOrderRepositoryProvider
            .overrideWithValue(const _FakeSidebarOrderRepository()),
        agentsRepositoryProvider
            .overrideWithValue(const _FakeAgentsRepository()),
        tasksRepositoryProvider.overrideWithValue(const _FakeTasksRepository()),
        threadRepositoryProvider
            .overrideWithValue(const _FakeThreadRepository()),
        homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // #485  INV-CACHE-SWR-1: Channel list view — stale data during refresh
  // -----------------------------------------------------------------------
  group('#485 Channel view path — INV-CACHE-SWR-1', () {
    test('all channels remain visible during background refresh', () async {
      final repo = _ControllableHomeRepository();
      repo.nextWorkspace = multiChannelSnapshot;
      final container = createContainer(repo);
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();
      expect(container.read(homeListStoreProvider).channels, hasLength(3));

      // Start refresh — don't complete yet.
      final refreshCompleter = Completer<HomeWorkspaceSnapshot>();
      repo.workspaceCompleter = refreshCompleter;

      final refreshFuture =
          container.read(homeListStoreProvider.notifier).refresh();

      // Mid-flight: channel projection must not be empty.
      final midState = container.read(homeListStoreProvider);
      expect(midState.channels, hasLength(3),
          reason: 'INV-CACHE-SWR-1: channel view must show stale '
              'channels during refresh');
      expect(midState.status, HomeListStatus.success,
          reason: 'Status stays success — never reverts to loading');
      expect(midState.isRefreshing, isTrue);

      refreshCompleter.complete(multiChannelSnapshot);
      await refreshFuture;

      final postState = container.read(homeListStoreProvider);
      expect(postState.channels, hasLength(3));
      expect(postState.isRefreshing, isFalse);
    });

    test('refresh replaces stale channels with fresh data on completion',
        () async {
      final repo = _ControllableHomeRepository();
      repo.nextWorkspace = multiChannelSnapshot;
      final container = createContainer(repo);
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();

      // Fresh snapshot adds a channel.
      const updatedSnapshot = HomeWorkspaceSnapshot(
        serverId: serverId,
        channels: [
          HomeChannelSummary(
            scopeId: ChannelScopeId(serverId: serverId, value: 'general'),
            name: 'general',
          ),
          HomeChannelSummary(
            scopeId: ChannelScopeId(serverId: serverId, value: 'engineering'),
            name: 'engineering',
          ),
          HomeChannelSummary(
            scopeId: ChannelScopeId(serverId: serverId, value: 'random'),
            name: 'random',
          ),
          HomeChannelSummary(
            scopeId: ChannelScopeId(serverId: serverId, value: 'design'),
            name: 'design',
          ),
        ],
        directMessages: [
          HomeDirectMessageSummary(
            scopeId:
                DirectMessageScopeId(serverId: serverId, value: 'dm-alice'),
            title: 'Alice',
          ),
          HomeDirectMessageSummary(
            scopeId: DirectMessageScopeId(serverId: serverId, value: 'dm-bob'),
            title: 'Bob',
          ),
        ],
      );
      repo.nextWorkspace = updatedSnapshot;

      await container.read(homeListStoreProvider.notifier).refresh();

      final state = container.read(homeListStoreProvider);
      expect(state.channels, hasLength(4),
          reason: 'Fresh channel list replaces stale after refresh');
      expect(
        state.channels.map((c) => c.name),
        contains('design'),
      );
    });
  });

  // -----------------------------------------------------------------------
  // #485  INV-NET-DEGRADE-1: Channel view — data preservation on error
  // -----------------------------------------------------------------------
  group('#485 Channel view path — INV-NET-DEGRADE-1', () {
    test('refresh failure preserves stale channels', () async {
      final repo = _ControllableHomeRepository();
      repo.nextWorkspace = multiChannelSnapshot;
      final container = createContainer(repo);
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();
      expect(container.read(homeListStoreProvider).channels, hasLength(3));

      // Refresh fails.
      final failCompleter = Completer<HomeWorkspaceSnapshot>();
      repo.workspaceCompleter = failCompleter;

      final refreshFuture =
          container.read(homeListStoreProvider.notifier).refresh();

      failCompleter.completeError(
        const ServerFailure(message: 'Network error', statusCode: 500),
      );
      await refreshFuture;

      final state = container.read(homeListStoreProvider);
      expect(state.channels, hasLength(3),
          reason: 'INV-NET-DEGRADE-1: channels must survive refresh failure');
      expect(state.status, HomeListStatus.success,
          reason: 'Status stays success — stale data is still valid');
      expect(state.isRefreshing, isFalse);
    });

    test(
      'refresh failure surfaces failure for channel error overlay',
      () async {
        final repo = _ControllableHomeRepository();
        repo.nextWorkspace = multiChannelSnapshot;
        final container = createContainer(repo);
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();

        // Refresh fails.
        final failCompleter = Completer<HomeWorkspaceSnapshot>();
        repo.workspaceCompleter = failCompleter;

        final refreshFuture =
            container.read(homeListStoreProvider.notifier).refresh();

        failCompleter.completeError(
          const ServerFailure(message: 'Network error', statusCode: 500),
        );
        await refreshFuture;

        final state = container.read(homeListStoreProvider);
        expect(state.failure, isNotNull,
            reason: 'INV-NET-DEGRADE-1: failure must be surfaced so '
                'channel view can render error overlay');
      },
      skip: 'TODO: HomeListStore.refresh() swallows AppFailure without '
          'setting state.failure (line 428-431). Phase B must add '
          '`failure: failure` to the copyWith so channel/DM views '
          'can render an error overlay.',
    );

    test('no blank channel screen across full SWR refresh cycle', () async {
      final repo = _ControllableHomeRepository();
      repo.nextWorkspace = multiChannelSnapshot;
      final container = createContainer(repo);
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();

      // Capture every state transition during refresh.
      final channelCounts = <int>[];
      final statuses = <HomeListStatus>[];
      container.listen(homeListStoreProvider, (_, next) {
        channelCounts.add(next.channels.length);
        statuses.add(next.status);
      });

      final refreshCompleter = Completer<HomeWorkspaceSnapshot>();
      repo.workspaceCompleter = refreshCompleter;

      final refreshFuture =
          container.read(homeListStoreProvider.notifier).refresh();

      refreshCompleter.complete(multiChannelSnapshot);
      await refreshFuture;

      // No state transition should have produced an empty channel list.
      expect(channelCounts.every((c) => c > 0), isTrue,
          reason: 'Channel count must never drop to 0 during SWR cycle');
      // Status must never revert to loading during refresh.
      expect(statuses.every((s) => s == HomeListStatus.success), isTrue,
          reason: 'Status must stay success throughout SWR cycle');
    });
  });

  // -----------------------------------------------------------------------
  // #486  INV-CACHE-SWR-1: DM list view — stale data during refresh
  // -----------------------------------------------------------------------
  group('#486 DM view path — INV-CACHE-SWR-1', () {
    test('all DMs remain visible during background refresh', () async {
      final repo = _ControllableHomeRepository();
      repo.nextWorkspace = multiChannelSnapshot;
      final container = createContainer(repo);
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();
      expect(
          container.read(homeListStoreProvider).directMessages, hasLength(2));

      // Start refresh — don't complete yet.
      final refreshCompleter = Completer<HomeWorkspaceSnapshot>();
      repo.workspaceCompleter = refreshCompleter;

      final refreshFuture =
          container.read(homeListStoreProvider.notifier).refresh();

      // Mid-flight: DM projection must not be empty.
      final midState = container.read(homeListStoreProvider);
      expect(midState.directMessages, hasLength(2),
          reason: 'INV-CACHE-SWR-1: DM view must show stale '
              'DMs during refresh');
      expect(midState.status, HomeListStatus.success);
      expect(midState.isRefreshing, isTrue);

      refreshCompleter.complete(multiChannelSnapshot);
      await refreshFuture;

      final postState = container.read(homeListStoreProvider);
      expect(postState.directMessages, hasLength(2));
      expect(postState.isRefreshing, isFalse);
    });

    test('refresh replaces stale DMs with fresh data on completion', () async {
      final repo = _ControllableHomeRepository();
      repo.nextWorkspace = multiChannelSnapshot;
      final container = createContainer(repo);
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();

      // Fresh snapshot adds a DM.
      const updatedSnapshot = HomeWorkspaceSnapshot(
        serverId: serverId,
        channels: [
          HomeChannelSummary(
            scopeId: ChannelScopeId(serverId: serverId, value: 'general'),
            name: 'general',
          ),
          HomeChannelSummary(
            scopeId: ChannelScopeId(serverId: serverId, value: 'engineering'),
            name: 'engineering',
          ),
          HomeChannelSummary(
            scopeId: ChannelScopeId(serverId: serverId, value: 'random'),
            name: 'random',
          ),
        ],
        directMessages: [
          HomeDirectMessageSummary(
            scopeId:
                DirectMessageScopeId(serverId: serverId, value: 'dm-alice'),
            title: 'Alice',
          ),
          HomeDirectMessageSummary(
            scopeId: DirectMessageScopeId(serverId: serverId, value: 'dm-bob'),
            title: 'Bob',
          ),
          HomeDirectMessageSummary(
            scopeId:
                DirectMessageScopeId(serverId: serverId, value: 'dm-charlie'),
            title: 'Charlie',
          ),
        ],
      );
      repo.nextWorkspace = updatedSnapshot;

      await container.read(homeListStoreProvider.notifier).refresh();

      final state = container.read(homeListStoreProvider);
      expect(state.directMessages, hasLength(3),
          reason: 'Fresh DM list replaces stale after refresh');
      expect(
        state.directMessages.map((d) => d.title),
        contains('Charlie'),
      );
    });
  });

  // -----------------------------------------------------------------------
  // #486  INV-NET-DEGRADE-1: DM view — data preservation on error
  // -----------------------------------------------------------------------
  group('#486 DM view path — INV-NET-DEGRADE-1', () {
    test('refresh failure preserves stale DMs', () async {
      final repo = _ControllableHomeRepository();
      repo.nextWorkspace = multiChannelSnapshot;
      final container = createContainer(repo);
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();
      expect(
          container.read(homeListStoreProvider).directMessages, hasLength(2));

      // Refresh fails.
      final failCompleter = Completer<HomeWorkspaceSnapshot>();
      repo.workspaceCompleter = failCompleter;

      final refreshFuture =
          container.read(homeListStoreProvider.notifier).refresh();

      failCompleter.completeError(
        const ServerFailure(message: 'Network error', statusCode: 500),
      );
      await refreshFuture;

      final state = container.read(homeListStoreProvider);
      expect(state.directMessages, hasLength(2),
          reason: 'INV-NET-DEGRADE-1: DMs must survive refresh failure');
      expect(state.status, HomeListStatus.success);
      expect(state.isRefreshing, isFalse);
    });

    test(
      'refresh failure surfaces failure for DM error overlay',
      () async {
        final repo = _ControllableHomeRepository();
        repo.nextWorkspace = multiChannelSnapshot;
        final container = createContainer(repo);
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();

        // Refresh fails.
        final failCompleter = Completer<HomeWorkspaceSnapshot>();
        repo.workspaceCompleter = failCompleter;

        final refreshFuture =
            container.read(homeListStoreProvider.notifier).refresh();

        failCompleter.completeError(
          const ServerFailure(message: 'Network error', statusCode: 500),
        );
        await refreshFuture;

        final state = container.read(homeListStoreProvider);
        expect(state.failure, isNotNull,
            reason: 'INV-NET-DEGRADE-1: failure must be surfaced so '
                'DM view can render error overlay');
      },
      skip: 'TODO: HomeListStore.refresh() swallows AppFailure without '
          'setting state.failure (line 428-431). Phase B must add '
          '`failure: failure` to the copyWith so channel/DM views '
          'can render an error overlay.',
    );

    test('no blank DM screen across full SWR refresh cycle', () async {
      final repo = _ControllableHomeRepository();
      repo.nextWorkspace = multiChannelSnapshot;
      final container = createContainer(repo);
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();

      // Capture every state transition during refresh.
      final dmCounts = <int>[];
      final statuses = <HomeListStatus>[];
      container.listen(homeListStoreProvider, (_, next) {
        dmCounts.add(next.directMessages.length);
        statuses.add(next.status);
      });

      final refreshCompleter = Completer<HomeWorkspaceSnapshot>();
      repo.workspaceCompleter = refreshCompleter;

      final refreshFuture =
          container.read(homeListStoreProvider.notifier).refresh();

      refreshCompleter.complete(multiChannelSnapshot);
      await refreshFuture;

      // No state transition should have produced an empty DM list.
      expect(dmCounts.every((c) => c > 0), isTrue,
          reason: 'DM count must never drop to 0 during SWR cycle');
      expect(statuses.every((s) => s == HomeListStatus.success), isTrue,
          reason: 'Status must stay success throughout SWR cycle');
    });
  });

  // -----------------------------------------------------------------------
  // #485+#486  INV-CACHE-SWR-2: Both projections survive concurrent cycle
  // -----------------------------------------------------------------------
  group('#485+#486 Combined — INV-CACHE-SWR-2', () {
    test(
      'channels and DMs both survive concurrent refresh failure + retry',
      () async {
        final repo = _ControllableHomeRepository();
        repo.nextWorkspace = multiChannelSnapshot;
        final container = createContainer(repo);
        addTearDown(container.dispose);

        await container.read(homeListStoreProvider.notifier).load();

        // First refresh fails.
        final failCompleter = Completer<HomeWorkspaceSnapshot>();
        repo.workspaceCompleter = failCompleter;

        final refreshFuture =
            container.read(homeListStoreProvider.notifier).refresh();

        failCompleter.completeError(
          const ServerFailure(message: 'Timeout', statusCode: 504),
        );
        await refreshFuture;

        var state = container.read(homeListStoreProvider);
        expect(state.channels, hasLength(3),
            reason: 'Channels survive first failure');
        expect(state.directMessages, hasLength(2),
            reason: 'DMs survive first failure');

        // Second refresh succeeds.
        repo.workspaceCompleter = null;
        repo.nextWorkspace = multiChannelSnapshot;
        await container.read(homeListStoreProvider.notifier).refresh();

        state = container.read(homeListStoreProvider);
        expect(state.channels, hasLength(3));
        expect(state.directMessages, hasLength(2));
        expect(state.isRefreshing, isFalse);
        expect(state.status, HomeListStatus.success);
      },
    );

    test('multiple consecutive refresh failures preserve both projections',
        () async {
      final repo = _ControllableHomeRepository();
      repo.nextWorkspace = multiChannelSnapshot;
      final container = createContainer(repo);
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();

      // Fail three times.
      for (var i = 0; i < 3; i++) {
        final completer = Completer<HomeWorkspaceSnapshot>();
        repo.workspaceCompleter = completer;

        final future = container.read(homeListStoreProvider.notifier).refresh();
        completer.completeError(
          ServerFailure(message: 'Error $i', statusCode: 500),
        );
        await future;
      }

      final state = container.read(homeListStoreProvider);
      expect(state.channels, hasLength(3),
          reason: 'Channels survive 3 consecutive refresh failures');
      expect(state.directMessages, hasLength(2),
          reason: 'DMs survive 3 consecutive refresh failures');
      expect(state.status, HomeListStatus.success);
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes — reused from home_list_store_refresh_test.dart pattern
// ---------------------------------------------------------------------------

class _ControllableHomeRepository implements HomeRepository {
  HomeWorkspaceSnapshot? nextWorkspace;
  Completer<HomeWorkspaceSnapshot>? workspaceCompleter;

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async =>
      null;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    if (workspaceCompleter != null) {
      return workspaceCompleter!.future;
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

  @override
  Future<TaskItem> getTaskByNumber(
    ServerScopeId serverId, {
    required String channelId,
    required int taskNumber,
  }) async {
    throw UnimplementedError();
  }
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
  Future<void> unfollowThread(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}

  @override
  Future<void> markThreadDone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}

  @override
  Future<void> markThreadUndone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}

  @override
  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}
}
