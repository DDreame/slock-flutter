import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';

import '../../../core/local_data/fake_conversation_local_store.dart';

ProviderContainer _createContainer(_FakeAppDioClient appDioClient) {
  return ProviderContainer(
    overrides: [
      appDioClientProvider.overrideWithValue(appDioClient),
      conversationLocalStoreProvider.overrideWithValue(
        FakeConversationLocalStore(),
      ),
    ],
  );
}

void main() {
  group('homeRepositoryProvider', () {
    test('loads channel and dm lists through the inferred web contract',
        () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          '/channels': [
            {'id': 'channel-1', 'name': 'Engineering'},
            {'id': 'channel-2', 'name': 'General'},
          ],
          '/channels/dm': [
            {
              'id': 'dm-1',
              'participant': {'displayName': 'Alice'},
            },
            {
              'id': 'dm-2',
              'peer': {'name': 'Bob'},
            },
            {'id': 'dm-3'},
          ],
        },
      );
      final container = _createContainer(appDioClient);
      addTearDown(container.dispose);

      final repository = container.read(homeRepositoryProvider);
      final snapshot = await repository.loadWorkspace(
        const ServerScopeId('server-1'),
      );

      expect(
        appDioClient.requests.map((request) => request.path),
        ['/channels', '/channels/dm'],
      );
      expect(
        appDioClient.requests.map((request) => request.serverIdHeader),
        ['server-1', 'server-1'],
      );
      expect(snapshot.serverId, const ServerScopeId('server-1'));
      expect(snapshot.channels.length, 2);
      expect(
          snapshot.channels.first.scopeId,
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'channel-1',
          ));
      expect(snapshot.channels.first.name, 'Engineering');
      expect(snapshot.directMessages.length, 3);
      expect(
          snapshot.directMessages.first.scopeId,
          const DirectMessageScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'dm-1',
          ));
      expect(snapshot.directMessages.first.title, 'Alice');
      expect(snapshot.directMessages[1].title, 'Bob');
      expect(snapshot.directMessages.last.title, 'dm-3');
    });

    test('rethrows transport AppFailure without wrapping it', () async {
      const failure = ServerFailure(
        message: 'upstream exploded',
        statusCode: 500,
      );
      final appDioClient = _FakeAppDioClient(
        responses: {
          '/channels/dm': [
            {'id': 'dm-1', 'displayName': 'Alice'},
          ],
        },
        failures: {'/channels': failure},
      );
      final container = _createContainer(appDioClient);
      addTearDown(container.dispose);

      final repository = container.read(homeRepositoryProvider);

      await expectLater(
        repository.loadWorkspace(const ServerScopeId('server-1')),
        throwsA(same(failure)),
      );
      expect(
        appDioClient.requests.map((request) => request.path),
        ['/channels', '/channels/dm'],
      );
    });

    test('throws SerializationFailure for malformed payloads', () async {
      final appDioClient = _FakeAppDioClient(
        responses: {
          '/channels': [
            {'id': 'channel-1', 'name': 'Engineering'},
          ],
          '/channels/dm': [
            {'displayName': 'Alice'},
          ],
        },
      );
      final container = _createContainer(appDioClient);
      addTearDown(container.dispose);

      final repository = container.read(homeRepositoryProvider);

      await expectLater(
        repository.loadWorkspace(const ServerScopeId('server-1')),
        throwsA(
          isA<SerializationFailure>()
              .having(
                (failure) => failure.message,
                'message',
                'Malformed directMessages[0] payload: missing string field "id".',
              )
              .having(
                (failure) => failure.causeType,
                'causeType',
                'Null',
              ),
        ),
      );
    });
  });

  test('baseline repository wraps unexpected seam errors in UnknownFailure',
      () async {
    final repository = BaselineHomeRepository(
      loadWorkspace: (serverId) async => throw StateError('boom'),
      loadCachedWorkspace: (serverId) async => null,
      persistDirectMessageSummary: (summary) async => summary,
      persistConversationActivity: ({
        required serverId,
        required conversationId,
        required messageId,
        required preview,
        required activityAt,
      }) async {},
      persistConversationPreviewUpdate: ({
        required serverId,
        required conversationId,
        required messageId,
        required preview,
      }) async {},
    );

    await expectLater(
      repository.loadWorkspace(const ServerScopeId('server-1')),
      throwsA(
        isA<UnknownFailure>()
            .having(
              (failure) => failure.message,
              'message',
              'Failed to load home workspace snapshot.',
            )
            .having(
              (failure) => failure.causeType,
              'causeType',
              'StateError',
            ),
      ),
    );
  });
}

class _FakeAppDioClient extends AppDioClient {
  _FakeAppDioClient({
    Map<String, Object?> responses = const {},
    Map<String, Object> failures = const {},
  })  : _responses = responses,
        _failures = failures,
        super(Dio());

  final Map<String, Object?> _responses;
  final Map<String, Object> _failures;
  final List<_CapturedRequest> requests = [];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    final headers = Map<String, Object?>.from(options?.headers ?? const {});
    requests.add(_CapturedRequest(path: path, headers: headers));

    final failure = _failures[path];
    if (failure != null) {
      throw failure;
    }

    if (!_responses.containsKey(path)) {
      throw StateError('Missing fake response for $path');
    }

    return Response<T>(
      requestOptions: RequestOptions(path: path, headers: headers),
      data: _responses[path] as T,
    );
  }
}

class _CapturedRequest {
  const _CapturedRequest({required this.path, required this.headers});

  final String path;
  final Map<String, Object?> headers;

  String? get serverIdHeader => headers['X-Server-Id'] as String?;
}
