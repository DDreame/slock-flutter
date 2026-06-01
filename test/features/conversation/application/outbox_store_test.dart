import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/outbox_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart'
    show conversationRepositoryProvider;
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

Future<AppDatabase?> _tryOpenMemoryDb() async {
  AppDatabase? database;
  try {
    database = AppDatabase(NativeDatabase.memory());
    await database.customSelect('SELECT 1').get();
    return database;
  } catch (_) {
    await database?.close();
    return null;
  }
}

Future<void> _waitForStoredOutboxItem(
  OutboxLocalStore store,
  String targetKey,
) async {
  for (var attempt = 0; attempt < 10; attempt += 1) {
    final stored = await store.loadAll();
    if ((stored[targetKey]?.isNotEmpty ?? false)) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late ProviderContainer container;
  late _FakeConversationRepository repository;
  late StreamController<ConnectivityStatus> connectivityController;
  late ConnectivityService connectivityService;
  late _FakeOutboxLocalStore outboxLocalStore;

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
    outboxLocalStore = _FakeOutboxLocalStore();

    container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(repository),
        connectivityServiceProvider.overrideWithValue(connectivityService),
        sharedPreferencesProvider.overrideWithValue(prefs),
        outboxLocalStoreProvider.overrideWithValue(outboxLocalStore),
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

    test('duplicate content is deduplicated (only one entry)', () {
      final notifier = container.read(outboxStoreProvider.notifier);

      notifier.enqueue(target, 'Same message');
      notifier.enqueue(target, 'Same message');

      final state = container.read(outboxStoreProvider);
      final targetKey = outboxTargetKey(target);
      expect(state.items[targetKey], hasLength(1));
    });

    test('duplicate content with different replyToId is not deduplicated', () {
      final notifier = container.read(outboxStoreProvider.notifier);

      notifier.enqueue(target, 'Same message', replyToId: 'msg-1');
      notifier.enqueue(target, 'Same message', replyToId: 'msg-2');

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

    test('enqueue with custom localId uses it', () {
      final notifier = container.read(outboxStoreProvider.notifier);

      notifier.enqueue(target, 'Custom ID', localId: 'pending-custom-1');

      final state = container.read(outboxStoreProvider);
      final targetKey = outboxTargetKey(target);
      expect(state.items[targetKey]!.first.localId, 'pending-custom-1');
    });

    test('outboxTargetKey includes surface type', () {
      final channelTarget = ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('s1'),
          value: 'general',
        ),
      );
      final dmTarget = ConversationDetailTarget.directMessage(
        const DirectMessageScopeId(
          serverId: ServerScopeId('s1'),
          value: 'dm-123',
        ),
      );

      expect(outboxTargetKey(channelTarget), 'channel/s1/general');
      expect(outboxTargetKey(dmTarget), 'directMessage/s1/dm-123');
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

    test('drain invokes registered callback on success', () async {
      final sentMessage = ConversationMessageSummary(
        id: 'server-1',
        content: 'Queued',
        createdAt: DateTime.parse('2026-05-07T12:00:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      );
      repository.sentMessage = sentMessage;

      final notifier = container.read(outboxStoreProvider.notifier);
      notifier.enqueue(target, 'Queued', localId: 'pending-1');

      ConversationMessageSummary? callbackMessage;
      String? callbackLocalId;
      notifier.registerDrainCallback(
        outboxTargetKey(target),
        (t, localId, msg, failure) {
          callbackLocalId = localId;
          callbackMessage = msg;
        },
      );

      await notifier.drain(target);

      expect(callbackLocalId, 'pending-1');
      expect(callbackMessage?.id, 'server-1');
    });

    test('drain invokes registered callback on non-retryable failure',
        () async {
      repository.sendFailure = const NotFoundFailure(
        message: 'Not found',
      );

      final notifier = container.read(outboxStoreProvider.notifier);
      notifier.enqueue(target, 'Will fail', localId: 'pending-2');

      AppFailure? callbackFailure;
      String? callbackLocalId;
      notifier.registerDrainCallback(
        outboxTargetKey(target),
        (t, localId, msg, failure) {
          callbackLocalId = localId;
          callbackFailure = failure;
        },
      );

      await notifier.drain(target);

      expect(callbackLocalId, 'pending-2');
      expect(callbackFailure, isA<NotFoundFailure>());
    });

    test(
      'drainAll retries automatically after repeated retryable failures (#721)',
      () {
        fakeAsync((async) {
          repository.sendFailure = const NetworkFailure(
            message: 'Server unreachable',
          );

          final notifier = container.read(outboxStoreProvider.notifier);
          notifier.enqueue(target, 'Will retry with backoff');

          notifier.drainAll();
          async.flushMicrotasks();
          // First attempt fails (counter=1), Timer(100ms) scheduled.
          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();
          // Second attempt fails (counter=2), Timer(100ms) scheduled.
          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();
          // Third attempt fails (counter=3), backoff kicks in (30s).

          expect(repository.sentContents.length, 3);
          final targetKey = outboxTargetKey(target);
          expect(container.read(outboxStoreProvider).items[targetKey],
              hasLength(1));

          repository.sendFailure = null;
          async.elapse(const Duration(seconds: 30));
          async.flushMicrotasks();
          // Backoff timer fires → _scheduleDrainIfNeeded() → Timer(100ms).
          async.elapse(const Duration(milliseconds: 100));
          async.flushMicrotasks();

          expect(repository.sentContents.length, 4);
          expect(container.read(outboxStoreProvider).items[targetKey] ?? [],
              isEmpty);
        });
      },
    );

    test('concurrent drainAll calls send each queued message only once',
        () async {
      repository.sendGate = Completer<void>();
      repository.sendStarted = Completer<void>();

      final notifier = container.read(outboxStoreProvider.notifier);
      notifier.enqueue(target, 'Queued once');

      final firstDrain = notifier.drainAll();
      await repository.sendStarted!.future;

      final secondDrain = notifier.drainAll();
      await Future<void>.delayed(Duration.zero);

      expect(repository.sentContents, ['Queued once']);

      repository.sendGate!.complete();
      await Future.wait([firstDrain, secondDrain]);

      expect(repository.sentContents, ['Queued once']);
      final state = container.read(outboxStoreProvider);
      expect(state.items[outboxTargetKey(target)] ?? [], isEmpty);
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
    test('enqueue persists to SQLite local store', () async {
      final notifier = container.read(outboxStoreProvider.notifier);
      notifier.enqueue(target, 'Persisted');
      await Future<void>.delayed(Duration.zero);

      final stored = await container.read(outboxLocalStoreProvider).loadAll();
      final targetKey = outboxTargetKey(target);
      expect(stored[targetKey], hasLength(1));
      expect(stored[targetKey]!.first.content, 'Persisted');
    });

    test('restores queue from SQLite local store after container restart',
        () async {
      final sharedOutboxStore = _FakeOutboxLocalStore();
      final offlineController =
          StreamController<ConnectivityStatus>.broadcast();
      addTearDown(offlineController.close);
      final offlineConnectivity = ConnectivityService.withInitialStatus(
        ConnectivityStatus.offline,
        controller: offlineController,
      );

      final firstContainer = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(offlineConnectivity),
          sharedPreferencesProvider.overrideWithValue(
            container.read(sharedPreferencesProvider),
          ),
          outboxLocalStoreProvider.overrideWithValue(sharedOutboxStore),
        ],
      );
      addTearDown(firstContainer.dispose);
      firstContainer.read(outboxStoreProvider.notifier).enqueue(
            target,
            'Survives restart',
            localId: 'restart-1',
          );
      await Future<void>.delayed(Duration.zero);

      final targetKey = outboxTargetKey(target);
      expect((await sharedOutboxStore.loadAll())[targetKey], hasLength(1));
      firstContainer.dispose();

      final secondContainer = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(offlineConnectivity),
          sharedPreferencesProvider.overrideWithValue(
            container.read(sharedPreferencesProvider),
          ),
          outboxLocalStoreProvider.overrideWithValue(sharedOutboxStore),
        ],
      );
      addTearDown(secondContainer.dispose);
      secondContainer.read(outboxStoreProvider);
      await Future<void>.delayed(Duration.zero);

      final state = secondContainer.read(outboxStoreProvider);
      expect(state.items[targetKey], hasLength(1));
      expect(state.items[targetKey]!.first.content, 'Survives restart');
    });

    test('restores queue from real Drift database after container restart',
        () async {
      final database = await _tryOpenMemoryDb();
      if (database == null) {
        markTestSkipped('sqlite3 native library not available');
        return;
      }
      addTearDown(database.close);
      final offlineController =
          StreamController<ConnectivityStatus>.broadcast();
      addTearDown(offlineController.close);
      final offlineConnectivity = ConnectivityService.withInitialStatus(
        ConnectivityStatus.offline,
        controller: offlineController,
      );
      final prefs = container.read(sharedPreferencesProvider);
      final targetKey = outboxTargetKey(target);

      final firstContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(offlineConnectivity),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(firstContainer.dispose);
      firstContainer.read(outboxStoreProvider.notifier).enqueue(
            target,
            'Survives real database restart',
            localId: 'real-db-restart-1',
          );
      await _waitForStoredOutboxItem(database.outboxLocalDao, targetKey);
      firstContainer.dispose();

      final secondContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(offlineConnectivity),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(secondContainer.dispose);
      secondContainer.read(outboxStoreProvider);
      await Future<void>.delayed(Duration.zero);

      final state = secondContainer.read(outboxStoreProvider);
      expect(state.items[targetKey], hasLength(1));
      expect(
        state.items[targetKey]!.first.content,
        'Survives real database restart',
      );
    });

    test('imports legacy queue from SharedPreferences on build', () async {
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

      final legacyConnectivityController =
          StreamController<ConnectivityStatus>.broadcast();
      addTearDown(legacyConnectivityController.close);
      final legacyConnectivity = ConnectivityService.withInitialStatus(
        ConnectivityStatus.offline,
        controller: legacyConnectivityController,
      );

      // Create a new container to simulate app restart. Keep it offline so the
      // imported queue is not drained before the migration assertion.
      final newContainer = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(legacyConnectivity),
          sharedPreferencesProvider.overrideWithValue(prefs),
          outboxLocalStoreProvider.overrideWithValue(outboxLocalStore),
        ],
      );
      addTearDown(newContainer.dispose);

      final state = newContainer.read(outboxStoreProvider);
      expect(state.items[targetKey], hasLength(1));
      expect(state.items[targetKey]!.first.content, 'Restored message');
      await Future<void>.delayed(Duration.zero);

      final stored =
          await newContainer.read(outboxLocalStoreProvider).loadAll();
      expect(stored[targetKey], hasLength(1));
      expect(prefs.getString('outbox_queue'), isNull);
    });

    test('online legacy import cannot resurrect entries drained on startup',
        () async {
      final targetKey = outboxTargetKey(target);
      final prefs = container.read(sharedPreferencesProvider);
      await prefs.setString(
        'outbox_queue',
        jsonEncode({
          targetKey: [
            {
              'localId': 'legacy-online-1',
              'content': 'Send me during migration',
              'status': 'pending',
              'createdAt': '2026-05-07T12:00:00.000Z',
            },
          ],
        }),
      );
      repository.sentMessage = ConversationMessageSummary(
        id: 'sent-online-1',
        content: 'Send me during migration',
        createdAt: DateTime.parse('2026-05-07T12:00:01Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      );
      repository.sendStarted = Completer<void>();
      final migratingStore = _FakeOutboxLocalStore();
      final legacyImportGate = Completer<void>();
      migratingStore.nextReplaceGate = legacyImportGate;

      final newContainer = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(connectivityService),
          sharedPreferencesProvider.overrideWithValue(prefs),
          outboxLocalStoreProvider.overrideWithValue(migratingStore),
        ],
      );
      addTearDown(newContainer.dispose);

      final initialState = newContainer.read(outboxStoreProvider);
      expect(initialState.items[targetKey], hasLength(1));

      await repository.sendStarted!.future;
      expect(repository.sentContents, ['Send me during migration']);

      legacyImportGate.complete();
      await migratingStore.waitForReplaceCount(2);

      expect(
        newContainer.read(outboxStoreProvider).items[targetKey] ?? [],
        isEmpty,
      );
      expect((await migratingStore.loadAll())[targetKey] ?? [], isEmpty);
      expect(prefs.getString('outbox_queue'), isNull);
    });

    test('legacy persisted DM targets are restored as DM (not channel)',
        () async {
      final dmTarget = ConversationDetailTarget.directMessage(
        const DirectMessageScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'dm-abc',
        ),
      );
      final dmKey = outboxTargetKey(dmTarget);

      final prefs = container.read(sharedPreferencesProvider);
      final queueJson = jsonEncode({
        dmKey: [
          {
            'localId': 'dm-1',
            'content': 'DM message',
            'status': 'pending',
            'createdAt': '2026-05-07T12:00:00.000Z',
          },
        ],
      });
      await prefs.setString('outbox_queue', queueJson);

      final legacyConnectivityController =
          StreamController<ConnectivityStatus>.broadcast();
      addTearDown(legacyConnectivityController.close);
      final legacyConnectivity = ConnectivityService.withInitialStatus(
        ConnectivityStatus.offline,
        controller: legacyConnectivityController,
      );

      // Create a new container to simulate app restart. Keep it offline so the
      // imported queue is not drained before the migration assertion.
      final newContainer = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(legacyConnectivity),
          sharedPreferencesProvider.overrideWithValue(prefs),
          outboxLocalStoreProvider.overrideWithValue(outboxLocalStore),
        ],
      );
      addTearDown(newContainer.dispose);

      final state = newContainer.read(outboxStoreProvider);
      expect(state.items[dmKey], hasLength(1));
      // Verify the key format includes surface
      expect(dmKey, 'directMessage/server-1/dm-abc');
      await Future<void>.delayed(Duration.zero);

      final stored =
          await newContainer.read(outboxLocalStoreProvider).loadAll();
      expect(stored[dmKey], hasLength(1));
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

class _FakeOutboxLocalStore implements OutboxLocalStore {
  Map<String, List<LocalOutboxEntry>> _items = const {};
  Completer<void>? nextReplaceGate;
  int replaceCount = 0;
  final List<Completer<void>> _replaceWaiters = [];

  @override
  Future<Map<String, List<LocalOutboxEntry>>> loadAll() async {
    return _clone(_items);
  }

  Future<void> waitForReplaceCount(int expectedCount) async {
    if (replaceCount >= expectedCount) return;
    final completer = Completer<void>();
    _replaceWaiters.add(completer);
    await completer.future;
  }

  @override
  Future<void> replaceAll(Map<String, List<LocalOutboxEntry>> items) async {
    final gate = nextReplaceGate;
    nextReplaceGate = null;
    if (gate != null) {
      await gate.future;
    }
    _items = _clone(items);
    replaceCount += 1;
    for (final waiter in List<Completer<void>>.of(_replaceWaiters)) {
      if (replaceCount >= 2 && !waiter.isCompleted) {
        waiter.complete();
        _replaceWaiters.remove(waiter);
      }
    }
  }

  @override
  Future<void> clearAll() async {
    _items = const {};
  }

  Map<String, List<LocalOutboxEntry>> _clone(
    Map<String, List<LocalOutboxEntry>> items,
  ) {
    return {
      for (final entry in items.entries) entry.key: List.of(entry.value),
    };
  }
}

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
