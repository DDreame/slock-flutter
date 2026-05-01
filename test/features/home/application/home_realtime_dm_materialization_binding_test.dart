import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_realtime_dm_materialization_binding.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
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

import '../../../core/local_data/fake_conversation_local_store.dart';
import '../../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage;

class _FakeRealtimeSocketClient implements RealtimeSocketClient {
  final List<(String, Object?)> emitted = [];

  @override
  Stream<RealtimeSocketSignal> get signals => const Stream.empty();

  @override
  bool get isConnected => true;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  void emit(String eventName, Object? payload) {
    emitted.add((eventName, payload));
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  const serverId = ServerScopeId('server-1');

  ProviderContainer createContainer({
    required _FakeRealtimeSocketClient fakeSocket,
    List<HomeDirectMessageSummary> existingDms = const [],
  }) {
    final ingress = RealtimeReductionIngress();
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(FakeSecureStorage()),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
        realtimeSocketClientProvider.overrideWithValue(fakeSocket),
        activeServerScopeIdProvider.overrideWithValue(serverId),
        conversationLocalStoreProvider.overrideWithValue(
          FakeConversationLocalStore(),
        ),
        sidebarOrderRepositoryProvider
            .overrideWithValue(const _FakeSidebarOrderRepository()),
        agentsRepositoryProvider
            .overrideWithValue(const _FakeAgentsRepository()),
        homeWorkspaceSnapshotLoaderProvider.overrideWithValue(
          (scopeId) async => HomeWorkspaceSnapshot(
            serverId: scopeId,
            channels: const [],
            directMessages: existingDms,
          ),
        ),
        tasksRepositoryProvider.overrideWithValue(const _FakeTasksRepository()),
        threadRepositoryProvider
            .overrideWithValue(const _FakeThreadRepository()),
        homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await ingress.dispose();
    });
    return container;
  }

  test('dm:new materializes new DM in home list', () async {
    final fakeSocket = _FakeRealtimeSocketClient();
    final container = createContainer(fakeSocket: fakeSocket);

    container.read(homeRealtimeDmMaterializationBindingProvider);
    await container.read(homeListStoreProvider.notifier).load();

    container.read(realtimeReductionIngressProvider).accept(
          RealtimeEventEnvelope(
            eventType: realtimeDmNewEventType,
            scopeKey: RealtimeEventEnvelope.globalScopeKey,
            receivedAt: DateTime(2026, 4, 20),
            seq: 1,
            payload: const {
              'channelId': 'dm-new-conversation',
              'participant': {'displayName': 'Bob'},
            },
          ),
        );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(homeListStoreProvider);
    expect(state.directMessages.length, 1);
    expect(state.directMessages.first.scopeId.value, 'dm-new-conversation');
    expect(state.directMessages.first.title, 'Bob');
  });

  test('dm:new emits join:channel back to server', () async {
    final fakeSocket = _FakeRealtimeSocketClient();
    final container = createContainer(fakeSocket: fakeSocket);

    container.read(homeRealtimeDmMaterializationBindingProvider);
    await container.read(homeListStoreProvider.notifier).load();

    container.read(realtimeReductionIngressProvider).accept(
          RealtimeEventEnvelope(
            eventType: realtimeDmNewEventType,
            scopeKey: RealtimeEventEnvelope.globalScopeKey,
            receivedAt: DateTime(2026, 4, 20),
            seq: 1,
            payload: const {'channelId': 'dm-new-conversation'},
          ),
        );
    await Future<void>.delayed(Duration.zero);

    expect(fakeSocket.emitted, hasLength(1));
    expect(fakeSocket.emitted.first.$1, 'join:channel');
    expect(fakeSocket.emitted.first.$2, 'dm-new-conversation');
  });

  test(
      'dm:new before explicit load emits join:channel and materializes via buffer replay',
      () async {
    final fakeSocket = _FakeRealtimeSocketClient();
    final container = createContainer(fakeSocket: fakeSocket);

    container.read(homeRealtimeDmMaterializationBindingProvider);

    container.read(realtimeReductionIngressProvider).accept(
          RealtimeEventEnvelope(
            eventType: realtimeDmNewEventType,
            scopeKey: RealtimeEventEnvelope.globalScopeKey,
            receivedAt: DateTime(2026, 4, 20),
            seq: 1,
            payload: const {
              'channelId': 'dm-early',
              'displayName': 'Early Bob'
            },
          ),
        );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(fakeSocket.emitted, hasLength(1));
    expect(fakeSocket.emitted.first.$1, 'join:channel');
    expect(fakeSocket.emitted.first.$2, 'dm-early');

    final state = container.read(homeListStoreProvider);
    expect(
      state.directMessages.any((dm) => dm.scopeId.value == 'dm-early'),
      isTrue,
      reason:
          'Buffered DM should be materialized after auto-load reaches success',
    );
    expect(
      state.directMessages
          .firstWhere((dm) => dm.scopeId.value == 'dm-early')
          .title,
      'Early Bob',
      reason: 'Buffered replay should preserve the original payload title',
    );
  });

  test(
      'dm:new buffered while load is in-flight materializes after load completes',
      () async {
    final fakeSocket = _FakeRealtimeSocketClient();
    final loadCompleter = Completer<HomeWorkspaceSnapshot>();
    final ingress = RealtimeReductionIngress();
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(FakeSecureStorage()),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
        realtimeSocketClientProvider.overrideWithValue(fakeSocket),
        activeServerScopeIdProvider.overrideWithValue(serverId),
        conversationLocalStoreProvider.overrideWithValue(
          FakeConversationLocalStore(),
        ),
        sidebarOrderRepositoryProvider
            .overrideWithValue(const _FakeSidebarOrderRepository()),
        agentsRepositoryProvider
            .overrideWithValue(const _FakeAgentsRepository()),
        homeWorkspaceSnapshotLoaderProvider.overrideWithValue(
          (scopeId) => loadCompleter.future,
        ),
        tasksRepositoryProvider.overrideWithValue(const _FakeTasksRepository()),
        threadRepositoryProvider
            .overrideWithValue(const _FakeThreadRepository()),
        homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await ingress.dispose();
    });

    container.read(homeRealtimeDmMaterializationBindingProvider);
    await Future<void>.delayed(Duration.zero);

    container.read(realtimeReductionIngressProvider).accept(
          RealtimeEventEnvelope(
            eventType: realtimeDmNewEventType,
            scopeKey: RealtimeEventEnvelope.globalScopeKey,
            receivedAt: DateTime(2026, 4, 20),
            seq: 1,
            payload: const {
              'channelId': 'dm-buffered',
              'participant': {'displayName': 'Buffered Bob'},
            },
          ),
        );
    await Future<void>.delayed(Duration.zero);

    expect(
      container
          .read(homeListStoreProvider)
          .directMessages
          .any((dm) => dm.scopeId.value == 'dm-buffered'),
      isFalse,
      reason: 'DM should not be materialized while load is still in-flight',
    );

    loadCompleter.complete(
      const HomeWorkspaceSnapshot(
        serverId: serverId,
        channels: [],
        directMessages: [],
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(homeListStoreProvider);
    expect(
      state.directMessages.any((dm) => dm.scopeId.value == 'dm-buffered'),
      isTrue,
      reason: 'Buffered dm:new should be materialized after load completes',
    );
    expect(
      state.directMessages
          .firstWhere((dm) => dm.scopeId.value == 'dm-buffered')
          .title,
      'Buffered Bob',
      reason: 'Buffered replay should preserve the original participant title',
    );
  });

  test('dm:new for already-known DM is deduped', () async {
    final fakeSocket = _FakeRealtimeSocketClient();
    final container = createContainer(
      fakeSocket: fakeSocket,
      existingDms: const [
        HomeDirectMessageSummary(
          scopeId: DirectMessageScopeId(
            serverId: serverId,
            value: 'dm-existing',
          ),
          title: 'Existing DM',
        ),
      ],
    );

    container.read(homeRealtimeDmMaterializationBindingProvider);
    await container.read(homeListStoreProvider.notifier).load();

    container.read(realtimeReductionIngressProvider).accept(
          RealtimeEventEnvelope(
            eventType: realtimeDmNewEventType,
            scopeKey: RealtimeEventEnvelope.globalScopeKey,
            receivedAt: DateTime(2026, 4, 20),
            seq: 1,
            payload: const {
              'channelId': 'dm-existing',
              'displayName': 'Existing'
            },
          ),
        );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(homeListStoreProvider);
    expect(state.directMessages.length, 1);
    expect(state.directMessages.first.title, 'Existing DM');
    expect(fakeSocket.emitted, hasLength(1));
  });
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

class _FakeTasksRepository implements TasksRepository {
  const _FakeTasksRepository();

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async =>
      const [];

  @override
  Future<List<TaskItem>> createTasks(ServerScopeId serverId,
          {required String channelId, required List<String> titles}) async =>
      const [];

  @override
  Future<TaskItem> updateTaskStatus(ServerScopeId serverId,
          {required String taskId, required String status}) =>
      throw UnimplementedError();

  @override
  Future<void> deleteTask(ServerScopeId serverId,
      {required String taskId}) async {}

  @override
  Future<TaskItem> claimTask(ServerScopeId serverId,
          {required String taskId}) =>
      throw UnimplementedError();

  @override
  Future<TaskItem> unclaimTask(ServerScopeId serverId,
          {required String taskId}) =>
      throw UnimplementedError();

  @override
  Future<TaskItem> convertMessageToTask(ServerScopeId serverId,
          {required String messageId}) =>
      throw UnimplementedError();
}

class _FakeThreadRepository implements ThreadRepository {
  const _FakeThreadRepository();

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
          ServerScopeId serverId) async =>
      const [];

  @override
  Future<ResolvedThreadChannel> resolveThread(ThreadRouteTarget target) =>
      throw UnimplementedError();

  @override
  Future<void> followThread(ThreadRouteTarget target) async {}

  @override
  Future<void> markThreadDone(ServerScopeId serverId,
      {required String threadChannelId}) async {}

  @override
  Future<void> markThreadRead(ServerScopeId serverId,
      {required String threadChannelId}) async {}
}
