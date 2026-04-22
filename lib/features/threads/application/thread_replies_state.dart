import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';

enum ThreadRepliesStatus { initial, loading, success, failure }

@immutable
class ThreadRepliesState {
  const ThreadRepliesState({
    required this.routeTarget,
    this.status = ThreadRepliesStatus.initial,
    this.resolvedThreadChannelId,
    this.replyCount = 0,
    this.participantIds = const [],
    this.lastReplyAt,
    this.isFollowingInFlight = false,
    this.isDoneInFlight = false,
    this.isDone = false,
    this.failure,
  });

  final ThreadRouteTarget routeTarget;
  final ThreadRepliesStatus status;
  final String? resolvedThreadChannelId;
  final int replyCount;
  final List<String> participantIds;
  final DateTime? lastReplyAt;
  final bool isFollowingInFlight;
  final bool isDoneInFlight;
  final bool isDone;
  final AppFailure? failure;

  bool get isFollowing => routeTarget.isFollowed;

  ConversationDetailTarget? get conversationTarget {
    final channelId = resolvedThreadChannelId;
    if (channelId == null) {
      return null;
    }
    return ConversationDetailTarget.channel(
      ChannelScopeId(
        serverId: ServerScopeId(routeTarget.serverId),
        value: channelId,
      ),
    );
  }

  ThreadRepliesState copyWith({
    ThreadRouteTarget? routeTarget,
    ThreadRepliesStatus? status,
    String? resolvedThreadChannelId,
    int? replyCount,
    List<String>? participantIds,
    DateTime? lastReplyAt,
    bool? isFollowingInFlight,
    bool? isDoneInFlight,
    bool? isDone,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return ThreadRepliesState(
      routeTarget: routeTarget ?? this.routeTarget,
      status: status ?? this.status,
      resolvedThreadChannelId:
          resolvedThreadChannelId ?? this.resolvedThreadChannelId,
      replyCount: replyCount ?? this.replyCount,
      participantIds: participantIds ?? this.participantIds,
      lastReplyAt: lastReplyAt ?? this.lastReplyAt,
      isFollowingInFlight: isFollowingInFlight ?? this.isFollowingInFlight,
      isDoneInFlight: isDoneInFlight ?? this.isDoneInFlight,
      isDone: isDone ?? this.isDone,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ThreadRepliesState &&
            runtimeType == other.runtimeType &&
            routeTarget == other.routeTarget &&
            status == other.status &&
            resolvedThreadChannelId == other.resolvedThreadChannelId &&
            replyCount == other.replyCount &&
            listEquals(participantIds, other.participantIds) &&
            lastReplyAt == other.lastReplyAt &&
            isFollowingInFlight == other.isFollowingInFlight &&
            isDoneInFlight == other.isDoneInFlight &&
            isDone == other.isDone &&
            failure == other.failure;
  }

  @override
  int get hashCode => Object.hash(
        routeTarget,
        status,
        resolvedThreadChannelId,
        replyCount,
        Object.hashAll(participantIds),
        lastReplyAt,
        isFollowingInFlight,
        isDoneInFlight,
        isDone,
        failure,
      );
}
