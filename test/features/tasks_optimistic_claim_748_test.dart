// =============================================================================
// #748 — TasksStore Optimistic Claim/Unclaim
//
// Tests verify:
// 1. Optimistic state appears immediately before API resolves
// 2. On failure, state rolls back to previous assignee
// 3. On success, final state matches API response
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  const serverId = ServerScopeId('server-1');

  final sampleTask = TaskItem(
    id: 'task-1',
    taskNumber: 1,
    title: 'Test task',
    status: 'todo',
    channelId: 'ch-1',
    channelType: 'channel',
    createdById: 'user-a',
    createdByName: 'Alice',
    createdByType: 'human',
    createdAt: DateTime(2026),
  );

  ProviderContainer createContainer({
    required TasksRepository tasksRepository,
    String? userId,
    String? displayName,
  }) {
    return ProviderContainer(
      overrides: [
        currentTasksServerIdProvider.overrideWithValue(serverId),
        tasksRepositoryProvider.overrideWithValue(tasksRepository),
        sessionStoreProvider.overrideWith(
          () => _FakeSessionStore(
            userId: userId ?? 'current-user',
            displayName: displayName ?? 'Current User',
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // claimTask optimistic
  // ---------------------------------------------------------------------------
  group('#748 — TasksStore.claimTask optimistic', () {
    test('optimistic claim appears immediately before API resolves', () async {
      final claimCompleter = Completer<TaskItem>();
      final repo = _ControllableTasksRepository(
        tasks: [sampleTask],
        claimCompleter: claimCompleter,
      );
      final container = createContainer(tasksRepository: repo);
      addTearDown(container.dispose);
      container.listen(tasksStoreProvider, (_, __) {});

      // Load initial state.
      await container.read(tasksStoreProvider.notifier).load();
      expect(
        container.read(tasksStoreProvider).items.first.claimedById,
        isNull,
      );

      // Start claimTask — should be optimistic immediately.
      final future =
          container.read(tasksStoreProvider.notifier).claimTask('task-1');

      // Mid-flight: optimistic state shows current user as assignee.
      final midState = container.read(tasksStoreProvider);
      expect(midState.items.first.claimedById, 'current-user',
          reason: '#748: Optimistic claim must appear before API resolves');
      expect(midState.items.first.claimedByName, 'Current User');

      // Complete API with server response.
      claimCompleter.complete(sampleTask.copyWith(
        claimedById: 'current-user',
        claimedByName: 'Current User',
        claimedByType: 'human',
        claimedAt: DateTime(2026, 1, 1, 12),
      ));
      await future;

      // Final state matches server response.
      final finalState = container.read(tasksStoreProvider);
      expect(finalState.items.first.claimedById, 'current-user');
      expect(finalState.items.first.claimedAt, DateTime(2026, 1, 1, 12));
    });

    test('claimTask rolls back on API failure', () async {
      final claimCompleter = Completer<TaskItem>();
      final repo = _ControllableTasksRepository(
        tasks: [sampleTask],
        claimCompleter: claimCompleter,
      );
      final container = createContainer(tasksRepository: repo);
      addTearDown(container.dispose);
      container.listen(tasksStoreProvider, (_, __) {});

      await container.read(tasksStoreProvider.notifier).load();

      // Start claim.
      final future =
          container.read(tasksStoreProvider.notifier).claimTask('task-1');

      // Verify optimistic.
      expect(
        container.read(tasksStoreProvider).items.first.claimedById,
        'current-user',
      );

      // Fail the API.
      claimCompleter.completeError(
        const ServerFailure(message: 'conflict', statusCode: 409),
      );

      // Expect the error to propagate.
      await expectLater(future, throwsA(isA<AppFailure>()));

      // State must be rolled back to unclaimed.
      final rolledBack = container.read(tasksStoreProvider);
      expect(rolledBack.items.first.claimedById, isNull,
          reason: '#748: Claim must roll back on API failure');
    });

    test('claimTask rollback restores previous assignee (edge case)', () async {
      // Task already claimed by someone else.
      final alreadyClaimed = sampleTask.copyWith(
        claimedById: 'other-user',
        claimedByName: 'Other User',
        claimedByType: 'human',
        claimedAt: DateTime(2026, 1, 1),
      );
      final claimCompleter = Completer<TaskItem>();
      final repo = _ControllableTasksRepository(
        tasks: [alreadyClaimed],
        claimCompleter: claimCompleter,
      );
      final container = createContainer(tasksRepository: repo);
      addTearDown(container.dispose);
      container.listen(tasksStoreProvider, (_, __) {});

      await container.read(tasksStoreProvider.notifier).load();
      expect(
        container.read(tasksStoreProvider).items.first.claimedById,
        'other-user',
      );

      // Start claim (try to take over).
      final future =
          container.read(tasksStoreProvider.notifier).claimTask('task-1');

      // Optimistic shows current user.
      expect(
        container.read(tasksStoreProvider).items.first.claimedById,
        'current-user',
      );

      // Fail — conflict (someone else already claimed).
      claimCompleter.completeError(
        const ServerFailure(message: 'already claimed', statusCode: 409),
      );
      await expectLater(future, throwsA(isA<AppFailure>()));

      // Must restore the previous assignee, not null.
      final rolledBack = container.read(tasksStoreProvider);
      expect(rolledBack.items.first.claimedById, 'other-user',
          reason:
              '#748: Rollback must restore exact previous assignee, not null');
      expect(rolledBack.items.first.claimedByName, 'Other User');
    });
  });

  // ---------------------------------------------------------------------------
  // unclaimTask optimistic
  // ---------------------------------------------------------------------------
  group('#748 — TasksStore.unclaimTask optimistic', () {
    test('optimistic unclaim clears assignee immediately', () async {
      final claimed = sampleTask.copyWith(
        claimedById: 'current-user',
        claimedByName: 'Current User',
        claimedByType: 'human',
        claimedAt: DateTime(2026, 1, 1),
      );
      final unclaimCompleter = Completer<TaskItem>();
      final repo = _ControllableTasksRepository(
        tasks: [claimed],
        unclaimCompleter: unclaimCompleter,
      );
      final container = createContainer(tasksRepository: repo);
      addTearDown(container.dispose);
      container.listen(tasksStoreProvider, (_, __) {});

      await container.read(tasksStoreProvider.notifier).load();
      expect(
        container.read(tasksStoreProvider).items.first.claimedById,
        'current-user',
      );

      // Start unclaim.
      final future =
          container.read(tasksStoreProvider.notifier).unclaimTask('task-1');

      // Optimistic: assignee cleared immediately.
      final midState = container.read(tasksStoreProvider);
      expect(midState.items.first.claimedById, isNull,
          reason: '#748: Optimistic unclaim must clear assignee immediately');

      // Complete API.
      unclaimCompleter.complete(TaskItem(
        id: 'task-1',
        taskNumber: 1,
        title: 'Test task',
        status: 'todo',
        channelId: 'ch-1',
        channelType: 'channel',
        createdById: 'user-a',
        createdByName: 'Alice',
        createdByType: 'human',
        createdAt: DateTime(2026),
      ));
      await future;

      // Final state confirmed unclaimed.
      final finalState = container.read(tasksStoreProvider);
      expect(finalState.items.first.claimedById, isNull);
    });

    test('unclaimTask rolls back on API failure', () async {
      final claimed = sampleTask.copyWith(
        claimedById: 'current-user',
        claimedByName: 'Current User',
        claimedByType: 'human',
        claimedAt: DateTime(2026, 1, 1),
      );
      final unclaimCompleter = Completer<TaskItem>();
      final repo = _ControllableTasksRepository(
        tasks: [claimed],
        unclaimCompleter: unclaimCompleter,
      );
      final container = createContainer(tasksRepository: repo);
      addTearDown(container.dispose);
      container.listen(tasksStoreProvider, (_, __) {});

      await container.read(tasksStoreProvider.notifier).load();

      // Start unclaim.
      final future =
          container.read(tasksStoreProvider.notifier).unclaimTask('task-1');

      // Optimistic: cleared.
      expect(
        container.read(tasksStoreProvider).items.first.claimedById,
        isNull,
      );

      // Fail.
      unclaimCompleter.completeError(
        const ServerFailure(message: 'server error', statusCode: 500),
      );
      await expectLater(future, throwsA(isA<AppFailure>()));

      // Rolled back: assignee restored.
      final rolledBack = container.read(tasksStoreProvider);
      expect(rolledBack.items.first.claimedById, 'current-user',
          reason: '#748: Unclaim must roll back on API failure');
      expect(rolledBack.items.first.claimedByName, 'Current User');
    });
  });
}

// =============================================================================
// Test Doubles
// =============================================================================

class _FakeSessionStore extends SessionStore {
  _FakeSessionStore({required this.userId, required this.displayName});

  final String userId;
  final String displayName;

  @override
  SessionState build() {
    return SessionState(
      status: AuthStatus.authenticated,
      userId: userId,
      displayName: displayName,
    );
  }
}

class _ControllableTasksRepository implements TasksRepository {
  _ControllableTasksRepository({
    required this.tasks,
    this.claimCompleter,
    this.unclaimCompleter,
  });

  final List<TaskItem> tasks;
  Completer<TaskItem>? claimCompleter;
  Completer<TaskItem>? unclaimCompleter;

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async => tasks;

  @override
  Future<TaskItem> claimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) =>
      claimCompleter?.future ??
      Future.value(tasks.firstWhere((t) => t.id == taskId));

  @override
  Future<TaskItem> unclaimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) =>
      unclaimCompleter?.future ??
      Future.value(tasks.firstWhere((t) => t.id == taskId));

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
      tasks.firstWhere((t) => t.id == taskId);

  @override
  Future<void> deleteTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async {}

  @override
  Future<TaskItem> convertMessageToTask(
    ServerScopeId serverId, {
    required String messageId,
  }) async =>
      throw UnimplementedError();
}
