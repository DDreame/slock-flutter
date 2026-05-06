import 'package:flutter/foundation.dart';

@immutable
class ThreadRouteTarget {
  const ThreadRouteTarget({
    required this.serverId,
    required this.parentChannelId,
    required this.parentMessageId,
    this.threadChannelId,
    this.isFollowed = false,
    this.highlightMessageId,
  });

  final String serverId;
  final String parentChannelId;
  final String parentMessageId;
  final String? threadChannelId;
  final bool isFollowed;

  /// When set, the thread replies page will scroll to this message.
  final String? highlightMessageId;

  Uri toUri() {
    return Uri(
      path: '/servers/$serverId/threads/$parentMessageId/replies',
      queryParameters: {
        'channelId': parentChannelId,
        if (threadChannelId != null && threadChannelId!.isNotEmpty)
          'threadChannelId': threadChannelId!,
        if (isFollowed) 'followed': '1',
        if (highlightMessageId != null && highlightMessageId!.isNotEmpty)
          'messageId': highlightMessageId!,
      },
    );
  }

  String toLocation() => toUri().toString();

  ThreadRouteTarget copyWith({
    String? threadChannelId,
    bool? isFollowed,
    String? highlightMessageId,
  }) {
    return ThreadRouteTarget(
      serverId: serverId,
      parentChannelId: parentChannelId,
      parentMessageId: parentMessageId,
      threadChannelId: threadChannelId ?? this.threadChannelId,
      isFollowed: isFollowed ?? this.isFollowed,
      highlightMessageId: highlightMessageId ?? this.highlightMessageId,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ThreadRouteTarget &&
            runtimeType == other.runtimeType &&
            serverId == other.serverId &&
            parentChannelId == other.parentChannelId &&
            parentMessageId == other.parentMessageId &&
            threadChannelId == other.threadChannelId &&
            isFollowed == other.isFollowed &&
            highlightMessageId == other.highlightMessageId;
  }

  @override
  int get hashCode => Object.hash(
        serverId,
        parentChannelId,
        parentMessageId,
        threadChannelId,
        isFollowed,
        highlightMessageId,
      );
}

ThreadRouteTarget? tryParseThreadRouteTarget(Uri uri) {
  final segments = uri.pathSegments;
  if (segments.length != 5 ||
      segments[0] != 'servers' ||
      segments[2] != 'threads' ||
      segments[4] != 'replies') {
    return null;
  }

  final serverId = segments[1];
  final parentMessageId = segments[3];
  final parentChannelId = uri.queryParameters['channelId'];
  if (serverId.isEmpty ||
      parentMessageId.isEmpty ||
      parentChannelId == null ||
      parentChannelId.isEmpty) {
    return null;
  }

  final followedValue = uri.queryParameters['followed'];
  return ThreadRouteTarget(
    serverId: serverId,
    parentChannelId: parentChannelId,
    parentMessageId: parentMessageId,
    threadChannelId: uri.queryParameters['threadChannelId'],
    isFollowed: followedValue == '1' || followedValue == 'true',
    highlightMessageId: uri.queryParameters['messageId'],
  );
}
