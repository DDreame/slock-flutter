// ignore_for_file: lines_longer_than_80_chars
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

// ---------------------------------------------------------------------------
// #817 — TasksStore Per-Item Rollback
//
// Verifies that concurrent realtime mutations (upsertTask/removeTask events)
// arriving between optimistic update and API failure are NOT dropped by
// the rollback. Current code snapshots full state.items and restores it
// entirely on failure, losing any interleaved realtime changes.
//
// ROLLBACK-1: updateTaskStatus failure preserves concurrent realtime upsert
// ROLLBACK-2: updateTaskStatus failure preserves concurrent realtime remove
// ROLLBACK-3: deleteTask failure preserves concurrent realtime upsert
// ROLLBACK-4: deleteTask failure preserves concurrent realtime remove
// ROLLBACK-5: claimTask failure preserves concurrent realtime upsert
// ROLLBACK-6: unclaimTask failure preserves concurrent realtime upsert
// ---------------------------------------------------------------------------

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
      createdAt: DateTime(2026, 4, 22),
    );
  }

  late _DelayedFakeTasksRepository fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = _DelayedFakeTasksRepository();
    container = ProviderContainer(overrides: [
      currentTasksServerIdProvider.overrideWithValue(serverId),
      tasksRepositoryProvider.overrideWithValue(fakeRepo),
      sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
    ]);
    // Keep the provider alive during async operations.
    container.listen(tasksStoreProvider, (_, __) {});
  });

  tearDown(() => container.dispose());

  TasksStore store() => container.read(tasksStoreProvider.notifier);
  TasksState state() => container.read(tasksStoreProvider);

  /// Seeds the store with initial tasks synchronously.
  Future<void> seedTasks(List<TaskItem> tasks) async {
    fakeRepo.listResult = tasks;
    await store().load();
    expect(state().status, TasksStatus.success);
  }

  group('TasksStore per-item rollback', () {
    test(
      'updateTaskStatus failure preserves concurrent realtime upsert '
      '(ROLLBACK-1)',
      () async {
        await seedTasks([makeTask(id: 't1', status: 'todo')]);

        // Setup delayed failure for updateStatus.
        final completer = Completer<TaskItem>();
        fakeRepo.statusCompleter = completer;

        // Start optimistic status update.
        final future = store().updateTaskStatus(
          taskId: 't1',
          status: 'in_progress',
        );
        await Future<void>.delayed(Duration.zero);

        // Simulate concurrent realtime event: new task arrives.
        store().upsertTask(makeTask(id: 't-realtime', taskNumber: 99));
        expect(state().items.any((t) => t.id == 't-realtime'), isTrue);

        // API fails — rollback should NOT drop the realtime task.
        completer.completeError(
          const UnknownFailure(message: 'fail', causeType: 'test'),
        );

        try {
          await future;
        } on AppFailure {
          // expected
        }

        // The target task should be rolled back to 'todo'.
        expect(
          state().items.firstWhere((t) => t.id == 't1').status,
          'todo',
        );
        // The realtime-upserted task should survive.
        expect(state().items.any((t) => t.id == 't-realtime'), isTrue);
      },
    );

    test(
      'updateTaskStatus failure preserves concurrent realtime remove '
      '(ROLLBACK-2)',
      () async {
        await seedTasks([
          makeTask(id: 't1', status: 'todo'),
          makeTask(id: 't2', taskNumber: 2, status: 'done'),
        ]);

        final completer = Completer<TaskItem>();
        fakeRepo.statusCompleter = completer;

        final future = store().updateTaskStatus(
          taskId: 't1',
          status: 'in_progress',
        );
        await Future<void>.delayed(Duration.zero);

        // Simulate concurrent realtime event: t2 removed.
        store().removeTask('t2');
        expect(state().items.any((t) => t.id == 't2'), isFalse);

        completer.completeError(
          const UnknownFailure(message: 'fail', causeType: 'test'),
        );

        try {
          await future;
        } on AppFailure {
          // expected
        }

        // t1 rolled back, but t2 should remain gone (not resurrected).
        expect(
          state().items.firstWhere((t) => t.id == 't1').status,
          'todo',
        );
        expect(state().items.any((t) => t.id == 't2'), isFalse);
      },
    );

    test(
      'deleteTask failure preserves concurrent realtime upsert '
      '(ROLLBACK-3)',
      () async {
        await seedTasks([makeTask(id: 't1')]);

        final completer = Completer<void>();
        fakeRepo.deleteCompleter = completer;

        final future = store().deleteTask('t1');
        await Future<void>.delayed(Duration.zero);

        // t1 optimistically removed.
        expect(state().items.any((t) => t.id == 't1'), isFalse);

        // Concurrent realtime: new task arrives.
        store().upsertTask(makeTask(id: 't-realtime', taskNumber: 99));

        completer.completeError(
          const UnknownFailure(message: 'fail', causeType: 'test'),
        );

        try {
          await future;
        } on AppFailure {
          // expected
        }

        // t1 restored (rollback), t-realtime also preserved.
        expect(state().items.any((t) => t.id == 't1'), isTrue);
        expect(state().items.any((t) => t.id == 't-realtime'), isTrue);
      },
    );

    test(
      'deleteTask failure preserves concurrent realtime remove '
      '(ROLLBACK-4)',
      () async {
        await seedTasks([
          makeTask(id: 't1'),
          makeTask(id: 't2', taskNumber: 2),
        ]);

        final completer = Completer<void>();
        fakeRepo.deleteCompleter = completer;

        final future = store().deleteTask('t1');
        await Future<void>.delayed(Duration.zero);

        // Concurrent realtime: t2 removed.
        store().removeTask('t2');

        completer.completeError(
          const UnknownFailure(message: 'fail', causeType: 'test'),
        );

        try {
          await future;
        } on AppFailure {
          // expected
        }

        // t1 restored (rollback), t2 stays gone.
        expect(state().items.any((t) => t.id == 't1'), isTrue);
        expect(state().items.any((t) => t.id == 't2'), isFalse);
      },
    );

    test(
      'deleteTask failure restores item at original position '
      '(ROLLBACK-ORDER)',
      () async {
        await seedTasks([
          makeTask(id: 't1', taskNumber: 1),
          makeTask(id: 't2', taskNumber: 2),
          makeTask(id: 't3', taskNumber: 3),
        ]);

        final completer = Completer<void>();
        fakeRepo.deleteCompleter = completer;

        final future = store().deleteTask('t1');
        await Future<void>.delayed(Duration.zero);

        // t1 optimistically removed — list is [t2, t3].
        expect(state().items.map((t) => t.id).toList(), ['t2', 't3']);

        completer.completeError(
          const UnknownFailure(message: 'fail', causeType: 'test'),
        );

        try {
          await future;
        } on AppFailure {
          // expected
        }

        // t1 restored at original index 0 — order is [t1, t2, t3].
        expect(
          state().items.map((t) => t.id).toList(),
          ['t1', 't2', 't3'],
        );
      },
    );

    test(
      'claimTask failure preserves concurrent realtime upsert '
      '(ROLLBACK-5)',
      () async {
        await seedTasks([makeTask(id: 't1')]);

        final completer = Completer<TaskItem>();
        fakeRepo.claimCompleter = completer;

        final future = store().claimTask('t1');
        await Future<void>.delayed(Duration.zero);

        // Concurrent realtime: new task arrives.
        store().upsertTask(makeTask(id: 't-realtime', taskNumber: 99));

        completer.completeError(
          const UnknownFailure(message: 'fail', causeType: 'test'),
        );

        try {
          await future;
        } on AppFailure {
          // expected
        }

        // t1 rolled back (no claim), t-realtime preserved.
        expect(
            state().items.firstWhere((t) => t.id == 't1').claimedById, isNull);
        expect(state().items.any((t) => t.id == 't-realtime'), isTrue);
      },
    );

    test(
      'unclaimTask failure preserves concurrent realtime upsert '
      '(ROLLBACK-6)',
      () async {
        await seedTasks([
          makeTask(id: 't1').copyWith(
            claimedById: 'user-1',
            claimedByName: 'User',
          ),
        ]);

        final completer = Completer<TaskItem>();
        fakeRepo.unclaimCompleter = completer;

        final future = store().unclaimTask('t1');
        await Future<void>.delayed(Duration.zero);

        // Concurrent realtime: new task arrives.
        store().upsertTask(makeTask(id: 't-realtime', taskNumber: 99));

        completer.completeError(
          const UnknownFailure(message: 'fail', causeType: 'test'),
        );

        try {
          await future;
        } on AppFailure {
          // expected
        }

        // t1 rolled back (claim restored), t-realtime preserved.
        expect(
          state().items.firstWhere((t) => t.id == 't1').claimedById,
          'user-1',
        );
        expect(state().items.any((t) => t.id == 't-realtime'), isTrue);
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _DelayedFakeTasksRepository implements TasksRepository {
  List<TaskItem>? listResult;
  Completer<TaskItem>? statusCompleter;
  Completer<void>? deleteCompleter;
  Completer<TaskItem>? claimCompleter;
  Completer<TaskItem>? unclaimCompleter;

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async {
    return listResult ?? [];
  }

  @override
  Future<List<TaskItem>> createTasks(
    ServerScopeId serverId, {
    required String channelId,
    required List<String> titles,
  }) async {
    return [];
  }

  @override
  Future<TaskItem> updateTaskStatus(
    ServerScopeId serverId, {
    required String taskId,
    required String status,
  }) {
    return statusCompleter!.future;
  }

  @override
  Future<void> deleteTask(
    ServerScopeId serverId, {
    required String taskId,
  }) {
    return deleteCompleter!.future;
  }

  @override
  Future<TaskItem> claimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) {
    return claimCompleter!.future;
  }

  @override
  Future<TaskItem> unclaimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) {
    return unclaimCompleter!.future;
  }

  @override
  Future<TaskItem> convertMessageToTask(
    ServerScopeId serverId, {
    required String messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<TaskItem> getTaskByNumber(
    ServerScopeId serverId, {
    required String channelId,
    required int taskNumber,
  }) async {
    throw UnimplementedError();
  }
}

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-1',
        displayName: 'User',
      );
}
