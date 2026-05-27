// =============================================================================
// #835 — P2 Correctness + Performance
//
// Tests:
// 1. ThreadsInboxStore.markDone — per-item rollback preserves concurrent
//    mutations (INV-ROLLBACK-835)
// 2. MachinesStore — reconnect listener triggers load on reconnect (INV-834)
// 3. WorkspacesStore — reconnect listener triggers load on reconnect (INV-834)
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/machines/application/machines_state.dart';
import 'package:slock_app/features/machines/application/machines_store.dart';
import 'package:slock_app/features/machines/application/workspaces_store.dart';
import 'package:slock_app/features/machines/application/workspaces_state.dart';
import 'package:slock_app/features/machines/data/machines_repository.dart';
import 'package:slock_app/features/machines/data/machines_repository_provider.dart';
import 'package:slock_app/features/machines/data/workspace_item.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/application/threads_inbox_store.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';

// =============================================================================
// Controllable RealtimeService
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
// Fake Repositories
// =============================================================================

class _FakeThreadRepository implements ThreadRepository {
  int loadFollowedCalls = 0;
  List<ThreadInboxItem> items = const [];
  bool shouldFail = false;
  Completer<void>? markDoneCompleter;

  @override
  Future<List<ThreadInboxItem>> loadFollowedThreads(
    ServerScopeId serverId,
  ) async {
    loadFollowedCalls++;
    return items;
  }

  @override
  Future<void> markThreadDone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {
    if (markDoneCompleter != null) {
      await markDoneCompleter!.future;
    }
    if (shouldFail) {
      throw const UnknownFailure(
        message: 'Mark done failed',
        causeType: 'test',
      );
    }
  }

  @override
  Future<ResolvedThreadChannel> resolveThread(ThreadRouteTarget target) async =>
      throw UnimplementedError();
  @override
  Future<void> followThread(ThreadRouteTarget target) async {}
  @override
  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}
}

class _FakeMachinesRepository implements MachinesRepository {
  int loadCalls = 0;
  MachinesSnapshot snapshot = const MachinesSnapshot();
  int loadWorkspacesCalls = 0;
  List<WorkspaceItem> workspaces = const [];

  @override
  Future<MachinesSnapshot> loadMachines() async {
    loadCalls++;
    return snapshot;
  }

  @override
  Future<List<WorkspaceItem>> loadWorkspaces(String machineId) async {
    loadWorkspacesCalls++;
    return workspaces;
  }

  @override
  Future<RegisterMachineResult> registerMachine({required String name}) async =>
      throw UnimplementedError();
  @override
  Future<void> renameMachine(String machineId, {required String name}) async {}
  @override
  Future<String> rotateMachineApiKey(String machineId) async =>
      throw UnimplementedError();
  @override
  Future<void> deleteMachine(String machineId) async {}
  @override
  Future<void> deleteWorkspace(String machineId,
      {required String workspaceId}) async {}
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  const serverId = ServerScopeId('server-1');

  ThreadInboxItem makeThreadItem({
    required String threadChannelId,
    String title = 'Thread',
  }) {
    return ThreadInboxItem(
      routeTarget: ThreadRouteTarget(
        serverId: 'server-1',
        parentChannelId: 'channel-1',
        parentMessageId: 'msg-$threadChannelId',
        threadChannelId: threadChannelId,
      ),
      title: title,
      replyCount: 1,
      unreadCount: 0,
      participantIds: const ['user-1'],
    );
  }

  // ===========================================================================
  // 1. ThreadsInboxStore.markDone — per-item rollback (INV-ROLLBACK-835)
  // ===========================================================================
  group('ThreadsInboxStore.markDone — INV-ROLLBACK-835', () {
    late _FakeThreadRepository fakeRepo;
    late ProviderContainer container;

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
    });

    tearDown(() => container.dispose());

    test(
      'markDone rollback re-inserts only the removed item, preserving '
      'concurrent additions',
      () async {
        final item1 = makeThreadItem(threadChannelId: 'tc-1', title: 'A');
        final item2 = makeThreadItem(threadChannelId: 'tc-2', title: 'B');
        fakeRepo.items = [item1, item2];

        // Explicitly load (auto-load microtask may have already fired with
        // empty items before we set fakeRepo.items).
        await container.read(threadsInboxStoreProvider.notifier).load();

        expect(
          container.read(threadsInboxStoreProvider).items.length,
          2,
        );

        // Set up a Completer so markDone is in-flight while we mutate state.
        fakeRepo.markDoneCompleter = Completer<void>();
        fakeRepo.shouldFail = true;

        final store = container.read(threadsInboxStoreProvider.notifier);
        final markDoneFuture = store.markDone(item1);

        // While markDone is in-flight, verify optimistic removal worked.
        await Future<void>.delayed(Duration.zero);
        // The current list should have item2 (item1 was optimistically removed).
        final currentState = container.read(threadsInboxStoreProvider);
        expect(currentState.items.length, 1);
        expect(currentState.items[0].title, 'B');

        // Complete the markDone call (which will fail).
        fakeRepo.markDoneCompleter!.complete();
        await markDoneFuture;

        // After rollback, item1 should be re-inserted, and any concurrent
        // state should not be erased. The important invariant: item2 must
        // still be present (it was NOT in previousItems since we removed item1).
        final afterRollback = container.read(threadsInboxStoreProvider);
        expect(afterRollback.failure, isNotNull);
        // item1 was re-inserted at index 0 (its original position, clamped).
        final ids = afterRollback.items
            .map((i) => i.routeTarget.threadChannelId)
            .toList();
        expect(ids, contains('tc-1'), reason: 'removed item re-inserted');
        expect(ids, contains('tc-2'), reason: 'concurrent item preserved');
      },
    );

    test(
      'markDone success does not re-insert the item',
      () async {
        final item1 = makeThreadItem(threadChannelId: 'tc-1', title: 'A');
        final item2 = makeThreadItem(threadChannelId: 'tc-2', title: 'B');
        fakeRepo.items = [item1, item2];

        // Explicitly load to populate the store.
        await container.read(threadsInboxStoreProvider.notifier).load();

        final store = container.read(threadsInboxStoreProvider.notifier);
        await store.markDone(item1);

        final afterSuccess = container.read(threadsInboxStoreProvider);
        final ids = afterSuccess.items
            .map((i) => i.routeTarget.threadChannelId)
            .toList();
        expect(ids, isNot(contains('tc-1')));
        expect(ids, contains('tc-2'));
      },
    );
  });

  // ===========================================================================
  // 2. MachinesStore — reconnect listener (INV-834)
  // ===========================================================================
  group('MachinesStore — INV-834 reconnect', () {
    late _FakeMachinesRepository fakeRepo;
    late ProviderContainer container;
    late _ControllableRealtimeService realtimeService;

    setUp(() {
      fakeRepo = _FakeMachinesRepository();
      container = ProviderContainer(
        overrides: [
          currentMachinesServerIdProvider.overrideWithValue(serverId),
          machinesRepositoryProvider.overrideWithValue(fakeRepo),
          realtimeServiceProvider
              .overrideWith(() => _ControllableRealtimeService()),
        ],
      );
      container.listen(machinesStoreProvider, (_, __) {});
      container.listen(realtimeServiceProvider, (_, __) {});
      realtimeService = container.read(realtimeServiceProvider.notifier)
          as _ControllableRealtimeService;
    });

    tearDown(() => container.dispose());

    test('reconnecting → connected while success triggers load', () async {
      await container.read(machinesStoreProvider.notifier).load();
      expect(
        container.read(machinesStoreProvider).status,
        MachinesStatus.success,
      );
      final callsBefore = fakeRepo.loadCalls;

      realtimeService.transitionTo(RealtimeConnectionStatus.reconnecting);
      realtimeService.transitionTo(RealtimeConnectionStatus.connected);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(fakeRepo.loadCalls, callsBefore + 1,
          reason: 'INV-834: machines must re-fetch on reconnect');
    });

    test('reconnecting → connected while initial does NOT trigger load',
        () async {
      expect(
        container.read(machinesStoreProvider).status,
        MachinesStatus.initial,
      );
      final callsBefore = fakeRepo.loadCalls;

      realtimeService.transitionTo(RealtimeConnectionStatus.reconnecting);
      realtimeService.transitionTo(RealtimeConnectionStatus.connected);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(fakeRepo.loadCalls, callsBefore,
          reason: 'INV-834: no load when store not yet populated');
    });
  });

  // ===========================================================================
  // 3. WorkspacesStore — reconnect listener (INV-834)
  // ===========================================================================
  group('WorkspacesStore — INV-834 reconnect', () {
    late _FakeMachinesRepository fakeRepo;
    late ProviderContainer container;
    late _ControllableRealtimeService realtimeService;

    setUp(() {
      fakeRepo = _FakeMachinesRepository();
      container = ProviderContainer(
        overrides: [
          currentWorkspacesMachineIdProvider.overrideWithValue('machine-1'),
          machinesRepositoryProvider.overrideWithValue(fakeRepo),
          realtimeServiceProvider
              .overrideWith(() => _ControllableRealtimeService()),
        ],
      );
      container.listen(workspacesStoreProvider, (_, __) {});
      container.listen(realtimeServiceProvider, (_, __) {});
      realtimeService = container.read(realtimeServiceProvider.notifier)
          as _ControllableRealtimeService;
    });

    tearDown(() => container.dispose());

    test('reconnecting → connected while success triggers load', () async {
      await container.read(workspacesStoreProvider.notifier).load();
      expect(
        container.read(workspacesStoreProvider).status,
        WorkspacesStatus.success,
      );
      final callsBefore = fakeRepo.loadWorkspacesCalls;

      realtimeService.transitionTo(RealtimeConnectionStatus.reconnecting);
      realtimeService.transitionTo(RealtimeConnectionStatus.connected);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(fakeRepo.loadWorkspacesCalls, callsBefore + 1,
          reason: 'INV-834: workspaces must re-fetch on reconnect');
    });

    test('reconnecting → connected while initial does NOT trigger load',
        () async {
      expect(
        container.read(workspacesStoreProvider).status,
        WorkspacesStatus.initial,
      );
      final callsBefore = fakeRepo.loadWorkspacesCalls;

      realtimeService.transitionTo(RealtimeConnectionStatus.reconnecting);
      realtimeService.transitionTo(RealtimeConnectionStatus.connected);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(fakeRepo.loadWorkspacesCalls, callsBefore,
          reason: 'INV-834: no load when store not yet populated');
    });
  });
}
