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

    test(
      'loadWorkspace extracts unreadCount from channel '
      'and dm payloads',
      () async {
        final appDioClient = _FakeAppDioClient(
          responses: {
            '/channels': [
              {
                'id': 'channel-1',
                'name': 'Engineering',
                'unreadCount': 5,
              },
              {
                'id': 'channel-2',
                'name': 'General',
                'unreadCount': 0,
              },
              {'id': 'channel-3', 'name': 'Random'},
            ],
            '/channels/dm': [
              {
                'id': 'dm-1',
                'participant': {'displayName': 'Alice'},
                'unreadCount': 3,
              },
              {
                'id': 'dm-2',
                'peer': {'name': 'Bob'},
              },
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
          snapshot.channelUnreadCounts,
          {'channel-1': 5},
        );
        expect(
          snapshot.dmUnreadCounts,
          {'dm-1': 3},
        );
      },
    );

    test(
      'loadWorkspace filters thread, inbox, system, and '
      'archived channels from response',
      () async {
        final appDioClient = _FakeAppDioClient(
          responses: {
            '/channels': [
              {'id': 'ch-1', 'name': 'General'},
              {
                'id': 'thread-ch',
                'name': 'Thread Channel',
                'type': 'thread',
              },
              {
                'id': 'inbox-ch',
                'name': 'Inbox Channel',
                'type': 'inbox',
              },
              {
                'id': 'system-ch',
                'name': 'System Channel',
                'type': 'system',
              },
              {
                'id': 'archived-ch',
                'name': 'Archived Channel',
                'archived': true,
              },
              {'id': 'ch-2', 'name': 'Engineering'},
            ],
            '/channels/dm': <Object?>[],
          },
        );
        final container = _createContainer(appDioClient);
        addTearDown(container.dispose);

        final repository = container.read(homeRepositoryProvider);
        final snapshot = await repository.loadWorkspace(
          const ServerScopeId('server-1'),
        );

        expect(
          snapshot.channels.map((c) => c.scopeId.value),
          ['ch-1', 'ch-2'],
          reason: 'Only top-level, non-archived channels '
              'should be included',
        );
      },
    );

    test(
      'loadWorkspace populates threadChannelIds from '
      'filtered thread channels',
      () async {
        final appDioClient = _FakeAppDioClient(
          responses: {
            '/channels': [
              {'id': 'ch-1', 'name': 'General'},
              {
                'id': 'thread-a',
                'name': 'Thread A',
                'type': 'thread',
              },
              {
                'id': 'thread-b',
                'name': 'Thread B',
                'type': 'thread',
              },
            ],
            '/channels/dm': <Object?>[],
          },
        );
        final container = _createContainer(appDioClient);
        addTearDown(container.dispose);

        final repository = container.read(homeRepositoryProvider);
        final snapshot = await repository.loadWorkspace(
          const ServerScopeId('server-1'),
        );

        expect(
          snapshot.threadChannelIds,
          {'thread-a', 'thread-b'},
          reason: 'Thread channel IDs should be collected '
              'for knownThreadChannelIds guard',
        );
      },
    );

    test(
      'loadWorkspace removes stale local phantoms not in '
      'current API response',
      () async {
        final localStore = FakeConversationLocalStore();
        // Pre-populate local store with a phantom channel.
        await localStore.upsertConversationSummaries([
          const LocalConversationSummaryUpsert(
            serverId: 'server-1',
            conversationId: 'phantom-ch',
            surface: 'channel',
            title: 'Phantom',
            sortIndex: 0,
          ),
          const LocalConversationSummaryUpsert(
            serverId: 'server-1',
            conversationId: 'real-ch',
            surface: 'channel',
            title: 'Real',
            sortIndex: 1,
          ),
        ]);

        final appDioClient = _FakeAppDioClient(
          responses: {
            '/channels': [
              // Only real-ch is in the API response.
              {'id': 'real-ch', 'name': 'Real'},
            ],
            '/channels/dm': <Object?>[],
          },
        );
        final container = ProviderContainer(
          overrides: [
            appDioClientProvider.overrideWithValue(appDioClient),
            conversationLocalStoreProvider.overrideWithValue(localStore),
          ],
        );
        addTearDown(container.dispose);

        final repository = container.read(homeRepositoryProvider);
        final snapshot = await repository.loadWorkspace(
          const ServerScopeId('server-1'),
        );

        expect(
          snapshot.channels.map((c) => c.scopeId.value),
          ['real-ch'],
          reason: 'Phantom channel not in API response '
              'must be removed from local store and '
              'excluded from snapshot',
        );

        // Verify the persisted store was actually cleaned —
        // a subsequent cached load must also exclude the
        // phantom, not just the immediate snapshot.
        final cachedSnapshot = await repository.loadCachedWorkspace(
          const ServerScopeId('server-1'),
        );

        expect(
          cachedSnapshot?.channels.map((c) => c.scopeId.value),
          ['real-ch'],
          reason: 'Phantom channel must be purged from the '
              'persisted store so it does not reappear '
              'on the cached-load path / app restart',
        );
      },
    );

    test(
      'loadWorkspace returns empty unread maps when no '
      'unreadCount fields present',
      () async {
        final appDioClient = _FakeAppDioClient(
          responses: {
            '/channels': [
              {'id': 'channel-1', 'name': 'Engineering'},
            ],
            '/channels/dm': [
              {
                'id': 'dm-1',
                'participant': {'displayName': 'Alice'},
              },
            ],
          },
        );
        final container = _createContainer(appDioClient);
        addTearDown(container.dispose);

        final repository = container.read(homeRepositoryProvider);
        final snapshot = await repository.loadWorkspace(
          const ServerScopeId('server-1'),
        );

        expect(snapshot.channelUnreadCounts, isEmpty);
        expect(snapshot.dmUnreadCounts, isEmpty);
      },
    );

    test(
      'loadWorkspace parses lastMessage from channel '
      'and dm API responses',
      () async {
        final appDioClient = _FakeAppDioClient(
          responses: {
            '/channels': [
              {
                'id': 'ch-1',
                'name': 'General',
                'lastMessage': {
                  'id': 'msg-100',
                  'content': 'Hello from channel',
                  'createdAt': '2026-05-01T12:00:00Z',
                },
              },
              {
                'id': 'ch-2',
                'name': 'Random',
                // No lastMessage — preview should be null.
              },
            ],
            '/channels/dm': [
              {
                'id': 'dm-1',
                'participant': {'displayName': 'Alice'},
                'lastMessage': {
                  'id': 'msg-200',
                  'content': 'Hey there',
                  'createdAt': '2026-05-02T08:30:00Z',
                },
              },
              {
                'id': 'dm-2',
                'peer': {'name': 'Bob'},
                // No lastMessage.
              },
            ],
          },
        );
        final container = _createContainer(appDioClient);
        addTearDown(container.dispose);

        final repository = container.read(homeRepositoryProvider);
        final snapshot = await repository.loadWorkspace(
          const ServerScopeId('server-1'),
        );

        // Channel with lastMessage.
        expect(snapshot.channels[0].lastMessageId, 'msg-100');
        expect(
          snapshot.channels[0].lastMessagePreview,
          'Hello from channel',
        );
        expect(
          snapshot.channels[0].lastActivityAt,
          DateTime.utc(2026, 5, 1, 12),
        );

        // Channel without lastMessage.
        expect(snapshot.channels[1].lastMessageId, isNull);
        expect(snapshot.channels[1].lastMessagePreview, isNull);
        expect(snapshot.channels[1].lastActivityAt, isNull);

        // DM with lastMessage.
        expect(
          snapshot.directMessages[0].lastMessageId,
          'msg-200',
        );
        expect(
          snapshot.directMessages[0].lastMessagePreview,
          'Hey there',
        );
        expect(
          snapshot.directMessages[0].lastActivityAt,
          DateTime.utc(2026, 5, 2, 8, 30),
        );

        // DM without lastMessage.
        expect(
          snapshot.directMessages[1].lastMessageId,
          isNull,
        );
        expect(
          snapshot.directMessages[1].lastMessagePreview,
          isNull,
        );
      },
    );

    test(
      'loadWorkspace persists lastMessage previews so '
      'cached load returns them',
      () async {
        final localStore = FakeConversationLocalStore();
        final appDioClient = _FakeAppDioClient(
          responses: {
            '/channels': [
              {
                'id': 'ch-1',
                'name': 'General',
                'lastMessage': {
                  'id': 'msg-100',
                  'content': 'Persisted preview',
                  'createdAt': '2026-05-01T12:00:00Z',
                },
              },
            ],
            '/channels/dm': [
              {
                'id': 'dm-1',
                'participant': {'displayName': 'Alice'},
                'lastMessage': {
                  'id': 'msg-200',
                  'content': 'DM persisted',
                  'createdAt': '2026-05-02T08:30:00Z',
                },
              },
            ],
          },
        );
        final container = ProviderContainer(
          overrides: [
            appDioClientProvider.overrideWithValue(appDioClient),
            conversationLocalStoreProvider.overrideWithValue(localStore),
          ],
        );
        addTearDown(container.dispose);

        final repository = container.read(homeRepositoryProvider);
        // Network load → persists to local store.
        await repository.loadWorkspace(
          const ServerScopeId('server-1'),
        );

        // Cached load — should return persisted previews.
        final cached = await repository.loadCachedWorkspace(
          const ServerScopeId('server-1'),
        );

        expect(cached, isNotNull);
        expect(cached!.channels.first.lastMessageId, 'msg-100');
        expect(
          cached.channels.first.lastMessagePreview,
          'Persisted preview',
        );
        expect(
          cached.channels.first.lastActivityAt,
          DateTime.utc(2026, 5, 1, 12),
        );
        expect(
          cached.directMessages.first.lastMessageId,
          'msg-200',
        );
        expect(
          cached.directMessages.first.lastMessagePreview,
          'DM persisted',
        );
        expect(
          cached.directMessages.first.lastActivityAt,
          DateTime.utc(2026, 5, 2, 8, 30),
        );
      },
    );
  });

  test(
      'loadWorkspace succeeds with API data when local store '
      'upsert throws a non-AppFailure', () async {
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/channels': [
          {'id': 'channel-1', 'name': 'Engineering'},
        ],
        '/channels/dm': [
          {
            'id': 'dm-1',
            'participant': {'displayName': 'Alice'},
          },
        ],
      },
    );
    final container = ProviderContainer(
      overrides: [
        appDioClientProvider.overrideWithValue(appDioClient),
        conversationLocalStoreProvider.overrideWithValue(
          _ThrowingConversationLocalStore(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final repository = container.read(homeRepositoryProvider);
    final snapshot = await repository.loadWorkspace(
      const ServerScopeId('server-1'),
    );

    expect(snapshot.serverId, const ServerScopeId('server-1'));
    expect(snapshot.channels.length, 1);
    expect(snapshot.channels.first.name, 'Engineering');
    expect(snapshot.directMessages.length, 1);
    expect(snapshot.directMessages.first.title, 'Alice');
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

class _ThrowingConversationLocalStore extends FakeConversationLocalStore {
  @override
  Future<void> upsertConversationSummaries(
    Iterable<LocalConversationSummaryUpsert> summaries, {
    bool preserveExistingSortIndex = false,
  }) async {
    throw StateError('SQLite disk I/O error');
  }

  @override
  Future<List<LocalConversationSummaryRecord>> listConversationSummaries(
    String serverId, {
    required String surface,
  }) async {
    throw StateError('SQLite disk I/O error');
  }
}
