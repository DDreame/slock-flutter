// =============================================================================
// #834 — WebSocket Reconnect Gaps: 7 Stores Missing Re-fetch on Reconnect
//
// Invariant: INV-834
//   When WebSocket transitions from reconnecting → connected, stores that
//   already hold stale data (status == success) must re-fetch. Stores still
//   in initial/loading state must NOT trigger a redundant load.
//
// Strategy per store:
// T1: reconnecting → connected while status == success → triggers load()
// T2: reconnecting → connected while status == initial → no load()
// T3: connected → connected (no-op transition) → no load()
//
// Stores under test:
// 1. AgentsStore (global Notifier)
// 2. TasksStore (AutoDispose)
// 3. ThreadsInboxStore (AutoDispose)
// 4. ThreadRepliesStore (AutoDispose)
// 5. SavedMessagesStore (AutoDispose)
// 6. MemberListStore (AutoDispose)
// 7. ChannelMemberStore (AutoDispose)
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/channels/application/channel_member_state.dart';
import 'package:slock_app/features/channels/application/channel_member_store.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/data/channel_member_repository.dart';
import 'package:slock_app/features/channels/data/channel_member_repository_provider.dart';
import 'package:slock_app/features/members/application/member_list_state.dart';
import 'package:slock_app/features/members/application/member_list_store.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_state.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_store.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_replies_state.dart';
import 'package:slock_app/features/threads/application/thread_replies_store.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/application/threads_inbox_state.dart';
import 'package:slock_app/features/threads/application/threads_inbox_store.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/features/machines/data/machine_item.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

// =============================================================================
// Controllable RealtimeService — allows direct status transitions.
// =============================================================================

class _ControllableRealtimeService extends RealtimeService {
  @override
  RealtimeConnectionState build() => const RealtimeConnectionState(
        status: RealtimeConnectionStatus.connected,
      );

  void transitionTo(RealtimeConnectionStatus status) {
    state = state.copyWith(status: status);
  }
}

// =============================================================================
// Fake Repositories — minimal implementations tracking call counts.
// =============================================================================

class _FakeAgentsRepository
    implements AgentsRepository, AgentsMutationRepository {
  int listCalls = 0;
  List<AgentItem> listResult = const [];

  @override
  Future<List<AgentItem>> listAgents() async {
    listCalls++;
    return listResult;
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
      [];
  @override
  Future<AgentItem> createAgent(AgentMutationInput input) async =>
      throw UnimplementedError();
  @override
  Future<AgentItem> updateAgent(
          String agentId, AgentMutationInput input) async =>
      throw UnimplementedError();
  @override
  Future<void> deleteAgent(String agentId) async {}
}

class _FakeTasksRepository implements TasksRepository {
  int listCalls = 0;
  List<TaskItem> listResult = const [];

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async {
    listCalls++;
    return listResult;
  }

  @override
  Future<List<TaskItem>> createTasks(
    ServerScopeId serverId, {
    required String channelId,
    required List<String> titles,
  }) async =>
      [];
  @override
  Future<TaskItem> updateTaskStatus(
    ServerScopeId serverId, {
    required String taskId,
    required String status,
  }) async =>
      throw UnimplementedError();
  @override
  Future<void> deleteTask(ServerScopeId serverId,
      {required String taskId}) async {}
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

class _FakeThreadRepository implements ThreadRepository {
  int loadFollowedCalls = 0;
  List<ThreadInboxItem> followedResult = const [];
  int resolveCalls = 0;

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
    ServerScopeId serverId,
  ) async {
    loadFollowedCalls++;
    return followedResult;
  }

  @override
  Future<ResolvedThreadChannel> resolveThread(ThreadRouteTarget target) async {
    resolveCalls++;
    return const ResolvedThreadChannel(
      threadChannelId: 'tc-1',
      replyCount: 0,
      participantIds: [],
    );
  }

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

class _FakeSavedMessagesRepository implements SavedMessagesRepository {
  int listCalls = 0;
  SavedMessagesPage listResult =
      const SavedMessagesPage(items: [], hasMore: false);

  @override
  Future<SavedMessagesPage> listSavedMessages(
    ServerScopeId serverId, {
    int limit = 50,
    int offset = 0,
  }) async {
    listCalls++;
    return listResult;
  }

  @override
  Future<void> saveMessage(ServerScopeId serverId, String messageId) async {}
  @override
  Future<void> unsaveMessage(ServerScopeId serverId, String messageId) async {}
  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) async =>
      {};
}

class _FakeMemberRepository implements MemberRepository {
  int listCalls = 0;
  List<MemberProfile> members = const [];

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async {
    listCalls++;
    return members;
  }

  @override
  Future<String> createInvite(ServerScopeId serverId) async => 'invite-code';
  @override
  Future<void> updateMemberRole(
    ServerScopeId serverId, {
    required String userId,
    required String role,
  }) async {}
  @override
  Future<void> removeMember(
    ServerScopeId serverId, {
    required String userId,
  }) async {}
  @override
  Future<String> openDirectMessage(
    ServerScopeId serverId, {
    required String userId,
  }) async =>
      'dm-channel-id';
  @override
  Future<String> openAgentDirectMessage(
    ServerScopeId serverId, {
    required String agentId,
  }) async =>
      'dm-agent-channel-id';
}

class _FakeChannelMemberRepository implements ChannelMemberRepository {
  int listCalls = 0;
  List<ChannelMember> members = const [];

  @override
  Future<List<ChannelMember>> listMembers(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    listCalls++;
    return members;
  }

  @override
  Future<void> addHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) async {}
  @override
  Future<void> addAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  }) async {}
  @override
  Future<void> removeHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) async {}
  @override
  Future<void> removeAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  }) async {}
}

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-123',
        displayName: 'Alice',
        token: 'test-token',
      );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  const serverId = ServerScopeId('server-1');
  const channelId = 'channel-1';

  const threadRouteTarget = ThreadRouteTarget(
    serverId: 'server-1',
    parentChannelId: 'channel-1',
    parentMessageId: 'msg-1',
  );

  // ===========================================================================
  // 1. AgentsStore — global Notifier
  // ===========================================================================
  group('AgentsStore — INV-834 reconnect', () {
    late _FakeAgentsRepository fakeRepo;
    late ProviderContainer container;
    late ProviderSubscription<AgentsState> sub;
    late _ControllableRealtimeService realtimeService;

    setUp(() {
      fakeRepo = _FakeAgentsRepository();
      container = ProviderContainer(
        overrides: [
          agentsRepositoryProvider.overrideWithValue(fakeRepo),
          agentsMachinesLoaderProvider
              .overrideWithValue(() async => const <MachineItem>[]),
          realtimeServiceProvider
              .overrideWith(() => _ControllableRealtimeService()),
        ],
      );
      sub = container.listen(agentsStoreProvider, (_, __) {});
      realtimeService = container.read(realtimeServiceProvider.notifier)
          as _ControllableRealtimeService;
    });

    tearDown(() {
      sub.close();
      container.dispose();
    });

    test('reconnecting → connected while success triggers load', () async {
      // Put store into success state.
      await container.read(agentsStoreProvider.notifier).load();
      expect(container.read(agentsStoreProvider).status, AgentsStatus.success);
      final callsBefore = fakeRepo.listCalls;

      // Simulate WS reconnect cycle.
      realtimeService.transitionTo(RealtimeConnectionStatus.reconnecting);
      realtimeService.transitionTo(RealtimeConnectionStatus.connected);

      // Drain microtasks so async load() completes.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        fakeRepo.listCalls,
        callsBefore + 1,
        reason: 'INV-834: load() must be called on reconnect when success',
      );
    });

    test('reconnecting → connected while initial does NOT trigger load',
        () async {
      // Store remains in initial state (never loaded).
      expect(container.read(agentsStoreProvider).status, AgentsStatus.initial);
      final callsBefore = fakeRepo.listCalls;

      realtimeService.transitionTo(RealtimeConnectionStatus.reconnecting);
      realtimeService.transitionTo(RealtimeConnectionStatus.connected);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        fakeRepo.listCalls,
        callsBefore,
        reason: 'INV-834: no load when store not yet populated',
      );
    });

    test('connected → connected (no-op) does NOT trigger load', () async {
      await container.read(agentsStoreProvider.notifier).load();
      final callsBefore = fakeRepo.listCalls;

      // No reconnecting phase — just a connected → connected non-transition.
      realtimeService.transitionTo(RealtimeConnectionStatus.connected);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        fakeRepo.listCalls,
        callsBefore,
        reason: 'Must only re-fetch on reconnecting→connected, not same-status',
      );
    });
  });

  // ===========================================================================
  // 2. TasksStore — AutoDispose
  // ===========================================================================
  group('TasksStore — INV-834 reconnect', () {
    late _FakeTasksRepository fakeRepo;
    late ProviderContainer container;
    late _ControllableRealtimeService realtimeService;

    setUp(() {
      fakeRepo = _FakeTasksRepository();
      container = ProviderContainer(
        overrides: [
          currentTasksServerIdProvider.overrideWithValue(serverId),
          tasksRepositoryProvider.overrideWithValue(fakeRepo),
          realtimeServiceProvider
              .overrideWith(() => _ControllableRealtimeService()),
        ],
      );
      // Keep providers alive so auto-dispose doesn't discard mid-test.
      container.listen(tasksStoreProvider, (_, __) {});
      container.listen(realtimeServiceProvider, (_, __) {});
      realtimeService = container.read(realtimeServiceProvider.notifier)
          as _ControllableRealtimeService;
    });

    tearDown(() => container.dispose());

    test('reconnecting → connected while success triggers load', () async {
      await container.read(tasksStoreProvider.notifier).load();
      expect(container.read(tasksStoreProvider).status, TasksStatus.success);
      final callsBefore = fakeRepo.listCalls;

      realtimeService.transitionTo(RealtimeConnectionStatus.reconnecting);
      realtimeService.transitionTo(RealtimeConnectionStatus.connected);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(fakeRepo.listCalls, callsBefore + 1,
          reason: 'INV-834: tasks must re-fetch on reconnect');
    });

    test('reconnecting → connected while initial does NOT trigger load',
        () async {
      expect(container.read(tasksStoreProvider).status, TasksStatus.initial);
      final callsBefore = fakeRepo.listCalls;

      realtimeService.transitionTo(RealtimeConnectionStatus.reconnecting);
      realtimeService.transitionTo(RealtimeConnectionStatus.connected);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(fakeRepo.listCalls, callsBefore,
          reason: 'INV-834: no load when store not yet populated');
    });
  });

  // ===========================================================================
  // 3. ThreadsInboxStore — AutoDispose
  // ===========================================================================
  group('ThreadsInboxStore — INV-834 reconnect', () {
    late _FakeThreadRepository fakeRepo;
    late ProviderContainer container;
    late _ControllableRealtimeService realtimeService;

    setUp(() {
      fakeRepo = _FakeThreadRepository();
      container = ProviderContainer(
        overrides: [
          currentThreadsServerIdProvider.overrideWithValue(serverId),
          threadRepositoryProvider.overrideWithValue(fakeRepo),
          realtimeServiceProvider
              .overrideWith(() => _ControllableRealtimeService()),
        ],
      );
      container.listen(threadsInboxStoreProvider, (_, __) {});
      container.listen(realtimeServiceProvider, (_, __) {});
      realtimeService = container.read(realtimeServiceProvider.notifier)
          as _ControllableRealtimeService;
    });

    tearDown(() => container.dispose());

    test('reconnecting → connected while success triggers load', () async {
      // ThreadsInboxStore auto-loads via microtask in build().
      // We need to drain that microtask first.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(threadsInboxStoreProvider).status,
        ThreadsInboxStatus.success,
      );
      final callsBefore = fakeRepo.loadFollowedCalls;

      realtimeService.transitionTo(RealtimeConnectionStatus.reconnecting);
      realtimeService.transitionTo(RealtimeConnectionStatus.connected);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(fakeRepo.loadFollowedCalls, callsBefore + 1,
          reason: 'INV-834: threads inbox must re-fetch on reconnect');
    });
  });

  // ===========================================================================
  // 4. ThreadRepliesStore — AutoDispose
  // ===========================================================================
  group('ThreadRepliesStore — INV-834 reconnect', () {
    late _FakeThreadRepository fakeRepo;
    late ProviderContainer container;
    late _ControllableRealtimeService realtimeService;

    setUp(() {
      fakeRepo = _FakeThreadRepository();
      container = ProviderContainer(
        overrides: [
          currentThreadRouteTargetProvider.overrideWithValue(threadRouteTarget),
          threadRepositoryProvider.overrideWithValue(fakeRepo),
          realtimeServiceProvider
              .overrideWith(() => _ControllableRealtimeService()),
        ],
      );
      container.listen(threadRepliesStoreProvider, (_, __) {});
      container.listen(realtimeServiceProvider, (_, __) {});
      realtimeService = container.read(realtimeServiceProvider.notifier)
          as _ControllableRealtimeService;
    });

    tearDown(() => container.dispose());

    test('reconnecting → connected while success triggers load', () async {
      // ThreadRepliesStore auto-loads via microtask in build().
      // With threadChannelId == null, load() calls resolveThread.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(threadRepliesStoreProvider).status,
        ThreadRepliesStatus.success,
      );
      // Initial load should have called resolveThread exactly once.
      final callsBefore = fakeRepo.resolveCalls;
      expect(callsBefore, 1, reason: 'initial load calls resolveThread');

      realtimeService.transitionTo(RealtimeConnectionStatus.reconnecting);
      realtimeService.transitionTo(RealtimeConnectionStatus.connected);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        fakeRepo.resolveCalls,
        callsBefore + 1,
        reason:
            'INV-834: thread replies must re-fetch (resolveThread) on reconnect',
      );
    });
  });

  // ===========================================================================
  // 5. SavedMessagesStore — AutoDispose
  // ===========================================================================
  group('SavedMessagesStore — INV-834 reconnect', () {
    late _FakeSavedMessagesRepository fakeRepo;
    late ProviderContainer container;
    late _ControllableRealtimeService realtimeService;

    setUp(() {
      fakeRepo = _FakeSavedMessagesRepository();
      container = ProviderContainer(
        overrides: [
          currentSavedMessagesServerIdProvider.overrideWithValue(serverId),
          savedMessagesRepositoryProvider.overrideWithValue(fakeRepo),
          realtimeServiceProvider
              .overrideWith(() => _ControllableRealtimeService()),
        ],
      );
      container.listen(savedMessagesStoreProvider, (_, __) {});
      container.listen(realtimeServiceProvider, (_, __) {});
      realtimeService = container.read(realtimeServiceProvider.notifier)
          as _ControllableRealtimeService;
    });

    tearDown(() => container.dispose());

    test('reconnecting → connected while success triggers load', () async {
      await container.read(savedMessagesStoreProvider.notifier).load();
      expect(
        container.read(savedMessagesStoreProvider).status,
        SavedMessagesStatus.success,
      );
      final callsBefore = fakeRepo.listCalls;

      realtimeService.transitionTo(RealtimeConnectionStatus.reconnecting);
      realtimeService.transitionTo(RealtimeConnectionStatus.connected);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(fakeRepo.listCalls, callsBefore + 1,
          reason: 'INV-834: saved messages must re-fetch on reconnect');
    });

    test('reconnecting → connected while initial does NOT trigger load',
        () async {
      expect(
        container.read(savedMessagesStoreProvider).status,
        SavedMessagesStatus.initial,
      );
      final callsBefore = fakeRepo.listCalls;

      realtimeService.transitionTo(RealtimeConnectionStatus.reconnecting);
      realtimeService.transitionTo(RealtimeConnectionStatus.connected);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(fakeRepo.listCalls, callsBefore,
          reason: 'INV-834: no load when store not yet populated');
    });
  });

  // ===========================================================================
  // 6. MemberListStore — AutoDispose
  // ===========================================================================
  group('MemberListStore — INV-834 reconnect', () {
    late _FakeMemberRepository fakeRepo;
    late ProviderContainer container;
    late _ControllableRealtimeService realtimeService;

    setUp(() {
      fakeRepo = _FakeMemberRepository();
      container = ProviderContainer(
        overrides: [
          currentMembersServerIdProvider.overrideWithValue(serverId),
          memberRepositoryProvider.overrideWithValue(fakeRepo),
          sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          realtimeServiceProvider
              .overrideWith(() => _ControllableRealtimeService()),
        ],
      );
      container.listen(memberListStoreProvider, (_, __) {});
      container.listen(realtimeServiceProvider, (_, __) {});
      realtimeService = container.read(realtimeServiceProvider.notifier)
          as _ControllableRealtimeService;
    });

    tearDown(() => container.dispose());

    test('reconnecting → connected while success triggers load', () async {
      await container.read(memberListStoreProvider.notifier).load();
      expect(
        container.read(memberListStoreProvider).status,
        MemberListStatus.success,
      );
      final callsBefore = fakeRepo.listCalls;

      realtimeService.transitionTo(RealtimeConnectionStatus.reconnecting);
      realtimeService.transitionTo(RealtimeConnectionStatus.connected);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(fakeRepo.listCalls, callsBefore + 1,
          reason: 'INV-834: member list must re-fetch on reconnect');
    });

    test('reconnecting → connected while initial does NOT trigger load',
        () async {
      expect(
        container.read(memberListStoreProvider).status,
        MemberListStatus.initial,
      );
      final callsBefore = fakeRepo.listCalls;

      realtimeService.transitionTo(RealtimeConnectionStatus.reconnecting);
      realtimeService.transitionTo(RealtimeConnectionStatus.connected);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(fakeRepo.listCalls, callsBefore,
          reason: 'INV-834: no load when store not yet populated');
    });
  });

  // ===========================================================================
  // 7. ChannelMemberStore — AutoDispose
  // ===========================================================================
  group('ChannelMemberStore — INV-834 reconnect', () {
    late _FakeChannelMemberRepository fakeRepo;
    late ProviderContainer container;
    late _ControllableRealtimeService realtimeService;

    setUp(() {
      fakeRepo = _FakeChannelMemberRepository();
      container = ProviderContainer(
        overrides: [
          currentChannelMemberServerIdProvider.overrideWithValue(serverId),
          currentChannelMemberChannelIdProvider.overrideWithValue(channelId),
          channelMemberRepositoryProvider.overrideWithValue(fakeRepo),
          realtimeServiceProvider
              .overrideWith(() => _ControllableRealtimeService()),
        ],
      );
      container.listen(channelMemberStoreProvider, (_, __) {});
      container.listen(realtimeServiceProvider, (_, __) {});
      realtimeService = container.read(realtimeServiceProvider.notifier)
          as _ControllableRealtimeService;
    });

    tearDown(() => container.dispose());

    test('reconnecting → connected while success triggers load', () async {
      await container.read(channelMemberStoreProvider.notifier).load();
      expect(
        container.read(channelMemberStoreProvider).status,
        ChannelMemberStatus.success,
      );
      final callsBefore = fakeRepo.listCalls;

      realtimeService.transitionTo(RealtimeConnectionStatus.reconnecting);
      realtimeService.transitionTo(RealtimeConnectionStatus.connected);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(fakeRepo.listCalls, callsBefore + 1,
          reason: 'INV-834: channel members must re-fetch on reconnect');
    });

    test('reconnecting → connected while initial does NOT trigger load',
        () async {
      expect(
        container.read(channelMemberStoreProvider).status,
        ChannelMemberStatus.initial,
      );
      final callsBefore = fakeRepo.listCalls;

      realtimeService.transitionTo(RealtimeConnectionStatus.reconnecting);
      realtimeService.transitionTo(RealtimeConnectionStatus.connected);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(fakeRepo.listCalls, callsBefore,
          reason: 'INV-834: no load when store not yet populated');
    });
  });
}
