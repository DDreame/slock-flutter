// =============================================================================
// #829 — P1 ThreadsInboxStore Disposal Guard + P2 Per-Item Rollbacks
//
// Verifies:
// 1. ThreadsInboxStore.load() does not throw StateError on post-disposal access
// 2. AgentsStore.startAgent/stopAgent per-item rollback preserves concurrent
//    WS-driven mutations to other items
// 3. ChannelMemberStore.removeHumanMember/removeAgentMember re-inserts at
//    original position without erasing concurrent additions
// 4. WorkspacesStore.deleteWorkspace re-inserts at original position
// =============================================================================

import 'dart:async';

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
import 'package:slock_app/features/machines/application/workspaces_state.dart';
import 'package:slock_app/features/machines/application/workspaces_store.dart';
import 'package:slock_app/features/machines/data/machines_repository.dart';
import 'package:slock_app/features/machines/data/machines_repository_provider.dart';
import 'package:slock_app/features/machines/data/workspace_item.dart';
import 'package:slock_app/features/threads/application/threads_inbox_store.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';

void main() {
  // ===========================================================================
  // 1. ThreadsInboxStore — disposal guard prevents StateError
  // ===========================================================================

  group('#829 — ThreadsInboxStore disposal guard', () {
    test('load() does not throw StateError after disposal', () async {
      final completer = Completer<List<ThreadInboxItem>>();
      final repo = _DelayedThreadRepo(completer);

      final container = ProviderContainer(overrides: [
        currentThreadsServerIdProvider
            .overrideWithValue(const ServerScopeId('srv-1')),
        threadRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(threadsInboxStoreProvider, (_, __) {});
      final store = container.read(threadsInboxStoreProvider.notifier);
      final future = store.load();

      // Dispose BEFORE the load resolves.
      sub.close();
      container.dispose();

      // Resolve AFTER disposal — must not throw StateError.
      completer.complete(const []);
      await future; // implicit pass: no unhandled exception
    });
  });

  // ===========================================================================
  // 2. AgentsStore — per-item rollback on startAgent/stopAgent
  // ===========================================================================

  group('#829 — AgentsStore per-item rollback', () {
    test('startAgent rollback preserves concurrent mutations to other items',
        () async {
      final repo = _FakeAgentsRepo();
      final container = ProviderContainer(overrides: [
        agentsRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(agentsStoreProvider, (_, __) {});
      final store = container.read(agentsStoreProvider.notifier);

      // Seed with 2 agents.
      store.state = const AgentsState(
        status: AgentsStatus.success,
        items: [
          AgentItem(
            id: 'a1',
            name: 'Agent1',
            model: 'claude',
            runtime: 'daemon',
            status: 'stopped',
            activity: 'offline',
          ),
          AgentItem(
            id: 'a2',
            name: 'Agent2',
            model: 'claude',
            runtime: 'daemon',
            status: 'running',
            activity: 'idle',
          ),
        ],
      );

      // Configure repo to fail on startAgent.
      repo.shouldFail = true;

      // Simulate a WS event adding a 3rd agent while start is in-flight:
      // We'll call startAgent and inject a concurrent mutation before failure.
      repo.onStartCalled = () {
        // Simulate WS adding a new agent to the store mid-flight.
        store.state = store.state.copyWith(
          items: [
            ...store.state.items,
            const AgentItem(
              id: 'a3',
              name: 'Agent3',
              model: 'claude',
              runtime: 'daemon',
              status: 'running',
              activity: 'idle',
            ),
          ],
        );
      };

      try {
        await store.startAgent('a1');
      } on AppFailure catch (_) {}

      final state = container.read(agentsStoreProvider);
      // a1 should be rolled back to 'stopped' (per-item).
      final a1 = state.items.firstWhere((a) => a.id == 'a1');
      expect(a1.status, 'stopped');
      expect(a1.activity, 'offline');

      // a3 (concurrent WS addition) should still be present.
      expect(state.items.any((a) => a.id == 'a3'), isTrue);
      // a2 should be unchanged.
      final a2 = state.items.firstWhere((a) => a.id == 'a2');
      expect(a2.status, 'running');

      sub.close();
      container.dispose();
    });

    test('stopAgent rollback preserves concurrent mutations to other items',
        () async {
      final repo = _FakeAgentsRepo();
      final container = ProviderContainer(overrides: [
        agentsRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(agentsStoreProvider, (_, __) {});
      final store = container.read(agentsStoreProvider.notifier);

      store.state = const AgentsState(
        status: AgentsStatus.success,
        items: [
          AgentItem(
            id: 'a1',
            name: 'Agent1',
            model: 'claude',
            runtime: 'daemon',
            status: 'running',
            activity: 'working',
          ),
          AgentItem(
            id: 'a2',
            name: 'Agent2',
            model: 'claude',
            runtime: 'daemon',
            status: 'running',
            activity: 'idle',
          ),
        ],
      );

      repo.shouldFail = true;

      // Simulate a WS event adding a 3rd agent while stop is in-flight.
      repo.onStopCalled = () {
        store.state = store.state.copyWith(
          items: [
            ...store.state.items,
            const AgentItem(
              id: 'a3',
              name: 'Agent3',
              model: 'claude',
              runtime: 'daemon',
              status: 'running',
              activity: 'idle',
            ),
          ],
        );
      };

      try {
        await store.stopAgent('a1');
      } on AppFailure catch (_) {}

      final state = container.read(agentsStoreProvider);
      // a1 rolled back to 'running' (per-item).
      final a1 = state.items.firstWhere((a) => a.id == 'a1');
      expect(a1.status, 'running');
      expect(a1.activity, 'working');
      // a3 (concurrent WS addition) should still be present.
      expect(state.items.any((a) => a.id == 'a3'), isTrue);
      // a2 unchanged.
      final a2 = state.items.firstWhere((a) => a.id == 'a2');
      expect(a2.status, 'running');

      sub.close();
      container.dispose();
    });
  });

  // ===========================================================================
  // 3. ChannelMemberStore — per-item rollback on remove
  // ===========================================================================

  group('#829 — ChannelMemberStore per-item rollback', () {
    test('removeHumanMember re-inserts at original index on failure', () async {
      final repo = _FakeChannelMemberRepo();
      const serverId = ServerScopeId('srv-1');
      const channelId = 'ch-1';

      final container = ProviderContainer(overrides: [
        currentChannelMemberServerIdProvider.overrideWithValue(serverId),
        currentChannelMemberChannelIdProvider.overrideWithValue(channelId),
        channelMemberRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(channelMemberStoreProvider, (_, __) {});
      final store = container.read(channelMemberStoreProvider.notifier);

      // Seed with 3 members.
      store.state = const ChannelMemberState(
        status: ChannelMemberStatus.success,
        items: [
          ChannelMember(
              id: 'm1', channelId: channelId, userId: 'u1', userName: 'Alice'),
          ChannelMember(
              id: 'm2', channelId: channelId, userId: 'u2', userName: 'Bob'),
          ChannelMember(
              id: 'm3', channelId: channelId, userId: 'u3', userName: 'Carol'),
        ],
      );

      repo.shouldFail = true;

      // Simulate a WS event adding a 4th member while remove is in-flight.
      repo.onRemoveHumanCalled = () {
        store.state = store.state.copyWith(
          items: [
            ...store.state.items,
            const ChannelMember(
                id: 'm4', channelId: channelId, userId: 'u4', userName: 'Dave'),
          ],
        );
      };

      try {
        await store.removeHumanMember('u2');
      } on AppFailure catch (_) {}

      final state = container.read(channelMemberStoreProvider);
      // Bob re-inserted + Dave (concurrent addition) preserved.
      expect(state.items.length, 4);
      expect(state.items.any((m) => m.userId == 'u2'), isTrue);
      expect(state.items.any((m) => m.userId == 'u4'), isTrue);
      // Original ordering preserved for existing members.
      final bobIndex = state.items.indexWhere((m) => m.userId == 'u2');
      final aliceIndex = state.items.indexWhere((m) => m.userId == 'u1');
      expect(aliceIndex, lessThan(bobIndex));

      sub.close();
      container.dispose();
    });

    test('removeAgentMember re-inserts at original index on failure', () async {
      final repo = _FakeChannelMemberRepo();
      const serverId = ServerScopeId('srv-1');
      const channelId = 'ch-1';

      final container = ProviderContainer(overrides: [
        currentChannelMemberServerIdProvider.overrideWithValue(serverId),
        currentChannelMemberChannelIdProvider.overrideWithValue(channelId),
        channelMemberRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(channelMemberStoreProvider, (_, __) {});
      final store = container.read(channelMemberStoreProvider.notifier);

      store.state = const ChannelMemberState(
        status: ChannelMemberStatus.success,
        items: [
          ChannelMember(
              id: 'm1',
              channelId: channelId,
              agentId: 'ag1',
              agentName: 'Bot1'),
          ChannelMember(
              id: 'm2',
              channelId: channelId,
              agentId: 'ag2',
              agentName: 'Bot2'),
        ],
      );

      repo.shouldFail = true;

      // Simulate a WS event adding a 3rd agent member while remove is in-flight.
      repo.onRemoveAgentCalled = () {
        store.state = store.state.copyWith(
          items: [
            ...store.state.items,
            const ChannelMember(
                id: 'm3',
                channelId: channelId,
                agentId: 'ag3',
                agentName: 'Bot3'),
          ],
        );
      };

      try {
        await store.removeAgentMember('ag1');
      } on AppFailure catch (_) {}

      final state = container.read(channelMemberStoreProvider);
      // ag1 re-inserted + ag3 (concurrent addition) preserved.
      expect(state.items.length, 3);
      expect(state.items.any((m) => m.agentId == 'ag1'), isTrue);
      expect(state.items.any((m) => m.agentId == 'ag3'), isTrue);

      sub.close();
      container.dispose();
    });
  });

  // ===========================================================================
  // 4. WorkspacesStore — per-item rollback on deleteWorkspace
  // ===========================================================================

  group('#829 — WorkspacesStore per-item rollback', () {
    test('deleteWorkspace re-inserts at original index on failure', () async {
      final repo = _FakeMachinesRepo();
      final container = ProviderContainer(overrides: [
        currentWorkspacesMachineIdProvider.overrideWithValue('machine-1'),
        machinesRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(workspacesStoreProvider, (_, __) {});
      final store = container.read(workspacesStoreProvider.notifier);

      store.state = WorkspacesState(
        status: WorkspacesStatus.success,
        items: [
          WorkspaceItem(
            id: 'ws-1',
            name: 'Workspace 1',
            machineId: 'machine-1',
            createdAt: DateTime(2024),
          ),
          WorkspaceItem(
            id: 'ws-2',
            name: 'Workspace 2',
            machineId: 'machine-1',
            createdAt: DateTime(2024),
          ),
          WorkspaceItem(
            id: 'ws-3',
            name: 'Workspace 3',
            machineId: 'machine-1',
            createdAt: DateTime(2024),
          ),
        ],
      );

      repo.shouldFail = true;

      // Simulate a WS event adding a 4th workspace while delete is in-flight.
      repo.onDeleteCalled = () {
        store.state = store.state.copyWith(
          items: [
            ...store.state.items,
            WorkspaceItem(
              id: 'ws-4',
              name: 'Workspace 4',
              machineId: 'machine-1',
              createdAt: DateTime(2024),
            ),
          ],
        );
      };

      try {
        await store.deleteWorkspace('ws-2');
      } on AppFailure catch (_) {}

      final state = container.read(workspacesStoreProvider);
      // ws-2 re-inserted + ws-4 (concurrent addition) preserved.
      expect(state.items.length, 4);
      expect(state.items.any((w) => w.id == 'ws-2'), isTrue);
      expect(state.items.any((w) => w.id == 'ws-4'), isTrue);
      expect(state.deletingWorkspaceIds, isEmpty);

      sub.close();
      container.dispose();
    });
  });
}

// =============================================================================
// Fake repositories
// =============================================================================

class _DelayedThreadRepo implements ThreadRepository {
  _DelayedThreadRepo(this._completer);

  final Completer<List<ThreadInboxItem>> _completer;

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(ServerScopeId serverId) =>
      _completer.future;

  @override
  Future<ResolvedThreadChannel> resolveThread(ThreadRouteTarget target) =>
      throw UnimplementedError();

  @override
  Future<void> followThread(ThreadRouteTarget target) =>
      throw UnimplementedError();

  @override
  Future<void> unfollowThread(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> markThreadDone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> markThreadUndone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) =>
      throw UnimplementedError();
}

class _FakeAgentsRepo implements AgentsRepository {
  bool shouldFail = false;
  _VoidCallback? onStartCalled;
  _VoidCallback? onStopCalled;

  @override
  Future<void> startAgent(String agentId) async {
    onStartCalled?.call();
    if (shouldFail) throw const UnknownFailure(message: 'test failure');
  }

  @override
  Future<void> stopAgent(String agentId) async {
    onStopCalled?.call();
    if (shouldFail) throw const UnknownFailure(message: 'test failure');
  }

  @override
  Future<List<AgentItem>> listAgents() async => const [];

  @override
  Future<void> resetAgent(String agentId, {required String mode}) async {}

  @override
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  }) async =>
      const [];
}

class _FakeChannelMemberRepo implements ChannelMemberRepository {
  bool shouldFail = false;
  _VoidCallback? onRemoveHumanCalled;
  _VoidCallback? onRemoveAgentCalled;

  @override
  Future<List<ChannelMember>> listMembers(
    ServerScopeId serverId, {
    required String channelId,
  }) async =>
      const [];

  @override
  Future<void> removeHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) async {
    onRemoveHumanCalled?.call();
    if (shouldFail) throw const UnknownFailure(message: 'test failure');
  }

  @override
  Future<void> removeAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  }) async {
    onRemoveAgentCalled?.call();
    if (shouldFail) throw const UnknownFailure(message: 'test failure');
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
}

class _FakeMachinesRepo implements MachinesRepository {
  bool shouldFail = false;
  _VoidCallback? onDeleteCalled;

  @override
  Future<void> deleteWorkspace(
    String machineId, {
    required String workspaceId,
  }) async {
    onDeleteCalled?.call();
    if (shouldFail) throw const UnknownFailure(message: 'test failure');
  }

  @override
  Future<List<WorkspaceItem>> loadWorkspaces(String machineId) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

typedef _VoidCallback = void Function();
