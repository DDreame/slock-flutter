import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/tasks/application/tasks_state.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';

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
  @override
  TasksState build() {
    return const TasksState();
  }

  Future<void> load() async {
    final serverId = ref.read(currentTasksServerIdProvider);
    state = state.copyWith(
      status: TasksStatus.loading,
      clearFailure: true,
    );

    try {
      final repo = ref.read(tasksRepositoryProvider);
      final tasks = await repo.listServerTasks(serverId);
      state = state.copyWith(
        status: TasksStatus.success,
        items: tasks,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(
        status: TasksStatus.failure,
        failure: failure,
      );
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
      state = state.copyWith(
        items: [...state.items, ...created],
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
    try {
      final repo = ref.read(tasksRepositoryProvider);
      final updated = await repo.claimTask(serverId, taskId: taskId);
      state = state.copyWith(
        items: state.items.map((t) => t.id == taskId ? updated : t).toList(),
      );
    } on AppFailure {
      rethrow;
    }
  }

  Future<void> unclaimTask(String taskId) async {
    final serverId = ref.read(currentTasksServerIdProvider);
    try {
      final repo = ref.read(tasksRepositoryProvider);
      final updated = await repo.unclaimTask(serverId, taskId: taskId);
      state = state.copyWith(
        items: state.items.map((t) => t.id == taskId ? updated : t).toList(),
      );
    } on AppFailure {
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

  void retry() => load();
}
