import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';

// ---------------------------------------------------------------------------
// Phase A: ConversationStore SWR invariant tests (#483)
//
// Tests for INV-CACHE-SWR-1, INV-CACHE-SWR-2, INV-NET-DEGRADE-1 applied
// to ConversationDetailStore.
//
// Tests that pass on current implementation are active.
// Tests that require Phase B changes use skip+TODO.
// ---------------------------------------------------------------------------

void main() {
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    ),
  );

  final baselineMessages = [
    ConversationMessageSummary(
      id: 'msg-1',
      content: 'Hello world',
      createdAt: DateTime.utc(2026, 5, 10, 8),
      senderType: 'human',
      messageType: 'message',
      seq: 1,
    ),
    ConversationMessageSummary(
      id: 'msg-2',
      content: 'How are you?',
      createdAt: DateTime.utc(2026, 5, 10, 9),
      senderType: 'human',
      messageType: 'message',
      seq: 2,
    ),
  ];

  final baselineSnapshot = ConversationDetailSnapshot(
    target: target,
    title: '#general',
    messages: baselineMessages,
    historyLimited: false,
    hasOlder: false,
  );

  ProviderContainer createContainer(_ControllableConversationRepository repo) {
    return ProviderContainer(
      overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(repo),
      ],
    );
  }

  group('INV-CACHE-SWR-1: refresh keeps stale data visible', () {
    test('messages remain visible during background refresh', () async {
      final repo = _ControllableConversationRepository();
      repo.completeNextLoadWith(baselineSnapshot);
      final container = createContainer(repo);
      addTearDown(container.dispose);

      // Initial load.
      await container.read(conversationDetailStoreProvider.notifier).load();
      var state = container.read(conversationDetailStoreProvider);
      expect(state.status, ConversationDetailStatus.success);
      expect(state.messages, hasLength(2));

      // Start refresh with a delayed response.
      final refreshCompleter = Completer<ConversationDetailSnapshot>();
      repo.nextLoadCompleter = refreshCompleter;

      final refreshFuture =
          container.read(conversationDetailStoreProvider.notifier).refresh();

      // Mid-flight: stale data must remain visible.
      state = container.read(conversationDetailStoreProvider);
      expect(state.messages, hasLength(2),
          reason: 'INV-CACHE-SWR-1: stale messages must remain visible '
              'during refresh');
      expect(state.isRefreshing, isTrue,
          reason: 'isRefreshing flag signals background work');
      expect(state.status, ConversationDetailStatus.success,
          reason: 'status stays success during SWR refresh');

      // Complete the refresh.
      refreshCompleter.complete(baselineSnapshot);
      await refreshFuture;

      state = container.read(conversationDetailStoreProvider);
      expect(state.isRefreshing, isFalse);
      expect(state.messages, hasLength(2));
    });

    test('refresh replaces stale data with fresh data on completion', () async {
      final repo = _ControllableConversationRepository();
      repo.completeNextLoadWith(baselineSnapshot);
      final container = createContainer(repo);
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();

      // Prepare updated snapshot with a new message.
      final updatedSnapshot = ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ...baselineMessages,
          ConversationMessageSummary(
            id: 'msg-3',
            content: 'New message!',
            createdAt: DateTime.utc(2026, 5, 10, 10),
            senderType: 'human',
            messageType: 'message',
            seq: 3,
          ),
        ],
        historyLimited: false,
        hasOlder: false,
      );
      repo.completeNextLoadWith(updatedSnapshot);

      await container.read(conversationDetailStoreProvider.notifier).refresh();

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages, hasLength(3),
          reason: 'Fresh data replaces stale after refresh completes');
      expect(state.messages.last.content, 'New message!');
    });
  });

  group('INV-CACHE-SWR-2: no clear-then-load on loaded store', () {
    test(
      'load() on already-loaded store preserves messages during fetch',
      () async {
        final repo = _ControllableConversationRepository();
        repo.completeNextLoadWith(baselineSnapshot);
        final container = createContainer(repo);
        addTearDown(container.dispose);

        // Initial load succeeds.
        await container.read(conversationDetailStoreProvider.notifier).load();
        expect(
          container.read(conversationDetailStoreProvider).messages,
          hasLength(2),
        );

        // Second load with delayed response.
        final secondCompleter = Completer<ConversationDetailSnapshot>();
        repo.nextLoadCompleter = secondCompleter;

        final loadFuture =
            container.read(conversationDetailStoreProvider.notifier).load();

        // Mid-flight: messages must NOT be cleared.
        final midState = container.read(conversationDetailStoreProvider);
        expect(midState.messages, hasLength(2),
            reason: 'INV-CACHE-SWR-2: load() must not clear items when '
                'stale data exists');

        secondCompleter.complete(baselineSnapshot);
        await loadFuture;
      },
      skip: 'TODO: ConversationDetailStore.load() unconditionally clears '
          'messages to [] before fetching (line 180-190). Phase B must '
          'change load() to preserve stale data when status == success, '
          'using isRefreshing instead of full clear.',
    );

    test(
      'retry() from error with prior data preserves stale messages',
      () async {
        final repo = _ControllableConversationRepository();
        repo.completeNextLoadWith(baselineSnapshot);
        final container = createContainer(repo);
        addTearDown(container.dispose);

        // Initial load succeeds.
        await container.read(conversationDetailStoreProvider.notifier).load();
        expect(
          container.read(conversationDetailStoreProvider).messages,
          hasLength(2),
        );

        // Second load fails.
        repo.nextLoadFailure = const UnknownFailure(message: 'Network error');

        await container.read(conversationDetailStoreProvider.notifier).load();
        // Error state — messages cleared by current impl (will be fixed in Phase B).
        container.read(conversationDetailStoreProvider);

        // Retry should preserve stale messages, not clear them.
        repo.nextLoadFailure = null;
        repo.completeNextLoadWith(baselineSnapshot);

        await container.read(conversationDetailStoreProvider.notifier).retry();

        final retryState = container.read(conversationDetailStoreProvider);
        expect(retryState.messages, hasLength(2),
            reason: 'INV-CACHE-SWR-2: retry() must not clear stale data');
      },
      skip: 'TODO: retry() delegates to load() which clears messages to [] '
          'before fetching. Phase B must make retry() use refresh() when '
          'stale data is available, or make load() SWR-aware.',
    );
  });

  group('INV-NET-DEGRADE-1: network error overlays on existing data', () {
    test('refresh failure preserves stale messages and sets failure', () async {
      final repo = _ControllableConversationRepository();
      repo.completeNextLoadWith(baselineSnapshot);
      final container = createContainer(repo);
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();
      expect(
        container.read(conversationDetailStoreProvider).messages,
        hasLength(2),
      );

      // Refresh fails.
      repo.nextLoadFailure = const UnknownFailure(message: 'Network error');

      await container.read(conversationDetailStoreProvider.notifier).refresh();

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages, hasLength(2),
          reason: 'INV-NET-DEGRADE-1: stale messages must survive '
              'refresh failure');
      expect(state.failure, isNotNull,
          reason: 'Failure must be surfaced for UI error overlay');
      expect(state.isRefreshing, isFalse);
      expect(state.status, ConversationDetailStatus.success,
          reason: 'Status stays success — data is still valid');
    });

    test('multiple consecutive refresh failures preserve stale data', () async {
      final repo = _ControllableConversationRepository();
      repo.completeNextLoadWith(baselineSnapshot);
      final container = createContainer(repo);
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();

      // Fail twice.
      repo.nextLoadFailure = const UnknownFailure(message: 'Network error');

      await container.read(conversationDetailStoreProvider.notifier).refresh();
      await container.read(conversationDetailStoreProvider.notifier).refresh();

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages, hasLength(2),
          reason: 'Stale data survives multiple refresh failures');
      expect(state.failure, isNotNull);
    });

    test('successful refresh after failure clears failure and updates data',
        () async {
      final repo = _ControllableConversationRepository();
      repo.completeNextLoadWith(baselineSnapshot);
      final container = createContainer(repo);
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();

      // Refresh fails.
      repo.nextLoadFailure = const UnknownFailure(message: 'Network error');
      await container.read(conversationDetailStoreProvider.notifier).refresh();

      expect(
        container.read(conversationDetailStoreProvider).failure,
        isNotNull,
      );

      // Refresh succeeds.
      repo.nextLoadFailure = null;
      final updatedSnapshot = ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ...baselineMessages,
          ConversationMessageSummary(
            id: 'msg-3',
            content: 'Recovery!',
            createdAt: DateTime.utc(2026, 5, 10, 10),
            senderType: 'human',
            messageType: 'message',
            seq: 3,
          ),
        ],
        historyLimited: false,
        hasOlder: false,
      );
      repo.completeNextLoadWith(updatedSnapshot);

      await container.read(conversationDetailStoreProvider.notifier).refresh();

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages, hasLength(3));
      expect(state.failure, isNull,
          reason: 'Successful refresh clears prior failure');
    });
  });

  group('State distinguishes initialLoading vs refreshing', () {
    test('initial load uses loading status with empty messages', () async {
      final repo = _ControllableConversationRepository();
      final loadCompleter = Completer<ConversationDetailSnapshot>();
      repo.nextLoadCompleter = loadCompleter;
      final container = createContainer(repo);
      addTearDown(container.dispose);

      final loadFuture =
          container.read(conversationDetailStoreProvider.notifier).load();

      final state = container.read(conversationDetailStoreProvider);
      expect(state.status, ConversationDetailStatus.loading,
          reason: 'Initial load uses loading status');
      expect(state.messages, isEmpty,
          reason: 'No data yet during initial load');
      expect(state.isRefreshing, isFalse,
          reason: 'isRefreshing is false during initial load');

      loadCompleter.complete(baselineSnapshot);
      await loadFuture;
    });

    test('refresh uses isRefreshing flag with success status', () async {
      final repo = _ControllableConversationRepository();
      repo.completeNextLoadWith(baselineSnapshot);
      final container = createContainer(repo);
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();

      // Start refresh.
      final refreshCompleter = Completer<ConversationDetailSnapshot>();
      repo.nextLoadCompleter = refreshCompleter;

      final refreshFuture =
          container.read(conversationDetailStoreProvider.notifier).refresh();

      final state = container.read(conversationDetailStoreProvider);
      expect(state.status, ConversationDetailStatus.success,
          reason: 'Refresh keeps success status (not loading)');
      expect(state.isRefreshing, isTrue,
          reason: 'isRefreshing signals background work');
      expect(state.messages, hasLength(2),
          reason: 'Stale data visible during refresh');

      refreshCompleter.complete(baselineSnapshot);
      await refreshFuture;
    });
  });

  // ---------------------------------------------------------------------------
  // #860: SQLite seed — instant display from local store
  // ---------------------------------------------------------------------------
  group('#860 — SQLite seed instant display', () {
    test(
      'load() with local messages shows them instantly (status=success, isRefreshing=true)',
      () async {
        final repo = _ControllableConversationRepository();
        // Configure local messages to return immediately.
        repo.localMessages = baselineMessages;
        // Network response is delayed via completer.
        final networkCompleter = Completer<ConversationDetailSnapshot>();
        repo.nextLoadCompleter = networkCompleter;

        final container = createContainer(repo);
        addTearDown(container.dispose);
        container.listen(conversationDetailStoreProvider, (_, __) {});

        // Start load — should seed from local messages immediately.
        final loadFuture =
            container.read(conversationDetailStoreProvider.notifier).load();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // State should show local messages with isRefreshing = true.
        var state = container.read(conversationDetailStoreProvider);
        expect(state.status, ConversationDetailStatus.success,
            reason: '#860: Local messages must put store in success state');
        expect(state.messages, hasLength(2),
            reason: '#860: Local messages displayed immediately');
        expect(state.isRefreshing, isTrue,
            reason: '#860: isRefreshing=true signals network fetch in flight');
        expect(state.messages.first.content, 'Hello world');

        // Complete network fetch.
        networkCompleter.complete(baselineSnapshot);
        await loadFuture;

        state = container.read(conversationDetailStoreProvider);
        expect(state.isRefreshing, isFalse,
            reason: 'After network completes, isRefreshing clears');
        expect(state.messages, hasLength(2));
      },
    );

    test(
      'load() without local messages shows loading state until network responds',
      () async {
        final repo = _ControllableConversationRepository();
        // No local messages (null).
        repo.localMessages = null;
        final networkCompleter = Completer<ConversationDetailSnapshot>();
        repo.nextLoadCompleter = networkCompleter;

        final container = createContainer(repo);
        addTearDown(container.dispose);
        container.listen(conversationDetailStoreProvider, (_, __) {});

        final loadFuture =
            container.read(conversationDetailStoreProvider.notifier).load();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Without local messages, must still be in loading state.
        var state = container.read(conversationDetailStoreProvider);
        expect(state.status, ConversationDetailStatus.loading,
            reason: '#860: Without local messages, state stays loading');

        networkCompleter.complete(baselineSnapshot);
        await loadFuture;

        state = container.read(conversationDetailStoreProvider);
        expect(state.status, ConversationDetailStatus.success);
        expect(state.messages, hasLength(2));
      },
    );

    test(
      'load() with local messages still updates to network data on completion',
      () async {
        final repo = _ControllableConversationRepository();
        repo.localMessages = baselineMessages;

        // Network returns additional message.
        final updatedSnapshot = ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ...baselineMessages,
            ConversationMessageSummary(
              id: 'msg-3',
              content: 'Fresh from network!',
              createdAt: DateTime.utc(2026, 5, 10, 10),
              senderType: 'human',
              messageType: 'message',
              seq: 3,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        );
        repo.completeNextLoadWith(updatedSnapshot);

        final container = createContainer(repo);
        addTearDown(container.dispose);

        await container.read(conversationDetailStoreProvider.notifier).load();

        final state = container.read(conversationDetailStoreProvider);
        expect(state.messages, hasLength(3),
            reason: '#860: Network data replaces local seed on completion');
        expect(state.messages.last.content, 'Fresh from network!');
        expect(state.isRefreshing, isFalse);
      },
    );

    test(
      'load() local messages failure is non-fatal (falls through to network)',
      () async {
        final repo = _ControllableConversationRepository();
        // Simulate SQLite crash.
        repo.localMessagesError = true;
        repo.completeNextLoadWith(baselineSnapshot);

        final container = createContainer(repo);
        addTearDown(container.dispose);

        await container.read(conversationDetailStoreProvider.notifier).load();

        final state = container.read(conversationDetailStoreProvider);
        expect(state.status, ConversationDetailStatus.success,
            reason: '#860: SQLite failure is non-fatal, network still works');
        expect(state.messages, hasLength(2));
      },
    );

    test(
      'load() with local seed preserves messages on network failure (SWR)',
      () async {
        final repo = _ControllableConversationRepository();
        // Configure local messages to seed successfully.
        repo.localMessages = baselineMessages;
        // Network will throw.
        repo.nextLoadFailure = const NetworkFailure(
          message: 'Network timeout',
        );

        final container = createContainer(repo);
        addTearDown(container.dispose);
        container.listen(conversationDetailStoreProvider, (_, __) {});

        await container.read(conversationDetailStoreProvider.notifier).load();

        final state = container.read(conversationDetailStoreProvider);
        // SWR contract: seeded messages must survive network failure.
        expect(state.status, ConversationDetailStatus.success,
            reason: '#860: Local-seeded messages must persist on network '
                'failure. Removing the messages.isNotEmpty guard → messages '
                'cleared to [] → RED.');
        expect(state.messages, hasLength(2),
            reason: '#860: Messages must not be cleared on network failure');
        expect(state.messages.first.content, 'Hello world');
        expect(state.isRefreshing, isFalse);
        expect(state.failure, isNotNull,
            reason: '#860: Failure must be overlaid so UI can show soft error');
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Local fake: Completer-based controllable ConversationRepository
//
// Justification: Phase A SWR tests need Completer-based timing control
// to observe mid-flight state (messages visible while refresh in progress).
// No shared fake exists for ConversationRepository.
// ---------------------------------------------------------------------------

class _ControllableConversationRepository implements ConversationRepository {
  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async {
    if (localMessagesError) throw Exception('SQLite read failure');
    return localMessages;
  }

  List<ConversationMessageSummary>? localMessages;
  bool localMessagesError = false;
  Completer<ConversationDetailSnapshot>? nextLoadCompleter;
  ConversationDetailSnapshot? _nextSnapshot;
  AppFailure? nextLoadFailure;

  void completeNextLoadWith(ConversationDetailSnapshot snapshot) {
    nextLoadCompleter = null;
    _nextSnapshot = snapshot;
  }

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    if (nextLoadCompleter != null) {
      return nextLoadCompleter!.future;
    }
    if (nextLoadFailure != null) {
      final failure = nextLoadFailure!;
      throw failure;
    }
    return _nextSnapshot!;
  }

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
      );

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
    dynamic cancelToken,
  }) async =>
      throw UnimplementedError();

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    dynamic attachment, {
    void Function(int sent, int total)? onSendProgress,
    dynamic cancelToken,
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
  ) async =>
      const [];

  @override
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}
}
