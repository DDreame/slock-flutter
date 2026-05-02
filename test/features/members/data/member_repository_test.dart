import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';

void main() {
  group('memberRepositoryProvider', () {
    test('listMembers gets server-scoped members payload', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('GET', '/servers/s1/members'): {
            'members': [
              {
                'id': 'user-1',
                'displayName': 'Alice',
                'username': 'alice',
                'type': 'human',
                'presence': {'label': 'online'},
              },
            ],
          },
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repository = container.read(memberRepositoryProvider);
      final members = await repository.listMembers(const ServerScopeId('s1'));

      expect(members, [
        const MemberProfile(
          id: 'user-1',
          displayName: 'Alice',
          username: 'alice',
          type: MemberType.human,
          presence: 'online',
        ),
      ]);
      expect(appDioClient.requests.single.method, 'GET');
      expect(appDioClient.requests.single.path, '/servers/s1/members');
      expect(appDioClient.requests.single.serverIdHeader, 's1');
    });

    test('listMembers parses agent type and description', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('GET', '/servers/s1/members'): {
            'members': [
              {
                'id': 'agent-1',
                'displayName': 'J1',
                'type': 'agent',
                'description': 'Developer agent',
                'presence': 'online',
                'role': 'member',
              },
            ],
          },
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repository = container.read(memberRepositoryProvider);
      final members = await repository.listMembers(const ServerScopeId('s1'));

      expect(members.single.type, MemberType.agent);
      expect(members.single.isAgent, isTrue);
      expect(members.single.description, 'Developer agent');
    });

    test('listMembers defaults to human type when not specified', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('GET', '/servers/s1/members'): {
            'members': [
              {
                'id': 'user-1',
                'displayName': 'Alice',
              },
            ],
          },
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repository = container.read(memberRepositoryProvider);
      final members = await repository.listMembers(const ServerScopeId('s1'));

      expect(members.single.type, MemberType.human);
      expect(members.single.isAgent, isFalse);
    });

    test(
      'openDirectMessage posts payload and returns nested channel id',
      () async {
        final appDioClient = _FakeAppDioClient(
          responses: {
            ('POST', '/channels/dm'): {
              'channel': {'id': 'dm-123'},
            },
          },
        );
        final container = ProviderContainer(
          overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
        );
        addTearDown(container.dispose);

        final repository = container.read(memberRepositoryProvider);
        final channelId = await repository.openDirectMessage(
          const ServerScopeId('s1'),
          userId: 'user-2',
        );

        expect(channelId, 'dm-123');
        expect(appDioClient.requests.single.method, 'POST');
        expect(appDioClient.requests.single.path, '/channels/dm');
        expect(appDioClient.requests.single.serverIdHeader, 's1');
        expect(appDioClient.requests.single.data, {'userId': 'user-2'});
      },
    );

    test(
      'createInvite posts to server invite path and parses invite url',
      () async {
        final appDioClient = _FakeAppDioClient(
          responses: {
            ('POST', '/servers/s1/invites'): {
              'invite': {'url': 'https://slock.ai/invite/token-123'},
            },
          },
        );
        final container = ProviderContainer(
          overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
        );
        addTearDown(container.dispose);

        final repository = container.read(memberRepositoryProvider);
        final inviteCode = await repository.createInvite(
          const ServerScopeId('s1'),
        );

        expect(inviteCode, 'https://slock.ai/invite/token-123');
        expect(appDioClient.requests.single.method, 'POST');
        expect(appDioClient.requests.single.path, '/servers/s1/invites');
        expect(appDioClient.requests.single.serverIdHeader, 's1');
      },
    );

    test('inviteByEmail posts email payload to server invite path', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {('POST', '/servers/s1/invites'): null},
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repository = container.read(memberRepositoryProvider);
      await repository.inviteByEmail(
        const ServerScopeId('s1'),
        email: 'user@example.com',
      );

      expect(appDioClient.requests.single.method, 'POST');
      expect(appDioClient.requests.single.path, '/servers/s1/invites');
      expect(appDioClient.requests.single.serverIdHeader, 's1');
      expect(appDioClient.requests.single.data, {'email': 'user@example.com'});
    });

    test('updateMemberRole patches server member role', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {('PATCH', '/servers/s1/members/user-2'): null},
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repository = container.read(memberRepositoryProvider);
      await repository.updateMemberRole(
        const ServerScopeId('s1'),
        userId: 'user-2',
        role: 'admin',
      );

      expect(appDioClient.requests.single.method, 'PATCH');
      expect(appDioClient.requests.single.path, '/servers/s1/members/user-2');
      expect(appDioClient.requests.single.serverIdHeader, 's1');
      expect(appDioClient.requests.single.data, {'role': 'admin'});
    });

    test(
      'openAgentDirectMessage posts agentId payload and returns channel id',
      () async {
        final appDioClient = _FakeAppDioClient(
          responses: {
            ('POST', '/channels/dm'): {
              'channel': {'id': 'dm-agent-456'},
            },
          },
        );
        final container = ProviderContainer(
          overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
        );
        addTearDown(container.dispose);

        final repository = container.read(memberRepositoryProvider);
        final channelId = await repository.openAgentDirectMessage(
          const ServerScopeId('s1'),
          agentId: 'agent-1',
        );

        expect(channelId, 'dm-agent-456');
        expect(appDioClient.requests.single.method, 'POST');
        expect(appDioClient.requests.single.path, '/channels/dm');
        expect(appDioClient.requests.single.serverIdHeader, 's1');
        expect(appDioClient.requests.single.data, {'agentId': 'agent-1'});
      },
    );

    test('removeMember deletes server member path', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {('DELETE', '/servers/s1/members/user-2'): null},
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repository = container.read(memberRepositoryProvider);
      await repository.removeMember(
        const ServerScopeId('s1'),
        userId: 'user-2',
      );

      expect(appDioClient.requests.single.method, 'DELETE');
      expect(appDioClient.requests.single.path, '/servers/s1/members/user-2');
      expect(appDioClient.requests.single.serverIdHeader, 's1');
    });
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
