import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';

/// Resolves a task by its channel-scoped number.
///
/// Used by inline `task #N` reference taps in the presentation layer.
/// Thin application-layer wrapper around [TasksRepository.getTaskByNumber].
final getTaskByNumberUseCaseProvider = Provider<
    Future<TaskItem> Function(
      ServerScopeId serverId, {
      required String channelId,
      required int taskNumber,
    })>((ref) {
  return (
    ServerScopeId serverId, {
    required String channelId,
    required int taskNumber,
  }) =>
      ref.read(tasksRepositoryProvider).getTaskByNumber(
            serverId,
            channelId: channelId,
            taskNumber: taskNumber,
          );
});

/// Converts an existing message into a task.
///
/// Used by the message context menu "Convert to task" action.
/// Thin application-layer wrapper around
/// [TasksRepository.convertMessageToTask].
final convertMessageToTaskUseCaseProvider = Provider<
    Future<TaskItem> Function(
      ServerScopeId serverId, {
      required String messageId,
    })>((ref) {
  return (ServerScopeId serverId, {required String messageId}) =>
      ref.read(tasksRepositoryProvider).convertMessageToTask(
            serverId,
            messageId: messageId,
          );
});
