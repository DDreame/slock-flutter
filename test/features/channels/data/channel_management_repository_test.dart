import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/data/channel_management_repository_provider.dart';

void main() {
  group('channelManagementRepositoryProvider', () {
    test('createChannel posts text-channel payload and returns id when present',
        () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('POST', '/channels'): {'id': 'channel-2'},
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repository = container.read(channelManagementRepositoryProvider);
      final channelId = await repository.createChannel(
        const ServerScopeId('server-1'),
        name: 'support',
      );

      expect(channelId, 'channel-2');
      expect(appDioClient.requests, hasLength(1));
      expect(appDioClient.requests.single.method, 'POST');
      expect(appDioClient.requests.single.path, '/channels');
      expect(appDioClient.requests.single.serverIdHeader, 'server-1');
      expect(appDioClient.requests.single.data, {
        'name': 'support',
        'type': 'text',
      });
    });

    test('createChannel returns null when success payload omits id', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('POST', '/channels'): {'name': 'support'},
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repository = container.read(channelManagementRepositoryProvider);
      final channelId = await repository.createChannel(
        const ServerScopeId('server-1'),
        name: 'support',
      );

      expect(channelId, isNull);
    });

    test('update/delete/leave use the expected channel endpoints', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('PATCH', '/channels/channel-1'): {'id': 'channel-1'},
          ('DELETE', '/channels/channel-1'): null,
          ('POST', '/channels/channel-1/leave'): null,
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repository = container.read(channelManagementRepositoryProvider);

      await repository.updateChannel(
        const ServerScopeId('server-1'),
        channelId: 'channel-1',
        name: 'general-updated',
      );
      await repository.deleteChannel(
        const ServerScopeId('server-1'),
        channelId: 'channel-1',
      );
      await repository.leaveChannel(
        const ServerScopeId('server-1'),
        channelId: 'channel-1',
      );

      expect(
        appDioClient.requests
            .map((request) => (request.method, request.path))
            .toList(growable: false),
        [
          ('PATCH', '/channels/channel-1'),
          ('DELETE', '/channels/channel-1'),
          ('POST', '/channels/channel-1/leave'),
        ],
      );
      expect(appDioClient.requests.first.data, {'name': 'general-updated'});
      expect(
        appDioClient.requests.every(
          (request) => request.serverIdHeader == 'server-1',
        ),
        isTrue,
      );
    });
  });
}

class _FakeAppDioClient extends AppDioClient {
  _FakeAppDioClient({
    Map<(String, String), Object?> responses = const {},
    Map<(String, String), Object> failures = const {},
  })  : _responses = responses,
        _failures = failures,
        super(Dio());

  final Map<(String, String), Object?> _responses;
  final Map<(String, String), Object> _failures;
  final List<_CapturedRequest> requests = [];

  @override
  Future<Response<T>> request<T>(
    String path, {
    required String method,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final headers = Map<String, Object?>.from(options?.headers ?? const {});
    requests.add(
      _CapturedRequest(
        method: method,
        path: path,
        data: data,
        headers: headers,
      ),
    );

    final key = (method, path);
    final failure = _failures[key];
    if (failure != null) {
      throw failure;
    }

    if (!_responses.containsKey(key)) {
      throw StateError('Missing fake response for $key');
    }

    return Response<T>(
      requestOptions: RequestOptions(
        path: path,
        method: method,
        headers: headers,
      ),
      data: _responses[key] as T,
    );
  }
}

class _CapturedRequest {
  const _CapturedRequest({
    required this.method,
    required this.path,
    required this.data,
    required this.headers,
  });

  final String method;
  final String path;
  final Object? data;
  final Map<String, Object?> headers;

  String? get serverIdHeader => headers['X-Server-Id'] as String?;
}
