import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/unread/data/channel_unread_repository_provider.dart';

void main() {
  ProviderContainer createContainer(
    _FakeAppDioClient appDioClient,
  ) {
    return ProviderContainer(
      overrides: [
        appDioClientProvider.overrideWithValue(appDioClient),
      ],
    );
  }

  const serverId = ServerScopeId('server-1');

  group('fetchUnreadCounts', () {
    test('GET /channels/unread with server header', () async {
      final client = _FakeAppDioClient(responses: {
        '/channels/unread': <Object>[
          {'channelId': 'ch-1', 'unreadCount': 5},
          {'channelId': 'ch-2', 'unreadCount': 0},
          {'channelId': 'dm-1', 'unreadCount': 3},
        ],
      });
      final container = createContainer(client);
      addTearDown(container.dispose);

      final repo = container.read(channelUnreadRepositoryProvider);
      final result = await repo.fetchUnreadCounts(serverId);

      expect(client.requests, hasLength(1));
      expect(client.requests.single.path, '/channels/unread');
      expect(
        client.requests.single.serverIdHeader,
        'server-1',
      );
      // Zero-count entries are excluded.
      expect(result, {'ch-1': 5, 'dm-1': 3});
    });

    test('parses map-shaped response', () async {
      final client = _FakeAppDioClient(responses: {
        '/channels/unread': <String, Object>{
          'ch-1': 5,
          'ch-2': 0,
          'dm-1': 3,
        },
      });
      final container = createContainer(client);
      addTearDown(container.dispose);

      final repo = container.read(channelUnreadRepositoryProvider);
      final result = await repo.fetchUnreadCounts(serverId);

      expect(result, {'ch-1': 5, 'dm-1': 3});
    });

    test('returns empty map on null response', () async {
      final client = _FakeAppDioClient(responses: {
        '/channels/unread': null,
      });
      final container = createContainer(client);
      addTearDown(container.dispose);

      final repo = container.read(channelUnreadRepositoryProvider);
      final result = await repo.fetchUnreadCounts(serverId);

      expect(result, isEmpty);
    });

    test('skips malformed items in list response', () async {
      final client = _FakeAppDioClient(responses: {
        '/channels/unread': <Object>[
          {'channelId': 'ch-1', 'unreadCount': 5},
          'not-a-map',
          {'channelId': '', 'unreadCount': 2},
          {'unreadCount': 3},
          {'channelId': 'ch-2', 'unreadCount': 'bad'},
        ],
      });
      final container = createContainer(client);
      addTearDown(container.dispose);

      final repo = container.read(channelUnreadRepositoryProvider);
      final result = await repo.fetchUnreadCounts(serverId);

      expect(result, {'ch-1': 5});
    });

    test('wraps unknown errors as UnknownFailure', () async {
      final client = _FakeAppDioClient(failures: {
        '/channels/unread': Exception('network error'),
      });
      final container = createContainer(client);
      addTearDown(container.dispose);

      final repo = container.read(channelUnreadRepositoryProvider);
      expect(
        () => repo.fetchUnreadCounts(serverId),
        throwsA(isA<UnknownFailure>()),
      );
    });

    test('rethrows AppFailure without wrapping', () async {
      final client = _FakeAppDioClient(failures: {
        '/channels/unread': const NetworkFailure(message: 'test'),
      });
      final container = createContainer(client);
      addTearDown(container.dispose);

      final repo = container.read(channelUnreadRepositoryProvider);
      expect(
        () => repo.fetchUnreadCounts(serverId),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('markChannelRead', () {
    test('POST /channels/{id}/read with server header', () async {
      final client = _FakeAppDioClient(responses: {
        '/channels/ch-1/read': null,
      });
      final container = createContainer(client);
      addTearDown(container.dispose);

      final repo = container.read(channelUnreadRepositoryProvider);
      await repo.markChannelRead(
        serverId,
        channelId: 'ch-1',
      );

      expect(client.requests, hasLength(1));
      expect(client.requests.single.method, 'POST');
      expect(
        client.requests.single.path,
        '/channels/ch-1/read',
      );
      expect(
        client.requests.single.serverIdHeader,
        'server-1',
      );
    });

    test('wraps unknown errors as UnknownFailure', () async {
      final client = _FakeAppDioClient(failures: {
        '/channels/ch-1/read': Exception('server error'),
      });
      final container = createContainer(client);
      addTearDown(container.dispose);

      final repo = container.read(channelUnreadRepositoryProvider);
      expect(
        () => repo.markChannelRead(
          serverId,
          channelId: 'ch-1',
        ),
        throwsA(isA<UnknownFailure>()),
      );
    });
  });

  group('markAllInboxRead', () {
    test('POST /channels/inbox/read-all with server header', () async {
      final client = _FakeAppDioClient(responses: {
        '/channels/inbox/read-all': null,
      });
      final container = createContainer(client);
      addTearDown(container.dispose);

      final repo = container.read(channelUnreadRepositoryProvider);
      await repo.markAllInboxRead(serverId);

      expect(client.requests, hasLength(1));
      expect(client.requests.single.method, 'POST');
      expect(
        client.requests.single.path,
        '/channels/inbox/read-all',
      );
      expect(
        client.requests.single.serverIdHeader,
        'server-1',
      );
    });

    test('wraps unknown errors as UnknownFailure', () async {
      final client = _FakeAppDioClient(failures: {
        '/channels/inbox/read-all': Exception('server error'),
      });
      final container = createContainer(client);
      addTearDown(container.dispose);

      final repo = container.read(channelUnreadRepositoryProvider);
      expect(
        () => repo.markAllInboxRead(serverId),
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
    ));
    final failure = _failures[path];
    if (failure != null) throw failure;
    return Response<T>(
      requestOptions: RequestOptions(
        path: path,
        headers: headers,
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
    this.data,
  });

  final String method;
  final String path;
  final Map<String, Object?> headers;
  final Object? data;

  String? get serverIdHeader => headers['X-Server-Id'] as String?;
}
