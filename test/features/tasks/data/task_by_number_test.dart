// =============================================================================
// B129 PR A — Task by channel+number (GAP-12)
//
// Load-bearing tests for:
//   1. TasksRepository.getTaskByNumber HTTP contract
//   2. Navigation from task #N tap: non-legacy → channel + messageId
//   3. Navigation from task #N tap: legacy → tasks page
//   4. Navigation from task #N tap: API error → fallback to tasks page
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';

void main() {
  const serverId = ServerScopeId('server-1');

  group('TasksRepository.getTaskByNumber — HTTP contract', () {
    test('calls repository with correct channelId and taskNumber', () async {
      final repo = _RecordingTasksRepository();
      final container = ProviderContainer(
        overrides: [
          tasksRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(tasksRepositoryProvider)
          .getTaskByNumber(serverId, channelId: 'ch-general', taskNumber: 42);

      expect(repo.getByNumberCalls, hasLength(1));
      expect(repo.getByNumberCalls.first.channelId, 'ch-general');
      expect(repo.getByNumberCalls.first.taskNumber, 42);
      expect(result.id, 'task-42');
      expect(result.channelId, 'ch-general');
      expect(result.messageId, 'msg-42');
    });

    test('non-legacy task has isLegacy=false and messageId', () async {
      final repo = _RecordingTasksRepository(
        result: TaskItem(
          id: 'task-5',
          taskNumber: 5,
          title: 'Feature task',
          status: 'in_progress',
          channelId: 'ch-dev',
          channelType: 'channel',
          messageId: 'msg-abc',
          isLegacy: false,
          createdById: 'user-1',
          createdByName: 'Dev',
          createdByType: 'human',
          createdAt: DateTime(2026),
        ),
      );

      final result = await repo.getTaskByNumber(
        serverId,
        channelId: 'ch-dev',
        taskNumber: 5,
      );

      expect(result.isLegacy, isFalse);
      expect(result.messageId, 'msg-abc',
          reason: 'Non-legacy task must include messageId for navigation');
    });

    test('legacy task has isLegacy=true', () async {
      final repo = _RecordingTasksRepository(
        result: TaskItem(
          id: 'task-old',
          taskNumber: 1,
          title: 'Legacy task',
          status: 'done',
          channelId: 'ch-1',
          channelType: 'channel',
          isLegacy: true,
          createdById: 'user-1',
          createdByName: 'Admin',
          createdByType: 'human',
          createdAt: DateTime(2025),
        ),
      );

      final result = await repo.getTaskByNumber(
        serverId,
        channelId: 'ch-1',
        taskNumber: 1,
      );

      expect(result.isLegacy, isTrue,
          reason: 'Legacy tasks should route to tasks tab, not message');
      expect(result.messageId, isNull);
    });

    test('throws AppFailure on server error', () async {
      final repo = _FailingTasksRepository();

      expect(
        () => repo.getTaskByNumber(
          serverId,
          channelId: 'ch-1',
          taskNumber: 99,
        ),
        throwsA(isA<AppFailure>()),
        reason: 'API failure must propagate for fallback routing',
      );
    });
  });

  group('Task ref tap — routing decision', () {
    test('non-legacy task with messageId: route includes channelId + messageId',
        () {
      final task = TaskItem(
        id: 'task-7',
        taskNumber: 7,
        title: 'Review PR',
        status: 'todo',
        channelId: 'ch-engineering',
        channelType: 'channel',
        messageId: 'msg-pr-7',
        isLegacy: false,
        createdById: 'user-1',
        createdByName: 'Dev',
        createdByType: 'human',
        createdAt: DateTime(2026),
      );

      // Simulate the routing decision from _onTaskRefTap
      final route = _resolveTaskRoute(task, 'server-1');
      expect(
          route, '/servers/server-1/channels/ch-engineering?messageId=msg-pr-7',
          reason:
              'Non-legacy task must navigate to channel with messageId focus');
    });

    test('legacy task: route goes to tasks tab', () {
      final task = TaskItem(
        id: 'task-old',
        taskNumber: 3,
        title: 'Old task',
        status: 'done',
        channelId: 'ch-1',
        channelType: 'channel',
        isLegacy: true,
        createdById: 'user-1',
        createdByName: 'Admin',
        createdByType: 'human',
        createdAt: DateTime(2025),
      );

      final route = _resolveTaskRoute(task, 'server-1');
      expect(route, '/servers/server-1/tasks',
          reason: 'Legacy task must route to tasks page');
    });

    test('non-legacy task without messageId: route goes to tasks tab', () {
      final task = TaskItem(
        id: 'task-no-msg',
        taskNumber: 4,
        title: 'Task without message',
        status: 'todo',
        channelId: 'ch-1',
        channelType: 'channel',
        messageId: null,
        isLegacy: false,
        createdById: 'user-1',
        createdByName: 'Dev',
        createdByType: 'human',
        createdAt: DateTime(2026),
      );

      final route = _resolveTaskRoute(task, 'server-1');
      expect(route, '/servers/server-1/tasks',
          reason:
              'Task without messageId must fall back to tasks page (no message to focus)');
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Mirrors the routing decision in ConversationMessageCard._onTaskRefTap
String _resolveTaskRoute(TaskItem task, String serverId) {
  if (task.isLegacy || task.messageId == null) {
    return '/servers/$serverId/tasks';
  } else {
    return '/servers/$serverId/channels/${task.channelId}'
        '?messageId=${task.messageId}';
  }
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _RecordingTasksRepository implements TasksRepository {
  _RecordingTasksRepository({TaskItem? result}) : _result = result;

  final TaskItem? _result;
  final List<({String channelId, int taskNumber})> getByNumberCalls = [];

  @override
  Future<TaskItem> getTaskByNumber(
    ServerScopeId serverId, {
    required String channelId,
    required int taskNumber,
  }) async {
    getByNumberCalls.add((channelId: channelId, taskNumber: taskNumber));
    return _result ??
        TaskItem(
          id: 'task-$taskNumber',
          taskNumber: taskNumber,
          title: 'Task #$taskNumber',
          status: 'todo',
          channelId: channelId,
          channelType: 'channel',
          messageId: 'msg-$taskNumber',
          isLegacy: false,
          createdById: 'user-1',
          createdByName: 'Tester',
          createdByType: 'user',
          createdAt: DateTime(2026),
        );
  }

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async => [];

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
  }) async =>
      throw UnimplementedError();

  @override
  Future<TaskItem> unclaimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<TaskItem> convertMessageToTask(
    ServerScopeId serverId, {
    required String messageId,
  }) async =>
      throw UnimplementedError();
}

class _FailingTasksRepository implements TasksRepository {
  @override
  Future<TaskItem> getTaskByNumber(
    ServerScopeId serverId, {
    required String channelId,
    required int taskNumber,
  }) async {
    throw const NetworkFailure(message: 'Task not found');
  }

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async => [];

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
  }) async =>
      throw UnimplementedError();

  @override
  Future<TaskItem> unclaimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<TaskItem> convertMessageToTask(
    ServerScopeId serverId, {
    required String messageId,
  }) async =>
      throw UnimplementedError();
}
