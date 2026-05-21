// =============================================================================
// #714 — Inbox Reliability
//
// A. P1: _isLoadingMore not reset on server switch → pagination blocked
// B. P1: markRead silently swallows API failure without rollback
// C. P2: SavedMessagesStore.ensureLoaded() fires-and-forgets → lost errors
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_state.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_store.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';

void main() {
  group('#714A — P1: _isLoadingMore reset on server switch', () {
    test(
        'server switch while loadMore in-flight resets flag → new server pagination works',
        () async {
      final repo = _ControllableInboxRepository();
      // First page for server-1.
      repo.nextResponse = const InboxResponse(
        items: [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-1',
            unreadCount: 1,
          ),
        ],
        totalCount: 2,
        totalUnreadCount: 2,
        hasMore: true,
      );

      final serverIdState = StateProvider<ServerScopeId?>(
        (ref) => const ServerScopeId('server-1'),
      );

      final container = ProviderContainer(
        overrides: [
          inboxRepositoryProvider.overrideWithValue(repo),
          activeServerScopeIdProvider
              .overrideWith((ref) => ref.watch(serverIdState)),
        ],
      );
      addTearDown(container.dispose);

      // Initial load.
      await container.read(inboxStoreProvider.notifier).load();
      expect(container.read(inboxStoreProvider).items, hasLength(1));

      // Start loadMore — block it with a completer that never completes.
      repo.fetchCompleter = Completer<InboxResponse>();
      // Fire and forget — the loadMore will hang.
      unawaited(container.read(inboxStoreProvider.notifier).loadMore());
      await Future<void>.delayed(Duration.zero);

      // Switch server while loadMore is in-flight (_isLoadingMore is true).
      repo.fetchCompleter = null;
      repo.nextResponse = const InboxResponse(
        items: [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'srv2-ch-1',
            unreadCount: 3,
          ),
        ],
        totalCount: 2,
        totalUnreadCount: 3,
        hasMore: true,
      );
      container.read(serverIdState.notifier).state =
          const ServerScopeId('server-2');
      await Future<void>.delayed(Duration.zero);

      // Load for new server.
      await container.read(inboxStoreProvider.notifier).load();

      // Now loadMore on new server should work (flag must have been reset).
      repo.nextResponse = const InboxResponse(
        items: [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'srv2-ch-2',
            unreadCount: 2,
          ),
        ],
        totalCount: 2,
        totalUnreadCount: 5,
        hasMore: false,
      );
      await container.read(inboxStoreProvider.notifier).loadMore();

      final state = container.read(inboxStoreProvider);
      expect(state.items, hasLength(2),
          reason:
              'loadMore must work after server switch (flag was reset in build)');
      expect(state.items.map((i) => i.channelId), ['srv2-ch-1', 'srv2-ch-2']);
    });
  });

  group('#714B — P1: markRead rollback on API failure', () {
    test('markRead restores unread count on API failure', () async {
      final repo = _ControllableInboxRepository();
      repo.nextResponse = const InboxResponse(
        items: [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-1',
            channelName: 'general',
            unreadCount: 5,
          ),
          InboxItem(
            kind: InboxItemKind.dm,
            channelId: 'dm-1',
            channelName: 'Bob',
            unreadCount: 2,
          ),
        ],
        totalCount: 2,
        totalUnreadCount: 7,
        hasMore: false,
      );

      final container = ProviderContainer(
        overrides: [
          inboxRepositoryProvider.overrideWithValue(repo),
          activeServerScopeIdProvider
              .overrideWithValue(const ServerScopeId('server-1')),
        ],
      );
      addTearDown(container.dispose);

      await container.read(inboxStoreProvider.notifier).load();

      // Make markRead API call fail.
      repo.markReadFailure =
          const NetworkFailure(message: 'server unreachable');
      await container.read(inboxStoreProvider.notifier).markRead(
            channelId: 'ch-1',
          );

      final state = container.read(inboxStoreProvider);
      // Rollback: unread count should be restored.
      final ch1 = state.items.firstWhere((i) => i.channelId == 'ch-1');
      expect(ch1.unreadCount, 5,
          reason: 'markRead must rollback on API failure');
      expect(state.totalUnreadCount, 7,
          reason: 'Total unread must be restored on failure');
    });

    test('markRead success does NOT rollback', () async {
      final repo = _ControllableInboxRepository();
      repo.nextResponse = const InboxResponse(
        items: [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-1',
            channelName: 'general',
            unreadCount: 5,
          ),
        ],
        totalCount: 1,
        totalUnreadCount: 5,
        hasMore: false,
      );

      final container = ProviderContainer(
        overrides: [
          inboxRepositoryProvider.overrideWithValue(repo),
          activeServerScopeIdProvider
              .overrideWithValue(const ServerScopeId('server-1')),
        ],
      );
      addTearDown(container.dispose);

      await container.read(inboxStoreProvider.notifier).load();
      await container
          .read(inboxStoreProvider.notifier)
          .markRead(channelId: 'ch-1');

      final state = container.read(inboxStoreProvider);
      final ch1 = state.items.firstWhere((i) => i.channelId == 'ch-1');
      expect(ch1.unreadCount, 0,
          reason: 'Successful markRead should keep optimistic state');
    });

    test('markRead rollback in unread filter restores removed items', () async {
      final repo = _ControllableInboxRepository();
      repo.nextResponse = const InboxResponse(
        items: [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-1',
            unreadCount: 3,
          ),
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-2',
            unreadCount: 1,
          ),
        ],
        totalCount: 2,
        totalUnreadCount: 4,
        hasMore: false,
      );

      final container = ProviderContainer(
        overrides: [
          inboxRepositoryProvider.overrideWithValue(repo),
          activeServerScopeIdProvider
              .overrideWithValue(const ServerScopeId('server-1')),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(inboxStoreProvider.notifier)
          .load(filter: InboxFilter.unread);
      expect(container.read(inboxStoreProvider).items, hasLength(2));

      // Make markRead fail → item should be restored.
      repo.markReadFailure =
          const NetworkFailure(message: 'server unreachable');
      await container
          .read(inboxStoreProvider.notifier)
          .markRead(channelId: 'ch-1');

      final state = container.read(inboxStoreProvider);
      expect(state.items, hasLength(2),
          reason:
              'Removed item must be restored in unread filter on API failure');
      expect(state.items.first.unreadCount, 3);
    });
  });

  group('#714C — P2: SavedMessagesStore.ensureLoaded() error surfacing', () {
    test('ensureLoaded surfaces load failure as failure status', () async {
      final repo = _FakeSavedMessagesRepository(
        failure: const NetworkFailure(message: 'timeout'),
      );
      final container = ProviderContainer(
        overrides: [
          savedMessagesRepositoryProvider.overrideWithValue(repo),
          currentSavedMessagesServerIdProvider
              .overrideWithValue(const ServerScopeId('server-1')),
        ],
      );
      addTearDown(container.dispose);

      // Keep the auto-dispose provider alive.
      container.listen(savedMessagesStoreProvider, (_, __) {});

      await container.read(savedMessagesStoreProvider.notifier).ensureLoaded();

      final state = container.read(savedMessagesStoreProvider);
      expect(state.status, SavedMessagesStatus.failure,
          reason: 'ensureLoaded must surface load failure, not stay stuck');
      expect(state.failure, isA<NetworkFailure>());
    });

    test('ensureLoaded success reaches success status', () async {
      final repo = _FakeSavedMessagesRepository();
      final container = ProviderContainer(
        overrides: [
          savedMessagesRepositoryProvider.overrideWithValue(repo),
          currentSavedMessagesServerIdProvider
              .overrideWithValue(const ServerScopeId('server-1')),
        ],
      );
      addTearDown(container.dispose);

      // Keep the auto-dispose provider alive.
      container.listen(savedMessagesStoreProvider, (_, __) {});

      await container.read(savedMessagesStoreProvider.notifier).ensureLoaded();

      final state = container.read(savedMessagesStoreProvider);
      expect(state.status, SavedMessagesStatus.success);
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableInboxRepository implements InboxRepository {
  InboxResponse? nextResponse;
  Completer<InboxResponse>? fetchCompleter;
  int fetchCallCount = 0;
  AppFailure? markReadFailure;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    fetchCallCount += 1;
    if (fetchCompleter != null) {
      return fetchCompleter!.future;
    }
    return nextResponse!;
  }

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    if (markReadFailure != null) throw markReadFailure!;
  }

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}
}

class _FakeSavedMessagesRepository implements SavedMessagesRepository {
  _FakeSavedMessagesRepository({this.failure});

  final AppFailure? failure;

  @override
  Future<SavedMessagesPage> listSavedMessages(
    ServerScopeId serverId, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (failure != null) throw failure!;
    return const SavedMessagesPage(items: [], hasMore: false);
  }

  @override
  Future<void> saveMessage(ServerScopeId serverId, String messageId) async {}

  @override
  Future<void> unsaveMessage(ServerScopeId serverId, String messageId) async {}

  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) async {
    return {};
  }
}
