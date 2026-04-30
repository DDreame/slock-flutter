import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';

import '../../../core/local_data/fake_conversation_local_store.dart';

ProviderContainer _createContainer(
  _FakeAppDioClient appDioClient, {
  FakeConversationLocalStore? localStore,
}) {
  return ProviderContainer(
    overrides: [
      appDioClientProvider.overrideWithValue(appDioClient),
      conversationLocalStoreProvider.overrideWithValue(
        localStore ?? FakeConversationLocalStore(),
      ),
    ],
  );
}

void main() {
  test('loads channel detail with message and metadata requests', () async {
    final localStore = FakeConversationLocalStore();
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/messages/channel/general': {
          'messages': [
            {
              'id': 'message-1',
              'content': 'Hello world',
              'createdAt': '2026-04-19T15:00:00Z',
              'senderId': 'user-1',
              'senderName': 'Alice',
              'senderType': 'human',
              'messageType': 'message',
              'seq': 1,
            },
          ],
          'historyLimited': true,
        },
        '/channels': [
          {'id': 'general', 'name': 'general'},
        ],
      },
    );
    final container = _createContainer(appDioClient, localStore: localStore);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);
    final snapshot = await repository.loadConversation(
      ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'general',
        ),
      ),
    );

    expect(
      appDioClient.requests.map((request) => request.path),
      ['/messages/channel/general', '/channels'],
    );
    expect(
      appDioClient.requests.map((request) => request.serverIdHeader),
      ['server-1', 'server-1'],
    );
    expect(snapshot.title, '#general');
    expect(snapshot.historyLimited, isTrue);
    expect(snapshot.hasOlder, isFalse);
    expect(snapshot.messages.single.id, 'message-1');
    expect(snapshot.messages.single.content, 'Hello world');
    expect(snapshot.messages.single.senderId, 'user-1');
    expect(snapshot.messages.single.senderName, 'Alice');
    expect(snapshot.messages.single.senderLabel, 'Alice');
    expect(snapshot.messages.single.senderType, 'human');
    expect(snapshot.messages.single.messageType, 'message');
    expect(snapshot.messages.single.seq, 1);
    expect(localStore.messages.single.senderId, 'user-1');
  });

  test('loads direct message title from dm metadata endpoint', () async {
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/messages/channel/dm-1': {
          'messages': [
            {
              'id': 'message-1',
              'content': 'Ping',
              'createdAt': '2026-04-19T15:00:00Z',
            },
          ],
        },
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

    final repository = container.read(conversationRepositoryProvider);
    final snapshot = await repository.loadConversation(
      ConversationDetailTarget.directMessage(
        const DirectMessageScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'dm-1',
        ),
      ),
    );

    expect(
      appDioClient.requests.map((request) => request.path),
      ['/messages/channel/dm-1', '/channels/dm'],
    );
    expect(snapshot.title, 'Alice');
    expect(snapshot.hasOlder, isFalse);
  });

  test('loads channel title from stored summary when metadata is missing',
      () async {
    final localStore = FakeConversationLocalStore();
    await localStore.upsertConversationSummaries([
      const LocalConversationSummaryUpsert(
        serverId: 'server-1',
        conversationId: 'channel-uuid-1',
        surface: 'channel',
        title: 'announcements',
        sortIndex: 0,
      ),
    ]);
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/messages/channel/channel-uuid-1': {
          'messages': [
            {
              'id': 'message-1',
              'content': 'Hello world',
              'createdAt': '2026-04-19T15:00:00Z',
            },
          ],
        },
        '/channels': [
          {'id': 'different-channel', 'name': 'general'},
        ],
      },
    );
    final container = _createContainer(appDioClient, localStore: localStore);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);
    final snapshot = await repository.loadConversation(
      ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'channel-uuid-1',
        ),
      ),
    );

    expect(snapshot.title, '#announcements');
  });

  test('loads older history with before query and hasOlder truth', () async {
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/messages/channel/general': {
          'messages': List<Object?>.generate(50, (index) {
            final seq = index + 1;
            return {
              'id': 'message-$seq',
              'content': 'Message $seq',
              'createdAt': '2026-04-19T15:00:00Z',
              'seq': seq,
            };
          }),
          'historyLimited': true,
        },
      },
    );
    final container = _createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);
    final page = await repository.loadOlderMessages(
      ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'general',
        ),
      ),
      beforeSeq: 51,
    );

    final request = appDioClient.requests.single;
    expect(request.path, '/messages/channel/general');
    expect(request.queryParameters, {'limit': 50, 'before': 51});
    expect(request.serverIdHeader, 'server-1');
    expect(page.messages, hasLength(50));
    expect(page.hasOlder, isTrue);
    expect(page.historyLimited, isTrue);
  });

  test('rethrows transport AppFailure without wrapping it', () async {
    const failure = ServerFailure(
      message: 'upstream exploded',
      statusCode: 500,
    );
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/channels': [
          {'id': 'general', 'name': 'general'},
        ],
      },
      failures: {'/messages/channel/general': failure},
    );
    final container = _createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);

    await expectLater(
      repository.loadConversation(
        ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'general',
          ),
        ),
      ),
      throwsA(same(failure)),
    );
  });

  test('throws SerializationFailure for malformed message payloads', () async {
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/messages/channel/general': {
          'messages': [
            {
              'id': 'message-1',
              'createdAt': '2026-04-19T15:00:00Z',
            },
          ],
        },
        '/channels': [
          {'id': 'general', 'name': 'general'},
        ],
      },
    );
    final container = _createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);

    await expectLater(
      repository.loadConversation(
        ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'general',
          ),
        ),
      ),
      throwsA(
        isA<SerializationFailure>().having(
          (failure) => failure.message,
          'message',
          'Malformed messagesResponse.messages[0] payload: missing string field "content".',
        ),
      ),
    );
  });

  test('sendMessage posts trimmed content with explicit server header',
      () async {
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/messages': {
          'id': 'message-2',
          'content': 'Hello again',
          'createdAt': '2026-04-19T15:05:00Z',
          'senderType': 'human',
          'messageType': 'message',
          'seq': 2,
        },
      },
    );
    final container = _createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);
    final message = await repository.sendMessage(
      ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'general',
        ),
      ),
      '  Hello again  ',
    );

    final request = appDioClient.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/messages');
    expect(request.serverIdHeader, 'server-1');
    expect(request.data, {
      'channelId': 'general',
      'content': 'Hello again',
    });
    expect(message.id, 'message-2');
    expect(message.content, 'Hello again');
    expect(message.seq, 2);
  });

  test('sendMessage throws SerializationFailure for malformed response',
      () async {
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/messages': {
          'content': 'Hello again',
          'createdAt': '2026-04-19T15:05:00Z',
        },
      },
    );
    final container = _createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);

    await expectLater(
      repository.sendMessage(
        ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'general',
          ),
        ),
        'Hello again',
      ),
      throwsA(
        isA<SerializationFailure>().having(
          (failure) => failure.message,
          'message',
          'Malformed sendMessageResponse payload: missing string field "id".',
        ),
      ),
    );
  });

  test('loads newer messages with after query and hasNewer truth', () async {
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/messages/channel/general': {
          'messages': List<Object?>.generate(50, (index) {
            final seq = index + 51;
            return {
              'id': 'message-$seq',
              'content': 'Message $seq',
              'createdAt': '2026-04-19T15:00:00Z',
              'seq': seq,
            };
          }),
          'historyLimited': false,
        },
      },
    );
    final container = _createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);
    final page = await repository.loadNewerMessages(
      ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'general',
        ),
      ),
      afterSeq: 50,
    );

    final request = appDioClient.requests.single;
    expect(request.path, '/messages/channel/general');
    expect(request.queryParameters, {'limit': 50, 'after': 50});
    expect(request.serverIdHeader, 'server-1');
    expect(page.messages, hasLength(50));
    expect(page.hasNewer, isTrue);
    expect(page.hasOlder, isFalse);
  });

  test('loadNewerMessages hasNewer is false when under page size', () async {
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/messages/channel/general': {
          'messages': [
            {
              'id': 'message-2',
              'content': 'Just one',
              'createdAt': '2026-04-19T15:00:00Z',
              'seq': 2,
            },
          ],
          'historyLimited': false,
        },
      },
    );
    final container = _createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);
    final page = await repository.loadNewerMessages(
      ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'general',
        ),
      ),
      afterSeq: 1,
    );

    expect(page.messages, hasLength(1));
    expect(page.hasNewer, isFalse);
  });

  test('loadNewerMessages rethrows transport AppFailure', () async {
    const failure = ServerFailure(
      message: 'upstream exploded',
      statusCode: 500,
    );
    final appDioClient = _FakeAppDioClient(
      failures: {'/messages/channel/general': failure},
    );
    final container = _createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);

    await expectLater(
      repository.loadNewerMessages(
        ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'general',
          ),
        ),
        afterSeq: 1,
      ),
      throwsA(same(failure)),
    );
  });

  test('parses attachments and threadId from message payload', () async {
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/messages/channel/general': {
          'messages': [
            {
              'id': 'message-1',
              'content': 'With file',
              'createdAt': '2026-04-19T15:00:00Z',
              'senderType': 'human',
              'messageType': 'message',
              'seq': 1,
              'threadId': 'thread-abc',
              'attachments': [
                {
                  'name': 'report.pdf',
                  'type': 'application/pdf',
                  'url': 'https://example.com/report.pdf',
                  'id': 'att-1',
                },
              ],
            },
          ],
          'historyLimited': false,
        },
        '/channels': [
          {'id': 'general', 'name': 'general'},
        ],
      },
    );
    final container = _createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);
    final snapshot = await repository.loadConversation(
      ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'general',
        ),
      ),
    );

    final message = snapshot.messages.single;
    expect(message.threadId, 'thread-abc');
    expect(message.attachments, hasLength(1));
    expect(message.attachments![0].name, 'report.pdf');
    expect(message.attachments![0].type, 'application/pdf');
    expect(message.attachments![0].url, 'https://example.com/report.pdf');
    expect(message.attachments![0].id, 'att-1');
  });

  test('attachments and threadId are null when absent from payload', () async {
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/messages/channel/general': {
          'messages': [
            {
              'id': 'message-1',
              'content': 'Plain message',
              'createdAt': '2026-04-19T15:00:00Z',
              'senderType': 'human',
              'messageType': 'message',
              'seq': 1,
            },
          ],
          'historyLimited': false,
        },
        '/channels': [
          {'id': 'general', 'name': 'general'},
        ],
      },
    );
    final container = _createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);
    final snapshot = await repository.loadConversation(
      ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'general',
        ),
      ),
    );

    final message = snapshot.messages.single;
    expect(message.threadId, isNull);
    expect(message.attachments, isNull);
  });

  test('attachments with missing name/type fields are skipped', () async {
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/messages/channel/general': {
          'messages': [
            {
              'id': 'message-1',
              'content': 'Partial attachments',
              'createdAt': '2026-04-19T15:00:00Z',
              'senderType': 'human',
              'messageType': 'message',
              'seq': 1,
              'attachments': [
                {'name': 'good.pdf', 'type': 'application/pdf'},
                {'name': 'missing-type'},
                {'type': 'image/png'},
              ],
            },
          ],
          'historyLimited': false,
        },
        '/channels': [
          {'id': 'general', 'name': 'general'},
        ],
      },
    );
    final container = _createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);
    final snapshot = await repository.loadConversation(
      ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'general',
        ),
      ),
    );

    final message = snapshot.messages.single;
    expect(message.attachments, hasLength(1));
    expect(message.attachments![0].name, 'good.pdf');
  });

  test('empty attachments array results in null', () async {
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/messages/channel/general': {
          'messages': [
            {
              'id': 'message-1',
              'content': 'Empty attachments',
              'createdAt': '2026-04-19T15:00:00Z',
              'senderType': 'human',
              'messageType': 'message',
              'seq': 1,
              'attachments': <Object>[],
            },
          ],
          'historyLimited': false,
        },
        '/channels': [
          {'id': 'general', 'name': 'general'},
        ],
      },
    );
    final container = _createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);
    final snapshot = await repository.loadConversation(
      ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'general',
        ),
      ),
    );

    expect(snapshot.messages.single.attachments, isNull);
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
    requests.add(
      _CapturedRequest(
        path: path,
        headers: headers,
        queryParameters: queryParameters ?? const {},
      ),
    );

    final failure = _failures[path];
    if (failure != null) {
      throw failure;
    }

    if (!_responses.containsKey(path)) {
      throw StateError('Missing fake response for $path');
    }

    return Response<T>(
      requestOptions: RequestOptions(
        path: path,
        headers: headers,
        queryParameters: queryParameters,
      ),
      data: _responses[path] as T,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    final headers = Map<String, Object?>.from(options?.headers ?? const {});
    requests.add(
      _CapturedRequest(
        method: 'POST',
        path: path,
        headers: headers,
        queryParameters: queryParameters ?? const {},
        data: data,
      ),
    );

    final failure = _failures[path];
    if (failure != null) {
      throw failure;
    }

    if (!_responses.containsKey(path)) {
      throw StateError('Missing fake response for $path');
    }

    return Response<T>(
      requestOptions: RequestOptions(
        path: path,
        headers: headers,
        queryParameters: queryParameters,
        data: data,
      ),
      data: _responses[path] as T,
    );
  }
}

class _CapturedRequest {
  const _CapturedRequest({
    this.method = 'GET',
    required this.path,
    required this.headers,
    required this.queryParameters,
    this.data,
  });

  final String method;
  final String path;
  final Map<String, Object?> headers;
  final Map<String, dynamic> queryParameters;
  final Object? data;

  String? get serverIdHeader => headers['X-Server-Id'] as String?;
}
