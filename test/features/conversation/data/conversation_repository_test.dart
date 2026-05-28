import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';

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
      savedMessagesRepositoryProvider
          .overrideWithValue(_NoOpSavedMessagesRepository()),
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
        '/channels/general': {'id': 'general', 'name': 'general'},
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
      ['/messages/channel/general', '/channels/general'],
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
        '/channels/dm/dm-1': {
          'id': 'dm-1',
          'participant': {'displayName': 'Alice'},
        },
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
      ['/messages/channel/dm-1', '/channels/dm/dm-1'],
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
        '/channels/channel-uuid-1': {
          'id': 'channel-uuid-1',
        },
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
        '/channels/general': {'id': 'general', 'name': 'general'},
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
              // Missing 'id' field — truly malformed
              'content': 'hello',
              'createdAt': '2026-04-19T15:00:00Z',
            },
          ],
        },
        '/channels/general': {'id': 'general', 'name': 'general'},
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
          'Malformed messagesResponse.messages[0] payload: missing string field "id".',
        ),
      ),
    );
  });

  test('message with missing content field parses as empty string', () async {
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/messages/channel/general': {
          'messages': [
            {
              'id': 'message-1',
              'createdAt': '2026-04-19T15:00:00Z',
              // No 'content' field — attachment-only message
            },
          ],
        },
        '/channels/general': {'id': 'general', 'name': 'general'},
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
    expect(snapshot.messages.first.content, '');
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

  test('uploadAttachment uses live attachment endpoint contract', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'conversation_repository_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final file = File('${tempDir.path}/report.pdf')
      ..writeAsStringSync('test file');

    final appDioClient = _FakeAppDioClient(
      responses: {
        '/attachments/upload': {
          'attachments': [
            {'id': 'att-1', 'name': 'report.pdf'},
          ],
        },
      },
    );
    final container = _createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);
    final attachmentId = await repository.uploadAttachment(
      ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'general',
        ),
      ),
      PendingAttachment(
        path: file.path,
        name: 'report.pdf',
        mimeType: 'application/pdf',
      ),
    );

    final request = appDioClient.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/attachments/upload');
    expect(request.serverIdHeader, 'server-1');
    expect(request.data, isA<FormData>());
    final formData = request.data! as FormData;
    expect(
      formData.fields.any(
        (field) => field.key == 'channelId' && field.value == 'general',
      ),
      isTrue,
    );
    expect(formData.files, hasLength(1));
    expect(formData.files.single.key, 'files');
    expect(formData.files.single.value.filename, 'report.pdf');
    expect(attachmentId, 'att-1');
  });

  test('uploadAttachment accepts legacy top-level id response', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'conversation_repository_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final file = File('${tempDir.path}/report.pdf')
      ..writeAsStringSync('test file');

    final appDioClient = _FakeAppDioClient(
      responses: {
        '/attachments/upload': {'id': 'att-legacy'},
      },
    );
    final container = _createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);
    final attachmentId = await repository.uploadAttachment(
      ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'general',
        ),
      ),
      PendingAttachment(
        path: file.path,
        name: 'report.pdf',
        mimeType: 'application/pdf',
      ),
    );

    expect(attachmentId, 'att-legacy');
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

  test('parses attachments, threadId, and linked task from message payload',
      () async {
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
              'replyCount': 5,
              'linkedTaskId': 'task-7',
              'linkedTask': {
                'id': 'task-7',
                'taskNumber': 7,
                'status': 'in_progress',
                'claimedByName': 'J2',
              },
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
        '/channels/general': {'id': 'general', 'name': 'general'},
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
    expect(message.replyCount, 5);
    expect(message.linkedTaskId, 'task-7');
    expect(message.linkedTask, isNotNull);
    expect(message.linkedTask!.id, 'task-7');
    expect(message.linkedTask!.taskNumber, 7);
    expect(message.linkedTask!.status, 'in_progress');
    expect(message.linkedTask!.claimedByName, 'J2');
    expect(message.attachments, hasLength(1));
    expect(message.attachments![0].name, 'report.pdf');
    expect(message.attachments![0].type, 'application/pdf');
    expect(message.attachments![0].url, 'https://example.com/report.pdf');
    expect(message.attachments![0].id, 'att-1');
  });

  test(
      'attachments, threadId, and linked task are null when absent from payload',
      () async {
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
        '/channels/general': {'id': 'general', 'name': 'general'},
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
    expect(message.replyCount, isNull);
    expect(message.linkedTaskId, isNull);
    expect(message.linkedTask, isNull);
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
        '/channels/general': {'id': 'general', 'name': 'general'},
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

  test(
      'loadConversation succeeds with API data when local store '
      'writes throw a non-AppFailure', () async {
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/messages/channel/general': {
          'messages': [
            {
              'id': 'message-1',
              'content': 'Hello world',
              'createdAt': '2026-04-19T15:00:00Z',
              'senderType': 'human',
              'messageType': 'message',
              'seq': 1,
            },
          ],
          'historyLimited': false,
        },
        '/channels/general': {'id': 'general', 'name': 'general'},
      },
    );
    final container = ProviderContainer(
      overrides: [
        appDioClientProvider.overrideWithValue(appDioClient),
        conversationLocalStoreProvider.overrideWithValue(
          _ThrowingConversationLocalStore(),
        ),
        savedMessagesRepositoryProvider
            .overrideWithValue(_NoOpSavedMessagesRepository()),
      ],
    );
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

    expect(snapshot.title, '#general');
    expect(snapshot.messages.single.id, 'message-1');
    expect(snapshot.messages.single.content, 'Hello world');
  });

  test(
      'loadConversation succeeds for direct messages when local store '
      'writes throw a non-AppFailure', () async {
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/messages/channel/dm-1': {
          'messages': [
            {
              'id': 'message-1',
              'content': 'Ping',
              'createdAt': '2026-04-19T15:00:00Z',
              'senderType': 'human',
              'messageType': 'message',
              'seq': 1,
            },
          ],
          'historyLimited': false,
        },
        '/channels/dm/dm-1': {
          'id': 'dm-1',
          'participant': {'displayName': 'Alice'},
        },
      },
    );
    final container = ProviderContainer(
      overrides: [
        appDioClientProvider.overrideWithValue(appDioClient),
        conversationLocalStoreProvider.overrideWithValue(
          _ThrowingConversationLocalStore(),
        ),
        savedMessagesRepositoryProvider
            .overrideWithValue(_NoOpSavedMessagesRepository()),
      ],
    );
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

    expect(snapshot.title, 'Alice');
    expect(snapshot.messages.single.id, 'message-1');
    expect(snapshot.messages.single.content, 'Ping');
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
        '/channels/general': {'id': 'general', 'name': 'general'},
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

  test(
      'attachment sizeBytes survives full round-trip: '
      'API parse → local JSON encode → decode', () async {
    final localStore = FakeConversationLocalStore();
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/messages/channel/general': {
          'messages': [
            {
              'id': 'message-1',
              'content': 'File with size',
              'createdAt': '2026-04-19T15:00:00Z',
              'senderType': 'human',
              'messageType': 'message',
              'seq': 1,
              'attachments': [
                {
                  'name': 'archive.zip',
                  'type': 'application/zip',
                  'url': 'https://example.com/archive.zip',
                  'id': 'att-sized',
                  'sizeBytes': 2500000,
                },
                {
                  'name': 'readme.txt',
                  'type': 'text/plain',
                  'url': 'https://example.com/readme.txt',
                  'id': 'att-nosize',
                },
              ],
            },
          ],
          'historyLimited': false,
        },
        '/channels/general': {'id': 'general', 'name': 'general'},
      },
    );
    final container = _createContainer(
      appDioClient,
      localStore: localStore,
    );
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);

    // Step 1: Load from API — exercises _parseAttachments + local
    // encode via _messageToLocalUpsert
    final snapshot = await repository.loadConversation(
      ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'general',
        ),
      ),
    );

    // Verify API parse preserved sizeBytes
    final apiAttachments = snapshot.messages.single.attachments!;
    expect(apiAttachments, hasLength(2));
    expect(apiAttachments[0].sizeBytes, 2500000);
    expect(apiAttachments[0].formattedSize, '2.4 MB');
    expect(
      apiAttachments[1].sizeBytes,
      isNull,
      reason: 'Attachment without sizeBytes should be null',
    );

    // Verify local store encoded sizeBytes into JSON
    final storedMessage = localStore.messages.single;
    expect(
      storedMessage.attachmentsJson,
      contains('"sizeBytes":2500000'),
      reason: 'Local JSON should contain sizeBytes',
    );

    // Step 2: Exercise the local decode path via
    // updateStoredMessageContent → _storedRowToMessage →
    // _decodeAttachments. This reads the stored JSON row and
    // decodes it, proving sizeBytes survives the full round-trip.
    final decoded = await repository.updateStoredMessageContent(
      ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'general',
        ),
      ),
      messageId: 'message-1',
      content: 'Updated content',
    );
    expect(decoded, isNotNull);
    expect(decoded!.attachments, hasLength(2));
    expect(decoded.attachments![0].sizeBytes, 2500000);
    expect(decoded.attachments![0].formattedSize, '2.4 MB');
    expect(decoded.attachments![1].sizeBytes, isNull);
  });

  // #861: Production-path proof that checkSavedMessages is called and its
  // result populates snapshot.savedMessageIds. Removing the batch call from
  // conversation_repository_provider.dart must turn this test RED.
  test('#861: loadConversation batches savedMessageIds via checkSavedMessages',
      () async {
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/messages/channel/general': {
          'messages': [
            {
              'id': 'msg-aaa',
              'content': 'Hello',
              'createdAt': '2026-05-20T10:00:00Z',
              'senderType': 'human',
              'messageType': 'message',
              'seq': 1,
            },
            {
              'id': 'msg-bbb',
              'content': 'World',
              'createdAt': '2026-05-20T11:00:00Z',
              'senderType': 'human',
              'messageType': 'message',
              'seq': 2,
            },
          ],
          'historyLimited': false,
        },
        '/channels/general': {'id': 'general', 'name': 'general'},
        // Production endpoint for saved-message batch check.
        '/channels/saved/check': {
          'savedIds': ['msg-bbb'],
        },
      },
    );
    // Do NOT override savedMessagesRepositoryProvider here — the real
    // provider goes through appDioClient, hitting /channels/saved/check.
    final container = ProviderContainer(
      overrides: [
        appDioClientProvider.overrideWithValue(appDioClient),
        conversationLocalStoreProvider.overrideWithValue(
          FakeConversationLocalStore(),
        ),
      ],
    );
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

    // Assert the batch check was called with the message IDs.
    final savedCheckRequest = appDioClient.requests.firstWhere(
      (r) => r.path == '/channels/saved/check',
      orElse: () => throw StateError(
        '#861: checkSavedMessages POST to /channels/saved/check was never '
        'called. Removing the batch call from the repository breaks this.',
      ),
    );
    expect(savedCheckRequest.method, 'POST');
    expect(
      (savedCheckRequest.data as Map)['messageIds'],
      containsAll(['msg-aaa', 'msg-bbb']),
    );

    // Assert savedMessageIds in the snapshot.
    expect(
      snapshot.savedMessageIds,
      {'msg-bbb'},
      reason: '#861: savedMessageIds must be populated from '
          'checkSavedMessages response. Removing the batch logic → null → RED.',
    );
  });

  test('editMessage sends PATCH with correct path, body, and server header',
      () async {
    final localStore = FakeConversationLocalStore();
    // Seed a message so local store update can find it
    await localStore.upsertMessages([
      LocalMessageUpsert(
        serverId: 'server-1',
        conversationId: 'general',
        messageId: 'message-1',
        content: 'Original',
        createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      ),
    ]);
    final appDioClient = _FakeAppDioClient(
      responses: {'/messages/message-1': null},
    );
    final container = _createContainer(appDioClient, localStore: localStore);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);
    await repository.editMessage(
      ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'general',
        ),
      ),
      messageId: 'message-1',
      content: 'Updated content',
    );

    final request = appDioClient.requests.single;
    expect(request.method, 'PATCH');
    expect(request.path, '/messages/message-1');
    expect(request.serverIdHeader, 'server-1');
    expect(request.data, {'content': 'Updated content'});

    // Verify local store was updated
    final stored = localStore.messages.single;
    expect(stored.content, 'Updated content');
  });

  test('deleteMessage sends DELETE with correct path and server header',
      () async {
    final localStore = FakeConversationLocalStore();
    await localStore.upsertMessages([
      LocalMessageUpsert(
        serverId: 'server-1',
        conversationId: 'general',
        messageId: 'message-1',
        content: 'To be deleted',
        createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      ),
    ]);
    final appDioClient = _FakeAppDioClient(
      responses: {'/messages/message-1': null},
    );
    final container = _createContainer(appDioClient, localStore: localStore);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);
    await repository.deleteMessage(
      ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'general',
        ),
      ),
      messageId: 'message-1',
    );

    final request = appDioClient.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, '/messages/message-1');
    expect(request.serverIdHeader, 'server-1');

    // Verify local store removed the message
    expect(localStore.messages, isEmpty);
  });

  test('editMessage rethrows AppFailure from transport', () async {
    const failure = ServerFailure(
      message: 'Forbidden.',
      statusCode: 403,
    );
    final appDioClient = _FakeAppDioClient(
      failures: {'/messages/message-1': failure},
    );
    final container = _createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);

    await expectLater(
      repository.editMessage(
        ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'general',
          ),
        ),
        messageId: 'message-1',
        content: 'Will fail',
      ),
      throwsA(same(failure)),
    );
  });

  test('deleteMessage rethrows AppFailure from transport', () async {
    const failure = ServerFailure(
      message: 'Not Found.',
      statusCode: 404,
    );
    final appDioClient = _FakeAppDioClient(
      failures: {'/messages/message-1': failure},
    );
    final container = _createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);

    await expectLater(
      repository.deleteMessage(
        ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'general',
          ),
        ),
        messageId: 'message-1',
      ),
      throwsA(same(failure)),
    );
  });

  test('addReaction sends POST with correct path, body, and server header',
      () async {
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/channels/general/messages/message-1/reactions': null,
      },
    );
    final container = _createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);

    await repository.addReaction(
      ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'general',
        ),
      ),
      messageId: 'message-1',
      emoji: '👍',
    );

    expect(appDioClient.requests.length, 1);
    final request = appDioClient.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/channels/general/messages/message-1/reactions');
    expect(request.data, {'emoji': '👍'});
    expect(request.serverIdHeader, 'server-1');
  });

  test('removeReaction sends DELETE with correct path and server header',
      () async {
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/channels/general/messages/message-1/reactions/👍': null,
      },
    );
    final container = _createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);

    await repository.removeReaction(
      ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'general',
        ),
      ),
      messageId: 'message-1',
      emoji: '👍',
    );

    expect(appDioClient.requests.length, 1);
    final request = appDioClient.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, '/channels/general/messages/message-1/reactions/👍');
    expect(request.serverIdHeader, 'server-1');
  });

  test('addReaction rethrows AppFailure from transport', () async {
    const failure = ServerFailure(
      message: 'Not Found.',
      statusCode: 404,
    );
    final appDioClient = _FakeAppDioClient(
      failures: {
        '/channels/general/messages/message-1/reactions': failure,
      },
    );
    final container = _createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);

    await expectLater(
      repository.addReaction(
        ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'general',
          ),
        ),
        messageId: 'message-1',
        emoji: '👍',
      ),
      throwsA(same(failure)),
    );
  });

  test('removeReaction rethrows AppFailure from transport', () async {
    const failure = ServerFailure(
      message: 'Not Found.',
      statusCode: 404,
    );
    final appDioClient = _FakeAppDioClient(
      failures: {
        '/channels/general/messages/message-1/reactions/👍': failure,
      },
    );
    final container = _createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);

    await expectLater(
      repository.removeReaction(
        ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'general',
          ),
        ),
        messageId: 'message-1',
        emoji: '👍',
      ),
      throwsA(same(failure)),
    );
  });

  test('loadPinnedMessages sends GET to /channels/{id}/pins', () async {
    final appDioClient = _FakeAppDioClient(
      responses: {
        '/channels/general/pins': [
          {
            'id': 'message-1',
            'content': 'Pinned!',
            'createdAt': '2026-05-07T10:00:00Z',
            'senderType': 'human',
            'messageType': 'message',
            'isPinned': true,
          },
        ],
      },
    );
    final container = _createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);
    final messages = await repository.loadPinnedMessages(
      ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'general',
        ),
      ),
    );

    expect(messages.length, 1);
    expect(messages.first.id, 'message-1');
    expect(messages.first.content, 'Pinned!');
    expect(messages.first.isPinned, isTrue);

    final request = appDioClient.requests.last;
    expect(request.path, '/channels/general/pins');
    expect(request.serverIdHeader, 'server-1');
  });

  test('loadPinnedMessages rethrows AppFailure from transport', () async {
    const failure = ServerFailure(
      message: 'Not found.',
      statusCode: 404,
    );
    final appDioClient = _FakeAppDioClient(
      failures: {'/channels/general/pins': failure},
    );
    final container = _createContainer(appDioClient);
    addTearDown(container.dispose);

    final repository = container.read(conversationRepositoryProvider);
    await expectLater(
      repository.loadPinnedMessages(
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
    void Function(int, int)? onSendProgress,
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

  @override
  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    final headers = Map<String, Object?>.from(options?.headers ?? const {});
    requests.add(
      _CapturedRequest(
        method: 'PATCH',
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

  @override
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    final headers = Map<String, Object?>.from(options?.headers ?? const {});
    requests.add(
      _CapturedRequest(
        method: 'DELETE',
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

  @override
  Future<void> upsertMessages(Iterable<LocalMessageUpsert> entries) async {
    throw StateError('SQLite disk I/O error');
  }

  @override
  Future<void> upsertIdentities(
    Iterable<LocalIdentityUpsert> entries,
  ) async {
    throw StateError('SQLite disk I/O error');
  }
}

/// No-op saved messages repository for tests that don't exercise saved logic.
class _NoOpSavedMessagesRepository implements SavedMessagesRepository {
  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) async =>
      {};

  @override
  Future<void> saveMessage(ServerScopeId serverId, String messageId) async {}

  @override
  Future<void> unsaveMessage(ServerScopeId serverId, String messageId) async {}

  @override
  Future<SavedMessagesPage> listSavedMessages(
    ServerScopeId serverId, {
    int limit = 50,
    int offset = 0,
  }) async =>
      const SavedMessagesPage(items: [], hasMore: false);
}
