import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';

enum TasksStatus { initial, loading, success, failure }

@immutable
class TasksState {
  const TasksState({
    this.status = TasksStatus.initial,
    this.items = const [],
    this.failure,
    this.isRefreshing = false,
  });

  final TasksStatus status;
  final List<TaskItem> items;
  final AppFailure? failure;
  final bool isRefreshing;

  TasksState copyWith({
    TasksStatus? status,
    List<TaskItem>? items,
    AppFailure? failure,
    bool? isRefreshing,
    bool clearFailure = false,
  }) {
    return TasksState(
      status: status ?? this.status,
      items: items ?? this.items,
      failure: clearFailure ? null : (failure ?? this.failure),
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TasksState &&
            runtimeType == other.runtimeType &&
            status == other.status &&
            listEquals(items, other.items) &&
            failure == other.failure &&
            isRefreshing == other.isRefreshing;
  }

  @override
  int get hashCode =>
      Object.hash(status, Object.hashAll(items), failure, isRefreshing);
}
