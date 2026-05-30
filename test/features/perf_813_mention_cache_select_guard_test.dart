// =============================================================================
// #813 — Mention Overlay Cache + SavedMessages .select() + Inbox Rollback Guard
//
// Sub-task 1: Cache _filteredMentionMembers — avoid recomputing .where().toList()
//   on every setState when query and members haven't changed.
//
// Sub-task 2: Narrow savedMessagesStoreProvider watch to only (status, items,
//   failure) so hasMore/isLoadingMore changes don't trigger page rebuild.
//
// Sub-task 3: Add server-switch guard in markAsUnread and markDone catch blocks
//   so rollback is skipped when the user switched servers during the API await.
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/page/mention_filter_cache.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/conversation_unread_repository.dart';
import 'package:slock_app/features/inbox/data/conversation_unread_repository_provider.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_state.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_store.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Sub-task 1: MentionFilterCache — cached filtering
  // ---------------------------------------------------------------------------
  group('#813 — MentionFilterCache', () {
    test('returns same list instance when query and members unchanged', () {
      final cache = MentionFilterCache();
      final members = [
        _fakeChannelMember('alice', 'Alice Smith'),
        _fakeChannelMember('bob', 'Bob Jones'),
      ];

      final result1 = cache.filter(members, 'ali');
      final result2 = cache.filter(members, 'ali');

      expect(identical(result1, result2), isTrue,
          reason: 'Same query + same members list → cached result identity');
    });

    test('recomputes when query changes', () {
      final cache = MentionFilterCache();
      final members = [
        _fakeChannelMember('alice', 'Alice Smith'),
        _fakeChannelMember('bob', 'Bob Jones'),
      ];

      final result1 = cache.filter(members, 'ali');
      final result2 = cache.filter(members, 'bob');

      expect(identical(result1, result2), isFalse,
          reason: 'Different query → new list');
      expect(result1.length, 1);
      expect(result1[0].displayName, 'Alice Smith');
      expect(result2.length, 1);
      expect(result2[0].displayName, 'Bob Jones');
    });

    test('recomputes when members list changes', () {
      final cache = MentionFilterCache();
      final members1 = [
        _fakeChannelMember('alice', 'Alice Smith'),
      ];
      final members2 = [
        _fakeChannelMember('alice', 'Alice Smith'),
        _fakeChannelMember('alicia', 'Alicia Keys'),
      ];

      final result1 = cache.filter(members1, 'ali');
      final result2 = cache.filter(members2, 'ali');

      expect(identical(result1, result2), isFalse,
          reason: 'Different members list → new computation');
      expect(result1.length, 1);
      expect(result2.length, 2);
    });

    test('returns members directly when query is empty', () {
      final cache = MentionFilterCache();
      final members = [
        _fakeChannelMember('alice', 'Alice Smith'),
        _fakeChannelMember('bob', 'Bob Jones'),
      ];

      final result = cache.filter(members, '');
      expect(result, same(members),
          reason: 'Empty query → return members directly (no allocation)');
    });

    test('filter is case-insensitive', () {
      final cache = MentionFilterCache();
      final members = [
        _fakeChannelMember('alice', 'Alice Smith'),
        _fakeChannelMember('bob', 'Bob Jones'),
      ];

      final result = cache.filter(members, 'ALICE');
      expect(result.length, 1);
      expect(result[0].displayName, 'Alice Smith');
    });
  });

  // ---------------------------------------------------------------------------
  // Sub-task 2: SavedMessages .select() — only rebuild on status/items/failure
  // ---------------------------------------------------------------------------
  group('#813 — SavedMessages .select() rebuild narrowing', () {
    test(
      'select does NOT fire when only isLoadingMore changes',
      () async {
        final loadMoreCompleter = Completer<SavedMessagesPage>();
        final repo = _DelayedSavedMessagesRepository(
          initialPage: SavedMessagesPage(
            items: [_fakeSavedMessageItem('msg-1')],
            hasMore: true,
          ),
          loadMoreCompleter: loadMoreCompleter,
        );

        final container = ProviderContainer(
          overrides: [
            currentSavedMessagesServerIdProvider
                .overrideWithValue(const ServerScopeId('srv-1')),
            savedMessagesRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        final store = container.read(savedMessagesStoreProvider.notifier);
        await store.ensureLoaded();

        // Verify initial load succeeded.
        expect(
          container.read(savedMessagesStoreProvider).status,
          SavedMessagesStatus.success,
        );
        expect(
          container.read(savedMessagesStoreProvider).hasMore,
          isTrue,
        );

        // Start listening AFTER initial load completes.
        var selectFired = 0;
        container.listen(
          savedMessagesStoreProvider.select(
            (s) => (status: s.status, items: s.items, failure: s.failure),
          ),
          (_, __) => selectFired++,
          fireImmediately: false,
        );

        // Call loadMore — this immediately sets isLoadingMore: true.
        final future = store.loadMore();

        // At this point, only isLoadingMore changed — items ref is same.
        expect(selectFired, equals(0),
            reason: 'isLoadingMore: true should not trigger page-level select');

        // Complete with empty page (no new items).
        loadMoreCompleter.complete(
          const SavedMessagesPage(items: [], hasMore: false),
        );
        await future;

        // The items list reference changed due to [...state.items, ...[]].
        // But the optimization still saved one rebuild for the intermediate
        // isLoadingMore: true state. The important assertion was above.
      },
    );

    test(
      'select DOES fire when status changes',
      () async {
        final repo = _SimpleSavedMessagesRepository();
        final container = ProviderContainer(
          overrides: [
            currentSavedMessagesServerIdProvider
                .overrideWithValue(const ServerScopeId('srv-1')),
            savedMessagesRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        var selectFired = 0;
        container.listen(
          savedMessagesStoreProvider.select(
            (s) => (status: s.status, items: s.items, failure: s.failure),
          ),
          (_, __) => selectFired++,
          fireImmediately: false,
        );

        // Load triggers initial → loading → success.
        await container
            .read(savedMessagesStoreProvider.notifier)
            .ensureLoaded();

        // Select should have fired for status transitions.
        expect(selectFired, greaterThan(0),
            reason: 'Status change should trigger page rebuild');
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Sub-task 3: Inbox rollback guard — skip rollback on server switch
  // ---------------------------------------------------------------------------
  group('#813 — Inbox rollback server-switch guard', () {
    test(
      'markAsUnread: rollback skipped when server switched during API call',
      () async {
        final items = [
          const InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-A',
            channelName: 'Channel A',
            unreadCount: 0,
          ),
        ];

        final unreadRepo = _ControllableUnreadRepository();
        final inboxRepo = _SeedableInboxRepository(seedItems: items);

        // Use a StateProvider so we can switch the server mid-test.
        final serverIdState = StateProvider<ServerScopeId?>(
          (_) => const ServerScopeId('srv-1'),
        );

        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider.overrideWith(
              (ref) => ref.watch(serverIdState),
            ),
            conversationUnreadRepositoryProvider.overrideWithValue(unreadRepo),
            inboxRepositoryProvider.overrideWithValue(inboxRepo),
            realtimeServiceProvider.overrideWith(_FakeRealtimeNotifier.new),
          ],
        );
        addTearDown(container.dispose);

        container.read(realtimeServiceProvider);
        final store = container.read(inboxStoreProvider.notifier);
        await store.load();

        // Verify baseline.
        expect(_unreadCountFor(container, 'ch-A'), equals(0));

        // Start markAsUnread — optimistic mutation applied.
        final future = store.markAsUnread(channelId: 'ch-A');
        expect(_unreadCountFor(container, 'ch-A'), equals(1),
            reason: 'Optimistic: ch-A unreadCount should be 1');

        // Switch server before API completes.
        container.read(serverIdState.notifier).state =
            const ServerScopeId('srv-2');

        // Fail the API call — rollback should be SKIPPED because server changed.
        unreadRepo.fail('ch-A', const NetworkFailure(message: 'timeout'));
        await future;

        // After server switch, InboxStore rebuilds for the new server.
        // The stale rollback must NOT inject old server data into new state.
        expect(_findItem(container, 'ch-A'), isNull,
            reason: 'Rollback must be skipped when server switched — '
                'stale rollback would corrupt the new server state');
      },
    );

    test(
      'markDone: rollback skipped when server switched during API call',
      () async {
        final items = [
          const InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-A',
            channelName: 'Channel A',
            unreadCount: 2,
          ),
          const InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-B',
            channelName: 'Channel B',
            unreadCount: 1,
          ),
        ];

        final inboxRepo = _ControllableInboxRepository(seedItems: items);
        final unreadRepo = _ControllableUnreadRepository();

        final serverIdState = StateProvider<ServerScopeId?>(
          (_) => const ServerScopeId('srv-1'),
        );

        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider.overrideWith(
              (ref) => ref.watch(serverIdState),
            ),
            conversationUnreadRepositoryProvider.overrideWithValue(unreadRepo),
            inboxRepositoryProvider.overrideWithValue(inboxRepo),
            realtimeServiceProvider.overrideWith(_FakeRealtimeNotifier.new),
          ],
        );
        addTearDown(container.dispose);

        container.read(realtimeServiceProvider);
        final store = container.read(inboxStoreProvider.notifier);
        await store.load();

        // Baseline: 2 items.
        expect(_itemCount(container), equals(2));

        // Start markDone — optimistic removal.
        final future = store.markDone(channelId: 'ch-A');
        expect(_findItem(container, 'ch-A'), isNull,
            reason: 'Optimistic: ch-A removed');

        // Switch server before API completes.
        container.read(serverIdState.notifier).state =
            const ServerScopeId('srv-2');

        // Fail the API call — rollback should be SKIPPED.
        inboxRepo.failDone(
            'ch-A', const NetworkFailure(message: 'server error'));
        await future;

        // ch-A should NOT be re-inserted because rollback was guarded.
        expect(_findItem(container, 'ch-A'), isNull,
            reason: 'Rollback must be skipped when server switched — '
                'stale rollback would corrupt the new server state');
      },
    );

    test(
      'markAsUnread: rollback still works when server has NOT switched',
      () async {
        // Sanity check: rollback still fires normally when server is stable.
        final items = [
          const InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-A',
            channelName: 'Channel A',
            unreadCount: 0,
          ),
        ];

        final unreadRepo = _ControllableUnreadRepository();
        final inboxRepo = _SeedableInboxRepository(seedItems: items);

        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider
                .overrideWith((_) => const ServerScopeId('srv-1')),
            conversationUnreadRepositoryProvider.overrideWithValue(unreadRepo),
            inboxRepositoryProvider.overrideWithValue(inboxRepo),
            realtimeServiceProvider.overrideWith(_FakeRealtimeNotifier.new),
          ],
        );
        addTearDown(container.dispose);

        container.read(realtimeServiceProvider);
        final store = container.read(inboxStoreProvider.notifier);
        await store.load();

        final future = store.markAsUnread(channelId: 'ch-A');
        expect(_unreadCountFor(container, 'ch-A'), equals(1));

        // Fail without server switch — rollback should execute.
        unreadRepo.fail('ch-A', const NetworkFailure(message: 'timeout'));
        await future;

        expect(_unreadCountFor(container, 'ch-A'), equals(0),
            reason: 'Rollback should execute when server has NOT switched');
      },
    );

    test(
      'markDone: rollback still works when server has NOT switched',
      () async {
        final items = [
          const InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-A',
            channelName: 'Channel A',
            unreadCount: 2,
          ),
        ];

        final inboxRepo = _ControllableInboxRepository(seedItems: items);
        final unreadRepo = _ControllableUnreadRepository();

        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider
                .overrideWith((_) => const ServerScopeId('srv-1')),
            conversationUnreadRepositoryProvider.overrideWithValue(unreadRepo),
            inboxRepositoryProvider.overrideWithValue(inboxRepo),
            realtimeServiceProvider.overrideWith(_FakeRealtimeNotifier.new),
          ],
        );
        addTearDown(container.dispose);

        container.read(realtimeServiceProvider);
        final store = container.read(inboxStoreProvider.notifier);
        await store.load();

        expect(_itemCount(container), equals(1));

        final future = store.markDone(channelId: 'ch-A');
        expect(_findItem(container, 'ch-A'), isNull);

        // Fail without server switch — rollback should execute.
        inboxRepo.failDone(
            'ch-A', const NetworkFailure(message: 'server error'));
        await future;

        expect(_findItem(container, 'ch-A'), isNotNull,
            reason: 'Rollback should execute when server has NOT switched');
      },
    );
  });
}

// =============================================================================
// Helpers
// =============================================================================

int _unreadCountFor(ProviderContainer container, String channelId) {
  final state = container.read(inboxStoreProvider);
  final item = state.items.where((i) => i.channelId == channelId).firstOrNull;
  return item?.unreadCount ?? -1;
}

InboxItem? _findItem(ProviderContainer container, String channelId) {
  final state = container.read(inboxStoreProvider);
  return state.items.where((i) => i.channelId == channelId).firstOrNull;
}

int _itemCount(ProviderContainer container) {
  return container.read(inboxStoreProvider).items.length;
}

ChannelMember _fakeChannelMember(String handle, String displayName) {
  return ChannelMember(
    id: 'member-$handle',
    channelId: 'ch-test',
    userId: 'user-$handle',
    userName: displayName,
  );
}

SavedMessageItem _fakeSavedMessageItem(String id) {
  return SavedMessageItem(
    message: ConversationMessageSummary(
      id: id,
      content: 'Test message $id',
      createdAt: DateTime(2025, 1, 1),
      senderType: 'human',
      messageType: 'text',
      senderName: 'Test User',
    ),
    channelId: 'ch-1',
    surface: 'channel',
  );
}

// =============================================================================
// Fakes
// =============================================================================

class _FakeRealtimeNotifier extends RealtimeService {
  @override
  RealtimeConnectionState build() => const RealtimeConnectionState();

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> forceReconnect({required String reason}) async {}
}

class _ControllableUnreadRepository implements ConversationUnreadRepository {
  final Map<String, Completer<void>> _completers = {};

  @override
  Future<void> markAsUnread(
    ServerScopeId serverId, {
    required String channelId,
  }) {
    final completer = Completer<void>();
    _completers[channelId] = completer;
    return completer.future;
  }

  void complete(String channelId) {
    _completers[channelId]!.complete();
  }

  void fail(String channelId, AppFailure failure) {
    _completers[channelId]!.completeError(failure);
  }
}

class _SeedableInboxRepository implements InboxRepository {
  _SeedableInboxRepository({required this.seedItems});

  final List<InboxItem> seedItems;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    return InboxResponse(
      items: seedItems,
      totalCount: seedItems.length,
      totalUnreadCount:
          seedItems.fold<int>(0, (sum, item) => sum + item.unreadCount),
      hasMore: false,
    );
  }

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}

  @override
  Future<void> markItemReadAt(
    ServerScopeId serverId, {
    required String channelId,
    required int seq,
  }) async {}
}

class _ControllableInboxRepository implements InboxRepository {
  _ControllableInboxRepository({required this.seedItems});

  final List<InboxItem> seedItems;
  final Map<String, Completer<void>> _doneCompleters = {};

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    return InboxResponse(
      items: seedItems,
      totalCount: seedItems.length,
      totalUnreadCount:
          seedItems.fold<int>(0, (sum, item) => sum + item.unreadCount),
      hasMore: false,
    );
  }

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) {
    final completer = Completer<void>();
    _doneCompleters[channelId] = completer;
    return completer.future;
  }

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}

  @override
  Future<void> markItemReadAt(
    ServerScopeId serverId, {
    required String channelId,
    required int seq,
  }) async {}

  void completeDone(String channelId) {
    _doneCompleters[channelId]!.complete();
  }

  void failDone(String channelId, AppFailure failure) {
    _doneCompleters[channelId]!.completeError(failure);
  }
}

/// Saved messages repo that delays loadMore via a Completer.
class _DelayedSavedMessagesRepository implements SavedMessagesRepository {
  _DelayedSavedMessagesRepository({
    required this.initialPage,
    required this.loadMoreCompleter,
  });

  final SavedMessagesPage initialPage;
  final Completer<SavedMessagesPage> loadMoreCompleter;
  bool _initialLoaded = false;

  @override
  Future<SavedMessagesPage> listSavedMessages(
    ServerScopeId serverId, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (!_initialLoaded || offset == 0) {
      _initialLoaded = true;
      return initialPage;
    }
    return loadMoreCompleter.future;
  }

  @override
  Future<void> saveMessage(
    ServerScopeId serverId,
    String messageId,
  ) async {}

  @override
  Future<void> unsaveMessage(
    ServerScopeId serverId,
    String messageId,
  ) async {}

  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) async =>
      {};
}

/// Simple repository that returns immediately.
class _SimpleSavedMessagesRepository implements SavedMessagesRepository {
  @override
  Future<SavedMessagesPage> listSavedMessages(
    ServerScopeId serverId, {
    int limit = 50,
    int offset = 0,
  }) async {
    return SavedMessagesPage(
      items: [_fakeSavedMessageItem('msg-1')],
      hasMore: false,
    );
  }

  @override
  Future<void> saveMessage(
    ServerScopeId serverId,
    String messageId,
  ) async {}

  @override
  Future<void> unsaveMessage(
    ServerScopeId serverId,
    String messageId,
  ) async {}

  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) async =>
      {};
}
