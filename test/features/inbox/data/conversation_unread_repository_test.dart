import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/inbox/data/conversation_unread_repository_provider.dart';

void main() {
  const serverId = ServerScopeId('server-1');

  test('POST /channels/{id}/unread with server header and no body', () async {
    final client = _FakeAppDioClient();
    final container = ProviderContainer(
      overrides: [appDioClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    await container
        .read(conversationUnreadRepositoryProvider)
        .markAsUnread(serverId, channelId: 'ch-1');

    expect(client.requests, hasLength(1));
    expect(client.requests.single.method, 'POST');
    expect(client.requests.single.path, '/channels/ch-1/unread');
    expect(client.requests.single.serverIdHeader, 'server-1');
    expect(client.requests.single.data, isNull);
  });

  test('wraps unknown errors as UnknownFailure', () async {
    final client = _FakeAppDioClient(failures: {
      '/channels/ch-1/unread': Exception('server error'),
    });
    final container = ProviderContainer(
      overrides: [appDioClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    expect(
      () => container
          .read(conversationUnreadRepositoryProvider)
          .markAsUnread(serverId, channelId: 'ch-1'),
      throwsA(isA<UnknownFailure>()),
    );
  });
}

class _FakeAppDioClient extends AppDioClient {
  _FakeAppDioClient({Map<String, Object> failures = const {}})
      : _failures = failures,
        super(Dio());

  final Map<String, Object> _failures;
  final List<_CapturedRequest> requests = [];

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
    void Function(int, int)? onSendProgress,
  }) async {
    final headers = Map<String, Object?>.from(options?.headers ?? const {});
    requests.add(_CapturedRequest(
      method: 'POST',
      path: path,
      headers: headers,
      data: data,
    ));
    final failure = _failures[path];
    if (failure != null) throw failure;
    return Response<T>(
      requestOptions: RequestOptions(path: path, headers: headers, data: data),
    );
  }
}

class _CapturedRequest {
  const _CapturedRequest({
    required this.method,
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
