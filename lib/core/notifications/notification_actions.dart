import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/network/dio_client.dart';
import 'package:slock_app/core/network/providers.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';

const notificationActionReply = 'reply';
const notificationActionMarkRead = 'mark_read';
const notificationActionInputKey = 'replyText';

const notificationReplyPath = '/messages';
const notificationChannelsPath = '/channels';
const notificationReadAllSuffix = '/read-all';

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
  const NotificationActionHandler({
    required NotificationActionApi api,
    DiagnosticsCollector? diagnostics,
    int markReadMaxAttempts = 2,
  })  : _api = api,
        _diagnostics = diagnostics,
        _markReadMaxAttempts = markReadMaxAttempts;

  static const _tag = 'notification-action';

  final NotificationActionApi _api;
  final DiagnosticsCollector? _diagnostics;
  final int _markReadMaxAttempts;

  Future<bool> handlePayload(Map<String, dynamic> payload) async {
    final request = NotificationActionRequest.fromPayload(payload);
    if (request == null) return false;

    try {
      if (request.isReply) {
        final text = request.replyText?.trim();
        if (text == null || text.isEmpty) return false;
        await _api.sendReply(request);
        return _markReadWithRetry(request, source: 'reply');
      }

      if (request.isMarkRead) {
        return _markReadWithRetry(request, source: 'mark_read');
      }

      return false;
    } on Object catch (error, stackTrace) {
      _diagnostics?.error(
        _tag,
        'notification action failed',
        metadata: _metadata(request, error, stackTrace),
      );
      return false;
    }
  }

  Future<bool> _markReadWithRetry(
    NotificationActionRequest request, {
    required String source,
  }) async {
    final attempts = _markReadMaxAttempts < 1 ? 1 : _markReadMaxAttempts;
    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        await _api.markRead(request);
        if (attempt > 1) {
          _diagnostics?.info(
            _tag,
            'notification mark-read retry succeeded',
            metadata: {
              'source': source,
              'attempt': attempt,
              'serverId': request.serverId,
              'channelId': request.channelId,
            },
          );
        }
        return true;
      } on Object catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (attempt < attempts) {
          _diagnostics?.warning(
            _tag,
            'notification mark-read failed; retrying',
            metadata: _metadata(
              request,
              error,
              stackTrace,
              extra: {'source': source, 'attempt': attempt},
            ),
          );
        }
      }
    }

    _diagnostics?.error(
      _tag,
      'notification mark-read failed after retry',
      metadata: _metadata(
        request,
        lastError ?? StateError('unknown mark-read failure'),
        lastStackTrace ?? StackTrace.current,
        extra: {'source': source, 'attempts': attempts},
      ),
    );
    return false;
  }

  Map<String, dynamic> _metadata(
    NotificationActionRequest request,
    Object error,
    StackTrace stackTrace, {
    Map<String, dynamic> extra = const {},
  }) {
    return {
      'action': request.action,
      'serverId': request.serverId,
      'channelId': request.channelId,
      'errorType': error.runtimeType.toString(),
      'error': error.toString(),
      'stackTrace': stackTrace.toString(),
      ...extra,
    };
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
    diagnostics: ref.watch(diagnosticsCollectorProvider),
  );
});
