// =============================================================================
// #761 — Rollback + Loading Fixes
//
// #3  (P1): WorkspacesStore.deleteWorkspace — data loss on non-AppFailure
// #8  (P2): TasksStore.load — status/isRefreshing stuck on non-AppFailure
// #9  (P2): PinnedMessagesStore.load — stuck at loading on non-AppFailure
// #10 (P2): ChannelMemberStore.load — stuck at loading on non-AppFailure
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_member_state.dart';
import 'package:slock_app/features/channels/application/channel_member_store.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/data/channel_member_repository.dart';
import 'package:slock_app/features/channels/data/channel_member_repository_provider.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/application/pinned_messages_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/machines/application/workspaces_store.dart';
import 'package:slock_app/features/machines/data/machines_repository.dart';
import 'package:slock_app/features/machines/data/machines_repository_provider.dart';
import 'package:slock_app/features/machines/data/workspace_item.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';

void main() {
  // ---------------------------------------------------------------------------
  // #761-3 — WorkspacesStore.deleteWorkspace rollback on non-AppFailure
  // ---------------------------------------------------------------------------
  group('#761-3 — WorkspacesStore.deleteWorkspace non-AppFailure rollback', () {
    test('deleted workspace is restored on non-AppFailure', () async {
      final repo = _FakeMachinesRepository();
      repo.workspaces = [
        WorkspaceItem(
          id: 'ws-1',
          name: 'My Workspace',
          machineId: 'machine-1',
          createdAt: DateTime(2026, 5, 22),
        ),
      ];
      final container = ProviderContainer(overrides: [
        currentWorkspacesMachineIdProvider.overrideWithValue('machine-1'),
        machinesRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await container.read(workspacesStoreProvider.notifier).load();
      expect(
        container.read(workspacesStoreProvider).items.length,
        1,
      );

      // Configure to throw non-AppFailure.
      repo.throwNonAppFailure = true;

      try {
        await container
            .read(workspacesStoreProvider.notifier)
            .deleteWorkspace('ws-1');
      } catch (_) {
        // expected to rethrow
      }

      final state = container.read(workspacesStoreProvider);
      expect(state.items.length, 1,
          reason: '#761: deleted workspace must be restored on non-AppFailure');
      expect(state.items.first.id, 'ws-1');
      expect(state.deletingWorkspaceIds, isEmpty,
          reason: '#761: deletingWorkspaceIds must be cleared');
      expect(state.failure, isA<UnknownFailure>());
    });

    test('deleted workspace is restored on AppFailure (unchanged behavior)',
        () async {
      final repo = _FakeMachinesRepository();
      repo.workspaces = [
        WorkspaceItem(
          id: 'ws-1',
          name: 'My Workspace',
          machineId: 'machine-1',
          createdAt: DateTime(2026, 5, 22),
        ),
      ];
      final container = ProviderContainer(overrides: [
        currentWorkspacesMachineIdProvider.overrideWithValue('machine-1'),
        machinesRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await container.read(workspacesStoreProvider.notifier).load();

      repo.appFailure =
          const ServerFailure(message: 'Delete failed', statusCode: 500);

      try {
        await container
            .read(workspacesStoreProvider.notifier)
            .deleteWorkspace('ws-1');
      } on AppFailure {
        // expected
      }

      final state = container.read(workspacesStoreProvider);
      expect(state.items.length, 1);
      expect(state.items.first.id, 'ws-1');
      expect(state.deletingWorkspaceIds, isEmpty);
    });

    test('diagnostics reporter crash does not block rollback', () async {
      final repo = _FakeMachinesRepository();
      repo.workspaces = [
        WorkspaceItem(
          id: 'ws-1',
          name: 'My Workspace',
          machineId: 'machine-1',
          createdAt: DateTime(2026, 5, 22),
        ),
      ];
      final container = ProviderContainer(overrides: [
        currentWorkspacesMachineIdProvider.overrideWithValue('machine-1'),
        machinesRepositoryProvider.overrideWithValue(repo),
        diagnosticsCollectorProvider
            .overrideWithValue(_ThrowingDiagnosticsCollector()),
      ]);
      addTearDown(container.dispose);

      await container.read(workspacesStoreProvider.notifier).load();

      repo.throwNonAppFailure = true;

      try {
        await container
            .read(workspacesStoreProvider.notifier)
            .deleteWorkspace('ws-1');
      } catch (_) {}

      final state = container.read(workspacesStoreProvider);
      expect(state.items.length, 1,
          reason: '#761: rollback must work even when reporter throws');
      expect(state.failure, isA<UnknownFailure>());
    });
  });

  // ---------------------------------------------------------------------------
  // #761-8 — TasksStore.load status/isRefreshing stuck on non-AppFailure
  // ---------------------------------------------------------------------------
  group('#761-8 — TasksStore.load non-AppFailure recovery', () {
    const serverId = ServerScopeId('server-1');

    test('status resets to failure on non-AppFailure (initial load)', () async {
      final repo = _FakeTasksRepository(throwNonAppFailure: true);
      final container = ProviderContainer(overrides: [
        currentTasksServerIdProvider.overrideWithValue(serverId),
        tasksRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await container.read(tasksStoreProvider.notifier).load();

      final state = container.read(tasksStoreProvider);
      expect(state.status, TasksStatus.failure,
          reason: '#761: status must not stick at loading');
      expect(state.failure, isA<UnknownFailure>());
    });

    test('isRefreshing resets on non-AppFailure (SWR path)', () async {
      final repo = _FakeTasksRepository();
      final container = ProviderContainer(overrides: [
        currentTasksServerIdProvider.overrideWithValue(serverId),
        tasksRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      // First load succeeds to enter SWR state.
      await container.read(tasksStoreProvider.notifier).load();
      expect(
        container.read(tasksStoreProvider).status,
        TasksStatus.success,
      );

      // Second load triggers SWR refresh — throws non-AppFailure.
      repo.throwNonAppFailure = true;
      await container.read(tasksStoreProvider.notifier).load();

      final state = container.read(tasksStoreProvider);
      expect(state.isRefreshing, isFalse,
          reason: '#761: isRefreshing must reset on non-AppFailure');
      expect(state.status, TasksStatus.success,
          reason: '#761: SWR should preserve success status');
      expect(state.failure, isA<UnknownFailure>());
    });

    test('diagnostics reporter crash does not block flag reset', () async {
      final repo = _FakeTasksRepository(throwNonAppFailure: true);
      final container = ProviderContainer(overrides: [
        currentTasksServerIdProvider.overrideWithValue(serverId),
        tasksRepositoryProvider.overrideWithValue(repo),
        diagnosticsCollectorProvider
            .overrideWithValue(_ThrowingDiagnosticsCollector()),
      ]);
      addTearDown(container.dispose);

      await container.read(tasksStoreProvider.notifier).load();

      final state = container.read(tasksStoreProvider);
      expect(state.status, TasksStatus.failure,
          reason: '#761: status must reset even when reporter throws');
      expect(state.failure, isA<UnknownFailure>());
    });
  });

  // ---------------------------------------------------------------------------
  // #761-9 — PinnedMessagesStore.load stuck on non-AppFailure
  // ---------------------------------------------------------------------------
  group('#761-9 — PinnedMessagesStore.load non-AppFailure recovery', () {
    final target = ConversationDetailTarget.channel(
      const ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'general',
      ),
    );

    test('status resets to failure on non-AppFailure', () async {
      final repo = _FakeConversationRepository(throwNonAppFailure: true);
      final container = ProviderContainer(overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await container.read(pinnedMessagesStoreProvider.notifier).load();

      final state = container.read(pinnedMessagesStoreProvider);
      expect(state.status, PinnedMessagesStatus.failure,
          reason: '#761: status must not stick at loading');
      expect(state.error, isNotNull);
    });

    test('stale error is cleared on retry', () async {
      final repo = _FakeConversationRepository(throwNonAppFailure: true);
      final container = ProviderContainer(overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      // First load fails.
      await container.read(pinnedMessagesStoreProvider.notifier).load();
      expect(container.read(pinnedMessagesStoreProvider).failure, isNotNull);

      // Second load succeeds — error should be cleared.
      repo.throwNonAppFailure = false;
      await container.read(pinnedMessagesStoreProvider.notifier).load();

      final state = container.read(pinnedMessagesStoreProvider);
      expect(state.status, PinnedMessagesStatus.success);
      expect(state.error, isNull,
          reason: '#761: stale error must be cleared on successful retry');
    });

    test('diagnostics reporter crash does not block flag reset', () async {
      final repo = _FakeConversationRepository(throwNonAppFailure: true);
      final container = ProviderContainer(overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(repo),
        diagnosticsCollectorProvider
            .overrideWithValue(_ThrowingDiagnosticsCollector()),
      ]);
      addTearDown(container.dispose);

      await container.read(pinnedMessagesStoreProvider.notifier).load();

      final state = container.read(pinnedMessagesStoreProvider);
      expect(state.status, PinnedMessagesStatus.failure,
          reason: '#761: status must reset even when reporter throws');
    });
  });

  // ---------------------------------------------------------------------------
  // #761-10 — ChannelMemberStore.load stuck on non-AppFailure
  // ---------------------------------------------------------------------------
  group('#761-10 — ChannelMemberStore.load non-AppFailure recovery', () {
    const serverId = ServerScopeId('server-1');
    const channelId = 'channel-1';

    test('status resets to failure on non-AppFailure', () async {
      final repo = _FakeChannelMemberRepository(throwNonAppFailure: true);
      final container = ProviderContainer(overrides: [
        currentChannelMemberServerIdProvider.overrideWithValue(serverId),
        currentChannelMemberChannelIdProvider.overrideWithValue(channelId),
        channelMemberRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await container.read(channelMemberStoreProvider.notifier).load();

      final state = container.read(channelMemberStoreProvider);
      expect(state.status, ChannelMemberStatus.failure,
          reason: '#761: status must not stick at loading');
      expect(state.failure, isA<UnknownFailure>());
    });

    test('AppFailure still sets failure status (unchanged behavior)', () async {
      final repo = _FakeChannelMemberRepository(
        appFailure:
            const ServerFailure(message: 'Network error', statusCode: 500),
      );
      final container = ProviderContainer(overrides: [
        currentChannelMemberServerIdProvider.overrideWithValue(serverId),
        currentChannelMemberChannelIdProvider.overrideWithValue(channelId),
        channelMemberRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await container.read(channelMemberStoreProvider.notifier).load();

      final state = container.read(channelMemberStoreProvider);
      expect(state.status, ChannelMemberStatus.failure);
      expect(state.failure, isA<ServerFailure>());
    });

    test('diagnostics reporter crash does not block flag reset', () async {
      final repo = _FakeChannelMemberRepository(throwNonAppFailure: true);
      final container = ProviderContainer(overrides: [
        currentChannelMemberServerIdProvider.overrideWithValue(serverId),
        currentChannelMemberChannelIdProvider.overrideWithValue(channelId),
        channelMemberRepositoryProvider.overrideWithValue(repo),
        diagnosticsCollectorProvider
            .overrideWithValue(_ThrowingDiagnosticsCollector()),
      ]);
      addTearDown(container.dispose);

      await container.read(channelMemberStoreProvider.notifier).load();

      final state = container.read(channelMemberStoreProvider);
      expect(state.status, ChannelMemberStatus.failure,
          reason: '#761: status must reset even when reporter throws');
      expect(state.failure, isA<UnknownFailure>());
    });
  });
}

// =============================================================================
// Test Doubles
// =============================================================================

class _FakeMachinesRepository implements MachinesRepository {
  List<WorkspaceItem> workspaces = [];
  bool throwNonAppFailure = false;
  AppFailure? appFailure;

  @override
  Future<List<WorkspaceItem>> loadWorkspaces(String machineId) async {
    if (throwNonAppFailure) {
      throw const FormatException('Simulated non-AppFailure in loadWorkspaces');
    }
    if (appFailure != null) throw appFailure!;
    return workspaces;
  }

  @override
  Future<void> deleteWorkspace(
    String machineId, {
    required String workspaceId,
  }) async {
    if (throwNonAppFailure) {
      throw const FormatException(
          'Simulated non-AppFailure in deleteWorkspace');
    }
    if (appFailure != null) throw appFailure!;
    workspaces = workspaces.where((w) => w.id != workspaceId).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTasksRepository implements TasksRepository {
  _FakeTasksRepository({this.throwNonAppFailure = false});

  bool throwNonAppFailure;

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async {
    if (throwNonAppFailure) {
      throw const FormatException(
          'Simulated non-AppFailure in listServerTasks');
    }
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({this.throwNonAppFailure = false});

  bool throwNonAppFailure;

  @override
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async {
    if (throwNonAppFailure) {
      throw const FormatException(
          'Simulated non-AppFailure in loadPinnedMessages');
    }
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChannelMemberRepository implements ChannelMemberRepository {
  _FakeChannelMemberRepository({
    this.throwNonAppFailure = false,
    this.appFailure,
  });

  final bool throwNonAppFailure;
  final AppFailure? appFailure;

  @override
  Future<List<ChannelMember>> listMembers(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    if (throwNonAppFailure) {
      throw const FormatException('Simulated non-AppFailure in listMembers');
    }
    if (appFailure != null) throw appFailure!;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingDiagnosticsCollector extends DiagnosticsCollector {
  @override
  void error(String tag, String message, {Map<String, dynamic>? metadata}) {
    throw StateError('Diagnostics collector crash: $message');
  }
}
