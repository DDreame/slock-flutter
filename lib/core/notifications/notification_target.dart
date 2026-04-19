import 'package:flutter/foundation.dart';

enum NotificationSurface { channel, dm, thread, agent }

@immutable
class VisibleTarget {
  final String serverId;
  final NotificationSurface surface;
  final String channelId;
  final String? threadId;
  final String? messageId;

  const VisibleTarget({
    required this.serverId,
    required this.surface,
    required this.channelId,
    this.threadId,
    this.messageId,
  });

  bool matches(NotificationTarget target) {
    if (serverId != target.serverId) return false;
    if (surface != target.surface) return false;
    if (channelId != target.channelId) return false;
    if (target.threadId != null && threadId != target.threadId) return false;
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisibleTarget &&
          runtimeType == other.runtimeType &&
          serverId == other.serverId &&
          surface == other.surface &&
          channelId == other.channelId &&
          threadId == other.threadId &&
          messageId == other.messageId;

  @override
  int get hashCode =>
      Object.hash(serverId, surface, channelId, threadId, messageId);
}

@immutable
class NotificationTarget {
  final String serverId;
  final NotificationSurface surface;
  final String channelId;
  final String? threadId;
  final String? messageId;

  const NotificationTarget({
    required this.serverId,
    required this.surface,
    required this.channelId,
    this.threadId,
    this.messageId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationTarget &&
          runtimeType == other.runtimeType &&
          serverId == other.serverId &&
          surface == other.surface &&
          channelId == other.channelId &&
          threadId == other.threadId &&
          messageId == other.messageId;

  @override
  int get hashCode =>
      Object.hash(serverId, surface, channelId, threadId, messageId);
}
