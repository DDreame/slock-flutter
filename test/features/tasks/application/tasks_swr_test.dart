import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';

// ---------------------------------------------------------------------------
// #496 Phase A: TaskListStore SWR + Lifecycle Invariant Tests
//
// Invariants verified:
// INV-CACHE-SWR-1: Stale task list remains visible during refresh.
// INV-CACHE-SWR-2: Task list is never cleared then reloaded.
// INV-NET-DEGRADE-1: Network error during refresh preserves stale data.
// INV-LIFECYCLE-1: TasksStore must use keepAlive (session-scoped).
//
// Active tests establish the current behavior baseline.
// Skip+TODO tests define target behavior for Phase B.
// ---------------------------------------------------------------------------

void main() {
  const serverId = ServerScopeId('server-1');

  // -----------------------------------------------------------------------
  // Seed data
  // -----------------------------------------------------------------------

  TaskItem makeTask({
    String id = 'task-1',
    int taskNumber = 1,
    String title = 'Test task',
    String status = 'todo',
    String channelId = 'ch-1',
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
      createdAt: DateTime(2026, 5, 1),
    );
  }

  final seedTasks = [
    makeTask(id: 't1', taskNumber: 1, title: 'Alpha task'),
    makeTask(
      id: 't2',
      taskNumber: 2,
      title: 'Beta task',
      status: 'in_progress',
    ),
    makeTask(id: 't3', taskNumber: 3, title: 'Gamma task', status: 'done'),
  ];

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  ProviderContainer createContainer(_ControllableTasksRepository repo) {
    return ProviderContainer(
      overrides: [
        currentTasksServerIdProvider.overrideWithValue(serverId),
        tasksRepositoryProvider.overrideWithValue(repo),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Baseline: initial load transitions
  // -----------------------------------------------------------------------
  group('Baseline: initial load behavior', () {
    test('initial load transitions from initial → loading → success', () async {
      final repo = _ControllableTasksRepository();
      final container = createContainer(repo);
      addTearDown(container.dispose);

      final sub = container.listen(tasksStoreProvider, (_, __) {});

      // State starts as initial.
      expect(container.read(tasksStoreProvider).status, TasksStatus.initial);

      // Start load — grab completer to control timing.
      final completer = repo.nextListCall();
      final loadFuture = container.read(tasksStoreProvider.notifier).load();

      // Mid-flight: status should be loading.
      expect(container.read(tasksStoreProvider).status, TasksStatus.loading);

      // Complete the fetch.
      completer.complete(seedTasks);
      await loadFuture;

      // Final: success with data.
      final state = container.read(tasksStoreProvider);
      expect(state.status, TasksStatus.success);
      expect(state.items, hasLength(3));
      expect(state.items.map((t) => t.title), [
        'Alpha task',
        'Beta task',
        'Gamma task',
      ]);
      sub.close();
    });

    test('initial load failure transitions to failure status', () async {
      final repo = _ControllableTasksRepository();
      final container = createContainer(repo);
      addTearDown(container.dispose);

      final sub = container.listen(tasksStoreProvider, (_, __) {});

      final completer = repo.nextListCall();
      final loadFuture = container.read(tasksStoreProvider.notifier).load();

      // Mid-flight: loading.
      expect(container.read(tasksStoreProvider).status, TasksStatus.loading);

      // Fail the fetch.
      completer.completeError(
        const ServerFailure(message: 'Server error', statusCode: 500),
      );
      await loadFuture;

      // Final: failure with error.
      final state = container.read(tasksStoreProvider);
      expect(state.status, TasksStatus.failure);
      expect(state.failure, isA<ServerFailure>());
      expect(state.items, isEmpty,
          reason: 'No stale data to preserve on initial load failure');
      sub.close();
    });
  });

  // -----------------------------------------------------------------------
  // INV-CACHE-SWR-1 / INV-CACHE-SWR-2: SWR refresh behavior
  // -----------------------------------------------------------------------
  group('INV-CACHE-SWR: SWR refresh preserves stale data', () {
    test(
      'stale task list remains present during refresh '
      '(INV-CACHE-SWR-1 — data preservation)',
      () async {
        final repo = _ControllableTasksRepository();
        final container = createContainer(repo);
        addTearDown(container.dispose);

        final sub = container.listen(tasksStoreProvider, (_, __) {});

        // Initial load — seed stale data.
        final c1 = repo.nextListCall();
        final f1 = container.read(tasksStoreProvider.notifier).load();
        c1.complete(seedTasks);
        await f1;
        expect(container.read(tasksStoreProvider).status, TasksStatus.success);
        expect(container.read(tasksStoreProvider).items, hasLength(3));

        // Start second load (refresh).
        final c2 = repo.nextListCall();
        // ignore: unawaited_futures
        container.read(tasksStoreProvider.notifier).load();

        // Mid-flight: stale items must remain in state.
        // load() changes status but does NOT clear items.
        final midState = container.read(tasksStoreProvider);
        expect(midState.items, hasLength(3),
            reason: 'INV-CACHE-SWR-1: stale task list must remain '
                'present during refresh — load() must not clear items');
        expect(midState.items.map((t) => t.title), [
          'Alpha task',
          'Beta task',
          'Gamma task',
        ]);

        // Complete refresh with updated data.
        final updatedTasks = [
          makeTask(id: 't1', taskNumber: 1, title: 'Alpha-v2'),
          makeTask(id: 't4', taskNumber: 4, title: 'Delta task'),
        ];
        c2.complete(updatedTasks);
        await Future.delayed(Duration.zero);

        // Final: new data replaces stale.
        final finalState = container.read(tasksStoreProvider);
        expect(finalState.items, hasLength(2));
        expect(
            finalState.items.map((t) => t.title), ['Alpha-v2', 'Delta task']);
        sub.close();
      },
    );

    test(
      'refresh exposes SWR status signal instead of full-screen loading '
      '(INV-CACHE-SWR-1 — status signal)',
      () async {
        final repo = _ControllableTasksRepository();
        final container = createContainer(repo);
        addTearDown(container.dispose);

        final sub = container.listen(tasksStoreProvider, (_, __) {});

        // Initial load — seed stale data.
        final c1 = repo.nextListCall();
        final f1 = container.read(tasksStoreProvider.notifier).load();
        c1.complete(seedTasks);
        await f1;

        // Start second load (refresh).
        final c2 = repo.nextListCall();
        // ignore: unawaited_futures
        container.read(tasksStoreProvider.notifier).load();

        // Mid-flight: status should remain success (not revert to loading).
        // Phase B adds isRefreshing field as the SWR signal.
        final midState = container.read(tasksStoreProvider);
        expect(midState.status, TasksStatus.success,
            reason: 'INV-CACHE-SWR-1: status must remain success during '
                'SWR refresh — use isRefreshing for loading signal');

        c2.complete(seedTasks);
        await Future.delayed(Duration.zero);
        sub.close();
      },
    );

    test(
      'task list is never cleared during refresh (INV-CACHE-SWR-2)',
      () async {
        final repo = _ControllableTasksRepository();
        final container = createContainer(repo);
        addTearDown(container.dispose);

        final sub = container.listen(tasksStoreProvider, (_, __) {});

        // Initial load.
        final c1 = repo.nextListCall();
        final f1 = container.read(tasksStoreProvider.notifier).load();
        c1.complete(seedTasks);
        await f1;

        // Start refresh — capture states during load.
        final states = <TasksState>[];
        container.listen(tasksStoreProvider, (_, next) => states.add(next));

        final c2 = repo.nextListCall();
        final f2 = container.read(tasksStoreProvider.notifier).load();
        c2.complete(seedTasks);
        await f2;

        // No intermediate state should have an empty items list.
        for (final s in states) {
          expect(s.items, isNotEmpty,
              reason: 'INV-CACHE-SWR-2: task list must never be cleared '
                  'during refresh — found empty items in intermediate state '
                  '(status=${s.status})');
        }
        sub.close();
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-NET-DEGRADE-1: error during refresh preserves stale data
  // -----------------------------------------------------------------------
  group('INV-NET-DEGRADE-1: error during refresh', () {
    test(
      'stale task list survives refresh error (data preservation)',
      () async {
        final repo = _ControllableTasksRepository();
        final container = createContainer(repo);
        addTearDown(container.dispose);

        final sub = container.listen(tasksStoreProvider, (_, __) {});

        // Initial load — seed stale data.
        final c1 = repo.nextListCall();
        final f1 = container.read(tasksStoreProvider.notifier).load();
        c1.complete(seedTasks);
        await f1;
        expect(container.read(tasksStoreProvider).items, hasLength(3));

        // Start refresh, then fail it.
        final c2 = repo.nextListCall();
        final f2 = container.read(tasksStoreProvider.notifier).load();
        c2.completeError(
          const ServerFailure(message: 'Refresh failed', statusCode: 503),
        );
        await f2;

        // Stale items must survive the error.
        // load() sets status=failure but does NOT clear items.
        final state = container.read(tasksStoreProvider);
        expect(state.items, hasLength(3),
            reason: 'INV-NET-DEGRADE-1: stale task list must survive '
                'refresh error — load() must not clear items');
        expect(
            state.items.map((t) => t.title),
            [
              'Alpha task',
              'Beta task',
              'Gamma task',
            ],
            reason: 'Task data from initial load must be preserved');
        sub.close();
      },
    );

    test(
      'refresh error keeps success status with failure overlay '
      '(INV-NET-DEGRADE-1 — error overlay signal)',
      () async {
        final repo = _ControllableTasksRepository();
        final container = createContainer(repo);
        addTearDown(container.dispose);

        final sub = container.listen(tasksStoreProvider, (_, __) {});

        // Initial load.
        final c1 = repo.nextListCall();
        final f1 = container.read(tasksStoreProvider.notifier).load();
        c1.complete(seedTasks);
        await f1;

        // Refresh with error.
        final c2 = repo.nextListCall();
        final f2 = container.read(tasksStoreProvider.notifier).load();
        c2.completeError(
          const ServerFailure(message: 'Network timeout', statusCode: 504),
        );
        await f2;

        // Status should remain success (not flip to failure) when
        // stale data exists. Error is surfaced via state.failure
        // as an overlay.
        final state = container.read(tasksStoreProvider);
        expect(state.status, TasksStatus.success,
            reason: 'INV-NET-DEGRADE-1: status must remain success when '
                'stale data exists after refresh error');
        expect(state.failure, isA<ServerFailure>(),
            reason: 'Error must be surfaced via state.failure for '
                'error overlay display');
        sub.close();
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-LIFECYCLE-1: keepAlive behavior
  // -----------------------------------------------------------------------
  group('INV-LIFECYCLE-1: TasksStore lifecycle', () {
    test(
      'provider retains state after listener removal (keepAlive)',
      () async {
        final repo = _ControllableTasksRepository();
        final container = createContainer(repo);
        addTearDown(container.dispose);

        // Add listener and load.
        final sub = container.listen(tasksStoreProvider, (_, __) {});
        final c1 = repo.nextListCall();
        final f1 = container.read(tasksStoreProvider.notifier).load();
        c1.complete(seedTasks);
        await f1;
        expect(container.read(tasksStoreProvider).status, TasksStatus.success);
        expect(container.read(tasksStoreProvider).items, hasLength(3));

        // Simulate tab switch: close listener.
        sub.close();
        await Future.delayed(Duration.zero);

        // keepAlive: state should be retained.
        final state = container.read(tasksStoreProvider);
        expect(state.status, TasksStatus.success,
            reason: 'INV-LIFECYCLE-1: TasksStore must retain state '
                'after listener removal (keepAlive)');
        expect(state.items, hasLength(3),
            reason: 'Task data must persist across tab switches');
      },
    );

    test(
      'no re-fetch on tab return (keepAlive retains data)',
      () async {
        final repo = _ControllableTasksRepository();
        final container = createContainer(repo);
        addTearDown(container.dispose);

        // First tab visit: load data.
        final sub1 = container.listen(tasksStoreProvider, (_, __) {});
        final c1 = repo.nextListCall();
        final f1 = container.read(tasksStoreProvider.notifier).load();
        c1.complete(seedTasks);
        await f1;
        expect(repo.loadCount, 1);
        sub1.close();

        await Future.delayed(Duration.zero);

        // Second tab visit: state should already have data.
        final sub2 = container.listen(tasksStoreProvider, (_, __) {});
        final state = container.read(tasksStoreProvider);
        expect(state.status, TasksStatus.success,
            reason: 'keepAlive: state survives between tab visits');
        expect(state.items, hasLength(3),
            reason: 'Task data persists without re-fetch');
        expect(repo.loadCount, 1,
            reason: 'No re-fetch on tab return — keepAlive retains data');
        sub2.close();
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Completer-based tasks repository for SWR timing tests.
///
/// Call [nextListCall] to arm a [Completer] before triggering [listServerTasks].
/// The completer controls when the async call resolves, allowing mid-flight
/// state assertions.
class _ControllableTasksRepository implements TasksRepository {
  Completer<List<TaskItem>>? _listCompleter;
  int loadCount = 0;

  /// Arm a new completer for the next [listServerTasks] call.
  Completer<List<TaskItem>> nextListCall() {
    _listCompleter = Completer<List<TaskItem>>();
    return _listCompleter!;
  }

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async {
    loadCount++;
    if (_listCompleter != null) {
      final completer = _listCompleter!;
      _listCompleter = null;
      return completer.future;
    }
    return const [];
  }

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
