import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';

void main() {
  ProviderContainer createContainer(_FakeAppDioClient appDioClient) {
    return ProviderContainer(
      overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
    );
  }

  test('loads followed threads with explicit parent channel route context',
      () async {
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/channels/threads/followed': {
          'threads': [
            {
              'channelId': 'general',
              'parentMessageId': 'message-1',
              'threadChannelId': 'thread-1',
              'channelName': 'general',
              'parentMessagePreview': 'Need input here',
              'parentMessageSenderName': 'Robin',
              'replyCount': 3,
              'unreadCount': 1,
              'participantIds': ['u1', 'u2'],
              'lastReplyAt': '2026-04-21T08:00:00Z',
            },
          ],
        },
      },
    );
    final container = createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(threadRepositoryProvider);
    final items = await repository.loadFollowedThreads(
      const ServerScopeId('server-1'),
    );

    final request = appDioClient.requests.single;
    expect(request.path, '/channels/threads/followed');
    expect(request.serverIdHeader, 'server-1');
    expect(items, hasLength(1));
    expect(
      items.single.routeTarget,
      const ThreadRouteTarget(
        serverId: 'server-1',
        parentChannelId: 'general',
        parentMessageId: 'message-1',
        threadChannelId: 'thread-1',
        isFollowed: true,
      ),
    );
    expect(items.single.replyCount, 3);
    expect(items.single.unreadCount, 1);
    expect(items.single.senderName, 'Robin');
  });

  test('resolveThread posts explicit parent message id to parent channel path',
      () async {
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/channels/general/threads': {
          'threadChannelId': 'thread-1',
          'replyCount': 5,
          'participantIds': ['u1', 'u2'],
        },
      },
    );
    final container = createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(threadRepositoryProvider);
    final resolved = await repository.resolveThread(
      const ThreadRouteTarget(
        serverId: 'server-1',
        parentChannelId: 'general',
        parentMessageId: 'message-1',
      ),
    );

    final request = appDioClient.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/channels/general/threads');
    expect(request.serverIdHeader, 'server-1');
    expect(request.data, {'parentMessageId': 'message-1'});
    expect(resolved.threadChannelId, 'thread-1');
    expect(resolved.replyCount, 5);
  });

  test('follow, done, and read reuse exact server-scoped thread endpoints',
      () async {
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/channels/threads/follow': const {},
        '/channels/threads/done': const {},
        '/channels/thread-1/read-all': const {},
      },
    );
    final container = createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(threadRepositoryProvider);
    await repository.followThread(
      const ThreadRouteTarget(
        serverId: 'server-1',
        parentChannelId: 'general',
        parentMessageId: 'message-1',
      ),
    );
    await repository.markThreadDone(
      const ServerScopeId('server-1'),
      threadChannelId: 'thread-1',
    );
    await repository.markThreadRead(
      const ServerScopeId('server-1'),
      threadChannelId: 'thread-1',
    );

    expect(
      appDioClient.requests.map((request) => request.path),
      [
        '/channels/threads/follow',
        '/channels/threads/done',
        '/channels/thread-1/read-all',
      ],
    );
    expect(
      appDioClient.requests
          .every((request) => request.serverIdHeader == 'server-1'),
      isTrue,
    );
  });
}

class _FakeAppDioClient extends AppDioClient {
  _FakeAppDioClient({
    Map<String, Object?> responses = const {},
    Map<String, Object> failures = const {},
  })  : _responses = responses,
        _failures = failures,
        super(Dio());

  final Map<String, Object?> _responses;
  final Map<String, Object> _failures;
  final List<_CapturedRequest> requests = [];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    final headers = Map<String, Object?>.from(options?.headers ?? const {});
    requests.add(
      _CapturedRequest(
        path: path,
        headers: headers,
        queryParameters: queryParameters ?? const {},
      ),
    );
    final failure = _failures[path];
    if (failure != null) {
      throw failure;
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path, headers: headers),
      data: _responses[path] as T,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    final headers = Map<String, Object?>.from(options?.headers ?? const {});
    requests.add(
      _CapturedRequest(
        method: 'POST',
        path: path,
        headers: headers,
        queryParameters: queryParameters ?? const {},
        data: data,
      ),
    );
    final failure = _failures[path];
    if (failure != null) {
      throw failure;
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path, headers: headers, data: data),
      data: _responses[path] as T,
    );
  }
}

class _CapturedRequest {
  const _CapturedRequest({
    this.method = 'GET',
    required this.path,
    required this.headers,
    required this.queryParameters,
    this.data,
  });

  final String method;
  final String path;
  final Map<String, Object?> headers;
  final Map<String, dynamic> queryParameters;
  final Object? data;

  String? get serverIdHeader => headers['X-Server-Id'] as String?;
}
