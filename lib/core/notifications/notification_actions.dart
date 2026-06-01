import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/network/dio_client.dart';
import 'package:slock_app/core/network/providers.dart';

const notificationActionReply = 'reply';
const notificationActionMarkRead = 'mark_read';
const notificationActionInputKey = 'replyText';

const notificationReplyPath = '/messages';
const notificationChannelsPath = '/channels';
const notificationReadAllSuffix = '/read-all';

/// User-configurable platform notification buckets.
///
/// Android maps these to NotificationChannels so users can tune importance in
/// system settings. iOS maps the same action category to message notifications.
enum SlockNotificationChannelType {
  directMessage,
  mention,
  channelMessage;

  String get id => switch (this) {
        SlockNotificationChannelType.directMessage => 'slock_direct_messages',
        SlockNotificationChannelType.mention => 'slock_mentions',
        SlockNotificationChannelType.channelMessage => 'slock_channel_messages',
      };

  String get payloadType => switch (this) {
        SlockNotificationChannelType.directMessage => 'direct_message',
        SlockNotificationChannelType.mention => 'mention',
        SlockNotificationChannelType.channelMessage => 'channel',
      };
}

@immutable
class NotificationActionRequest {
  const NotificationActionRequest({
    required this.action,
    required this.serverId,
    required this.channelId,
    this.messageId,
    this.replyText,
  });

  final String action;
  final String serverId;
  final String channelId;
  final String? messageId;
  final String? replyText;

  bool get isReply => action == notificationActionReply;
  bool get isMarkRead => action == notificationActionMarkRead;

  static NotificationActionRequest? fromPayload(Map<String, dynamic> payload) {
    final action = payload['action'] ?? payload['slock.action'];
    final serverId = payload['serverId'];
    final channelId = payload['channelId'];
    if (action is! String || serverId is! String || channelId is! String) {
      return null;
    }
    return NotificationActionRequest(
      action: action,
      serverId: serverId,
      channelId: channelId,
      messageId: payload['messageId'] as String?,
      replyText: payload[notificationActionInputKey] as String? ??
          payload['reply'] as String?,
    );
  }

  Map<String, dynamic> toPayload() => <String, dynamic>{
        'slock.action': action,
        'action': action,
        'serverId': serverId,
        'channelId': channelId,
        if (messageId != null) 'messageId': messageId,
        if (replyText != null) notificationActionInputKey: replyText,
      };
}

abstract class NotificationActionApi {
  Future<void> sendReply(NotificationActionRequest request);
  Future<void> markRead(NotificationActionRequest request);
}

class DioNotificationActionApi implements NotificationActionApi {
  DioNotificationActionApi({required AppDioClient client}) : _client = client;

  final AppDioClient _client;

  @override
  Future<void> sendReply(NotificationActionRequest request) async {
    final text = request.replyText?.trim();
    if (text == null || text.isEmpty) return;

    await _client.post<Object?>(
      notificationReplyPath,
      data: <String, dynamic>{
        'channelId': request.channelId,
        'content': text,
        if (request.messageId != null) 'replyToId': request.messageId,
      },
      options: _serverScopedOptions(request.serverId),
    );
  }

  @override
  Future<void> markRead(NotificationActionRequest request) async {
    await _client.post<Object?>(
      '$notificationChannelsPath/${request.channelId}'
      '$notificationReadAllSuffix',
      options: _serverScopedOptions(request.serverId),
    );
  }

  Options _serverScopedOptions(String serverId) {
    return Options(headers: {'X-Server-Id': serverId});
  }
}

class NotificationActionHandler {
  const NotificationActionHandler({required NotificationActionApi api})
      : _api = api;

  final NotificationActionApi _api;

  Future<bool> handlePayload(Map<String, dynamic> payload) async {
    final request = NotificationActionRequest.fromPayload(payload);
    if (request == null) return false;

    if (request.isReply) {
      final text = request.replyText?.trim();
      if (text == null || text.isEmpty) return false;
      await _api.sendReply(request);
      await _api.markRead(request);
      return true;
    }

    if (request.isMarkRead) {
      await _api.markRead(request);
      return true;
    }

    return false;
  }
}

final notificationActionApiProvider = Provider<NotificationActionApi>((ref) {
  return DioNotificationActionApi(client: ref.watch(appDioClientProvider));
});

final notificationActionHandlerProvider = Provider<NotificationActionHandler>((
  ref,
) {
  return NotificationActionHandler(
    api: ref.watch(notificationActionApiProvider),
  );
});
