import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/network/dio_client.dart';
import 'package:slock_app/core/notifications/notification_actions.dart';

void main() {
  group('NotificationActionRequest', () {
    test('parses reply payload from native action', () {
      final request = NotificationActionRequest.fromPayload({
        'slock.action': notificationActionReply,
        'serverId': 'server-1',
        'channelId': 'channel-1',
        'messageId': 'message-1',
        'replyText': '  hello  ',
      });

      expect(request, isNotNull);
      expect(request!.isReply, isTrue);
      expect(request.serverId, 'server-1');
      expect(request.channelId, 'channel-1');
      expect(request.messageId, 'message-1');
      expect(request.replyText, '  hello  ');
    });

    test('returns null for incomplete payload', () {
      expect(
        NotificationActionRequest.fromPayload({
          'slock.action': notificationActionReply,
          'serverId': 'server-1',
        }),
        isNull,
      );
    });
  });

  group('DioNotificationActionApi', () {
    test('posts direct reply to server-scoped messages endpoint', () async {
      final adapter = _CapturingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.slock.test'))
        ..httpClientAdapter = adapter;
      final api = DioNotificationActionApi(client: AppDioClient(dio));

      await api.sendReply(
        const NotificationActionRequest(
          action: notificationActionReply,
          serverId: 'server-1',
          channelId: 'channel-1',
          messageId: 'message-1',
          replyText: '  hello from shade  ',
        ),
      );

      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, '/messages');
      expect(adapter.requests.single.headers['X-Server-Id'], 'server-1');
      expect(adapter.bodies.single, {
        'channelId': 'channel-1',
        'content': 'hello from shade',
        'replyToId': 'message-1',
      });
    });

    test('posts mark-read to server-scoped read-all endpoint', () async {
      final adapter = _CapturingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.slock.test'))
        ..httpClientAdapter = adapter;
      final api = DioNotificationActionApi(client: AppDioClient(dio));

      await api.markRead(
        const NotificationActionRequest(
          action: notificationActionMarkRead,
          serverId: 'server-1',
          channelId: 'channel-1',
        ),
      );

      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, '/channels/channel-1/read-all');
      expect(adapter.requests.single.headers['X-Server-Id'], 'server-1');
      expect(adapter.bodies.single, isNull);
    });
  });

  group('NotificationActionHandler', () {
    test('reply sends message and marks conversation read', () async {
      final api = _FakeNotificationActionApi();
      final handler = NotificationActionHandler(api: api);

      final handled = await handler.handlePayload({
        'action': notificationActionReply,
        'serverId': 'server-1',
        'channelId': 'channel-1',
        'messageId': 'message-1',
        'replyText': 'Thanks!',
      });

      expect(handled, isTrue);
      expect(api.sentReplies.single.replyText, 'Thanks!');
      expect(api.sentReplies.single.messageId, 'message-1');
      expect(api.markedRead.single.channelId, 'channel-1');
    });

    test('blank reply is ignored', () async {
      final api = _FakeNotificationActionApi();
      final handler = NotificationActionHandler(api: api);

      final handled = await handler.handlePayload({
        'action': notificationActionReply,
        'serverId': 'server-1',
        'channelId': 'channel-1',
        'replyText': '   ',
      });

      expect(handled, isFalse);
      expect(api.sentReplies, isEmpty);
      expect(api.markedRead, isEmpty);
    });

    test('mark-read action marks read without sending', () async {
      final api = _FakeNotificationActionApi();
      final handler = NotificationActionHandler(api: api);

      final handled = await handler.handlePayload({
        'action': notificationActionMarkRead,
        'serverId': 'server-1',
        'channelId': 'channel-1',
      });

      expect(handled, isTrue);
      expect(api.sentReplies, isEmpty);
      expect(api.markedRead.single.channelId, 'channel-1');
    });
  });
}

class _FakeNotificationActionApi implements NotificationActionApi {
  final sentReplies = <NotificationActionRequest>[];
  final markedRead = <NotificationActionRequest>[];

  @override
  Future<void> sendReply(NotificationActionRequest request) async {
    sentReplies.add(request);
  }

  @override
  Future<void> markRead(NotificationActionRequest request) async {
    markedRead.add(request);
  }
}

class _CapturingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final bodies = <Object?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    bodies.add(await _decodeBody(requestStream));
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json']
      },
    );
  }

  Future<Object?> _decodeBody(Stream<List<int>>? requestStream) async {
    if (requestStream == null) return null;
    final bytes = <int>[];
    await for (final chunk in requestStream) {
      bytes.addAll(chunk);
    }
    if (bytes.isEmpty) return null;
    return jsonDecode(utf8.decode(bytes));
  }

  @override
  void close({bool force = false}) {}
}
