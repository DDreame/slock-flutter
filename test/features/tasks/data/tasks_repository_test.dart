import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';

void main() {
  group('tasksRepositoryProvider', () {
    test('listServerTasks sends GET /tasks/server with server header',
        () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('GET', '/tasks/server'): {
            'tasks': [
              {
                'id': 'task-1',
                'taskNumber': 1,
                'title': 'Fix bug',
                'status': 'todo',
                'channelId': 'ch1',
                'channelType': 'channel',
                'createdById': 'user-1',
                'createdByName': 'Alice',
                'createdByType': 'user',
                'createdAt': '2026-04-22T10:00:00Z',
              },
            ],
          },
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repo = container.read(tasksRepositoryProvider);
      final tasks = await repo.listServerTasks(const ServerScopeId('server-1'));

      expect(tasks.length, 1);
      expect(tasks.first.id, 'task-1');
      expect(tasks.first.title, 'Fix bug');
      expect(tasks.first.status, 'todo');
      expect(appDioClient.requests.single.method, 'GET');
      expect(appDioClient.requests.single.path, '/tasks/server');
      expect(appDioClient.requests.single.serverIdHeader, 'server-1');
    });

    test('createTasks sends POST with batch payload', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('POST', '/tasks/channel/ch1'): {
            'tasks': [
              {
                'id': 'task-new',
                'taskNumber': 2,
                'title': 'New task',
                'status': 'todo',
                'channelId': 'ch1',
                'channelType': 'channel',
                'createdById': 'user-1',
                'createdByName': 'Alice',
                'createdByType': 'user',
                'createdAt': '2026-04-22T10:00:00Z',
              },
            ],
          },
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repo = container.read(tasksRepositoryProvider);
      final tasks = await repo.createTasks(
        const ServerScopeId('server-1'),
        channelId: 'ch1',
        titles: ['New task'],
      );

      expect(tasks.length, 1);
      expect(tasks.first.title, 'New task');
      expect(appDioClient.requests.single.method, 'POST');
      expect(appDioClient.requests.single.data, {
        'tasks': [
          {'title': 'New task'}
        ],
      });
    });

    test('updateTaskStatus sends PATCH with status', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('PATCH', '/tasks/task-1/status'): {
            'task': {
              'id': 'task-1',
              'taskNumber': 1,
              'title': 'Fix bug',
              'status': 'in_progress',
              'channelId': 'ch1',
              'channelType': 'channel',
              'createdById': 'user-1',
              'createdByName': 'Alice',
              'createdByType': 'user',
              'createdAt': '2026-04-22T10:00:00Z',
            },
          },
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repo = container.read(tasksRepositoryProvider);
      final updated = await repo.updateTaskStatus(
        const ServerScopeId('server-1'),
        taskId: 'task-1',
        status: 'in_progress',
      );

      expect(updated.status, 'in_progress');
      expect(appDioClient.requests.single.data, {'status': 'in_progress'});
    });

    test('deleteTask sends DELETE', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('DELETE', '/tasks/task-1'): null,
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repo = container.read(tasksRepositoryProvider);
      await repo.deleteTask(
        const ServerScopeId('server-1'),
        taskId: 'task-1',
      );

      expect(appDioClient.requests.single.method, 'DELETE');
      expect(appDioClient.requests.single.path, '/tasks/task-1');
    });

    test('claimTask sends PATCH to /tasks/:id/claim', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('PATCH', '/tasks/task-1/claim'): {
            'task': {
              'id': 'task-1',
              'taskNumber': 1,
              'title': 'Fix bug',
              'status': 'todo',
              'channelId': 'ch1',
              'channelType': 'channel',
              'claimedById': 'user-1',
              'claimedByName': 'Alice',
              'createdById': 'user-1',
              'createdByName': 'Alice',
              'createdByType': 'user',
              'createdAt': '2026-04-22T10:00:00Z',
            },
          },
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repo = container.read(tasksRepositoryProvider);
      final claimed = await repo.claimTask(
        const ServerScopeId('server-1'),
        taskId: 'task-1',
      );

      expect(claimed.claimedById, 'user-1');
      expect(appDioClient.requests.single.path, '/tasks/task-1/claim');
    });

    test('unclaimTask sends PATCH to /tasks/:id/unclaim', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('PATCH', '/tasks/task-1/unclaim'): {
            'task': {
              'id': 'task-1',
              'taskNumber': 1,
              'title': 'Fix bug',
              'status': 'todo',
              'channelId': 'ch1',
              'channelType': 'channel',
              'createdById': 'user-1',
              'createdByName': 'Alice',
              'createdByType': 'user',
              'createdAt': '2026-04-22T10:00:00Z',
            },
          },
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repo = container.read(tasksRepositoryProvider);
      final unclaimed = await repo.unclaimTask(
        const ServerScopeId('server-1'),
        taskId: 'task-1',
      );

      expect(unclaimed.claimedById, isNull);
      expect(appDioClient.requests.single.path, '/tasks/task-1/unclaim');
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

  String? get serverIdHeader => headers['X-Server-Id'] as String?;
}
