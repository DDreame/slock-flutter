import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/machines/data/workspace_item.dart';

enum WorkspacesStatus { initial, loading, success, failure }

@immutable
class WorkspacesState {
  const WorkspacesState({
    this.status = WorkspacesStatus.initial,
    this.items = const [],
    this.failure,
    this.deletingWorkspaceIds = const {},
  });

  final WorkspacesStatus status;
  final List<WorkspaceItem> items;
  final AppFailure? failure;
  final Set<String> deletingWorkspaceIds;

  bool isDeleting(String id) => deletingWorkspaceIds.contains(id);

  WorkspacesState copyWith({
    WorkspacesStatus? status,
    List<WorkspaceItem>? items,
    AppFailure? failure,
    bool clearFailure = false,
    Set<String>? deletingWorkspaceIds,
  }) {
    return WorkspacesState(
      status: status ?? this.status,
      items: items ?? this.items,
      failure: clearFailure ? null : (failure ?? this.failure),
      deletingWorkspaceIds: deletingWorkspaceIds ?? this.deletingWorkspaceIds,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkspacesState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          listEquals(items, other.items) &&
          failure == other.failure &&
          setEquals(deletingWorkspaceIds, other.deletingWorkspaceIds);

  @override
  int get hashCode => Object.hash(
        status,
        Object.hashAll(items),
        failure,
        Object.hashAll(deletingWorkspaceIds),
      );
}
