// =============================================================================
// #838 — P1 TasksStore Concurrency Hardening
//
// Invariants verified:
// INV-838-GUARD-1: claimTask/unclaimTask/updateTaskStatus return gracefully
//                  when task was concurrently deleted (no StateError)
// INV-838-GUARD-2: deleteTask returns gracefully when task already gone
//                  (no RangeError from indexWhere == -1)
// INV-838-GUARD-3: Rapid double-tap → only one API call per taskId
//                  (_busyTaskIds re-entrancy guard)
// INV-838-GUARD-4: Concurrent load() calls → stale response discarded
//                  (request epoch pattern)
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';

void main() {
  const serverId = ServerScopeId('server-1');

  TaskItem makeTask({
    String id = 'task-1',
    int taskNumber = 1,
    String title = 'Test task',
    String status = 'todo',
    String channelId = 'ch1',
  }) {
    return TaskItem(
      id: id,
      taskNumber: taskNumber,
      title: title,
      status: status,
      channelId: channelId,
      channelType: 'channel',
      createdById: 'user-1',
      createdByName: 'User',
      createdByType: 'user',
      createdAt: DateTime(2026, 5, 27),
    );
  }

  late _ConcurrencyTestRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = _ConcurrencyTestRepository();
    container = ProviderContainer(overrides: [
      currentTasksServerIdProvider.overrideWithValue(serverId),
      tasksRepositoryProvider.overrideWithValue(fakeRepo),
    ]);
  });

  tearDown(() => container.dispose());

  TasksStore store() => container.read(tasksStoreProvider.notifier);
  TasksState state() => container.read(tasksStoreProvider);

  // ---------------------------------------------------------------------------
  // INV-838-GUARD-1: firstWhere guards — no StateError on missing task
  // ---------------------------------------------------------------------------
  group('INV-838-GUARD-1: firstWhere null-safety', () {
    test('claimTask returns gracefully when task concurrently deleted',
        () async {
      // Load a task, then simulate WS deleting it before claimTask resolves.
      fakeRepo.listResult = [makeTask(id: 'task-1')];
      await store().load();
      expect(state().items.length, 1);

      // Simulate concurrent WS deletion: remove task from state.
      store().removeTask('task-1');
      expect(state().items, isEmpty);

      // claimTask must NOT throw StateError — should return gracefully.
      await expectLater(
        store().claimTask('task-1'),
        completes,
      );
    });

    test('unclaimTask returns gracefully when task concurrently deleted',
        () async {
      fakeRepo.listResult = [
        makeTask(id: 'task-1').copyWith(
          claimedById: 'user-1',
          claimedByName: 'User',
        ),
      ];
      await store().load();

      // Simulate concurrent WS deletion.
      store().removeTask('task-1');

      await expectLater(
        store().unclaimTask('task-1'),
        completes,
      );
    });

    test('updateTaskStatus returns gracefully when task concurrently deleted',
        () async {
      fakeRepo.listResult = [makeTask(id: 'task-1', status: 'todo')];
      await store().load();

      // Simulate concurrent WS deletion.
      store().removeTask('task-1');

      await expectLater(
        store().updateTaskStatus(taskId: 'task-1', status: 'in_progress'),
        completes,
      );
    });

    test('claimTask on missing task does NOT call API', () async {
      fakeRepo.listResult = [makeTask(id: 'task-1')];
      await store().load();
      store().removeTask('task-1');

      await store().claimTask('task-1');

      expect(fakeRepo.claimCalls, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // INV-838-GUARD-2: indexWhere bounds check — no RangeError on index -1
  // ---------------------------------------------------------------------------
  group('INV-838-GUARD-2: deleteTask bounds check', () {
    test('deleteTask returns gracefully when task already gone', () async {
      fakeRepo.listResult = [
        makeTask(id: 'task-1'),
        makeTask(id: 'task-2', taskNumber: 2)
      ];
      await store().load();

      // Simulate concurrent deletion via WS.
      store().removeTask('task-1');

      // Second deleteTask should NOT throw RangeError.
      await expectLater(
        store().deleteTask('task-1'),
        completes,
      );
    });

    test('deleteTask on missing task does NOT call API', () async {
      fakeRepo.listResult = [makeTask(id: 'task-1')];
      await store().load();
      store().removeTask('task-1');

      await store().deleteTask('task-1');

      expect(fakeRepo.deleteCalls, 0);
    });

    test('deleteTask on existing task still works normally', () async {
      fakeRepo.listResult = [
        makeTask(id: 'task-1'),
        makeTask(id: 'task-2', taskNumber: 2)
      ];
      await store().load();

      await store().deleteTask('task-1');

      expect(state().items.length, 1);
      expect(state().items.first.id, 'task-2');
      expect(fakeRepo.deleteCalls, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // INV-838-GUARD-3: Double-tap re-entrancy guard
  // ---------------------------------------------------------------------------
  group('INV-838-GUARD-3: _busyTaskIds double-tap protection', () {
    test('rapid claimTask calls produce only one API request', () async {
      fakeRepo.listResult = [makeTask(id: 'task-1')];
      await store().load();

      // Slow claim response.
      final claimCompleter = Completer<TaskItem>();
      fakeRepo.claimCompleter = claimCompleter;

      // Fire two claims rapidly.
      final first = store().claimTask('task-1');
      final second = store().claimTask('task-1');

      // Complete the API call.
      claimCompleter.complete(makeTask(id: 'task-1').copyWith(
        claimedById: 'user-1',
        claimedByName: 'User',
      ));
      await first;
      await second;

      expect(fakeRepo.claimCalls, 1,
          reason: 'Second tap must be silently ignored');
    });

    test('rapid unclaimTask calls produce only one API request', () async {
      fakeRepo.listResult = [
        makeTask(id: 'task-1').copyWith(
          claimedById: 'user-1',
          claimedByName: 'User',
        ),
      ];
      await store().load();

      final unclaimCompleter = Completer<TaskItem>();
      fakeRepo.unclaimCompleter = unclaimCompleter;

      final first = store().unclaimTask('task-1');
      final second = store().unclaimTask('task-1');

      unclaimCompleter
          .complete(makeTask(id: 'task-1').copyWith(clearClaim: true));
      await first;
      await second;

      expect(fakeRepo.unclaimCalls, 1);
    });

    test('rapid updateTaskStatus calls produce only one API request', () async {
      fakeRepo.listResult = [makeTask(id: 'task-1', status: 'todo')];
      await store().load();

      final statusCompleter = Completer<TaskItem>();
      fakeRepo.statusCompleter = statusCompleter;

      final first =
          store().updateTaskStatus(taskId: 'task-1', status: 'in_progress');
      final second =
          store().updateTaskStatus(taskId: 'task-1', status: 'in_progress');

      statusCompleter.complete(makeTask(id: 'task-1', status: 'in_progress'));
      await first;
      await second;

      expect(fakeRepo.statusCalls, 1);
    });

    test('rapid deleteTask calls produce only one API request', () async {
      fakeRepo.listResult = [makeTask(id: 'task-1')];
      await store().load();

      final deleteCompleter = Completer<void>();
      fakeRepo.deleteCompleter = deleteCompleter;

      final first = store().deleteTask('task-1');
      final second = store().deleteTask('task-1');

      deleteCompleter.complete();
      await first;
      await second;

      expect(fakeRepo.deleteCalls, 1);
    });

    test('busyTaskIds guard is released after operation completes', () async {
      fakeRepo.listResult = [makeTask(id: 'task-1')];
      await store().load();

      fakeRepo.claimCompleter = Completer<TaskItem>()
        ..complete(makeTask(id: 'task-1').copyWith(
          claimedById: 'user-1',
          claimedByName: 'User',
        ));

      await store().claimTask('task-1');
      expect(fakeRepo.claimCalls, 1);

      // After completion, a new claim should work.
      fakeRepo.claimCompleter = Completer<TaskItem>()
        ..complete(makeTask(id: 'task-1').copyWith(
          claimedById: 'user-1',
          claimedByName: 'User',
        ));

      await store().claimTask('task-1');
      expect(fakeRepo.claimCalls, 2,
          reason: 'Guard must be released after first call completes');
    });

    test('busyTaskIds guard released even on failure', () async {
      fakeRepo.listResult = [makeTask(id: 'task-1')];
      await store().load();

      fakeRepo.shouldFail = true;

      try {
        await store().claimTask('task-1');
      } on AppFailure {
        // expected
      }
      expect(fakeRepo.claimCalls, 1);

      fakeRepo.shouldFail = false;
      fakeRepo.claimCompleter = Completer<TaskItem>()
        ..complete(makeTask(id: 'task-1').copyWith(
          claimedById: 'user-1',
          claimedByName: 'User',
        ));

      await store().claimTask('task-1');
      expect(fakeRepo.claimCalls, 2,
          reason: 'Guard must be released after failure');
    });
  });

  // ---------------------------------------------------------------------------
  // INV-838-GUARD-4: Load deduplication — request epoch
  // ---------------------------------------------------------------------------
  group('INV-838-GUARD-4: load() request epoch', () {
    test('concurrent loads: stale first response discarded', () async {
      // First load is slow, second is fast.
      final slowCompleter = Completer<List<TaskItem>>();
      final fastCompleter = Completer<List<TaskItem>>();

      var callCount = 0;
      fakeRepo.listHandler = () {
        callCount++;
        if (callCount == 1) return slowCompleter.future;
        return fastCompleter.future;
      };

      final sub = container.listen(tasksStoreProvider, (_, __) {});
      addTearDown(sub.close);

      // Trigger first load (reconnect listener).
      final first = store().load();
      await Future<void>.delayed(Duration.zero);

      // Trigger second load (pull-to-refresh) before first resolves.
      final second = store().load();
      await Future<void>.delayed(Duration.zero);

      // Second response arrives first (the "fresh" data).
      fastCompleter.complete([
        makeTask(id: 'fresh-1', title: 'Fresh data'),
      ]);
      await second;

      // First (stale) response arrives after.
      slowCompleter.complete([
        makeTask(id: 'stale-1', title: 'Stale data'),
      ]);
      await first;

      // State must reflect the SECOND (fresher) response, not the stale one.
      expect(state().items.length, 1);
      expect(state().items.first.id, 'fresh-1',
          reason: 'Stale response must be discarded');
    });

    test('single load works normally', () async {
      fakeRepo.listResult = [makeTask(id: 'task-1', title: 'Normal')];

      await store().load();

      expect(state().status, TasksStatus.success);
      expect(state().items.first.title, 'Normal');
    });

    test('sequential loads both apply (no false-positive staleness)', () async {
      fakeRepo.listResult = [makeTask(id: 'task-1', title: 'First load')];
      await store().load();
      expect(state().items.first.title, 'First load');

      fakeRepo.listResult = [makeTask(id: 'task-2', title: 'Second load')];
      await store().load();
      expect(state().items.first.title, 'Second load');
    });
  });
}

// =============================================================================
// Test helper: Fake repository with Completer-based async control
// =============================================================================
class _ConcurrencyTestRepository implements TasksRepository {
  List<TaskItem>? listResult;
  Future<List<TaskItem>> Function()? listHandler;
  int listCalls = 0;
  int claimCalls = 0;
  int unclaimCalls = 0;
  int statusCalls = 0;
  int deleteCalls = 0;
  bool shouldFail = false;

  Completer<TaskItem>? claimCompleter;
  Completer<TaskItem>? unclaimCompleter;
  Completer<TaskItem>? statusCompleter;
  Completer<void>? deleteCompleter;

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async {
    listCalls++;
    if (shouldFail) {
      throw const UnknownFailure(message: 'Load failed', causeType: 'test');
    }
    final handler = listHandler;
    if (handler != null) return handler();
    return listResult ?? [];
  }

  @override
  Future<List<TaskItem>> createTasks(
    ServerScopeId serverId, {
    required String channelId,
    required List<String> titles,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<TaskItem> updateTaskStatus(
    ServerScopeId serverId, {
    required String taskId,
    required String status,
  }) async {
    statusCalls++;
    if (shouldFail) {
      throw const UnknownFailure(message: 'Update failed', causeType: 'test');
    }
    final completer = statusCompleter;
    if (completer != null) return completer.future;
    return TaskItem(
      id: taskId,
      taskNumber: 1,
      title: 'Task',
      status: status,
      channelId: 'ch1',
      channelType: 'channel',
      createdById: 'user-1',
      createdByName: 'User',
      createdByType: 'user',
      createdAt: DateTime(2026, 5, 27),
    );
  }

  @override
  Future<void> deleteTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async {
    deleteCalls++;
    if (shouldFail) {
      throw const UnknownFailure(message: 'Delete failed', causeType: 'test');
    }
    final completer = deleteCompleter;
    if (completer != null) return completer.future;
  }

  @override
  Future<TaskItem> claimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async {
    claimCalls++;
    if (shouldFail) {
      throw const UnknownFailure(message: 'Claim failed', causeType: 'test');
    }
    final completer = claimCompleter;
    if (completer != null) return completer.future;
    return TaskItem(
      id: taskId,
      taskNumber: 1,
      title: 'Task',
      status: 'todo',
      channelId: 'ch1',
      channelType: 'channel',
      claimedById: 'user-1',
      claimedByName: 'User',
      claimedByType: 'human',
      claimedAt: DateTime.now(),
      createdById: 'user-1',
      createdByName: 'User',
      createdByType: 'user',
      createdAt: DateTime(2026, 5, 27),
    );
  }

  @override
  Future<TaskItem> unclaimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async {
    unclaimCalls++;
    if (shouldFail) {
      throw const UnknownFailure(message: 'Unclaim failed', causeType: 'test');
    }
    final completer = unclaimCompleter;
    if (completer != null) return completer.future;
    return TaskItem(
      id: taskId,
      taskNumber: 1,
      title: 'Task',
      status: 'todo',
      channelId: 'ch1',
      channelType: 'channel',
      createdById: 'user-1',
      createdByName: 'User',
      createdByType: 'user',
      createdAt: DateTime(2026, 5, 27),
    );
  }

  @override
  Future<TaskItem> convertMessageToTask(
    ServerScopeId serverId, {
    required String messageId,
  }) async {
    throw UnimplementedError();
  }
}
