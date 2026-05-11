import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';

/// Shared fake [TasksRepository] for tests.
///
/// By default returns empty lists. Supports per-operation result/failure
/// configuration and call tracking.
class FakeTasksRepository implements TasksRepository {
  FakeTasksRepository({
    this.listResult = const [],
    this.createResult = const [],
    this.shouldFail = false,
  });

  List<TaskItem> listResult;
  List<TaskItem> createResult;
  bool shouldFail;

  TaskItem? statusResult;
  TaskItem? claimResult;
  TaskItem? unclaimResult;
  TaskItem? convertResult;

  int listCalls = 0;
  final List<(String, List<String>)> createCalls = [];
  final List<(String, String)> statusUpdateCalls = [];
  final List<String> deletedTaskIds = [];
  final List<String> claimedTaskIds = [];
  final List<String> unclaimedTaskIds = [];
  final List<String> convertedMessageIds = [];

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async {
    listCalls++;
    if (shouldFail) {
      throw const UnknownFailure(message: 'Failed to load tasks.');
    }
    return listResult;
  }

  @override
  Future<List<TaskItem>> createTasks(
    ServerScopeId serverId, {
    required String channelId,
    required List<String> titles,
  }) async {
    createCalls.add((channelId, titles));
    if (shouldFail) {
      throw const UnknownFailure(message: 'Failed to create tasks.');
    }
    return createResult;
  }

  @override
  Future<TaskItem> updateTaskStatus(
    ServerScopeId serverId, {
    required String taskId,
    required String status,
  }) async {
    statusUpdateCalls.add((taskId, status));
    if (shouldFail) {
      throw const UnknownFailure(message: 'Failed to update task.');
    }
    return statusResult ??
        TaskItem(
          id: taskId,
          taskNumber: 1,
          title: 'Task',
          status: status,
          channelId: 'ch-1',
          channelType: 'channel',
          createdById: 'user-1',
          createdByName: 'Tester',
          createdByType: 'user',
          createdAt: DateTime(2026),
        );
  }

  @override
  Future<void> deleteTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async {
    deletedTaskIds.add(taskId);
    if (shouldFail) {
      throw const UnknownFailure(message: 'Failed to delete task.');
    }
  }

  @override
  Future<TaskItem> claimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async {
    claimedTaskIds.add(taskId);
    if (shouldFail) {
      throw const UnknownFailure(message: 'Failed to claim task.');
    }
    return claimResult ??
        TaskItem(
          id: taskId,
          taskNumber: 1,
          title: 'Task',
          status: 'todo',
          channelId: 'ch-1',
          channelType: 'channel',
          claimedById: 'user-1',
          claimedByName: 'Tester',
          createdById: 'user-1',
          createdByName: 'Tester',
          createdByType: 'user',
          createdAt: DateTime(2026),
        );
  }

  @override
  Future<TaskItem> unclaimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async {
    unclaimedTaskIds.add(taskId);
    if (shouldFail) {
      throw const UnknownFailure(message: 'Failed to unclaim task.');
    }
    return unclaimResult ??
        TaskItem(
          id: taskId,
          taskNumber: 1,
          title: 'Task',
          status: 'todo',
          channelId: 'ch-1',
          channelType: 'channel',
          createdById: 'user-1',
          createdByName: 'Tester',
          createdByType: 'user',
          createdAt: DateTime(2026),
        );
  }

  @override
  Future<TaskItem> convertMessageToTask(
    ServerScopeId serverId, {
    required String messageId,
  }) async {
    convertedMessageIds.add(messageId);
    if (shouldFail) {
      throw const UnknownFailure(message: 'Failed to convert message.');
    }
    return convertResult ??
        TaskItem(
          id: 'task-new',
          taskNumber: 1,
          title: 'Converted task',
          status: 'todo',
          channelId: 'ch-1',
          channelType: 'channel',
          messageId: messageId,
          createdById: 'user-1',
          createdByName: 'Tester',
          createdByType: 'user',
          createdAt: DateTime(2026),
        );
  }
}
