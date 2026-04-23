import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';

abstract class TasksRepository {
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId);

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
