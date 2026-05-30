// =============================================================================
// #708 — Outbox reliability fixes
//
// A. P0: Corrupt status deserialization — single corrupt entry degrades
//    gracefully without discarding entire outbox
// B. P1: drainAll re-checks connectivity between targets — stops early if
//    offline mid-drain
// C. P2: Dedup check uses localId as primary key — same localId deduplicates,
//    different localIds with same content both enqueue
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
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

  final target2 = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'random',
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

  group('#708A — P0: Corrupt status deserialization', () {
    // Use an offline connectivity service for deserialization tests to prevent
    // the startup auto-drain (Future.microtask(() => drainAll())) from firing
    // and accessing providers after container disposal.
    late StreamController<ConnectivityStatus> offlineController;
    late ConnectivityService offlineService;

    setUp(() {
      offlineController = StreamController<ConnectivityStatus>.broadcast();
      offlineService = ConnectivityService.withInitialStatus(
        ConnectivityStatus.offline,
        controller: offlineController,
      );
    });

    tearDown(() {
      offlineController.close();
    });

    test('corrupt status string falls back to pending (entry preserved)',
        () async {
      final targetKey = outboxTargetKey(target);
      final prefs = container.read(sharedPreferencesProvider);
      final queueJson = jsonEncode({
        targetKey: [
          {
            'localId': 'msg-1',
            'content': 'Good message',
            'status': 'pending',
            'createdAt': '2026-05-07T12:00:00.000Z',
          },
          {
            'localId': 'msg-2',
            'content': 'Corrupt entry',
            'status': 'INVALID_STATUS_XYZ',
            'createdAt': '2026-05-07T12:01:00.000Z',
          },
          {
            'localId': 'msg-3',
            'content': 'Another good message',
            'status': 'failed',
            'createdAt': '2026-05-07T12:02:00.000Z',
          },
        ],
      });
      await prefs.setString('outbox_queue', queueJson);

      // Create a new container to simulate app restart with corrupt data.
      // Uses offline connectivity to prevent startup auto-drain.
      final newContainer = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(offlineService),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(newContainer.dispose);

      final state = newContainer.read(outboxStoreProvider);
      // All 3 entries preserved — corrupt one falls back to pending.
      expect(state.items[targetKey], hasLength(3),
          reason: 'Corrupt entry must not discard entire outbox');
      expect(state.items[targetKey]![0].status, OutboxMessageStatus.pending);
      expect(state.items[targetKey]![1].status, OutboxMessageStatus.pending,
          reason: 'Corrupt status should fall back to pending');
      expect(state.items[targetKey]![1].content, 'Corrupt entry');
      expect(state.items[targetKey]![2].status, OutboxMessageStatus.failed);
    });

    test('null status string falls back to pending', () async {
      final targetKey = outboxTargetKey(target);
      final prefs = container.read(sharedPreferencesProvider);
      final queueJson = jsonEncode({
        targetKey: [
          {
            'localId': 'msg-1',
            'content': 'No status field',
            'createdAt': '2026-05-07T12:00:00.000Z',
          },
        ],
      });
      await prefs.setString('outbox_queue', queueJson);

      final newContainer = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(offlineService),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(newContainer.dispose);

      final state = newContainer.read(outboxStoreProvider);
      expect(state.items[targetKey], hasLength(1));
      expect(state.items[targetKey]![0].status, OutboxMessageStatus.pending);
    });

    test('multiple corrupt entries in different targets — all preserved',
        () async {
      final targetKey1 = outboxTargetKey(target);
      final targetKey2 = outboxTargetKey(target2);
      final prefs = container.read(sharedPreferencesProvider);
      final queueJson = jsonEncode({
        targetKey1: [
          {
            'localId': 'msg-1',
            'content': 'Target 1 message',
            'status': 'CORRUPT',
            'createdAt': '2026-05-07T12:00:00.000Z',
          },
        ],
        targetKey2: [
          {
            'localId': 'msg-2',
            'content': 'Target 2 message',
            'status': 'pending',
            'createdAt': '2026-05-07T12:01:00.000Z',
          },
        ],
      });
      await prefs.setString('outbox_queue', queueJson);

      final newContainer = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(offlineService),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(newContainer.dispose);

      final state = newContainer.read(outboxStoreProvider);
      expect(state.items[targetKey1], hasLength(1));
      expect(state.items[targetKey1]![0].status, OutboxMessageStatus.pending);
      expect(state.items[targetKey2], hasLength(1));
      expect(state.items[targetKey2]![0].status, OutboxMessageStatus.pending);
    });
  });

  group('#708B — P1: drainAll re-checks connectivity between targets', () {
    test('stops draining remaining targets when connectivity drops mid-drain',
        () async {
      repository.sentMessage = ConversationMessageSummary(
        id: 'server-1',
        content: 'First',
        createdAt: DateTime.parse('2026-05-07T12:00:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      );

      // Use a custom repo that flips connectivity after first target drains.
      final flipRepo = _ConnectivityFlipRepository(
        connectivityService: connectivityService,
        connectivityController: connectivityController,
      );

      final flipContainer = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(flipRepo),
          connectivityServiceProvider.overrideWithValue(connectivityService),
          sharedPreferencesProvider
              .overrideWithValue(container.read(sharedPreferencesProvider)),
        ],
      );
      addTearDown(flipContainer.dispose);

      final notifier = flipContainer.read(outboxStoreProvider.notifier);
      notifier.enqueue(target, 'Target 1 message');
      notifier.enqueue(target2, 'Target 2 message');

      // First target drain succeeds, then connectivity flips offline.
      await notifier.drainAll();

      // Target 1 was drained.
      expect(flipRepo.sentContents, ['Target 1 message']);
      // Target 2 was NOT attempted because connectivity check failed.
      final state = flipContainer.read(outboxStoreProvider);
      final targetKey2 = outboxTargetKey(target2);
      expect(state.items[targetKey2], hasLength(1),
          reason: 'Target 2 should not have been drained (offline)');
    });

    test('_isDraining is cleared after early break for offline', () async {
      // Use a connectivity service that starts offline.
      final offlineController =
          StreamController<ConnectivityStatus>.broadcast();
      final offlineService = ConnectivityService.withInitialStatus(
        ConnectivityStatus.offline,
        controller: offlineController,
      );

      final offlineContainer = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(offlineService),
          sharedPreferencesProvider
              .overrideWithValue(container.read(sharedPreferencesProvider)),
        ],
      );
      addTearDown(() {
        offlineContainer.dispose();
        offlineController.close();
      });

      final notifier = offlineContainer.read(outboxStoreProvider.notifier);
      notifier.enqueue(target, 'Offline message');

      // drainAll should break early since offline.
      await notifier.drainAll();

      // Verify _isDraining is cleared — subsequent drainAll should not no-op.
      // Go online and drain again.
      repository.sentMessage = ConversationMessageSummary(
        id: 'server-1',
        content: 'Offline message',
        createdAt: DateTime.parse('2026-05-07T12:00:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      );
      offlineController.add(ConnectivityStatus.online);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // The connectivity listener should have triggered drainAll again.
      expect(repository.sentContents, ['Offline message']);
    });
  });

  group('#708C — P2: Dedup check uses localId as primary key', () {
    test('same content + different localIds → both enqueued', () {
      final notifier = container.read(outboxStoreProvider.notifier);

      notifier.enqueue(target, 'Same content', localId: 'local-1');
      notifier.enqueue(target, 'Same content', localId: 'local-2');

      final state = container.read(outboxStoreProvider);
      final targetKey = outboxTargetKey(target);
      expect(state.items[targetKey], hasLength(2),
          reason: 'Different localIds should not be deduped by content');
      expect(state.items[targetKey]![0].localId, 'local-1');
      expect(state.items[targetKey]![1].localId, 'local-2');
    });

    test('same localId → deduplicated (second enqueue is no-op)', () {
      final notifier = container.read(outboxStoreProvider.notifier);

      notifier.enqueue(target, 'First content', localId: 'local-same');
      notifier.enqueue(target, 'Different content', localId: 'local-same');

      final state = container.read(outboxStoreProvider);
      final targetKey = outboxTargetKey(target);
      expect(state.items[targetKey], hasLength(1),
          reason: 'Same localId must be deduplicated');
      expect(state.items[targetKey]![0].content, 'First content');
    });

    test('no localId provided → content dedup still works', () {
      final notifier = container.read(outboxStoreProvider.notifier);

      notifier.enqueue(target, 'Same message');
      notifier.enqueue(target, 'Same message');

      final state = container.read(outboxStoreProvider);
      final targetKey = outboxTargetKey(target);
      expect(state.items[targetKey], hasLength(1),
          reason: 'Content dedup should still work when no localId provided');
    });

    test('null replyToId vs absent replyToId do not false-dedup', () {
      final notifier = container.read(outboxStoreProvider.notifier);

      // First message with replyToId = null (default), different localId.
      notifier.enqueue(target, 'Reply msg', localId: 'local-a');
      // Second message with same content but a reply (different localId).
      notifier.enqueue(target, 'Reply msg',
          localId: 'local-b', replyToId: 'msg-99');

      final state = container.read(outboxStoreProvider);
      final targetKey = outboxTargetKey(target);
      expect(state.items[targetKey], hasLength(2),
          reason: 'Different localIds with different replyToId both enqueue');
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeConversationRepository implements ConversationRepository {
  ConversationMessageSummary? sentMessage;
  AppFailure? sendFailure;
  Completer<void>? sendGate;
  Completer<void>? sendStarted;
  final List<String> sentContents = [];

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    bool? asTask,
    CancelToken? cancelToken,
  }) async {
    sentContents.add(content);
    if (!(sendStarted?.isCompleted ?? true)) {
      sendStarted!.complete();
    }
    if (sendGate != null) {
      await sendGate!.future;
    }
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

/// Repository that flips connectivity to offline after the first successful
/// send, simulating a network drop mid-drain.
class _ConnectivityFlipRepository implements ConversationRepository {
  _ConnectivityFlipRepository({
    required this.connectivityService,
    required this.connectivityController,
  });

  final ConnectivityService connectivityService;
  final StreamController<ConnectivityStatus> connectivityController;
  final List<String> sentContents = [];
  int _sendCount = 0;

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    bool? asTask,
    CancelToken? cancelToken,
  }) async {
    _sendCount++;
    sentContents.add(content);

    // After first send, flip connectivity to offline.
    if (_sendCount == 1) {
      connectivityController.add(ConnectivityStatus.offline);
      // Allow the stream event to propagate.
      await Future<void>.delayed(Duration.zero);
    }

    return ConversationMessageSummary(
      id: 'msg-$_sendCount',
      content: content,
      createdAt: DateTime.now(),
      senderType: 'human',
      messageType: 'message',
      seq: _sendCount,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
