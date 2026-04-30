import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/tasks/application/tasks_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';

const _taskCreatedEvent = 'task:created';
const _taskUpdatedEvent = 'task:updated';
const _taskDeletedEvent = 'task:deleted';

final tasksRealtimeBindingProvider = Provider.autoDispose<void>(
    dependencies: [currentTasksServerIdProvider], (ref) {
  ref.watch(currentTasksServerIdProvider);
  final ingress = ref.watch(realtimeReductionIngressProvider);
  final subscription = ingress.acceptedEvents.listen((event) {
    switch (event.eventType) {
      case _taskCreatedEvent:
        _handleTaskCreated(ref, event);
      case _taskUpdatedEvent:
        _handleTaskUpdated(ref, event);
      case _taskDeletedEvent:
        _handleTaskDeleted(ref, event);
    }
  });

  ref.onDispose(() {
    unawaited(subscription.cancel());
  });
});

void _handleTaskCreated(Ref ref, RealtimeEventEnvelope event) {
  final tasks = _parseTasksFromPayload(event.payload);
  if (tasks.isEmpty) return;

  try {
    final store = ref.read(tasksStoreProvider.notifier);
    for (final task in tasks) {
      store.upsertTask(task);
    }
  } catch (e, st) {
    ref.read(crashReporterProvider).captureException(e, stackTrace: st);
  }
}

void _handleTaskUpdated(Ref ref, RealtimeEventEnvelope event) {
  final task = _parseSingleTaskFromPayload(event.payload);
  if (task == null) return;

  try {
    final store = ref.read(tasksStoreProvider.notifier);
    store.upsertTask(task);
  } catch (e, st) {
    ref.read(crashReporterProvider).captureException(e, stackTrace: st);
  }
}

void _handleTaskDeleted(Ref ref, RealtimeEventEnvelope event) {
  final taskId = _parseTaskIdFromPayload(event.payload);
  if (taskId == null) return;

  try {
    final store = ref.read(tasksStoreProvider.notifier);
    store.removeTask(taskId);
  } catch (e, st) {
    ref.read(crashReporterProvider).captureException(e, stackTrace: st);
  }
}

List<TaskItem> _parseTasksFromPayload(Object? payload) {
  final map = _asMap(payload);
  if (map == null) return [];
  final tasks = map['tasks'];
  if (tasks is! List) return [];

  final result = <TaskItem>[];
  for (final item in tasks) {
    final taskMap = _asMap(item);
    if (taskMap == null) continue;
    final parsed = _tryParseTaskItem(taskMap);
    if (parsed != null) result.add(parsed);
  }
  return result;
}

TaskItem? _parseSingleTaskFromPayload(Object? payload) {
  final map = _asMap(payload);
  if (map == null) return null;
  final task = map['task'];
  final taskMap = _asMap(task);
  if (taskMap == null) return null;
  return _tryParseTaskItem(taskMap);
}

String? _parseTaskIdFromPayload(Object? payload) {
  final map = _asMap(payload);
  if (map == null) return null;
  final taskId = map['taskId'];
  return taskId is String && taskId.isNotEmpty ? taskId : null;
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

TaskItem? _tryParseTaskItem(Map<String, dynamic> map) {
  final id = _optionalString(map['id']);
  final title = _optionalString(map['title']);
  final status = _optionalString(map['status']);
  final channelId = _optionalString(map['channelId']);
  if (id == null || title == null || status == null || channelId == null) {
    return null;
  }
  final taskNumber = map['taskNumber'];
  return TaskItem(
    id: id,
    taskNumber: taskNumber is int
        ? taskNumber
        : taskNumber is num
            ? taskNumber.toInt()
            : 0,
    title: title,
    status: status,
    channelId: channelId,
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

String? _optionalString(Object? value) {
  if (value is String && value.isNotEmpty) return value;
  return null;
}

DateTime? _optionalDateTime(Object? value) {
  final raw = _optionalString(value);
  return raw != null ? DateTime.tryParse(raw) : null;
}
