import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/network/dio_client.dart';
import 'package:slock_app/core/notifications/background_notification_entrypoint.dart';
import 'package:slock_app/core/notifications/background_notification_worker.dart';
import 'package:slock_app/core/notifications/notification_actions.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';

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

  group('background action handler', () {
    test('builder wires diagnostics for headless action failures', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <HttpRequest>[];
      final serverDone = server.listen((request) async {
        requests.add(request);
        await request.drain<void>();
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      }).asFuture<void>();
      addTearDown(() async {
        await server.close(force: true);
        await serverDone.catchError((_) {});
      });

      final diagnostics = DiagnosticsCollector();
      final handler = buildBackgroundNotificationActionHandler(
        _FakeBackgroundAuthProvider(
          apiBaseUrl: 'http://${server.address.host}:${server.port}',
        ),
        diagnostics: diagnostics,
      );

      final handled = await handler.handlePayload({
        'action': notificationActionMarkRead,
        'serverId': 'server-1',
        'channelId': 'channel-1',
      });

      expect(handled, isFalse);
      expect(requests, hasLength(2));
      expect(diagnostics.entries.map((entry) => entry.level), [
        DiagnosticsLevel.warning,
        DiagnosticsLevel.error,
      ]);
      expect(
        diagnostics.entries.last.message,
        'notification mark-read failed after retry',
      );
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

    test('DioException from reply is contained and logged', () async {
      final diagnostics = DiagnosticsCollector();
      final api = _FakeNotificationActionApi()
        ..sendReplyError = _dioException(DioExceptionType.badResponse);
      final handler = NotificationActionHandler(
        api: api,
        diagnostics: diagnostics,
      );

      final handled = await handler.handlePayload({
        'action': notificationActionReply,
        'serverId': 'server-1',
        'channelId': 'channel-1',
        'replyText': 'background reply',
      });

      expect(handled, isFalse);
      expect(api.sentReplies.single.replyText, 'background reply');
      expect(api.markedRead, isEmpty);
      expect(diagnostics.entries.single.level, DiagnosticsLevel.error);
      expect(diagnostics.entries.single.tag, 'notification-action');
      expect(diagnostics.entries.single.message, 'notification action failed');
      expect(diagnostics.entries.single.metadata?['errorType'], 'DioException');
    });

    test('partial reply success retries mark-read and logs retry', () async {
      final diagnostics = DiagnosticsCollector();
      final api = _FakeNotificationActionApi()
        ..markReadErrors.add(_dioException(DioExceptionType.badResponse));
      final handler = NotificationActionHandler(
        api: api,
        diagnostics: diagnostics,
      );

      final handled = await handler.handlePayload({
        'action': notificationActionReply,
        'serverId': 'server-1',
        'channelId': 'channel-1',
        'messageId': 'message-1',
        'replyText': 'sent reply',
      });

      expect(handled, isTrue);
      expect(api.sentReplies.single.replyText, 'sent reply');
      expect(api.markedRead, hasLength(2));
      expect(
        diagnostics.entries.map((entry) => entry.message),
        containsAll([
          'notification mark-read failed; retrying',
          'notification mark-read retry succeeded',
        ]),
      );
      expect(diagnostics.entries.first.level, DiagnosticsLevel.warning);
      expect(diagnostics.entries.last.level, DiagnosticsLevel.info);
    });

    test('network timeout during mark-read retries then returns false',
        () async {
      final diagnostics = DiagnosticsCollector();
      final api = _FakeNotificationActionApi()
        ..markReadErrors.addAll([
          _dioException(DioExceptionType.connectionTimeout),
          _dioException(DioExceptionType.connectionTimeout),
        ]);
      final handler = NotificationActionHandler(
        api: api,
        diagnostics: diagnostics,
      );

      final handled = await handler.handlePayload({
        'action': notificationActionMarkRead,
        'serverId': 'server-1',
        'channelId': 'channel-1',
      });

      expect(handled, isFalse);
      expect(api.sentReplies, isEmpty);
      expect(api.markedRead, hasLength(2));
      expect(diagnostics.entries.map((entry) => entry.level), [
        DiagnosticsLevel.warning,
        DiagnosticsLevel.error,
      ]);
      expect(
        diagnostics.entries.last.message,
        'notification mark-read failed after retry',
      );
      expect(diagnostics.entries.last.metadata?['attempts'], 2);
    });
  });
}

class _FakeNotificationActionApi implements NotificationActionApi {
  final sentReplies = <NotificationActionRequest>[];
  final markedRead = <NotificationActionRequest>[];
  final markReadErrors = <Object>[];
  Object? sendReplyError;

  @override
  Future<void> sendReply(NotificationActionRequest request) async {
    sentReplies.add(request);
    final error = sendReplyError;
    if (error != null) throw error;
  }

  @override
  Future<void> markRead(NotificationActionRequest request) async {
    markedRead.add(request);
    if (markReadErrors.isNotEmpty) {
      throw markReadErrors.removeAt(0);
    }
  }
}

DioException _dioException(DioExceptionType type) {
  return DioException(
    requestOptions: RequestOptions(path: '/notification-action'),
    type: type,
    response: type == DioExceptionType.badResponse
        ? Response<Object?>(
            statusCode: 500,
            requestOptions: RequestOptions(path: '/notification-action'),
          )
        : null,
  );
}

class _FakeBackgroundAuthProvider implements BackgroundAuthProvider {
  const _FakeBackgroundAuthProvider({required this.apiBaseUrl});

  @override
  final String apiBaseUrl;

  @override
  String get realtimeUrl => 'wss://realtime.slock.test';

  @override
  String? get serverId => 'server-1';

  @override
  String? get token => 'token-1';

  @override
  String? get userId => 'user-1';
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
