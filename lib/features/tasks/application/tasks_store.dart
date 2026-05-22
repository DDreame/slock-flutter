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

  @override
  TasksState build() {
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
      state = state.copyWith(
        status: TasksStatus.success,
        items: tasks,
        isRefreshing: false,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
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
    }
  }

  Future<List<TaskItem>?> createTasks({
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
    final previousItems = state.items;
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
      state = state.copyWith(
        items: state.items.map((t) => t.id == taskId ? updated : t).toList(),
      );
    } on AppFailure {
      state = state.copyWith(items: previousItems);
      rethrow;
    }
  }

  Future<void> deleteTask(String taskId) async {
    final serverId = ref.read(currentTasksServerIdProvider);
    final previousItems = state.items;
    state = state.copyWith(
      items: state.items.where((t) => t.id != taskId).toList(),
    );

    try {
      final repo = ref.read(tasksRepositoryProvider);
      await repo.deleteTask(serverId, taskId: taskId);
    } on AppFailure {
      state = state.copyWith(items: previousItems);
      rethrow;
    }
  }

  Future<void> claimTask(String taskId) async {
    final serverId = ref.read(currentTasksServerIdProvider);
    final previousItems = state.items;

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
      state = state.copyWith(
        items: state.items.map((t) => t.id == taskId ? updated : t).toList(),
      );
    } on AppFailure {
      state = state.copyWith(items: previousItems);
      rethrow;
    }
  }

  Future<void> unclaimTask(String taskId) async {
    final serverId = ref.read(currentTasksServerIdProvider);
    final previousItems = state.items;

    // Optimistic: immediately clear assignee.
    state = state.copyWith(
      items: state.items
          .map((t) => t.id == taskId ? t.copyWith(clearClaim: true) : t)
          .toList(),
    );

    try {
      final repo = ref.read(tasksRepositoryProvider);
      final updated = await repo.unclaimTask(serverId, taskId: taskId);
      state = state.copyWith(
        items: state.items.map((t) => t.id == taskId ? updated : t).toList(),
      );
    } on AppFailure {
      state = state.copyWith(items: previousItems);
      rethrow;
    }
  }

  Future<TaskItem> convertMessageToTask({required String messageId}) async {
    final serverId = ref.read(currentTasksServerIdProvider);
    try {
      final repo = ref.read(tasksRepositoryProvider);
      final task =
          await repo.convertMessageToTask(serverId, messageId: messageId);
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
}
