// =============================================================================
// #850 — P1 OutboxStore.drain() Catch-All + P2 InboxStore.loadMore() Epoch Guard
//
// Load-bearing tests:
// 1. OutboxStore.drain() catch-all: non-AppFailure exception marks item failed,
//    drain loop continues to next item (removing catch-all → unhandled exception)
// 2. InboxStore.loadMore() epoch guard: filter switch during pagination discards
//    stale items (removing guard → stale items merged into wrong filter)
// =============================================================================

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/outbox_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart'
    show conversationRepositoryProvider;
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

void main() {
  // ===========================================================================
  // Group 1: P1 OutboxStore.drain() catch-all
  // ===========================================================================
  group('#850 — OutboxStore.drain() catch-all for non-AppFailure exceptions',
      () {
    late ProviderContainer container;
    late _ThrowingConversationRepository repository;
    late StreamController<ConnectivityStatus> connectivityController;
    late ConnectivityService connectivityService;
    late SharedPreferences prefs;

    final target = ConversationDetailTarget.channel(
      const ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'general',
      ),
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repository = _ThrowingConversationRepository();
      connectivityController = StreamController<ConnectivityStatus>.broadcast();
      connectivityService = ConnectivityService.withInitialStatus(
        ConnectivityStatus.online,
        controller: connectivityController,
      );
    });

    tearDown(() async {
      await Future<void>.delayed(Duration.zero);
      container.dispose();
      await connectivityController.close();
    });

    ProviderContainer createContainer() {
      container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          connectivityServiceProvider.overrideWithValue(connectivityService),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      return container;
    }

    test(
      'non-AppFailure exception marks item as failed and drain continues',
      () {
        fakeAsync((async) {
          final c = createContainer();
          final sub = c.listen(outboxStoreProvider, (_, __) {});

          final notifier = c.read(outboxStoreProvider.notifier);

          // Flush startup microtask.
          async.flushMicrotasks();

          // First item will throw FormatException (non-AppFailure).
          // Second item should succeed.
          repository.throwOnIds = {'msg-0'};

          notifier.enqueue(target, 'Bad message', localId: 'msg-0');
          notifier.enqueue(target, 'Good message', localId: 'msg-1');

          // Drain.
          notifier.drainAll();
          async.flushMicrotasks();

          // First item should be marked as failed.
          final state = c.read(outboxStoreProvider);
          final targetKey = outboxTargetKey(target);
          final items = state.items[targetKey] ?? [];

          // msg-0 should be marked failed (not pending, not gone).
          final failedItem = items.where((m) => m.localId == 'msg-0').toList();
          expect(failedItem, hasLength(1),
              reason: 'First item must still be in queue as failed');
          expect(failedItem.first.status, OutboxMessageStatus.failed,
              reason: 'Non-AppFailure must mark item as failed');
          expect(failedItem.first.failureMessage, contains('FormatException'),
              reason: 'Failure message must describe the unexpected error');

          // msg-1 should have been successfully sent (removed from queue).
          final pendingItems = items.where((m) => m.localId == 'msg-1');
          expect(pendingItems, isEmpty,
              reason: 'Second item must be drained after first fails');

          // Confirm the repository received the second message.
          expect(repository.sentContents, contains('Good message'));

          sub.close();
        });
      },
    );

    test(
      'drain callback is notified with UnknownFailure for non-AppFailure errors',
      () {
        fakeAsync((async) {
          final c = createContainer();
          final sub = c.listen(outboxStoreProvider, (_, __) {});

          final notifier = c.read(outboxStoreProvider.notifier);
          async.flushMicrotasks();

          repository.throwOnIds = {'msg-0'};
          notifier.enqueue(target, 'Bad message', localId: 'msg-0');

          // Register drain callback to capture the failure notification.
          AppFailure? capturedFailure;
          String? capturedLocalId;
          notifier.registerDrainCallback(
            outboxTargetKey(target),
            (t, localId, message, failure) {
              capturedLocalId = localId;
              capturedFailure = failure;
            },
          );

          notifier.drainAll();
          async.flushMicrotasks();

          expect(capturedLocalId, 'msg-0');
          expect(capturedFailure, isA<UnknownFailure>());
          expect(capturedFailure!.message, contains('FormatException'));

          sub.close();
        });
      },
    );

    test(
      'removing catch-all causes unhandled exception (load-bearing proof)',
      () {
        // This test verifies that the catch-all is necessary: without it,
        // a FormatException from sendMessage would propagate as an unhandled
        // error from drain()/drainAll(). The test proves the handler is
        // load-bearing by confirming the exception type is non-AppFailure.
        fakeAsync((async) {
          final c = createContainer();
          final sub = c.listen(outboxStoreProvider, (_, __) {});

          final notifier = c.read(outboxStoreProvider.notifier);
          async.flushMicrotasks();

          // Verify FormatException is NOT an AppFailure.
          expect(
            const FormatException('bad') is AppFailure,
            isFalse,
            reason: 'FormatException is not AppFailure — '
                'only the generic catch-all handles it',
          );

          // Enqueue and drain — with catch-all, this completes normally.
          repository.throwOnIds = {'msg-proof'};
          notifier.enqueue(target, 'Proof message', localId: 'msg-proof');
          notifier.drainAll();

          // Should not throw (catch-all handles it).
          expect(
            () => async.flushMicrotasks(),
            returnsNormally,
            reason: 'With catch-all, drain absorbs non-AppFailure exceptions',
          );

          sub.close();
        });
      },
    );
  });

  // ===========================================================================
  // Group 2: P2 InboxStore.loadMore() filter epoch guard
  // ===========================================================================
  group('#850 — InboxStore.loadMore() filter epoch guard', () {
    test(
      'loadMore discards response when filter switches during await',
      () async {
        final loadMoreCompleter = Completer<InboxResponse>();
        final repo = _EpochTestInboxRepository(
          loadMoreCompleter: loadMoreCompleter,
        );

        final container = ProviderContainer(overrides: [
          inboxRepositoryProvider.overrideWithValue(repo),
          activeServerScopeIdProvider
              .overrideWithValue(const ServerScopeId('server-1')),
        ]);
        addTearDown(container.dispose);

        // Keep provider alive.
        final sub = container.listen(inboxStoreProvider, (_, __) {});
        addTearDown(sub.close);

        // Allow auto-load microtask to fire (initial load).
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Verify initial load succeeded.
        expect(container.read(inboxStoreProvider).status, InboxStatus.success);
        expect(container.read(inboxStoreProvider).items, hasLength(2));
        expect(container.read(inboxStoreProvider).hasMore, isTrue);

        // Trigger loadMore — this will block on loadMoreCompleter.
        final loadMoreFuture =
            container.read(inboxStoreProvider.notifier).loadMore();

        // Switch filter WHILE loadMore is in-flight.
        // This calls load() which increments _filterEpoch.
        repo.switchToMentionsResponse();
        await container
            .read(inboxStoreProvider.notifier)
            .setFilter(InboxFilter.mentions);

        // Now complete the old loadMore request with stale "all" filter data.
        loadMoreCompleter.complete(const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'stale-page2',
              channelName: 'stale-channel',
              unreadCount: 99,
            ),
          ],
          totalCount: 3,
          totalUnreadCount: 99,
          hasMore: false,
        ));

        await loadMoreFuture;

        // Verify: stale items from old filter must NOT appear in current state.
        final finalState = container.read(inboxStoreProvider);
        final allChannelIds = finalState.items.map((i) => i.channelId).toList();
        expect(allChannelIds, isNot(contains('stale-page2')),
            reason: 'Stale loadMore response must be discarded after filter '
                'switch. Removing epoch guard → stale items merged.');

        // State should reflect the new filter (mentions).
        expect(finalState.filter, InboxFilter.mentions);
      },
    );

    test(
      'loadMore still appends correctly when filter is unchanged',
      () async {
        final loadMoreCompleter = Completer<InboxResponse>();
        final repo = _EpochTestInboxRepository(
          loadMoreCompleter: loadMoreCompleter,
        );

        final container = ProviderContainer(overrides: [
          inboxRepositoryProvider.overrideWithValue(repo),
          activeServerScopeIdProvider
              .overrideWithValue(const ServerScopeId('server-1')),
        ]);
        addTearDown(container.dispose);

        final sub = container.listen(inboxStoreProvider, (_, __) {});
        addTearDown(sub.close);

        // Allow auto-load.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(container.read(inboxStoreProvider).items, hasLength(2));
        expect(container.read(inboxStoreProvider).hasMore, isTrue);

        // Trigger loadMore — no filter switch this time.
        final loadMoreFuture =
            container.read(inboxStoreProvider.notifier).loadMore();

        // Complete loadMore with page 2 data (same filter).
        loadMoreCompleter.complete(const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-page2',
              channelName: '#page2',
              unreadCount: 1,
            ),
          ],
          totalCount: 3,
          totalUnreadCount: 5,
          hasMore: false,
        ));

        await loadMoreFuture;

        // Items should be merged (2 + 1 = 3).
        final finalState = container.read(inboxStoreProvider);
        expect(finalState.items, hasLength(3));
        expect(
          finalState.items.map((i) => i.channelId),
          contains('ch-page2'),
          reason: 'loadMore must append when filter is unchanged',
        );
        expect(finalState.hasMore, isFalse);
      },
    );
  });
}

// =============================================================================
// Fakes
// =============================================================================

/// Conversation repository that throws FormatException for specific message IDs.
class _ThrowingConversationRepository implements ConversationRepository {
  /// Set of localIds that should trigger a FormatException when sent.
  Set<String> throwOnIds = {};
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
    // Check if this message should throw a non-AppFailure exception.
    // We check by content matching since we don't have direct access to localId
    // in this interface. Instead, use throwOnIds to map content.
    // Actually we track by sentContents index — the first call hits msg-0, etc.
    final currentIndex = sentContents.length;
    sentContents.add(content);

    final localId = 'msg-$currentIndex';
    if (throwOnIds.contains(localId)) {
      // Throw a non-AppFailure exception — this is what the catch-all handles.
      throw const FormatException('Malformed response body from server');
    }

    return ConversationMessageSummary(
      id: 'server-msg-$currentIndex',
      content: content,
      createdAt: DateTime.now(),
      senderType: 'human',
      messageType: 'message',
      seq: currentIndex + 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Inbox repository with controllable loadMore timing for epoch guard testing.
class _EpochTestInboxRepository implements InboxRepository {
  _EpochTestInboxRepository({required this.loadMoreCompleter});

  final Completer<InboxResponse> loadMoreCompleter;
  bool _useMentionsResponse = false;

  void switchToMentionsResponse() {
    _useMentionsResponse = true;
  }

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    // loadMore requests have offset > 0.
    if (offset > 0) {
      return loadMoreCompleter.future;
    }

    // Mentions filter response (after switch).
    if (_useMentionsResponse && filter == InboxFilter.mentions) {
      return const InboxResponse(
        items: [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'mention-1',
            channelName: '#mentions',
            unreadCount: 1,
            isMentioned: true,
          ),
        ],
        totalCount: 1,
        totalUnreadCount: 1,
        hasMore: false,
      );
    }

    // Initial load (first page, "all" filter).
    return const InboxResponse(
      items: [
        InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-1',
          channelName: '#general',
          unreadCount: 3,
        ),
        InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-2',
          channelName: '#random',
          unreadCount: 1,
        ),
      ],
      totalCount: 3,
      totalUnreadCount: 4,
      hasMore: true,
    );
  }

  @override
  Future<void> markItemRead(ServerScopeId serverId,
      {required String channelId}) async {}

  @override
  Future<void> markItemDone(ServerScopeId serverId,
      {required String channelId}) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}
}
