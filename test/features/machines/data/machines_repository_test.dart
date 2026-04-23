import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/machines/data/machines_repository_provider.dart';

void main() {
  group('machinesRepositoryProvider', () {
    test(
      'loadMachines sends GET /servers/:id/machines with server header',
      () async {
        final appDioClient = _FakeAppDioClient(
          responses: {
            ('GET', '/servers/server-1/machines'): {
              'machines': [
                {
                  'id': 'machine-1',
                  'name': 'Build node',
                  'status': 'online',
                  'statusVersion': 4,
                  'runtimes': ['codex', 'claude'],
                  'hostname': 'builder.local',
                  'os': 'macOS',
                  'daemonVersion': '1.2.3',
                  'apiKeyPrefix': 'sk-machine-1',
                },
              ],
              'latestDaemonVersion': '1.2.3',
            },
          },
        );
        final container = ProviderContainer(
          overrides: [
            currentMachinesServerIdProvider.overrideWithValue(
              const ServerScopeId('server-1'),
            ),
            appDioClientProvider.overrideWithValue(appDioClient),
          ],
        );
        addTearDown(container.dispose);

        final snapshot =
            await container.read(machinesRepositoryProvider).loadMachines();

        expect(snapshot.latestDaemonVersion, '1.2.3');
        expect(snapshot.items, hasLength(1));
        expect(snapshot.items.single.name, 'Build node');
        expect(snapshot.items.single.hostname, 'builder.local');
        expect(snapshot.items.single.runtimes, ['codex', 'claude']);
        expect(appDioClient.requests.single.method, 'GET');
        expect(appDioClient.requests.single.path, '/servers/server-1/machines');
        expect(appDioClient.requests.single.serverIdHeader, 'server-1');
      },
    );

    test('registerMachine sends POST and returns machine + api key', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('POST', '/servers/server-1/machines'): {
            'machine': {
              'id': 'machine-2',
              'name': 'Runner',
              'status': 'offline',
              'runtimes': ['codex'],
            },
            'apiKey': 'sk-machine-2-secret',
          },
        },
      );
      final container = ProviderContainer(
        overrides: [
          currentMachinesServerIdProvider.overrideWithValue(
            const ServerScopeId('server-1'),
          ),
          appDioClientProvider.overrideWithValue(appDioClient),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(machinesRepositoryProvider)
          .registerMachine(name: 'Runner');

      expect(result.machine.id, 'machine-2');
      expect(result.machine.apiKeyPrefix, 'sk-machine-2-secret');
      expect(result.apiKey, 'sk-machine-2-secret');
      expect(appDioClient.requests.single.method, 'POST');
      expect(appDioClient.requests.single.data, {'name': 'Runner'});
    });

    test(
      'renameMachine sends PATCH to /servers/:id/machines/:machineId',
      () async {
        final appDioClient = _FakeAppDioClient(
          responses: {('PATCH', '/servers/server-1/machines/machine-1'): null},
        );
        final container = ProviderContainer(
          overrides: [
            currentMachinesServerIdProvider.overrideWithValue(
              const ServerScopeId('server-1'),
            ),
            appDioClientProvider.overrideWithValue(appDioClient),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(machinesRepositoryProvider)
            .renameMachine('machine-1', name: 'Renamed node');

        expect(appDioClient.requests.single.method, 'PATCH');
        expect(
          appDioClient.requests.single.path,
          '/servers/server-1/machines/machine-1',
        );
        expect(appDioClient.requests.single.data, {'name': 'Renamed node'});
      },
    );

    test(
      'rotateMachineApiKey and deleteMachine hit the expected endpoints',
      () async {
        final appDioClient = _FakeAppDioClient(
          responses: {
            ('POST', '/servers/server-1/machines/machine-1/rotate-key'): {
              'apiKey': 'sk-rotated-value',
            },
            ('DELETE', '/servers/server-1/machines/machine-1'): null,
          },
        );
        final container = ProviderContainer(
          overrides: [
            currentMachinesServerIdProvider.overrideWithValue(
              const ServerScopeId('server-1'),
            ),
            appDioClientProvider.overrideWithValue(appDioClient),
          ],
        );
        addTearDown(container.dispose);

        final apiKey = await container
            .read(machinesRepositoryProvider)
            .rotateMachineApiKey('machine-1');
        await container
            .read(machinesRepositoryProvider)
            .deleteMachine('machine-1');

        expect(apiKey, 'sk-rotated-value');
        expect(
          appDioClient.requests[0].path,
          '/servers/server-1/machines/machine-1/rotate-key',
        );
        expect(
          appDioClient.requests[1].path,
          '/servers/server-1/machines/machine-1',
        );
        expect(appDioClient.requests[1].method, 'DELETE');
      },
    );
  });
}

class _FakeAppDioClient extends AppDioClient {
  _FakeAppDioClient({Map<(String, String), Object?> responses = const {}})
      : _responses = responses,
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

  String? get serverIdHeader => headers['X-Server-Id'] as String?;
}
