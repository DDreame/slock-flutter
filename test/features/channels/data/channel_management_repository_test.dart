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

    test('createChannel sends description and visibility when provided',
        () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('POST', '/channels'): {'id': 'channel-3'},
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repository = container.read(channelManagementRepositoryProvider);
      final channelId = await repository.createChannel(
        const ServerScopeId('server-1'),
        name: 'design',
        description: 'Design discussions',
        isPrivate: true,
      );

      expect(channelId, 'channel-3');
      expect(appDioClient.requests.single.data, {
        'name': 'design',
        'type': 'text',
        'description': 'Design discussions',
        'isPrivate': true,
      });
    });

    test('createChannel omits description/isPrivate when not provided',
        () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('POST', '/channels'): {'id': 'channel-4'},
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repository = container.read(channelManagementRepositoryProvider);
      await repository.createChannel(
        const ServerScopeId('server-1'),
        name: 'general',
      );

      expect(appDioClient.requests.single.data, {
        'name': 'general',
        'type': 'text',
      });
    });

    test('createChannel throws when success payload omits id', () async {
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

      expect(
        () => repository.createChannel(
          const ServerScopeId('server-1'),
          name: 'support',
        ),
        throwsA(isA<UnknownFailure>().having(
          (f) => f.message,
          'message',
          'Server did not return a channel ID.',
        )),
      );
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

    test('stopAllAgents/resumeAllAgents post to correct endpoints (#737)',
        () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('POST', '/channels/channel-1/stop-all-agents'): null,
          ('POST', '/channels/channel-1/resume-all-agents'): null,
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repository = container.read(channelManagementRepositoryProvider);

      await repository.stopAllAgents(
        const ServerScopeId('server-1'),
        channelId: 'channel-1',
      );
      await repository.resumeAllAgents(
        const ServerScopeId('server-1'),
        channelId: 'channel-1',
      );

      expect(
        appDioClient.requests
            .map((request) => (request.method, request.path))
            .toList(growable: false),
        [
          ('POST', '/channels/channel-1/stop-all-agents'),
          ('POST', '/channels/channel-1/resume-all-agents'),
        ],
        reason: '#737: stop/resume all agents must POST to correct paths',
      );
      expect(
        appDioClient.requests.every(
          (request) => request.serverIdHeader == 'server-1',
        ),
        isTrue,
        reason: '#737: requests must include X-Server-Id header',
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
    void Function(int, int)? onSendProgress,
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
