import 'package:slock_app/core/notifications/notification_target.dart';

String? resolveNotificationRoute(Map<String, dynamic> payload) {
  final type = payload['type'] as String?;
  final serverId = payload['serverId'] as String?;
  final channelId = payload['channelId'] as String?;
  final threadId = payload['threadId'] as String?;
  final agentId = payload['agentId'] as String?;
  final userId = payload['userId'] as String?;

  if (type == null) return null;

  switch (type) {
    case 'channel':
      if (serverId == null || channelId == null) return null;
      return '/servers/$serverId/channels/$channelId';
    case 'dm':
      if (serverId == null || channelId == null) return null;
      return '/servers/$serverId/dms/$channelId';
    case 'thread':
      if (serverId == null || channelId == null || threadId == null) {
        return null;
      }
      return Uri(
        path: '/servers/$serverId/threads/$threadId/replies',
        queryParameters: {'channelId': channelId},
      ).toString();
    case 'agent':
      if (serverId == null || agentId == null) return null;
      return '/servers/$serverId/agents/$agentId';
    case 'profile':
      if (userId == null) return null;
      if (serverId != null) {
        return '/servers/$serverId/profile/$userId';
      }
      return '/profile/$userId';
    default:
      return null;
  }
}

NotificationTarget? parseNotificationTarget(Map<String, dynamic> payload) {
  final type = payload['type'] as String?;
  final serverId = payload['serverId'] as String?;
  final channelId = payload['channelId'] as String?;
  final threadId = payload['threadId'] as String?;
  final messageId = payload['messageId'] as String?;

  if (type == null || serverId == null || channelId == null) return null;

  final surface = switch (type) {
    'channel' => NotificationSurface.channel,
    'dm' => NotificationSurface.dm,
    'thread' => NotificationSurface.thread,
    'agent' => NotificationSurface.agent,
    _ => null,
  };

  if (surface == null) return null;

  return NotificationTarget(
    serverId: serverId,
    surface: surface,
    channelId: channelId,
    threadId: threadId,
    messageId: messageId,
  );
}
