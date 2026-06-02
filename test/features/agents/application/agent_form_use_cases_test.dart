import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agent_form_use_cases.dart';
import 'package:slock_app/features/machines/data/machines_repository.dart';

// ---------------------------------------------------------------------------
// Fake AppDioClient
// ---------------------------------------------------------------------------

class _FakeAppDioClient extends AppDioClient {
  _FakeAppDioClient({Map<(String, String), Object?> responses = const {}})
      : _responses = responses,
        super(Dio());

  final Map<(String, String), Object?> _responses;
  final List<_CapturedRequest> requests = [];
  Exception? throwOnRequest;

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
      _CapturedRequest(method: method, path: path, headers: headers),
    );

    if (throwOnRequest != null) throw throwOnRequest!;

    final key = (method, path);
    if (!_responses.containsKey(key)) {
      throw StateError('Missing fake response for $key');
    }

    return Response<T>(
      requestOptions: RequestOptions(path: path, method: method),
      data: _responses[key] as T,
    );
  }
}

class _CapturedRequest {
  const _CapturedRequest({
    required this.method,
    required this.path,
    required this.headers,
  });

  final String method;
  final String path;
  final Map<String, Object?> headers;

  String? get serverIdHeader => headers['X-Server-Id'] as String?;
}

void main() {
  const serverId = 'server-1';
  const machineId = 'machine-42';
  const runtime = 'claude';

  group('agentFormLoadMachinesUseCaseProvider', () {
    test('happy path — returns parsed MachinesSnapshot', () async {
      final client = _FakeAppDioClient(responses: {
        ('GET', '/servers/$serverId/machines'): {
          'machines': [
            {
              'id': machineId,
              'name': 'My Machine',
              'status': 'online',
              'daemonVersion': '0.40.0',
            },
          ],
        },
      });

      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);

      final loadMachines = container.read(agentFormLoadMachinesUseCaseProvider);
      final result = await loadMachines(serverId);

      expect(result, isA<MachinesSnapshot>());
      expect(result.items, hasLength(1));
      expect(result.items.first.id, machineId);

      // Verify correct headers.
      expect(client.requests, hasLength(1));
      expect(client.requests.single.serverIdHeader, serverId);
    });

    test('empty response — returns empty snapshot', () async {
      final client = _FakeAppDioClient(responses: {
        ('GET', '/servers/$serverId/machines'): <String, dynamic>{},
      });

      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);

      final loadMachines = container.read(agentFormLoadMachinesUseCaseProvider);
      final result = await loadMachines(serverId);

      expect(result.items, isEmpty);
    });

    test('network error propagates', () async {
      final client = _FakeAppDioClient();
      client.throwOnRequest = const UnknownFailure(
        message: 'Network error',
        causeType: 'DioException',
      );

      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);

      final loadMachines = container.read(agentFormLoadMachinesUseCaseProvider);

      expect(
        () => loadMachines(serverId),
        throwsA(isA<UnknownFailure>()),
      );
    });
  });

  group('agentFormLoadRuntimeModelsUseCaseProvider', () {
    test('happy path — returns parsed RuntimeModelsResult', () async {
      final client = _FakeAppDioClient(responses: {
        (
          'GET',
          '/servers/$serverId/machines/$machineId/runtime-models/$runtime'
        ): {
          'models': [
            {'id': 'claude-3-opus', 'label': 'Claude 3 Opus'},
            {'id': 'claude-3-sonnet', 'label': 'Claude 3 Sonnet'},
          ],
          'default': 'claude-3-sonnet',
        },
      });

      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);

      final loadModels =
          container.read(agentFormLoadRuntimeModelsUseCaseProvider);
      final result = await loadModels(
        serverId: serverId,
        machineId: machineId,
        runtime: runtime,
      );

      expect(result, isA<RuntimeModelsResult>());
      expect(result.models, hasLength(2));
      expect(result.models[0].id, 'claude-3-opus');
      expect(result.models[0].label, 'Claude 3 Opus');
      expect(result.models[1].id, 'claude-3-sonnet');
      expect(result.defaultModelId, 'claude-3-sonnet');

      // Verify headers.
      expect(client.requests.single.serverIdHeader, serverId);
    });

    test('empty models list — returns empty result', () async {
      final client = _FakeAppDioClient(responses: {
        (
          'GET',
          '/servers/$serverId/machines/$machineId/runtime-models/$runtime'
        ): {
          'models': <dynamic>[],
        },
      });

      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);

      final loadModels =
          container.read(agentFormLoadRuntimeModelsUseCaseProvider);
      final result = await loadModels(
        serverId: serverId,
        machineId: machineId,
        runtime: runtime,
      );

      expect(result.models, isEmpty);
      expect(result.defaultModelId, isNull);
    });

    test('malformed model entries are filtered out', () async {
      final client = _FakeAppDioClient(responses: {
        (
          'GET',
          '/servers/$serverId/machines/$machineId/runtime-models/$runtime'
        ): {
          'models': [
            {'id': 'valid-model', 'label': 'Valid'},
            {'label': 'no-id'}, // missing id — should be filtered
            42, // not a map — should be filtered
          ],
          'default': 'valid-model',
        },
      });

      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);

      final loadModels =
          container.read(agentFormLoadRuntimeModelsUseCaseProvider);
      final result = await loadModels(
        serverId: serverId,
        machineId: machineId,
        runtime: runtime,
      );

      expect(result.models, hasLength(1));
      expect(result.models[0].id, 'valid-model');
    });

    test('network error propagates', () async {
      final client = _FakeAppDioClient();
      client.throwOnRequest = const UnknownFailure(
        message: 'Timeout',
        causeType: 'DioException',
      );

      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);

      final loadModels =
          container.read(agentFormLoadRuntimeModelsUseCaseProvider);

      expect(
        () => loadModels(
          serverId: serverId,
          machineId: machineId,
          runtime: runtime,
        ),
        throwsA(isA<UnknownFailure>()),
      );
    });
  });
}
