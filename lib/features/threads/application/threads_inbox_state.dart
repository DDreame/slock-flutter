import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';

enum ThreadsInboxStatus { initial, loading, success, failure }

@immutable
class ThreadsInboxState {
  const ThreadsInboxState({
    required this.serverId,
    this.status = ThreadsInboxStatus.initial,
    this.items = const [],
    this.completingThreadIds = const [],
    this.failure,
  });

  final ServerScopeId serverId;
  final ThreadsInboxStatus status;
  final List<ThreadInboxItem> items;
  final List<String> completingThreadIds;
  final AppFailure? failure;

  ThreadsInboxState copyWith({
    ServerScopeId? serverId,
    ThreadsInboxStatus? status,
    List<ThreadInboxItem>? items,
    List<String>? completingThreadIds,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return ThreadsInboxState(
      serverId: serverId ?? this.serverId,
      status: status ?? this.status,
      items: items ?? this.items,
      completingThreadIds: completingThreadIds ?? this.completingThreadIds,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  bool isCompleting(String threadChannelId) {
    return completingThreadIds.contains(threadChannelId);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ThreadsInboxState &&
            runtimeType == other.runtimeType &&
            serverId == other.serverId &&
            status == other.status &&
            listEquals(items, other.items) &&
            listEquals(completingThreadIds, other.completingThreadIds) &&
            failure == other.failure;
  }

  @override
  int get hashCode => Object.hash(
        serverId,
        status,
        Object.hashAll(items),
        Object.hashAll(completingThreadIds),
        failure,
      );
}
