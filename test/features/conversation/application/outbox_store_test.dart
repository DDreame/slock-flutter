import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/outbox_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart'
    show conversationRepositoryProvider;
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

void main() {
  late ProviderContainer container;
  late _FakeConversationRepository repository;
  late StreamController<ConnectivityStatus> connectivityController;
  late ConnectivityService connectivityService;

  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    ),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repository = _FakeConversationRepository();
    connectivityController = StreamController<ConnectivityStatus>.broadcast();
    connectivityService = ConnectivityService.withInitialStatus(
      ConnectivityStatus.online,
      controller: connectivityController,
    );

    container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(repository),
        connectivityServiceProvider.overrideWithValue(connectivityService),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() async {
    await Future<void>.delayed(Duration.zero);
    container.dispose();
    await connectivityController.close();
  });

  group('OutboxStore enqueue', () {
    test('enqueue adds pending message with sending status', () {
      final notifier = container.read(outboxStoreProvider.notifier);

      notifier.enqueue(target, 'Hello offline');

      final state = container.read(outboxStoreProvider);
      final targetKey = outboxTargetKey(target);
      expect(state.items[targetKey], hasLength(1));
      expect(state.items[targetKey]!.first.content, 'Hello offline');
      expect(
        state.items[targetKey]!.first.status,
        OutboxMessageStatus.pending,
      );
    });

    test('enqueue assigns unique local IDs', () {
      final notifier = container.read(outboxStoreProvider.notifier);

      notifier.enqueue(target, 'First');
      notifier.enqueue(target, 'Second');

      final state = container.read(outboxStoreProvider);
      final targetKey = outboxTargetKey(target);
      final ids = state.items[targetKey]!.map((m) => m.localId).toList();
      expect(ids[0], isNot(ids[1]));
    });

    test('duplicate content can be enqueued (not deduplicated)', () {
      final notifier = container.read(outboxStoreProvider.notifier);

      notifier.enqueue(target, 'Same message');
      notifier.enqueue(target, 'Same message');

      final state = container.read(outboxStoreProvider);
      final targetKey = outboxTargetKey(target);
      expect(state.items[targetKey], hasLength(2));
    });

    test('enqueue with replyToId stores it', () {
      final notifier = container.read(outboxStoreProvider.notifier);

      notifier.enqueue(target, 'Reply', replyToId: 'msg-123');

      final state = container.read(outboxStoreProvider);
      final targetKey = outboxTargetKey(target);
      expect(state.items[targetKey]!.first.replyToId, 'msg-123');
    });
  });

  group('OutboxStore drain', () {
    test('drain sends pending messages via repository in FIFO order', () async {
      final sentMessage = ConversationMessageSummary(
        id: 'server-1',
        content: 'First',
        createdAt: DateTime.parse('2026-05-07T12:00:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      );
      repository.sentMessage = sentMessage;

      final notifier = container.read(outboxStoreProvider.notifier);
      notifier.enqueue(target, 'First');
      notifier.enqueue(target, 'Second');

      await notifier.drain(target);

      expect(repository.sentContents, ['First', 'Second']);
    });

    test('drain removes successfully sent messages', () async {
      repository.sentMessage = ConversationMessageSummary(
        id: 'server-1',
        content: 'Hello',
        createdAt: DateTime.parse('2026-05-07T12:00:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      );

      final notifier = container.read(outboxStoreProvider.notifier);
      notifier.enqueue(target, 'Hello');

      await notifier.drain(target);

      final state = container.read(outboxStoreProvider);
      final targetKey = outboxTargetKey(target);
      expect(state.items[targetKey] ?? [], isEmpty);
    });

    test('non-retryable failure marks item as failed', () async {
      repository.sendFailure = const NotFoundFailure(
        message: 'Conversation not found',
      );

      final notifier = container.read(outboxStoreProvider.notifier);
      notifier.enqueue(target, 'Will fail');

      await notifier.drain(target);

      final state = container.read(outboxStoreProvider);
      final targetKey = outboxTargetKey(target);
      expect(state.items[targetKey], hasLength(1));
      expect(
        state.items[targetKey]!.first.status,
        OutboxMessageStatus.failed,
      );
    });

    test('retryable failure keeps item pending for retry', () async {
      repository.sendFailure = const NetworkFailure(
        message: 'No connection',
      );

      final notifier = container.read(outboxStoreProvider.notifier);
      notifier.enqueue(target, 'Will retry');

      await notifier.drain(target);

      final state = container.read(outboxStoreProvider);
      final targetKey = outboxTargetKey(target);
      expect(state.items[targetKey], hasLength(1));
      expect(
        state.items[targetKey]!.first.status,
        OutboxMessageStatus.pending,
      );
    });

    test('drain stops on retryable failure', () async {
      repository.sendFailure = const NetworkFailure(
        message: 'No connection',
      );

      final notifier = container.read(outboxStoreProvider.notifier);
      notifier.enqueue(target, 'First');
      notifier.enqueue(target, 'Second');

      await notifier.drain(target);

      // Only first message attempted — drain stops on network failure
      expect(repository.sentContents, ['First']);
    });
  });

  group('OutboxStore connectivity', () {
    test('drain triggers on offline→online transition', () async {
      repository.sentMessage = ConversationMessageSummary(
        id: 'server-1',
        content: 'Queued',
        createdAt: DateTime.parse('2026-05-07T12:00:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      );

      final notifier = container.read(outboxStoreProvider.notifier);
      notifier.enqueue(target, 'Queued');

      // Simulate offline→online transition
      connectivityController.add(ConnectivityStatus.offline);
      await Future<void>.delayed(Duration.zero);
      connectivityController.add(ConnectivityStatus.online);
      await Future<void>.delayed(Duration.zero);
      // Allow drain future to complete
      await Future<void>.delayed(Duration.zero);

      expect(repository.sentContents, ['Queued']);
    });
  });

  group('OutboxStore persistence', () {
    test('enqueue persists to SharedPreferences', () async {
      final notifier = container.read(outboxStoreProvider.notifier);
      notifier.enqueue(target, 'Persisted');

      final prefs = container.read(sharedPreferencesProvider);
      final raw = prefs.getString('outbox_queue');
      expect(raw, isNotNull);

      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      expect(decoded.values.first, isA<List>());
    });

    test('restores queue from SharedPreferences on build', () async {
      final targetKey = outboxTargetKey(target);
      final prefs = container.read(sharedPreferencesProvider);
      final queueJson = jsonEncode({
        targetKey: [
          {
            'localId': 'restored-1',
            'content': 'Restored message',
            'status': 'pending',
            'createdAt': '2026-05-07T12:00:00.000Z',
          },
        ],
      });
      await prefs.setString('outbox_queue', queueJson);

      // Create a new container to simulate app restart
      final newContainer = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(connectivityService),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(newContainer.dispose);

      final state = newContainer.read(outboxStoreProvider);
      expect(state.items[targetKey], hasLength(1));
      expect(state.items[targetKey]!.first.content, 'Restored message');
    });
  });

  group('OutboxStore remove', () {
    test('removeItem removes a specific failed message', () {
      final notifier = container.read(outboxStoreProvider.notifier);
      notifier.enqueue(target, 'Remove me');

      final state = container.read(outboxStoreProvider);
      final targetKey = outboxTargetKey(target);
      final localId = state.items[targetKey]!.first.localId;

      notifier.removeItem(target, localId);

      final updated = container.read(outboxStoreProvider);
      expect(updated.items[targetKey] ?? [], isEmpty);
    });
  });
}

class _FakeConversationRepository implements ConversationRepository {
  ConversationMessageSummary? sentMessage;
  AppFailure? sendFailure;
  final List<String> sentContents = [];

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
  }) async {
    sentContents.add(content);
    if (sendFailure != null) throw sendFailure!;
    return sentMessage ??
        ConversationMessageSummary(
          id: 'msg-${sentContents.length}',
          content: content,
          createdAt: DateTime.now(),
          senderType: 'human',
          messageType: 'message',
          seq: sentContents.length,
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
