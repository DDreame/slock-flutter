import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';

void main() {
  group('agentsRepositoryProvider', () {
    test('listAgents sends GET /agents', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('GET', '/agents'): [
            {
              'id': 'agent-1',
              'name': 'Bot Alpha',
              'model': 'sonnet',
              'runtime': 'claude',
              'status': 'active',
              'activity': 'online',
              'activityDetail': 'Idle',
            },
          ],
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repo = container.read(agentsRepositoryProvider);
      final agents = await repo.listAgents();

      expect(agents.length, 1);
      expect(agents.first.id, 'agent-1');
      expect(agents.first.name, 'Bot Alpha');
      expect(agents.first.activity, 'online');
      expect(appDioClient.requests.single.method, 'GET');
      expect(appDioClient.requests.single.path, '/agents');
    });

    test('startAgent sends POST /agents/:id/start', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('POST', '/agents/agent-1/start'): null,
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repo = container.read(agentsRepositoryProvider);
      await repo.startAgent('agent-1');

      expect(appDioClient.requests.single.method, 'POST');
      expect(appDioClient.requests.single.path, '/agents/agent-1/start');
    });

    test('stopAgent sends POST /agents/:id/stop', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('POST', '/agents/agent-1/stop'): null,
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repo = container.read(agentsRepositoryProvider);
      await repo.stopAgent('agent-1');

      expect(appDioClient.requests.single.method, 'POST');
      expect(appDioClient.requests.single.path, '/agents/agent-1/stop');
    });

    test('resetAgent sends POST /agents/:id/reset with mode', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('POST', '/agents/agent-1/reset'): null,
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repo = container.read(agentsRepositoryProvider);
      await repo.resetAgent('agent-1', mode: 'session');

      expect(appDioClient.requests.single.method, 'POST');
      expect(appDioClient.requests.single.path, '/agents/agent-1/reset');
      expect(appDioClient.requests.single.data, {'mode': 'session'});
    });

    test('getActivityLog sends GET /agents/:id/activity-log', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('GET', '/agents/agent-1/activity-log'): [
            {
              'timestamp': '2026-04-22T10:00:00Z',
              'entry': 'Agent started',
            },
          ],
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repo = container.read(agentsRepositoryProvider);
      final log = await repo.getActivityLog('agent-1');

      expect(log.length, 1);
      expect(log.first.entry, 'Agent started');
      expect(appDioClient.requests.single.path, '/agents/agent-1/activity-log');
    });
  });
}

class _FakeAppDioClient extends AppDioClient {
  _FakeAppDioClient({
    Map<(String, String), Object?> responses = const {},
  })  : _responses = responses,
        super(Dio());

  final Map<(String, String), Object?> _responses;
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
}
