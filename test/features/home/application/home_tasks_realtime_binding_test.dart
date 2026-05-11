import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_tasks_realtime_binding.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';

import '../../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage;

void main() {
  const serverId = ServerScopeId('server-1');

  late RealtimeReductionIngress ingress;
  late _FakeHomeWorkspaceLoader homeLoader;
  late ProviderContainer container;
  late ProviderSubscription<void> bindingSub;
  late ProviderSubscription<Object?> homeSub;

  setUp(() async {
    ingress = RealtimeReductionIngress();
    homeLoader = _FakeHomeWorkspaceLoader();
    container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(FakeSecureStorage()),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
        homeWorkspaceSnapshotLoaderProvider.overrideWithValue(homeLoader.call),
        serverListLoaderProvider
            .overrideWithValue(() async => const <ServerSummary>[]),
        sidebarOrderRepositoryProvider.overrideWithValue(
          const _FakeSidebarOrderRepository(),
        ),
        tasksRepositoryProvider.overrideWithValue(
          const _FakeTasksRepository(),
        ),
        agentsRepositoryProvider.overrideWithValue(
          const _FakeAgentsRepository(),
        ),
        homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
        threadRepositoryProvider.overrideWithValue(
          const _FakeThreadRepository(),
        ),
      ],
    );

    await container
        .read(serverSelectionStoreProvider.notifier)
        .selectServer(serverId.value);
    homeSub = container.listen(homeListStoreProvider, (_, __) {});
    bindingSub = container.listen(homeTasksRealtimeBindingProvider, (_, __) {});

    // Wait for HomeListStore.build() auto-load to settle, then
    // clear the baseline so each test only sees its own calls.
    await _waitForHomeSuccess(container);
    homeLoader.calls.clear();
  });

  tearDown(() async {
    bindingSub.close();
    homeSub.close();
    container.dispose();
    await ingress.dispose();
  });

  group('homeTasksRealtimeBindingProvider', () {
    test('task:created triggers home refresh', () async {
      homeLoader.snapshots = [
        const HomeWorkspaceSnapshot(
          serverId: serverId,
          channels: [],
          directMessages: [],
        ),
      ];

      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'task:created',
          scopeKey: 'server:server-1',
          receivedAt: DateTime.now(),
          payload: const {'id': 'task-1', 'title': 'New task'},
        ),
      );
      await _waitForHomeReload(homeLoader, container, expectedCalls: 1);

      expect(homeLoader.calls, [serverId]);
    });

    test('task:updated triggers home refresh', () async {
      homeLoader.snapshots = [
        const HomeWorkspaceSnapshot(
          serverId: serverId,
          channels: [],
          directMessages: [],
        ),
      ];

      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'task:updated',
          scopeKey: 'server:server-1',
          receivedAt: DateTime.now(),
          payload: const {'id': 'task-1', 'status': 'done'},
        ),
      );
      await _waitForHomeReload(homeLoader, container, expectedCalls: 1);

      expect(homeLoader.calls, [serverId]);
    });

    test('task:deleted triggers home refresh', () async {
      homeLoader.snapshots = [
        const HomeWorkspaceSnapshot(
          serverId: serverId,
          channels: [],
          directMessages: [],
        ),
      ];

      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'task:deleted',
          scopeKey: 'server:server-1',
          receivedAt: DateTime.now(),
          payload: const {'id': 'task-1'},
        ),
      );
      await _waitForHomeReload(homeLoader, container, expectedCalls: 1);

      expect(homeLoader.calls, [serverId]);
    });

    test('unrelated event types are ignored', () async {
      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'message:new',
          scopeKey: 'server:server-1',
          receivedAt: DateTime.now(),
          payload: const {'id': 'msg-1'},
        ),
      );
      await _drainAsyncWork();

      // No call beyond the auto-load baseline (which was already cleared)
      expect(homeLoader.calls, isEmpty);
    });

    test('skips refresh when home list is still loading', () async {
      homeLoader.snapshots = [
        const HomeWorkspaceSnapshot(
          serverId: serverId,
          channels: [],
          directMessages: [],
        ),
      ];

      // Start a manual reload (don't await) to put home in loading state
      final loadFuture = container.read(homeListStoreProvider.notifier).load();
      final stateBeforeEvent = container.read(homeListStoreProvider);

      // Only send event if we're still loading; otherwise the test
      // proves nothing — just verify the guard exists.
      if (stateBeforeEvent.status == HomeListStatus.loading) {
        ingress.accept(
          RealtimeEventEnvelope(
            eventType: 'task:created',
            scopeKey: 'server:server-1',
            receivedAt: DateTime.now(),
            payload: const {'id': 'task-1'},
          ),
        );
      }

      await loadFuture;
      await _drainAsyncWork();

      // Only the manual load should exist — event should not enqueue
      // another refresh while HomeListStatus.loading.
      expect(homeLoader.calls, [serverId]);
    });
  });
}

/// Waits for [homeListStoreProvider] to reach [HomeListStatus.success].
Future<void> _waitForHomeSuccess(ProviderContainer container) async {
  final completer = Completer<void>();
  final subscription = container.listen<HomeListState>(
    homeListStoreProvider,
    (_, next) {
      if (!completer.isCompleted && next.status == HomeListStatus.success) {
        completer.complete();
      }
    },
    fireImmediately: true,
  );

  try {
    await completer.future.timeout(const Duration(seconds: 2));
  } finally {
    subscription.close();
  }
}

Future<void> _drainAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

Future<void> _waitForHomeReload(
  _FakeHomeWorkspaceLoader homeLoader,
  ProviderContainer container, {
  required int expectedCalls,
}) async {
  final completer = Completer<void>();
  late final ProviderSubscription<HomeListState> subscription;
  subscription = container.listen<HomeListState>(
    homeListStoreProvider,
    (_, next) {
      if (!completer.isCompleted &&
          homeLoader.calls.length >= expectedCalls &&
          next.status == HomeListStatus.success) {
        completer.complete();
      }
    },
    fireImmediately: true,
  );

  try {
    await completer.future.timeout(const Duration(seconds: 1));
  } finally {
    subscription.close();
  }
}

class _FakeHomeWorkspaceLoader {
  List<HomeWorkspaceSnapshot> snapshots = const [];
  final List<ServerScopeId> calls = [];

  Future<HomeWorkspaceSnapshot> call(ServerScopeId serverId) async {
    calls.add(serverId);
    if (snapshots.isEmpty) {
      return HomeWorkspaceSnapshot(
        serverId: serverId,
        channels: const [],
        directMessages: const [],
      );
    }
    if (calls.length <= snapshots.length) {
      return snapshots[calls.length - 1];
    }
    return snapshots.last;
  }
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
  }) async =>
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
  }) async =>
      throw UnimplementedError();

  @override
  Future<TaskItem> unclaimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<TaskItem> convertMessageToTask(
    ServerScopeId serverId, {
    required String messageId,
  }) async =>
      throw UnimplementedError();
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

class _FakeThreadRepository implements ThreadRepository {
  const _FakeThreadRepository();

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
    ServerScopeId serverId,
  ) async =>
      const [];

  @override
  Future<ResolvedThreadChannel> resolveThread(
    ThreadRouteTarget target,
  ) async =>
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
