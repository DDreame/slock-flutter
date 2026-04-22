import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';

const _serverHeaderName = 'X-Server-Id';
const _tasksPath = '/tasks';

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  final appDioClient = ref.watch(appDioClientProvider);
  return _ApiTasksRepository(appDioClient: appDioClient);
});

class _ApiTasksRepository implements TasksRepository {
  const _ApiTasksRepository({required AppDioClient appDioClient})
      : _appDioClient = appDioClient;

  final AppDioClient _appDioClient;

  Options _serverOptions(ServerScopeId serverId) =>
      Options(headers: {_serverHeaderName: serverId.value});

  @override
  Future<List<TaskItem>> listServerTasks(ServerScopeId serverId) async {
    try {
      final response = await _appDioClient.get<Object?>(
        '$_tasksPath/server',
        options: _serverOptions(serverId),
      );
      return _parseTaskList(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to load tasks.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<List<TaskItem>> createTasks(
    ServerScopeId serverId, {
    required String channelId,
    required List<String> titles,
  }) async {
    try {
      final response = await _appDioClient.post<Object?>(
        '$_tasksPath/channel/$channelId',
        data: {
          'tasks': [
            for (final title in titles) {'title': title}
          ],
        },
        options: _serverOptions(serverId),
      );
      return _parseTaskList(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to create task.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<TaskItem> updateTaskStatus(
    ServerScopeId serverId, {
    required String taskId,
    required String status,
  }) async {
    try {
      final response = await _appDioClient.request<Object?>(
        '$_tasksPath/$taskId/status',
        method: 'PATCH',
        data: {'status': status},
        options: _serverOptions(serverId),
      );
      return _parseSingleTask(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to update task status.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<void> deleteTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async {
    try {
      await _appDioClient.delete<Object?>(
        '$_tasksPath/$taskId',
        options: _serverOptions(serverId),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to delete task.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<TaskItem> claimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async {
    try {
      final response = await _appDioClient.request<Object?>(
        '$_tasksPath/$taskId/claim',
        method: 'PATCH',
        options: _serverOptions(serverId),
      );
      return _parseSingleTask(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to claim task.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  @override
  Future<TaskItem> unclaimTask(
    ServerScopeId serverId, {
    required String taskId,
  }) async {
    try {
      final response = await _appDioClient.request<Object?>(
        '$_tasksPath/$taskId/unclaim',
        method: 'PATCH',
        options: _serverOptions(serverId),
      );
      return _parseSingleTask(response.data);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw UnknownFailure(
        message: 'Failed to unclaim task.',
        causeType: error.runtimeType.toString(),
      );
    }
  }

  List<TaskItem> _parseTaskList(Object? payload) {
    final map = _requireMap(payload);
    final tasks = map['tasks'];
    if (tasks is! List) return [];
    return tasks
        .whereType<Map>()
        .map((t) => _parseTaskItem(
            t is Map<String, dynamic> ? t : Map<String, dynamic>.from(t)))
        .toList();
  }

  TaskItem _parseSingleTask(Object? payload) {
    final map = _requireMap(payload);
    final task = map['task'];
    if (task is Map<String, dynamic>) return _parseTaskItem(task);
    if (task is Map) return _parseTaskItem(Map<String, dynamic>.from(task));
    throw const UnknownFailure(
      message: 'Invalid task response.',
      causeType: 'ParseError',
    );
  }

  TaskItem _parseTaskItem(Map<String, dynamic> map) {
    return TaskItem(
      id: _requireString(map, 'id'),
      taskNumber: _requireInt(map, 'taskNumber'),
      title: _requireString(map, 'title'),
      status: _requireString(map, 'status'),
      channelId: _requireString(map, 'channelId'),
      channelType: _optionalString(map['channelType']) ?? 'channel',
      messageId: _optionalString(map['messageId']),
      isLegacy: map['isLegacy'] == true,
      claimedById: _optionalString(map['claimedById']),
      claimedByName: _optionalString(map['claimedByName']),
      claimedByType: _optionalString(map['claimedByType']),
      claimedAt: _optionalDateTime(map['claimedAt']),
      createdById: _optionalString(map['createdById']) ?? '',
      createdByName: _optionalString(map['createdByName']) ?? '',
      createdByType: _optionalString(map['createdByType']) ?? 'user',
      createdAt: _optionalDateTime(map['createdAt']) ?? DateTime.now(),
      completedAt: _optionalDateTime(map['completedAt']),
    );
  }

  Map<String, dynamic> _requireMap(Object? payload) {
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return Map<String, dynamic>.from(payload);
    throw const UnknownFailure(
      message: 'Invalid response format.',
      causeType: 'ParseError',
    );
  }

  String _requireString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is String && value.isNotEmpty) return value;
    throw UnknownFailure(
      message: 'Missing required field: $key',
      causeType: 'ParseError',
    );
  }

  int _requireInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw UnknownFailure(
      message: 'Missing required field: $key',
      causeType: 'ParseError',
    );
  }

  String? _optionalString(Object? value) {
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  DateTime? _optionalDateTime(Object? value) {
    final raw = _optionalString(value);
    return raw != null ? DateTime.tryParse(raw) : null;
  }
}
