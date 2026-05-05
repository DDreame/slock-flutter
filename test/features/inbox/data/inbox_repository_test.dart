import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';

void main() {
  ProviderContainer createContainer(_FakeAppDioClient client) {
    return ProviderContainer(
      overrides: [
        appDioClientProvider.overrideWithValue(client),
      ],
    );
  }

  const serverId = ServerScopeId('server-1');

  group('fetchInbox', () {
    test('GET /channels/inbox with server header and default params', () async {
      final client = _FakeAppDioClient(responses: {
        '/channels/inbox': <String, dynamic>{
          'items': [
            {
              'kind': 'channel',
              'channelId': 'ch-1',
              'channelName': 'general',
              'unreadCount': 5,
              'lastActivityAt': '2026-05-01T12:00:00.000Z',
            },
          ],
          'totalCount': 1,
          'totalUnreadCount': 5,
          'hasMore': false,
        },
      });
      final container = createContainer(client);
      addTearDown(container.dispose);

      final repo = container.read(inboxRepositoryProvider);
      final response = await repo.fetchInbox(serverId);

      expect(client.requests, hasLength(1));
      expect(client.requests.single.path, '/channels/inbox');
      expect(client.requests.single.serverIdHeader, 'server-1');
      expect(
        client.requests.single.queryParameters,
        {'filter': 'all', 'limit': 30, 'offset': 0},
      );
      expect(response.items, hasLength(1));
      expect(response.items.first.channelId, 'ch-1');
      expect(response.totalCount, 1);
      expect(response.totalUnreadCount, 5);
      expect(response.hasMore, isFalse);
    });

    test('passes filter=unread query parameter', () async {
      final client = _FakeAppDioClient(responses: {
        '/channels/inbox': <String, dynamic>{
          'items': [],
          'totalCount': 0,
          'totalUnreadCount': 0,
          'hasMore': false,
        },
      });
      final container = createContainer(client);
      addTearDown(container.dispose);

      final repo = container.read(inboxRepositoryProvider);
      await repo.fetchInbox(serverId, filter: InboxFilter.unread);

      expect(
        client.requests.single.queryParameters?['filter'],
        'unread',
      );
    });

    test('passes pagination params', () async {
      final client = _FakeAppDioClient(responses: {
        '/channels/inbox': <String, dynamic>{
          'items': [],
          'totalCount': 50,
          'totalUnreadCount': 10,
          'hasMore': true,
        },
      });
      final container = createContainer(client);
      addTearDown(container.dispose);

      final repo = container.read(inboxRepositoryProvider);
      final response = await repo.fetchInbox(
        serverId,
        limit: 10,
        offset: 30,
      );

      expect(
        client.requests.single.queryParameters,
        {'filter': 'all', 'limit': 10, 'offset': 30},
      );
      expect(response.hasMore, isTrue);
      expect(response.totalCount, 50);
    });

    test('wraps unknown errors as UnknownFailure', () async {
      final client = _FakeAppDioClient(failures: {
        '/channels/inbox': Exception('network error'),
      });
      final container = createContainer(client);
      addTearDown(container.dispose);

      final repo = container.read(inboxRepositoryProvider);
      expect(
        () => repo.fetchInbox(serverId),
        throwsA(isA<UnknownFailure>()),
      );
    });

    test('rethrows AppFailure without wrapping', () async {
      final client = _FakeAppDioClient(failures: {
        '/channels/inbox': const NetworkFailure(message: 'test'),
      });
      final container = createContainer(client);
      addTearDown(container.dispose);

      final repo = container.read(inboxRepositoryProvider);
      expect(
        () => repo.fetchInbox(serverId),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('handles null response data gracefully', () async {
      final client = _FakeAppDioClient(responses: {
        '/channels/inbox': null,
      });
      final container = createContainer(client);
      addTearDown(container.dispose);

      final repo = container.read(inboxRepositoryProvider);
      final response = await repo.fetchInbox(serverId);

      expect(response.items, isEmpty);
      expect(response.totalCount, 0);
      expect(response.hasMore, isFalse);
    });
  });

  group('markItemRead', () {
    test('POST /channels/{id}/read-all with server header', () async {
      final client = _FakeAppDioClient(responses: {
        '/channels/ch-1/read-all': null,
      });
      final container = createContainer(client);
      addTearDown(container.dispose);

      final repo = container.read(inboxRepositoryProvider);
      await repo.markItemRead(serverId, channelId: 'ch-1');

      expect(client.requests, hasLength(1));
      expect(client.requests.single.method, 'POST');
      expect(client.requests.single.path, '/channels/ch-1/read-all');
      expect(client.requests.single.serverIdHeader, 'server-1');
    });

    test('wraps unknown errors as UnknownFailure', () async {
      final client = _FakeAppDioClient(failures: {
        '/channels/ch-1/read-all': Exception('server error'),
      });
      final container = createContainer(client);
      addTearDown(container.dispose);

      final repo = container.read(inboxRepositoryProvider);
      expect(
        () => repo.markItemRead(serverId, channelId: 'ch-1'),
        throwsA(isA<UnknownFailure>()),
      );
    });
  });

  group('markItemDone', () {
    test('POST /channels/inbox/done with channelId body', () async {
      final client = _FakeAppDioClient(responses: {
        '/channels/inbox/done': null,
      });
      final container = createContainer(client);
      addTearDown(container.dispose);

      final repo = container.read(inboxRepositoryProvider);
      await repo.markItemDone(serverId, channelId: 'ch-1');

      expect(client.requests, hasLength(1));
      expect(client.requests.single.method, 'POST');
      expect(client.requests.single.path, '/channels/inbox/done');
      expect(client.requests.single.serverIdHeader, 'server-1');
      expect(client.requests.single.data, {'channelId': 'ch-1'});
    });

    test('wraps unknown errors as UnknownFailure', () async {
      final client = _FakeAppDioClient(failures: {
        '/channels/inbox/done': Exception('server error'),
      });
      final container = createContainer(client);
      addTearDown(container.dispose);

      final repo = container.read(inboxRepositoryProvider);
      expect(
        () => repo.markItemDone(serverId, channelId: 'ch-1'),
        throwsA(isA<UnknownFailure>()),
      );
    });
  });

  group('markAllRead', () {
    test('POST /channels/inbox/read-all with server header', () async {
      final client = _FakeAppDioClient(responses: {
        '/channels/inbox/read-all': null,
      });
      final container = createContainer(client);
      addTearDown(container.dispose);

      final repo = container.read(inboxRepositoryProvider);
      await repo.markAllRead(serverId);

      expect(client.requests, hasLength(1));
      expect(client.requests.single.method, 'POST');
      expect(client.requests.single.path, '/channels/inbox/read-all');
      expect(client.requests.single.serverIdHeader, 'server-1');
    });

    test('wraps unknown errors as UnknownFailure', () async {
      final client = _FakeAppDioClient(failures: {
        '/channels/inbox/read-all': Exception('server error'),
      });
      final container = createContainer(client);
      addTearDown(container.dispose);

      final repo = container.read(inboxRepositoryProvider);
      expect(
        () => repo.markAllRead(serverId),
        throwsA(isA<UnknownFailure>()),
      );
    });
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
    final headers = Map<String, Object?>.from(
      options?.headers ?? const {},
    );
    requests.add(_CapturedRequest(
      path: path,
      headers: headers,
      queryParameters: queryParameters,
    ));
    final failure = _failures[path];
    if (failure != null) throw failure;
    return Response<T>(
      requestOptions: RequestOptions(
        path: path,
        headers: headers,
        queryParameters: queryParameters ?? {},
      ),
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
    final headers = Map<String, Object?>.from(
      options?.headers ?? const {},
    );
    requests.add(_CapturedRequest(
      method: 'POST',
      path: path,
      headers: headers,
      data: data,
    ));
    final failure = _failures[path];
    if (failure != null) throw failure;
    return Response<T>(
      requestOptions: RequestOptions(
        path: path,
        headers: headers,
        data: data,
      ),
      data: _responses[path] as T,
    );
  }
}

class _CapturedRequest {
  const _CapturedRequest({
    this.method = 'GET',
    required this.path,
    required this.headers,
    this.queryParameters,
    this.data,
  });

  final String method;
  final String path;
  final Map<String, Object?> headers;
  final Map<String, dynamic>? queryParameters;
  final Object? data;

  String? get serverIdHeader => headers['X-Server-Id'] as String?;
}
