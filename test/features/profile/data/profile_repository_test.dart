import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/profile/data/profile_repository_provider.dart';

void main() {
  group('profileRepositoryProvider', () {
    test('loadProfile gets the server-scoped member profile payload', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          ('GET', '/servers/server-1/members/user-2/profile'): {
            'profile': {
              'id': 'user-2',
              'displayName': 'Bob',
              'username': 'bob',
              'email': 'bob@example.com',
              'role': 'member',
              'presence': {'label': 'online'},
            },
          },
        },
      );
      final container = ProviderContainer(
        overrides: [appDioClientProvider.overrideWithValue(appDioClient)],
      );
      addTearDown(container.dispose);

      final repository = container.read(profileRepositoryProvider);
      final profile = await repository.loadProfile(
        const ServerScopeId('server-1'),
        userId: 'user-2',
      );

      expect(
        profile,
        const MemberProfile(
          id: 'user-2',
          displayName: 'Bob',
          username: 'bob',
          email: 'bob@example.com',
          role: 'member',
          presence: 'online',
        ),
      );
      expect(appDioClient.requests, hasLength(1));
      expect(appDioClient.requests.single.method, 'GET');
      expect(
        appDioClient.requests.single.path,
        '/servers/server-1/members/user-2/profile',
      );
      expect(appDioClient.requests.single.serverIdHeader, 'server-1');
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
