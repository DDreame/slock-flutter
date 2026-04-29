import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';

void main() {
  group('serverListRepositoryProvider', () {
    test('loadServers parses workspaces with optional role and slug', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('GET', '/servers'): [
            {
              'id': 'server-1',
              'name': 'Workspace A',
              'slug': 'workspace-a',
              'role': 'owner',
            },
            {'id': 'server-2', 'name': 'Workspace B', 'role': 'member'},
          ],
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repo = container.read(serverListRepositoryProvider);
      final servers = await repo.loadServers();

      expect(servers, const [
        ServerSummary(
          id: 'server-1',
          name: 'Workspace A',
          slug: 'workspace-a',
          role: 'owner',
        ),
        ServerSummary(id: 'server-2', name: 'Workspace B', role: 'member'),
      ]);
      expect(appDioClient.requests.single.method, 'GET');
      expect(appDioClient.requests.single.path, '/servers');
    });

    test(
      'createServer posts name and slug and parses created workspace',
      () async {
        final appDioClient = _FakeAppDioClient(
          responses: {
            ('POST', '/servers'): {
              'id': 'server-3',
              'name': 'Workspace C',
              'slug': 'workspace-c',
              'role': 'owner',
            },
          },
        );
        final container = ProviderContainer(
          overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
        );
        addTearDown(container.dispose);

        final repo = container.read(serverListRepositoryProvider);
        final server = await repo.createServer(
          name: 'Workspace C',
          slug: 'workspace-c',
        );

        expect(
          server,
          const ServerSummary(
            id: 'server-3',
            name: 'Workspace C',
            slug: 'workspace-c',
            role: 'owner',
          ),
        );
        expect(appDioClient.requests.single.method, 'POST');
        expect(appDioClient.requests.single.path, '/servers');
        expect(appDioClient.requests.single.data, {
          'name': 'Workspace C',
          'slug': 'workspace-c',
        });
      },
    );

    test('renameServer patches server name', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('PATCH', '/servers/server-1'): {'name': 'Workspace Renamed'},
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repo = container.read(serverListRepositoryProvider);
      final updatedName = await repo.renameServer(
        'server-1',
        name: 'Workspace Renamed',
      );

      expect(updatedName, 'Workspace Renamed');
      expect(appDioClient.requests.single.method, 'PATCH');
      expect(appDioClient.requests.single.path, '/servers/server-1');
      expect(appDioClient.requests.single.data, {'name': 'Workspace Renamed'});
    });

    test('deleteServer sends DELETE /servers/:id', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {('DELETE', '/servers/server-1'): null},
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repo = container.read(serverListRepositoryProvider);
      await repo.deleteServer('server-1');

      expect(appDioClient.requests.single.method, 'DELETE');
      expect(appDioClient.requests.single.path, '/servers/server-1');
    });

    test('leaveServer posts to /servers/:id/leave', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {('POST', '/servers/server-1/leave'): null},
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repo = container.read(serverListRepositoryProvider);
      await repo.leaveServer('server-1');

      expect(appDioClient.requests.single.method, 'POST');
      expect(appDioClient.requests.single.path, '/servers/server-1/leave');
    });

    test(
      'acceptInvite posts token to auth path and returns server id',
      () async {
        final appDioClient = _FakeAppDioClient(
          responses: {
            ('POST', '/auth/accept-invite'): {'serverId': 'server-9'},
          },
        );
        final container = ProviderContainer(
          overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
        );
        addTearDown(container.dispose);

        final repo = container.read(serverListRepositoryProvider);
        final result = await repo.acceptInvite('token-123');

        expect(result.serverId, 'server-9');
        expect(appDioClient.requests.single.method, 'POST');
        expect(appDioClient.requests.single.path, '/auth/accept-invite');
        expect(appDioClient.requests.single.data, {'token': 'token-123'});
      },
    );
  });

  test('ServerSummary equality includes optional fields', () {
    const a = ServerSummary(
      id: 'x',
      name: 'X',
      slug: 'workspace-x',
      role: 'owner',
    );
    const b = ServerSummary(
      id: 'x',
      name: 'X',
      slug: 'workspace-x',
      role: 'owner',
    );
    const c = ServerSummary(id: 'x', name: 'X');

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
  });

  test('ServerSummary equality includes slug and role', () {
    const a = ServerSummary(id: 'x', name: 'X', slug: 'x-slug', role: 'owner');
    const b = ServerSummary(id: 'x', name: 'X', slug: 'x-slug', role: 'owner');
    const c = ServerSummary(id: 'x', name: 'X', slug: 'x-slug', role: 'member');

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
  });

  test('ServerSummary role helpers', () {
    const owner = ServerSummary(id: 'x', name: 'X', role: 'owner');
    const admin = ServerSummary(id: 'x', name: 'X', role: 'admin');
    const member = ServerSummary(id: 'x', name: 'X', role: 'member');
    const unknown = ServerSummary(id: 'x', name: 'X');

    expect(owner.isOwner, isTrue);
    expect(owner.isAdmin, isTrue);
    expect(admin.isOwner, isFalse);
    expect(admin.isAdmin, isTrue);
    expect(member.isOwner, isFalse);
    expect(member.isAdmin, isFalse);
    expect(unknown.isOwner, isFalse);
    expect(unknown.isAdmin, isFalse);
  });

  test('ServerSummary defaults for optional fields', () {
    const server = ServerSummary(id: 'x', name: 'X');
    expect(server.slug, '');
    expect(server.role, '');
    expect(server.createdAt, isNull);
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
    requests.add(_CapturedRequest(method: method, path: path, data: data));

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
    required this.data,
  });

  final String method;
  final String path;
  final Object? data;
}
