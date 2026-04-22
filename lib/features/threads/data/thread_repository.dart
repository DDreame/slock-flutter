import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';

abstract class ThreadRepository {
  Future<List<ThreadInboxItem>> loadFollowedThreads(ServerScopeId serverId);

  Future<ResolvedThreadChannel> resolveThread(ThreadRouteTarget target);

  Future<void> followThread(ThreadRouteTarget target);

  Future<void> markThreadDone(
    ServerScopeId serverId, {
    required String threadChannelId,
  });

  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  });
}

@immutable
class ThreadInboxItem {
  const ThreadInboxItem({
    required this.routeTarget,
    required this.replyCount,
    required this.unreadCount,
    required this.participantIds,
    this.title,
    this.preview,
    this.senderName,
    this.lastReplyAt,
  });

  final ThreadRouteTarget routeTarget;
  final String? title;
  final String? preview;
  final String? senderName;
  final int replyCount;
  final int unreadCount;
  final DateTime? lastReplyAt;
  final List<String> participantIds;

  String get resolvedTitle => title ?? routeTarget.parentChannelId;

  ThreadInboxItem copyWith({
    int? unreadCount,
  }) {
    return ThreadInboxItem(
      routeTarget: routeTarget,
      title: title,
      preview: preview,
      senderName: senderName,
      replyCount: replyCount,
      unreadCount: unreadCount ?? this.unreadCount,
      lastReplyAt: lastReplyAt,
      participantIds: participantIds,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ThreadInboxItem &&
            runtimeType == other.runtimeType &&
            routeTarget == other.routeTarget &&
            title == other.title &&
            preview == other.preview &&
            senderName == other.senderName &&
            replyCount == other.replyCount &&
            unreadCount == other.unreadCount &&
            lastReplyAt == other.lastReplyAt &&
            listEquals(participantIds, other.participantIds);
  }

  @override
  int get hashCode => Object.hash(
        routeTarget,
        title,
        preview,
        senderName,
        replyCount,
        unreadCount,
        lastReplyAt,
        Object.hashAll(participantIds),
      );
}

@immutable
class ResolvedThreadChannel {
  const ResolvedThreadChannel({
    required this.threadChannelId,
    required this.replyCount,
    required this.participantIds,
    this.lastReplyAt,
  });

  final String threadChannelId;
  final int replyCount;
  final List<String> participantIds;
  final DateTime? lastReplyAt;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ResolvedThreadChannel &&
            runtimeType == other.runtimeType &&
            threadChannelId == other.threadChannelId &&
            replyCount == other.replyCount &&
            listEquals(participantIds, other.participantIds) &&
            lastReplyAt == other.lastReplyAt;
  }

  @override
  int get hashCode => Object.hash(
        threadChannelId,
        replyCount,
        Object.hashAll(participantIds),
        lastReplyAt,
      );
}
