import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/stores/session/session_store.dart';

final currentTasksServerIdProvider = Provider<ServerScopeId>((ref) {
  throw UnimplementedError(
    'currentTasksServerIdProvider must be overridden.',
  );
});

final tasksStoreProvider = NotifierProvider.autoDispose<TasksStore, TasksState>(
  TasksStore.new,
  dependencies: [currentTasksServerIdProvider],
);

class TasksStore extends AutoDisposeNotifier<TasksState> {
  Completer<void>? _ensureLoadedCompleter;

  /// Prevents post-await state mutations after the store is disposed.
  bool _disposed = false;

  @override
  TasksState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);

    // INV-834: Re-fetch on WebSocket reconnect — data may be stale.
    ref.listen(realtimeServiceProvider.select((s) => s.status), (prev, next) {
      if (prev == RealtimeConnectionStatus.reconnecting &&
          next == RealtimeConnectionStatus.connected) {
        if (state.status == TasksStatus.success) {
          load();
        }
      }
    });

    return const TasksState();
  }

  Future<void> load() async {
    final serverId = ref.read(currentTasksServerIdProvider);
    final hasStaleData = state.status == TasksStatus.success;

    if (hasStaleData) {
      // SWR: keep status=success, signal refresh via isRefreshing.
      state = state.copyWith(
        isRefreshing: true,
        clearFailure: true,
      );
    } else {
      state = state.copyWith(
        status: TasksStatus.loading,
        clearFailure: true,
      );
    }

    try {
      final repo = ref.read(tasksRepositoryProvider);
      final tasks = await repo.listServerTasks(serverId);
      if (_disposed) return;
      state = state.copyWith(
        status: TasksStatus.success,
        items: tasks,
        isRefreshing: false,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      if (_disposed) return;
      if (hasStaleData) {
        // SWR: preserve success status, surface error as overlay.
        state = state.copyWith(
          isRefreshing: false,
          failure: failure,
        );
      } else {
        state = state.copyWith(
          status: TasksStatus.failure,
          failure: failure,
        );
      }
    } catch (e, st) {
      if (_disposed) return;
      _reportUnexpectedError('load', e, st);
      if (hasStaleData) {
        state = state.copyWith(
          isRefreshing: false,
          failure: UnknownFailure(
            message: 'Failed to load tasks.',
            causeType: e.runtimeType.toString(),
          ),
        );
      } else {
        state = state.copyWith(
          status: TasksStatus.failure,
          failure: UnknownFailure(
            message: 'Failed to load tasks.',
            causeType: e.runtimeType.toString(),
          ),
        );
      }
    }
  }

  Future<List<TaskItem>> createTasks({
    required String channelId,
    required List<String> titles,
  }) async {
    final serverId = ref.read(currentTasksServerIdProvider);
    try {
      final repo = ref.read(tasksRepositoryProvider);
      final created = await repo.createTasks(
        serverId,
        channelId: channelId,
        titles: titles,
      );
      if (_disposed) return created;
      final itemsById = <String, TaskItem>{
        for (final item in state.items) item.id: item,
        for (final item in created) item.id: item,
      };
      state = state.copyWith(
        items: itemsById.values.toList(),
      );
      return created;
    } on AppFailure {
      rethrow;
    }
  }

  Future<void> updateTaskStatus({
    required String taskId,
    required String status,
  }) async {
    final serverId = ref.read(currentTasksServerIdProvider);
    // INV-ROLLBACK-817: Snapshot only the target item, not full list.
    final previousItem = state.items.firstWhere((t) => t.id == taskId);
    state = state.copyWith(
      items: state.items
          .map((t) => t.id == taskId ? t.copyWith(status: status) : t)
          .toList(),
    );

    try {
      final repo = ref.read(tasksRepositoryProvider);
      final updated = await repo.updateTaskStatus(
        serverId,
        taskId: taskId,
        status: status,
      );
      if (_disposed) return;
      state = state.copyWith(
        items: state.items.map((t) => t.id == taskId ? updated : t).toList(),
      );
    } on AppFailure {
      if (_disposed) return;
      // Per-item rollback: restore only the target item in current list.
      state = state.copyWith(
        items:
            state.items.map((t) => t.id == taskId ? previousItem : t).toList(),
      );
      rethrow;
    } catch (e, st) {
      if (_disposed) return;
      _reportUnexpectedError('updateTaskStatus', e, st);
      state = state.copyWith(
        items:
            state.items.map((t) => t.id == taskId ? previousItem : t).toList(),
      );
      throw UnknownFailure(
        message: 'Failed to update task status.',
        causeType: e.runtimeType.toString(),
      );
    }
  }

  Future<void> deleteTask(String taskId) async {
    final serverId = ref.read(currentTasksServerIdProvider);
    // INV-ROLLBACK-817: Snapshot the deleted item and its original index.
    final deletedIndex = state.items.indexWhere((t) => t.id == taskId);
    final deletedItem = state.items[deletedIndex];
    state = state.copyWith(
      items: state.items.where((t) => t.id != taskId).toList(),
    );

    try {
      final repo = ref.read(tasksRepositoryProvider);
      await repo.deleteTask(serverId, taskId: taskId);
      if (_disposed) return;
    } on AppFailure {
      if (_disposed) return;
      // Per-item rollback: re-insert at original position (clamped to current
      // list length to handle concurrent removals that shrink the list).
      _reinsertAtPosition(deletedItem, deletedIndex);
      rethrow;
    } catch (e, st) {
      if (_disposed) return;
      _reportUnexpectedError('deleteTask', e, st);
      _reinsertAtPosition(deletedItem, deletedIndex);
      throw UnknownFailure(
        message: 'Failed to delete task.',
        causeType: e.runtimeType.toString(),
      );
    }
  }

  /// Re-inserts [item] at [originalIndex], clamped to the current list length.
  /// This preserves ordering in the simple case while tolerating concurrent
  /// list mutations (additions/removals) that shift boundaries.
  void _reinsertAtPosition(TaskItem item, int originalIndex) {
    final current = [...state.items];
    final insertAt = originalIndex.clamp(0, current.length);
    current.insert(insertAt, item);
    state = state.copyWith(items: current);
  }

  Future<void> claimTask(String taskId) async {
    final serverId = ref.read(currentTasksServerIdProvider);
    // INV-ROLLBACK-817: Snapshot only the target item for rollback.
    final previousItem = state.items.firstWhere((t) => t.id == taskId);

    // Optimistic: immediately show current user as assignee.
    final session = ref.read(sessionStoreProvider);
    state = state.copyWith(
      items: state.items
          .map((t) => t.id == taskId
              ? t.copyWith(
                  claimedById: session.userId ?? '',
                  claimedByName: session.displayName ?? '',
                  claimedByType: 'human',
                  claimedAt: DateTime.now(),
                )
              : t)
          .toList(),
    );

    try {
      final repo = ref.read(tasksRepositoryProvider);
      final updated = await repo.claimTask(serverId, taskId: taskId);
      if (_disposed) return;
      state = state.copyWith(
        items: state.items.map((t) => t.id == taskId ? updated : t).toList(),
      );
    } on AppFailure {
      if (_disposed) return;
      state = state.copyWith(
        items:
            state.items.map((t) => t.id == taskId ? previousItem : t).toList(),
      );
      rethrow;
    } catch (e, st) {
      if (_disposed) return;
      _reportUnexpectedError('claimTask', e, st);
      state = state.copyWith(
        items:
            state.items.map((t) => t.id == taskId ? previousItem : t).toList(),
      );
      throw UnknownFailure(
        message: 'Failed to claim task.',
        causeType: e.runtimeType.toString(),
      );
    }
  }

  Future<void> unclaimTask(String taskId) async {
    final serverId = ref.read(currentTasksServerIdProvider);
    // INV-ROLLBACK-817: Snapshot only the target item for rollback.
    final previousItem = state.items.firstWhere((t) => t.id == taskId);

    // Optimistic: immediately clear assignee.
    state = state.copyWith(
      items: state.items
          .map((t) => t.id == taskId ? t.copyWith(clearClaim: true) : t)
          .toList(),
    );

    try {
      final repo = ref.read(tasksRepositoryProvider);
      final updated = await repo.unclaimTask(serverId, taskId: taskId);
      if (_disposed) return;
      state = state.copyWith(
        items: state.items.map((t) => t.id == taskId ? updated : t).toList(),
      );
    } on AppFailure {
      if (_disposed) return;
      state = state.copyWith(
        items:
            state.items.map((t) => t.id == taskId ? previousItem : t).toList(),
      );
      rethrow;
    } catch (e, st) {
      if (_disposed) return;
      _reportUnexpectedError('unclaimTask', e, st);
      state = state.copyWith(
        items:
            state.items.map((t) => t.id == taskId ? previousItem : t).toList(),
      );
      throw UnknownFailure(
        message: 'Failed to unclaim task.',
        causeType: e.runtimeType.toString(),
      );
    }
  }

  Future<TaskItem> convertMessageToTask({required String messageId}) async {
    final serverId = ref.read(currentTasksServerIdProvider);
    try {
      final repo = ref.read(tasksRepositoryProvider);
      final task =
          await repo.convertMessageToTask(serverId, messageId: messageId);
      if (_disposed) return task;
      state = state.copyWith(items: [...state.items, task]);
      return task;
    } on AppFailure {
      rethrow;
    }
  }

  void upsertTask(TaskItem task) {
    final index = state.items.indexWhere((t) => t.id == task.id);
    if (index >= 0) {
      final updated = [...state.items];
      updated[index] = task;
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(items: [...state.items, task]);
    }
  }

  void removeTask(String taskId) {
    state = state.copyWith(
      items: state.items.where((t) => t.id != taskId).toList(),
    );
  }

  /// Idempotent load trigger — only fires [load] when the store has not yet
  /// loaded (status == initial). Safe to call from multiple entry points
  /// (initState, ref.listen callbacks) without risking duplicate requests.
  Future<void> ensureLoaded() async {
    if (state.status != TasksStatus.initial) return;
    final inFlight = _ensureLoadedCompleter;
    if (inFlight != null) {
      return inFlight.future;
    }

    final completer = Completer<void>();
    _ensureLoadedCompleter = completer;
    try {
      await load();
      completer.complete();
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    } finally {
      if (_ensureLoadedCompleter == completer) {
        _ensureLoadedCompleter = null;
      }
    }
  }

  void retry() => load();

  void _reportUnexpectedError(String method, Object error, StackTrace st) {
    try {
      ref.read(diagnosticsCollectorProvider).error(
        'TasksStore',
        '$method failed: $error',
        metadata: {'stackTrace': st.toString()},
      );
    } catch (_) {}
  }
}
