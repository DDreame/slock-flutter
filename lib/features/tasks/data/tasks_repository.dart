import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';

abstract class TasksRepository {
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId);

  /// Resolves a task by its channel-scoped number.
  ///
  /// Endpoint: `GET /tasks/channel/{channelId}/number/{taskNumber}`
  /// Used by the `task #N` inline reference tap to navigate to the
  /// correct message or legacy tasks tab.
  Future<TaskItem> getTaskByNumber(
    ServerScopeId serverId, {
    required String channelId,
    required int taskNumber,
  });

  Future<List<TaskItem>> createTasks(
    ServerScopeId serverId, {
    required String channelId,
    required List<String> titles,
  });

  Future<TaskItem> updateTaskStatus(
    ServerScopeId serverId, {
    required String taskId,
    required String status,
  });

  Future<void> deleteTask(
    ServerScopeId serverId, {
    required String taskId,
  });

  Future<TaskItem> claimTask(
    ServerScopeId serverId, {
    required String taskId,
  });

  Future<TaskItem> unclaimTask(
    ServerScopeId serverId, {
    required String taskId,
  });

  Future<TaskItem> convertMessageToTask(
    ServerScopeId serverId, {
    required String messageId,
  });
}
