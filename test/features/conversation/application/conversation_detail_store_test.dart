import 'package:dio/dio.dart';
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/message_send_status.dart';
import 'package:slock_app/features/conversation/application/outbox_store.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_session_store.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart'
    as saved_data;
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

/// Creates an always-online [ConnectivityService] for tests.
ConnectivityService _onlineConnectivity() {
  final c = StreamController<ConnectivityStatus>.broadcast();
  return ConnectivityService.withInitialStatus(
    ConnectivityStatus.online,
    controller: c,
  );
}

void main() {
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    ),
  );

  test('load populates title and messages on success', () async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'message-1',
            content: 'Hello world',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: 1,
          ),
        ],
        historyLimited: true,
        hasOlder: true,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(conversationDetailStoreProvider.notifier).load();
    final state = container.read(conversationDetailStoreProvider);

    expect(state.status, ConversationDetailStatus.success);
    expect(state.title, '#general');
    expect(state.messages.single.content, 'Hello world');
    expect(state.historyLimited, isTrue);
    expect(state.hasOlder, isTrue);
    expect(repository.requestedTargets, [target]);
  });

  test('load stores typed AppFailure in state without rethrowing', () async {
    const failure = ServerFailure(
      message: 'Conversation load failed.',
      statusCode: 500,
    );
    final container = ProviderContainer(
      overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(
          _FakeConversationRepository(failure: failure),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(conversationDetailStoreProvider.notifier).load();
    final state = container.read(conversationDetailStoreProvider);

    expect(state.status, ConversationDetailStatus.failure);
    expect(state.failure, failure);
    expect(state.messages, isEmpty);
    expect(state.resolvedTitle, '#general');
  });

  test('send appends deduped message and clears draft on success', () async {
    final sentMessage = ConversationMessageSummary(
      id: 'message-2',
      content: 'New message',
      createdAt: DateTime.parse('2026-04-19T15:05:00Z'),
      senderType: 'human',
      messageType: 'message',
      seq: 2,
    );
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'message-1',
            content: 'Hello world',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: 1,
          ),
        ],
        historyLimited: true,
        hasOlder: false,
      ),
      sentMessage: sentMessage,
    );
    final container = ProviderContainer(
      overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(repository),
        connectivityServiceProvider.overrideWithValue(_onlineConnectivity()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(conversationDetailStoreProvider.notifier).load();
    final notifier = container.read(conversationDetailStoreProvider.notifier);

    notifier.updateDraft('  New message  ');
    await notifier.send();

    final state = container.read(conversationDetailStoreProvider);
    expect(state.isSending, isFalse);
    expect(state.draft, isEmpty);
    expect(state.sendFailure, isNull);
    // Canonical message deferred until sent indicator removed (2s);
    // pending message transitions to 'sent' immediately.
    expect(state.pendingMessages, hasLength(1));
    expect(state.pendingMessages.first.status, MessageSendStatus.sent);
    expect(repository.sentContents, ['New message']);
  });

  test('send preserves draft and stores typed AppFailure on failure', () async {
    const failure = NotFoundFailure(
      message: 'Send failed.',
    );
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ),
      sendFailure: failure,
    );
    final container = ProviderContainer(
      overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(repository),
        connectivityServiceProvider.overrideWithValue(_onlineConnectivity()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(conversationDetailStoreProvider.notifier).load();
    final notifier = container.read(conversationDetailStoreProvider.notifier);

    notifier.updateDraft('Retry me');
    await notifier.send();

    final state = container.read(conversationDetailStoreProvider);
    expect(state.isSending, isFalse);
    // Draft cleared optimistically; content preserved in pending message
    expect(state.draft, isEmpty);
    // Failure stored on pending message, not state.sendFailure
    expect(state.pendingMessages, hasLength(1));
    expect(state.pendingMessages.first.status, MessageSendStatus.failed);
    expect(state.pendingMessages.first.content, 'Retry me');
    expect(state.pendingMessages.first.failure, failure);
    expect(state.messages, isEmpty);
  });

  test('concurrent send calls produce a single network request', () async {
    final sendCompleter = Completer<ConversationMessageSummary>();
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ),
      sentMessage: ConversationMessageSummary(
        id: 'message-1',
        content: 'Only once',
        createdAt: DateTime.parse('2026-04-19T15:05:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      ),
      sendCompleter: sendCompleter,
    );
    final container = ProviderContainer(
      overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(repository),
        connectivityServiceProvider.overrideWithValue(_onlineConnectivity()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(conversationDetailStoreProvider.notifier).load();
    final notifier = container.read(conversationDetailStoreProvider.notifier);

    notifier.updateDraft('Only once');

    final first = notifier.send();
    final second = notifier.send();

    // Draft cleared by first send; second is a no-op (empty draft)
    expect(
      container.read(conversationDetailStoreProvider).pendingMessages,
      hasLength(1),
    );

    sendCompleter.complete(repository.sentMessage!);
    await first;
    await second;

    expect(repository.sentContents, hasLength(1));
    expect(repository.sentContents.single, 'Only once');
  });

  test('realtime append shares send dedupe truth by message id', () async {
    final sentMessage = ConversationMessageSummary(
      id: 'message-2',
      content: 'Realtime echo',
      createdAt: DateTime.parse('2026-04-19T15:05:00Z'),
      senderType: 'human',
      messageType: 'message',
      seq: 2,
    );
    final ingress = RealtimeReductionIngress();
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ),
      sentMessage: sentMessage,
    );
    final container = ProviderContainer(
      overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(repository),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
        connectivityServiceProvider.overrideWithValue(_onlineConnectivity()),
      ],
    );
    final subscription = container.listen(
      conversationDetailStoreProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(() async {
      subscription.close();
      container.dispose();
      await ingress.dispose();
    });

    await container.read(conversationDetailStoreProvider.notifier).load();
    final notifier = container.read(conversationDetailStoreProvider.notifier);

    notifier.updateDraft('Realtime echo');
    await notifier.send();

    ingress.accept(
      RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime(2026, 4, 20),
        seq: 2,
        payload: {
          'id': 'message-2',
          'channelId': target.conversationId,
          'content': 'Realtime echo',
          'createdAt': '2026-04-19T15:05:00Z',
          'senderType': 'human',
          'messageType': 'message',
          'senderId': 'other-user',
          'seq': 2,
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(conversationDetailStoreProvider);
    expect(state.messages.map((message) => message.id), ['message-2']);
  });

  test('loadOlder prepends deduped older messages and updates hasOlder',
      () async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'message-3',
            content: 'Newest loaded',
            createdAt: DateTime.parse('2026-04-19T15:02:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: 3,
          ),
        ],
        historyLimited: false,
        hasOlder: true,
      ),
      olderPages: {
        3: ConversationMessagePage(
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'Older 1',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
            ConversationMessageSummary(
              id: 'message-2',
              content: 'Older 2',
              createdAt: DateTime.parse('2026-04-19T15:01:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 2,
            ),
            ConversationMessageSummary(
              id: 'message-3',
              content: 'Newest loaded',
              createdAt: DateTime.parse('2026-04-19T15:02:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 3,
            ),
          ],
          historyLimited: true,
          hasOlder: false,
        ),
      },
    );
    final container = ProviderContainer(
      overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(conversationDetailStoreProvider.notifier).load();
    await container.read(conversationDetailStoreProvider.notifier).loadOlder();

    final state = container.read(conversationDetailStoreProvider);
    expect(state.messages.map((message) => message.id), [
      'message-1',
      'message-2',
      'message-3',
    ]);
    expect(state.hasOlder, isFalse);
    expect(state.historyLimited, isTrue);
    expect(repository.olderRequests, [3]);
  });

  test('ensureLoaded restores cached window without re-requesting', () async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'message-1',
            content: 'Cached',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderType: 'human',
            messageType: 'message',
            seq: 1,
          ),
        ],
        historyLimited: false,
        hasOlder: false,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      conversationDetailStoreProvider,
      (_, __) {},
      fireImmediately: true,
    );
    await container.read(conversationDetailStoreProvider.notifier).load();
    subscription.close();
    await Future<void>.delayed(Duration.zero);

    final restoredState = container.read(conversationDetailStoreProvider);
    expect(restoredState.status, ConversationDetailStatus.success);
    expect(restoredState.messages.single.content, 'Cached');

    await container
        .read(conversationDetailStoreProvider.notifier)
        .ensureLoaded();

    expect(repository.requestedTargets, [target]);
  });
  test('realtime-first then send response deduplicates by message id',
      () async {
    final ingress = RealtimeReductionIngress();
    final sentMessage = ConversationMessageSummary(
      id: 'message-2',
      content: 'Race message',
      createdAt: DateTime.parse('2026-04-19T15:05:00Z'),
      senderType: 'human',
      messageType: 'message',
      seq: 2,
    );
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ),
      sentMessage: sentMessage,
    );
    final container = ProviderContainer(
      overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(repository),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
        connectivityServiceProvider.overrideWithValue(_onlineConnectivity()),
      ],
    );
    final subscription = container.listen(
      conversationDetailStoreProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(() async {
      subscription.close();
      container.dispose();
      await ingress.dispose();
    });

    await container.read(conversationDetailStoreProvider.notifier).load();
    final notifier = container.read(conversationDetailStoreProvider.notifier);

    notifier.updateDraft('Race message');

    ingress.accept(
      RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime(2026, 4, 20),
        seq: 2,
        payload: {
          'id': 'message-2',
          'channelId': target.conversationId,
          'content': 'Race message',
          'createdAt': '2026-04-19T15:05:00Z',
          'senderType': 'human',
          'messageType': 'message',
          'senderId': 'other-user',
          'seq': 2,
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);

    await notifier.send();

    final state = container.read(conversationDetailStoreProvider);
    expect(state.messages.map((message) => message.id), ['message-2']);
  });

  group('reopen refresh from cache', () {
    test('appends newer messages when reopening from stale cache', () async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'Cached',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
        newerPages: {
          1: ConversationMessagePage(
            messages: [
              ConversationMessageSummary(
                id: 'message-2',
                content: 'Newer',
                createdAt: DateTime.parse('2026-04-19T15:05:00Z'),
                senderType: 'human',
                messageType: 'message',
                seq: 2,
              ),
            ],
            historyLimited: false,
            hasOlder: false,
            hasNewer: true,
          ),
        },
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          conversationDetailSessionStoreProvider
              .overrideWith(() => ConversationDetailSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      final sub1 = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      await container.read(conversationDetailStoreProvider.notifier).load();
      expect(repository.requestedTargets, [target]);
      sub1.close();
      await Future<void>.delayed(Duration.zero);

      container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      final restoredState = container.read(conversationDetailStoreProvider);
      expect(restoredState.status, ConversationDetailStatus.success);
      expect(restoredState.messages.map((m) => m.id), ['message-1']);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final refreshedState = container.read(conversationDetailStoreProvider);
      expect(
          refreshedState.messages.map((m) => m.id), ['message-1', 'message-2']);
      expect(refreshedState.hasNewer, isTrue);
      expect(repository.newerRequests, [1]);
    });

    test('no-ops when cache is current (no newer messages)', () async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'Latest',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
        newerPages: {
          1: const ConversationMessagePage(
            messages: [],
            historyLimited: false,
            hasOlder: false,
          ),
        },
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          conversationDetailSessionStoreProvider
              .overrideWith(() => ConversationDetailSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      final sub1 = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      await container.read(conversationDetailStoreProvider.notifier).load();
      sub1.close();
      await Future<void>.delayed(Duration.zero);

      container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages.map((m) => m.id), ['message-1']);
      expect(repository.newerRequests, [1]);
    });

    test('keeps cached window when refresh fails (fail-soft)', () async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'Cached',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
        newerFailure: const ServerFailure(
          message: 'Network error',
          statusCode: 500,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          conversationDetailSessionStoreProvider
              .overrideWith(() => ConversationDetailSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      final sub1 = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      await container.read(conversationDetailStoreProvider.notifier).load();
      sub1.close();
      await Future<void>.delayed(Duration.zero);

      container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(conversationDetailStoreProvider);
      expect(state.status, ConversationDetailStatus.success);
      expect(state.messages.map((m) => m.id), ['message-1']);
      expect(state.failure, isNull);
    });
  });

  group('loadNewer', () {
    test('appends deduped newer messages and updates hasNewer', () async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'First',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
        newerPages: {
          1: ConversationMessagePage(
            messages: [
              ConversationMessageSummary(
                id: 'message-2',
                content: 'Second',
                createdAt: DateTime.parse('2026-04-19T15:05:00Z'),
                senderType: 'human',
                messageType: 'message',
                seq: 2,
              ),
            ],
            historyLimited: false,
            hasOlder: false,
            hasNewer: true,
          ),
          2: ConversationMessagePage(
            messages: [
              ConversationMessageSummary(
                id: 'message-3',
                content: 'Third',
                createdAt: DateTime.parse('2026-04-19T15:10:00Z'),
                senderType: 'human',
                messageType: 'message',
                seq: 3,
              ),
            ],
            historyLimited: false,
            hasOlder: false,
          ),
        },
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          conversationDetailSessionStoreProvider
              .overrideWith(() => ConversationDetailSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      final sub1 = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      await container.read(conversationDetailStoreProvider.notifier).load();
      sub1.close();
      await Future<void>.delayed(Duration.zero);

      container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        container
            .read(conversationDetailStoreProvider)
            .messages
            .map((m) => m.id),
        ['message-1', 'message-2'],
      );
      expect(
        container.read(conversationDetailStoreProvider).hasNewer,
        isTrue,
      );

      await container
          .read(conversationDetailStoreProvider.notifier)
          .loadNewer();

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages.map((m) => m.id),
          ['message-1', 'message-2', 'message-3']);
      expect(state.hasNewer, isFalse);
      expect(state.isLoadingNewer, isFalse);
      expect(repository.newerRequests, [1, 2]);
    });

    test('stores failure on loadNewer error', () async {
      const failure = ServerFailure(
        message: 'Newer load failed.',
        statusCode: 500,
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'First',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
        newerPages: {
          1: ConversationMessagePage(
            messages: [
              ConversationMessageSummary(
                id: 'message-2',
                content: 'Second',
                createdAt: DateTime.parse('2026-04-19T15:05:00Z'),
                senderType: 'human',
                messageType: 'message',
                seq: 2,
              ),
            ],
            historyLimited: false,
            hasOlder: false,
            hasNewer: true,
          ),
        },
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          conversationDetailSessionStoreProvider
              .overrideWith(() => ConversationDetailSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      final sub1 = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      await container.read(conversationDetailStoreProvider.notifier).load();
      sub1.close();
      await Future<void>.delayed(Duration.zero);

      container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      repository.newerFailure = failure;
      await container
          .read(conversationDetailStoreProvider.notifier)
          .loadNewer();

      final state = container.read(conversationDetailStoreProvider);
      expect(state.isLoadingNewer, isFalse);
      expect(state.failure, failure);
    });

    test('guards: no-op when hasNewer is false', () async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'First',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      await container
          .read(conversationDetailStoreProvider.notifier)
          .loadNewer();

      expect(repository.newerRequests, isEmpty);
    });

    test('guards: no-op when not in success status', () async {
      final repository = _FakeConversationRepository(
        failure: const ServerFailure(
          message: 'Load failed.',
          statusCode: 500,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      await container
          .read(conversationDetailStoreProvider.notifier)
          .loadNewer();

      expect(repository.newerRequests, isEmpty);
    });

    test('guards: no-op when messages are empty', () async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: const [],
          historyLimited: false,
          hasOlder: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      await container
          .read(conversationDetailStoreProvider.notifier)
          .loadNewer();

      expect(repository.newerRequests, isEmpty);
    });

    test('guards: no-op when all message seqs are null', () async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'No seq',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      await container
          .read(conversationDetailStoreProvider.notifier)
          .loadNewer();

      expect(repository.newerRequests, isEmpty);
    });
  });

  group('gap recovery', () {
    test('triggers loadNewerMessages when realtime message has gapDetected',
        () async {
      final ingress = RealtimeReductionIngress();
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'First',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
        newerPages: {
          1: ConversationMessagePage(
            messages: [
              ConversationMessageSummary(
                id: 'message-2',
                content: 'Missed',
                createdAt: DateTime.parse('2026-04-19T15:01:00Z'),
                senderType: 'human',
                messageType: 'message',
                seq: 2,
              ),
            ],
            historyLimited: false,
            hasOlder: false,
          ),
        },
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
        ],
      );
      final subscription = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await ingress.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();

      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'message:new',
          scopeKey: RealtimeEventEnvelope.globalScopeKey,
          receivedAt: DateTime(2026, 4, 20),
          seq: 3,
          payload: {
            'id': 'message-3',
            'channelId': target.conversationId,
            'content': 'After gap',
            'createdAt': '2026-04-19T15:02:00Z',
            'senderType': 'human',
            'messageType': 'message',
            'senderId': 'user-a',
            'seq': 3,
          },
          gapDetected: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(conversationDetailStoreProvider);
      expect(
        state.messages.map((m) => m.id),
        ['message-1', 'message-2', 'message-3'],
      );
      expect(repository.newerRequests, [1]);
    });

    test('gap recovery is best-effort and does not surface failure', () async {
      final ingress = RealtimeReductionIngress();
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'First',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
        newerFailure: const ServerFailure(
          message: 'Network error',
          statusCode: 500,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
        ],
      );
      final subscription = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await ingress.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();

      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'message:new',
          scopeKey: RealtimeEventEnvelope.globalScopeKey,
          receivedAt: DateTime(2026, 4, 20),
          seq: 5,
          payload: {
            'id': 'message-5',
            'channelId': target.conversationId,
            'content': 'After gap',
            'createdAt': '2026-04-19T15:05:00Z',
            'senderType': 'human',
            'messageType': 'message',
            'senderId': 'user-a',
            'seq': 5,
          },
          gapDetected: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(conversationDetailStoreProvider);
      expect(state.status, ConversationDetailStatus.success);
      expect(state.failure, isNull);
      expect(state.messages.map((m) => m.id), ['message-1', 'message-5']);
    });

    test('no recovery when gapDetected is false', () async {
      final ingress = RealtimeReductionIngress();
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'First',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
        newerPages: {
          2: ConversationMessagePage(
            messages: [
              ConversationMessageSummary(
                id: 'message-extra',
                content: 'Should not appear',
                createdAt: DateTime.parse('2026-04-19T15:01:00Z'),
                senderType: 'human',
                messageType: 'message',
                seq: 2,
              ),
            ],
            historyLimited: false,
            hasOlder: false,
          ),
        },
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
        ],
      );
      final subscription = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await ingress.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();

      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'message:new',
          scopeKey: RealtimeEventEnvelope.globalScopeKey,
          receivedAt: DateTime(2026, 4, 20),
          seq: 2,
          payload: {
            'id': 'message-2',
            'channelId': target.conversationId,
            'content': 'Normal',
            'createdAt': '2026-04-19T15:01:00Z',
            'senderType': 'human',
            'messageType': 'message',
            'senderId': 'user-a',
            'seq': 2,
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(repository.newerRequests, isEmpty);
    });
  });

  test('message:updated via copyWith preserves attachments and threadId',
      () async {
    final ingress = RealtimeReductionIngress();
    final container = ProviderContainer(
      overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(
          _FakeConversationRepository(
            snapshot: ConversationDetailSnapshot(
              target: target,
              title: '#general',
              messages: [
                ConversationMessageSummary(
                  id: 'msg-1',
                  content: 'Original',
                  createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
                  senderType: 'human',
                  messageType: 'message',
                  seq: 1,
                  attachments: const [
                    MessageAttachment(
                        name: 'file.pdf', type: 'application/pdf'),
                  ],
                  threadId: 'thread-abc',
                ),
              ],
              historyLimited: false,
              hasOlder: false,
            ),
          ),
        ),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
      ],
    );
    final subscription = container.listen(
      conversationDetailStoreProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(() async {
      subscription.close();
      container.dispose();
      await ingress.dispose();
    });

    await container.read(conversationDetailStoreProvider.notifier).load();

    ingress.accept(
      RealtimeEventEnvelope(
        eventType: 'message:updated',
        scopeKey: RealtimeEventEnvelope.globalScopeKey,
        receivedAt: DateTime(2026, 4, 20),
        seq: 2,
        payload: {
          'id': 'msg-1',
          'channelId': target.conversationId,
          'content': 'Edited',
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(conversationDetailStoreProvider);
    expect(state.messages[0].content, 'Edited');
    expect(state.messages[0].attachments, hasLength(1));
    expect(state.messages[0].attachments![0].name, 'file.pdf');
    expect(state.messages[0].threadId, 'thread-abc');
  });

  group('delete message', () {
    test('deleteMessage removes message from state and calls repo', () async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'First',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
            ConversationMessageSummary(
              id: 'message-2',
              content: 'Second',
              createdAt: DateTime.parse('2026-04-19T15:01:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 2,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      await container
          .read(conversationDetailStoreProvider.notifier)
          .deleteMessage('message-1');

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages.length, 2);
      expect(state.messages.first.isDeleted, isTrue);
      expect(state.messages.last.isDeleted, isFalse);
      expect(repository.deletedMessageIds, ['message-1']);
    });

    test('deleteMessage reverts on failure', () async {
      const failure = ServerFailure(
        message: 'Forbidden.',
        statusCode: 403,
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'Only',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
        deleteFailure: failure,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();

      await expectLater(
        container
            .read(conversationDetailStoreProvider.notifier)
            .deleteMessage('message-1'),
        throwsA(isA<ServerFailure>()),
      );

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages.map((m) => m.id), ['message-1']);
      expect(state.messages.first.isDeleted, isFalse);
    });

    test(
        'batchDeleteMessages starts all deletes concurrently and rolls back failures',
        () async {
      final deleteCompleters = {
        'message-1': Completer<void>(),
        'message-2': Completer<void>(),
        'message-3': Completer<void>(),
      };
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'First',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
            ConversationMessageSummary(
              id: 'message-2',
              content: 'Second',
              createdAt: DateTime.parse('2026-04-19T15:01:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 2,
            ),
            ConversationMessageSummary(
              id: 'message-3',
              content: 'Third',
              createdAt: DateTime.parse('2026-04-19T15:02:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 3,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
        deleteCompleters: deleteCompleters,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final deleteFuture = container
          .read(conversationDetailStoreProvider.notifier)
          .batchDeleteMessages({'message-1', 'message-2', 'message-3'});
      await Future<void>.delayed(Duration.zero);

      expect(
        repository.deletedMessageIds,
        containsAll(['message-1', 'message-2', 'message-3']),
        reason: 'All delete requests should be initiated before any completes',
      );

      deleteCompleters['message-1']!.complete();
      deleteCompleters['message-2']!.completeError(
        const ServerFailure(message: 'delete failed'),
      );
      deleteCompleters['message-3']!.complete();

      final result = await deleteFuture;

      expect(result.succeeded, 2);
      expect(result.failed, 1);
      final messages = container.read(conversationDetailStoreProvider).messages;
      expect(
          messages.singleWhere((m) => m.id == 'message-1').isDeleted, isTrue);
      expect(
          messages.singleWhere((m) => m.id == 'message-2').isDeleted, isFalse);
      expect(
          messages.singleWhere((m) => m.id == 'message-3').isDeleted, isTrue);
    });

    test('batchSaveMessages stops sequential saves after disposal', () async {
      final firstSaveCompleter = Completer<void>();
      final savedRepository = _ControllableSavedMessagesRepository(
        saveCompleters: {'message-1': firstSaveCompleter},
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'First',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
            ConversationMessageSummary(
              id: 'message-2',
              content: 'Second',
              createdAt: DateTime.parse('2026-04-19T15:01:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 2,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          savedMessagesRepositoryProvider.overrideWithValue(savedRepository),
        ],
      );

      await container.read(conversationDetailStoreProvider.notifier).load();
      final saveFuture = container
          .read(conversationDetailStoreProvider.notifier)
          .batchSaveMessages({'message-1', 'message-2'});
      await Future<void>.delayed(Duration.zero);

      expect(savedRepository.savedMessageIds, ['message-1']);

      container.dispose();
      firstSaveCompleter.complete();
      await saveFuture;

      expect(
        savedRepository.savedMessageIds,
        ['message-1'],
        reason: 'Disposed stores must stop before the next sequential save.',
      );
    });

    test('message:deleted realtime event removes message from state', () async {
      final ingress = RealtimeReductionIngress();
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'Will be deleted',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
            ConversationMessageSummary(
              id: 'message-2',
              content: 'Stays',
              createdAt: DateTime.parse('2026-04-19T15:01:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 2,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
        ],
      );
      final subscription = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await ingress.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();

      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'message:deleted',
          scopeKey: RealtimeEventEnvelope.globalScopeKey,
          receivedAt: DateTime(2026, 4, 20),
          seq: 3,
          payload: {
            'id': 'message-1',
            'channelId': target.conversationId,
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages.length, 2);
      expect(state.messages.first.isDeleted, isTrue);
      expect(state.messages.last.isDeleted, isFalse);
      expect(repository.removedStoredMessageIds, ['message-1']);
    });

    test('message:deleted ignores failed stored-message removal', () async {
      final ingress = RealtimeReductionIngress();
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'Will be deleted',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
        removeStoredFailure: StateError('local delete failed'),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
        ],
      );
      final subscription = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await ingress.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();

      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'message:deleted',
          scopeKey: RealtimeEventEnvelope.globalScopeKey,
          receivedAt: DateTime(2026, 4, 20),
          seq: 4,
          payload: {
            'id': 'message-1',
            'channelId': target.conversationId,
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages.single.isDeleted, isTrue);
      expect(repository.removedStoredMessageIds, ['message-1']);
    });
  });

  group('pin message', () {
    test('pinMessage toggles isPinned and calls repo', () async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'Pinnable',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      expect(
        container.read(conversationDetailStoreProvider).messages[0].isPinned,
        isFalse,
      );

      await container
          .read(conversationDetailStoreProvider.notifier)
          .pinMessage('message-1');

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages[0].isPinned, isTrue);
      expect(repository.pinnedMessageIds, ['message-1']);
    });

    test('pinMessage reverts on failure', () async {
      const failure = ServerFailure(
        message: 'Not allowed.',
        statusCode: 403,
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'Pinnable',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
        pinFailure: failure,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();

      await expectLater(
        container
            .read(conversationDetailStoreProvider.notifier)
            .pinMessage('message-1'),
        throwsA(isA<ServerFailure>()),
      );

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages[0].isPinned, isFalse);
    });

    test('unpinMessage toggles isPinned off and calls repo', () async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'Pinned',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
              isPinned: true,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      expect(
        container.read(conversationDetailStoreProvider).messages[0].isPinned,
        isTrue,
      );

      await container
          .read(conversationDetailStoreProvider.notifier)
          .unpinMessage('message-1');

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages[0].isPinned, isFalse);
      expect(repository.unpinnedMessageIds, ['message-1']);
    });

    test('message:pinned realtime event sets isPinned on matching message',
        () async {
      final ingress = RealtimeReductionIngress();
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'Will be pinned',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
        ],
      );
      final subscription = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await ingress.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();

      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'message:pinned',
          scopeKey: RealtimeEventEnvelope.globalScopeKey,
          receivedAt: DateTime(2026, 4, 20),
          seq: 2,
          payload: {
            'id': 'message-1',
            'channelId': target.conversationId,
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages[0].isPinned, isTrue);
    });

    test('message:unpinned realtime event clears isPinned', () async {
      final ingress = RealtimeReductionIngress();
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'message-1',
              content: 'Was pinned',
              createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
              isPinned: true,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
        ],
      );
      final subscription = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await ingress.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();
      expect(
        container.read(conversationDetailStoreProvider).messages[0].isPinned,
        isTrue,
      );

      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'message:unpinned',
          scopeKey: RealtimeEventEnvelope.globalScopeKey,
          receivedAt: DateTime(2026, 4, 20),
          seq: 2,
          payload: {
            'id': 'message-1',
            'channelId': target.conversationId,
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages[0].isPinned, isFalse);
    });
  });

  group('quote reply', () {
    final replyTarget = ConversationMessageSummary(
      id: 'message-1',
      content: 'Original message',
      createdAt: DateTime.parse('2026-05-01T10:00:00Z'),
      senderType: 'human',
      messageType: 'message',
      senderName: 'Alice',
      seq: 1,
    );

    test('setReplyTo sets replyToMessage in state', () async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [replyTarget],
          historyLimited: false,
          hasOlder: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      expect(
        container.read(conversationDetailStoreProvider).replyToMessage,
        isNull,
      );

      container
          .read(conversationDetailStoreProvider.notifier)
          .setReplyTo(replyTarget);

      final state = container.read(conversationDetailStoreProvider);
      expect(state.replyToMessage, replyTarget);
    });

    test('clearReplyTo nulls replyToMessage in state', () async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [replyTarget],
          historyLimited: false,
          hasOlder: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final notifier = container.read(conversationDetailStoreProvider.notifier);

      notifier.setReplyTo(replyTarget);
      expect(
        container.read(conversationDetailStoreProvider).replyToMessage,
        isNotNull,
      );

      notifier.clearReplyTo();

      expect(
        container.read(conversationDetailStoreProvider).replyToMessage,
        isNull,
      );
    });

    test('send passes replyToId and clears replyToMessage', () async {
      final sentMessage = ConversationMessageSummary(
        id: 'message-2',
        content: 'Reply text',
        createdAt: DateTime.parse('2026-05-01T10:05:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 2,
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [replyTarget],
          historyLimited: false,
          hasOlder: false,
        ),
        sentMessage: sentMessage,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(_onlineConnectivity()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final notifier = container.read(conversationDetailStoreProvider.notifier);

      notifier.setReplyTo(replyTarget);
      notifier.updateDraft('Reply text');
      await notifier.send();

      final state = container.read(conversationDetailStoreProvider);
      // replyToMessage cleared after send
      expect(state.replyToMessage, isNull);
      // replyToId passed to repository
      expect(repository.sentReplyToIds, ['message-1']);
      // pending message carries replyToId for retry
      expect(state.pendingMessages.first.replyToId, 'message-1');
    });

    test('send without reply passes null replyToId', () async {
      final sentMessage = ConversationMessageSummary(
        id: 'message-2',
        content: 'No reply',
        createdAt: DateTime.parse('2026-05-01T10:05:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 2,
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [replyTarget],
          historyLimited: false,
          hasOlder: false,
        ),
        sentMessage: sentMessage,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(_onlineConnectivity()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final notifier = container.read(conversationDetailStoreProvider.notifier);

      notifier.updateDraft('No reply');
      await notifier.send();

      expect(repository.sentReplyToIds, [null]);
      expect(
        container
            .read(conversationDetailStoreProvider)
            .pendingMessages
            .first
            .replyToId,
        isNull,
      );
    });

    test('retrySend preserves replyToId from pending message', () async {
      const failure = NotFoundFailure(
        message: 'Send failed.',
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [replyTarget],
          historyLimited: false,
          hasOlder: false,
        ),
        sendFailure: failure,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(_onlineConnectivity()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final notifier = container.read(conversationDetailStoreProvider.notifier);

      // Set reply, send (will fail)
      notifier.setReplyTo(replyTarget);
      notifier.updateDraft('Retry reply');
      await notifier.send();

      final failedState = container.read(conversationDetailStoreProvider);
      expect(
          failedState.pendingMessages.first.status, MessageSendStatus.failed);
      expect(failedState.pendingMessages.first.replyToId, 'message-1');

      // Clear the send failure and retry
      repository.sentContents.clear();
      repository.sentReplyToIds.clear();

      // Retry: still passes original replyToId
      await notifier.retrySend(failedState.pendingMessages.first.localId);

      expect(repository.sentReplyToIds, ['message-1']);
    });

    test('failed quoted send preserves replyToMessage in state', () async {
      const failure = NotFoundFailure(
        message: 'Send failed.',
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [replyTarget],
          historyLimited: false,
          hasOlder: false,
        ),
        sendFailure: failure,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(_onlineConnectivity()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final notifier = container.read(conversationDetailStoreProvider.notifier);

      notifier.setReplyTo(replyTarget);
      notifier.updateDraft('Will fail');
      await notifier.send();

      final state = container.read(conversationDetailStoreProvider);
      // Reply preview must survive the failure
      expect(state.replyToMessage, replyTarget);
      // Pending message still carries the replyToId
      expect(state.pendingMessages.first.status, MessageSendStatus.failed);
      expect(state.pendingMessages.first.replyToId, 'message-1');
    });
  });

  group('offline send', () {
    test('send when offline enqueues to outbox and adds pending message',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final connectivityController =
          StreamController<ConnectivityStatus>.broadcast();
      final connectivity = ConnectivityService.withInitialStatus(
        ConnectivityStatus.offline,
        controller: connectivityController,
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: const [],
          historyLimited: false,
          hasOlder: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(connectivity),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(() async {
        await Future<void>.delayed(Duration.zero);
        container.dispose();
        await connectivityController.close();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();
      final notifier = container.read(conversationDetailStoreProvider.notifier);

      notifier.updateDraft('Offline message');
      await notifier.send();

      final state = container.read(conversationDetailStoreProvider);
      // Draft is cleared
      expect(state.draft, isEmpty);
      // Pending message added with sending status
      expect(state.pendingMessages, hasLength(1));
      expect(state.pendingMessages.first.content, 'Offline message');
      // Repository was NOT called (message queued, not sent)
      expect(repository.sentContents, isEmpty);
      // Outbox has the queued message
      final outbox = container.read(outboxStoreProvider);
      final targetKey = outboxTargetKey(target);
      expect(outbox.items[targetKey], hasLength(1));
      expect(outbox.items[targetKey]!.first.content, 'Offline message');
    });

    test('send when online bypasses outbox and sends directly', () async {
      final sentMessage = ConversationMessageSummary(
        id: 'message-1',
        content: 'Online message',
        createdAt: DateTime.parse('2026-05-07T12:00:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: const [],
          historyLimited: false,
          hasOlder: false,
        ),
        sentMessage: sentMessage,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(_onlineConnectivity()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final notifier = container.read(conversationDetailStoreProvider.notifier);

      notifier.updateDraft('Online message');
      await notifier.send();

      // Repository was called directly
      expect(repository.sentContents, ['Online message']);
      // Pending message transitions to sent (online path)
      final state = container.read(conversationDetailStoreProvider);
      expect(state.pendingMessages, hasLength(1));
      expect(state.pendingMessages.first.status, MessageSendStatus.sent);
    });

    test('offline send with replyToId stores it in outbox', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final connectivityController =
          StreamController<ConnectivityStatus>.broadcast();
      final connectivity = ConnectivityService.withInitialStatus(
        ConnectivityStatus.offline,
        controller: connectivityController,
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-to-reply',
              content: 'Original',
              createdAt: DateTime.parse('2026-05-07T11:00:00Z'),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(connectivity),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(() async {
        await Future<void>.delayed(Duration.zero);
        container.dispose();
        await connectivityController.close();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();
      final notifier = container.read(conversationDetailStoreProvider.notifier);

      // Set reply target, then send offline
      final replyMsg =
          container.read(conversationDetailStoreProvider).messages.first;
      notifier.setReplyTo(replyMsg);
      notifier.updateDraft('Offline reply');
      await notifier.send();

      // Outbox stores the replyToId
      final outbox = container.read(outboxStoreProvider);
      final targetKey = outboxTargetKey(target);
      expect(outbox.items[targetKey]!.first.replyToId, 'msg-to-reply');
    });

    test('offline send shares localId between pending and outbox', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final connectivityController =
          StreamController<ConnectivityStatus>.broadcast();
      final connectivity = ConnectivityService.withInitialStatus(
        ConnectivityStatus.offline,
        controller: connectivityController,
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: const [],
          historyLimited: false,
          hasOlder: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(connectivity),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(() async {
        await Future<void>.delayed(Duration.zero);
        container.dispose();
        await connectivityController.close();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();
      final notifier = container.read(conversationDetailStoreProvider.notifier);

      notifier.updateDraft('Shared ID test');
      await notifier.send();

      final pendingId = container
          .read(conversationDetailStoreProvider)
          .pendingMessages
          .first
          .localId;
      final outbox = container.read(outboxStoreProvider);
      final targetKey = outboxTargetKey(target);
      final outboxId = outbox.items[targetKey]!.first.localId;

      // Both share the same localId for reconciliation
      expect(pendingId, outboxId);
    });

    test('retryable failure on direct send enqueues to outbox', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final connectivityController =
          StreamController<ConnectivityStatus>.broadcast();
      final connectivity = ConnectivityService.withInitialStatus(
        ConnectivityStatus.online,
        controller: connectivityController,
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: const [],
          historyLimited: false,
          hasOlder: false,
        ),
        sendFailure: const NetworkFailure(
          message: 'Connection lost',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(connectivity),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(() async {
        await Future<void>.delayed(Duration.zero);
        container.dispose();
        await connectivityController.close();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();
      final notifier = container.read(conversationDetailStoreProvider.notifier);

      notifier.updateDraft('Will retry');
      await notifier.send();

      // Pending message stays in sending (not failed) — outbox handles retry
      final state = container.read(conversationDetailStoreProvider);
      expect(state.pendingMessages, hasLength(1));
      expect(state.pendingMessages.first.content, 'Will retry');
      // Message was handed off to outbox
      final outbox = container.read(outboxStoreProvider);
      final targetKey = outboxTargetKey(target);
      expect(outbox.items[targetKey], hasLength(1));
    });

    test('non-retryable failure on direct send marks failed (not outbox)',
        () async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: const [],
          historyLimited: false,
          hasOlder: false,
        ),
        sendFailure: const NotFoundFailure(
          message: 'Not found',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(_onlineConnectivity()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final notifier = container.read(conversationDetailStoreProvider.notifier);

      notifier.updateDraft('Will fail');
      await notifier.send();

      // Pending message marked as failed
      final state = container.read(conversationDetailStoreProvider);
      expect(state.pendingMessages, hasLength(1));
      expect(state.pendingMessages.first.status, MessageSendStatus.failed);
    });
  });

  group('P0-B send reliability regression', () {
    test('send timeout transitions pending to queued and enqueues in outbox',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      fakeAsync((fake) {
        final sendCompleter = Completer<ConversationMessageSummary>();
        final repository = _FakeConversationRepository(
          snapshot: ConversationDetailSnapshot(
            target: target,
            title: '#general',
            messages: const [],
            historyLimited: false,
            hasOlder: false,
          ),
          sendCompleter: sendCompleter,
        );

        final container = ProviderContainer(
          overrides: [
            currentConversationDetailTargetProvider.overrideWithValue(target),
            conversationRepositoryProvider.overrideWithValue(repository),
            connectivityServiceProvider
                .overrideWithValue(_onlineConnectivity()),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );

        // Keep the autoDispose provider alive across the fakeAsync
        // timeline so Riverpod does not dispose it between timer ticks.
        final sub = container.listen(
          conversationDetailStoreProvider,
          (_, __) {},
        );

        // Load.
        container.read(conversationDetailStoreProvider.notifier).load();
        fake.flushMicrotasks();

        final notifier =
            container.read(conversationDetailStoreProvider.notifier);
        notifier.updateDraft('Timeout message');
        notifier.send();
        fake.flushMicrotasks();

        // Mid-flight: pending in sending state.
        expect(
          container
              .read(conversationDetailStoreProvider)
              .pendingMessages
              .first
              .status,
          MessageSendStatus.sending,
          reason: 'Message should be in sending state before timeout',
        );

        // Advance past timeout (30 seconds).
        fake.elapse(ConversationDetailStore.sendTimeoutDuration);
        fake.flushMicrotasks();

        // After timeout: pending transitions to queued.
        expect(
          container
              .read(conversationDetailStoreProvider)
              .pendingMessages
              .first
              .status,
          MessageSendStatus.queued,
          reason: 'Timeout must transition pending message to queued',
        );

        // CancelToken must have been cancelled by the timeout handler.
        expect(repository.lastSendCancelToken, isNotNull,
            reason: 'sendMessage must receive a CancelToken');
        expect(repository.lastSendCancelToken!.isCancelled, isTrue,
            reason: 'Timeout must cancel the in-flight CancelToken to prevent '
                'duplicate sends from both the original request and the '
                'outbox drain');

        // Outbox must contain the message.
        final outbox = container.read(outboxStoreProvider);
        final tKey = outboxTargetKey(target);
        expect(outbox.items[tKey], hasLength(1),
            reason: 'Timeout must enqueue message in outbox');
        expect(outbox.items[tKey]!.first.content, 'Timeout message');

        // Complete the send completer so the dangling future resolves.
        sendCompleter.completeError(const CancelledFailure(message: 'timeout'));
        fake.flushMicrotasks();

        // State must remain queued (CancelledFailure is no-op in catch).
        expect(
          container
              .read(conversationDetailStoreProvider)
              .pendingMessages
              .first
              .status,
          MessageSendStatus.queued,
          reason:
              'CancelledFailure after timeout must not change queued status',
        );

        sub.close();
        container.dispose();
      });
    });

    test('retrySend happy path: failed → sending → sent', () async {
      final sentMessage = ConversationMessageSummary(
        id: 'retry-msg-1',
        content: 'Retry this',
        createdAt: DateTime.parse('2026-05-09T12:00:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      );

      final mutableRepo = _MutableFakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: const [],
          historyLimited: false,
          hasOlder: false,
        ),
      );
      // First send will fail with non-retryable error.
      mutableRepo.sendFailure = const NotFoundFailure(message: 'Not found');

      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(mutableRepo),
          connectivityServiceProvider.overrideWithValue(_onlineConnectivity()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final notifier = container.read(conversationDetailStoreProvider.notifier);

      // Send — will fail.
      notifier.updateDraft('Retry this');
      await notifier.send();

      expect(
        container
            .read(conversationDetailStoreProvider)
            .pendingMessages
            .first
            .status,
        MessageSendStatus.failed,
        reason: 'Non-retryable failure must set status to failed',
      );

      // Clear failure, set success response for retry.
      mutableRepo.sendFailure = null;
      mutableRepo.sentMessage = sentMessage;

      final localId = container
          .read(conversationDetailStoreProvider)
          .pendingMessages
          .first
          .localId;
      await notifier.retrySend(localId);

      final retriedState = container.read(conversationDetailStoreProvider);
      expect(
        retriedState.pendingMessages.first.status,
        MessageSendStatus.sent,
        reason: 'retrySend must transition failed → sent on success',
      );
    });

    test('retrySend guard: no-op when message is not in failed status',
        () async {
      final sentMessage = ConversationMessageSummary(
        id: 'guard-msg-1',
        content: 'Guard test',
        createdAt: DateTime.parse('2026-05-09T12:00:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      );
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: const [],
          historyLimited: false,
          hasOlder: false,
        ),
        sentMessage: sentMessage,
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(_onlineConnectivity()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final notifier = container.read(conversationDetailStoreProvider.notifier);

      // Send succeeds → pending message is in 'sent' status.
      notifier.updateDraft('Guard test');
      await notifier.send();

      final sentState = container.read(conversationDetailStoreProvider);
      expect(sentState.pendingMessages.first.status, MessageSendStatus.sent);
      final localId = sentState.pendingMessages.first.localId;

      // Attempt retrySend on a sent message — must be no-op.
      repository.sentContents.clear();
      await notifier.retrySend(localId);

      // Repository should NOT have been called again.
      expect(repository.sentContents, isEmpty,
          reason: 'retrySend must not fire for non-failed messages');
    });

    test('permanent failure → terminal state, no infinite retry', () async {
      final repository = _FakeConversationRepository(
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: const [],
          historyLimited: false,
          hasOlder: false,
        ),
        sendFailure: const NotFoundFailure(message: 'Not found'),
      );
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(_onlineConnectivity()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      final notifier = container.read(conversationDetailStoreProvider.notifier);

      notifier.updateDraft('Will fail permanently');
      await notifier.send();

      final state = container.read(conversationDetailStoreProvider);
      expect(state.pendingMessages, hasLength(1));
      expect(state.pendingMessages.first.status, MessageSendStatus.failed,
          reason: 'Non-retryable failure must reach terminal failed state');

      // Verify the message was NOT enqueued in the outbox (no auto-retry).
      // NotFoundFailure.isRetryable is false.
      expect(repository.sentContents, hasLength(1),
          reason: 'Only one send attempt should occur');
    });
  });
}

/// Mutable fake for tests that need to change send behavior mid-test.
class _MutableFakeConversationRepository implements ConversationRepository {
  _MutableFakeConversationRepository({this.snapshot});

  final ConversationDetailSnapshot? snapshot;
  AppFailure? sendFailure;
  ConversationMessageSummary? sentMessage;
  final List<String> sentContents = [];
  final List<String?> sentReplyToIds = [];

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async =>
      snapshot!;

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) =>
      throw UnimplementedError();

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
      );

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    CancelToken? cancelToken,
  }) async {
    sentContents.add(content);
    sentReplyToIds.add(replyToId);
    if (sendFailure != null) throw sendFailure!;
    return sentMessage!;
  }

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async =>
      message;

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async =>
      null;

  @override
  Future<void> editMessage(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {}

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> pinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> unpinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async =>
      const [];

  @override
  Future<void> addReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}
}

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({
    this.snapshot,
    this.failure,
    this.olderPages = const {},
    this.newerPages = const {},
    this.newerFailure,
    this.sentMessage,
    this.sendFailure,
    this.deleteFailure,
    this.deleteCompleters = const {},
    this.removeStoredFailure,
    this.pinFailure,
    this.sendCompleter,
  });

  final ConversationDetailSnapshot? snapshot;
  final AppFailure? failure;
  final Map<int, ConversationMessagePage> olderPages;
  final Map<int, ConversationMessagePage> newerPages;
  AppFailure? newerFailure;
  final ConversationMessageSummary? sentMessage;
  final AppFailure? sendFailure;
  final AppFailure? deleteFailure;
  final Map<String, Completer<void>> deleteCompleters;
  final Object? removeStoredFailure;
  final AppFailure? pinFailure;
  final Completer<ConversationMessageSummary>? sendCompleter;
  final List<ConversationDetailTarget> requestedTargets = [];
  final List<int> olderRequests = [];
  final List<int> newerRequests = [];
  final List<String> sentContents = [];
  final List<String?> sentReplyToIds = [];
  CancelToken? lastSendCancelToken;
  final List<ConversationMessageSummary> persistedMessages = [];
  final Map<String, String> updatedContents = {};
  final List<String> deletedMessageIds = [];
  final List<String> pinnedMessageIds = [];
  final List<String> unpinnedMessageIds = [];
  final List<String> removedStoredMessageIds = [];

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    requestedTargets.add(target);
    if (failure != null) {
      throw failure!;
    }
    return snapshot!;
  }

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async {
    olderRequests.add(beforeSeq);
    return olderPages[beforeSeq]!;
  }

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async {
    newerRequests.add(afterSeq);
    if (newerFailure != null) {
      throw newerFailure!;
    }
    return newerPages[afterSeq] ??
        const ConversationMessagePage(
          messages: [],
          historyLimited: false,
          hasOlder: false,
        );
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    CancelToken? cancelToken,
  }) async {
    sentContents.add(content);
    sentReplyToIds.add(replyToId);
    lastSendCancelToken = cancelToken;
    if (sendFailure != null) {
      throw sendFailure!;
    }
    if (sendCompleter != null) {
      return sendCompleter!.future;
    }
    return sentMessage!;
  }

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async {
    persistedMessages.add(message);
    return message;
  }

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {
    updatedContents[messageId] = content;
    for (final message in statefulMessages()) {
      if (message.id == messageId) {
        return message.copyWith(content: content);
      }
    }
    return null;
  }

  Iterable<ConversationMessageSummary> statefulMessages() sync* {
    if (snapshot != null) {
      yield* snapshot!.messages;
    }
    for (final page in olderPages.values) {
      yield* page.messages;
    }
    for (final page in newerPages.values) {
      yield* page.messages;
    }
    if (sentMessage != null) {
      yield sentMessage!;
    }
    yield* persistedMessages;
  }

  @override
  Future<void> editMessage(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {}

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    deletedMessageIds.add(messageId);
    final completer = deleteCompleters[messageId];
    if (completer != null) {
      await completer.future;
    }
    if (deleteFailure != null) {
      throw deleteFailure!;
    }
  }

  @override
  Future<void> pinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    pinnedMessageIds.add(messageId);
    if (pinFailure != null) {
      throw pinFailure!;
    }
  }

  @override
  Future<void> unpinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    unpinnedMessageIds.add(messageId);
    if (pinFailure != null) {
      throw pinFailure!;
    }
  }

  @override
  Future<void> addReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async {
    return const [];
  }

  @override
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    removedStoredMessageIds.add(messageId);
    final failure = removeStoredFailure;
    if (failure != null) {
      throw failure;
    }
  }
}

class _ControllableSavedMessagesRepository implements SavedMessagesRepository {
  _ControllableSavedMessagesRepository({
    this.saveCompleters = const {},
  });

  final Map<String, Completer<void>> saveCompleters;
  final List<String> savedMessageIds = [];

  @override
  Future<saved_data.SavedMessagesPage> listSavedMessages(
    ServerScopeId serverId, {
    int limit = 50,
    int offset = 0,
  }) async =>
      const saved_data.SavedMessagesPage(items: [], hasMore: false);

  @override
  Future<void> saveMessage(ServerScopeId serverId, String messageId) async {
    savedMessageIds.add(messageId);
    final completer = saveCompleters[messageId];
    if (completer != null) {
      await completer.future;
    }
  }

  @override
  Future<void> unsaveMessage(ServerScopeId serverId, String messageId) async {
    savedMessageIds.remove(messageId);
  }

  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) async =>
      savedMessageIds.toSet().intersection(messageIds.toSet());
}
