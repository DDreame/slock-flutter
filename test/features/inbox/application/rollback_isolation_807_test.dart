// =============================================================================
// #807 — InboxStore markAsUnread / markDone Rollback Isolation
//
// Problem: Both markAsUnread() and markDone() snapshot the entire InboxState
// before the optimistic mutation and restore it wholesale on failure:
//
//   final previousState = state;
//   state = <optimistically-mutated>;
//   try { await repo.apiCall(); }
//   on AppFailure { state = previousState; }
//
// When two operations run concurrently on different items, the second snapshot
// captures the first operation's optimistic mutation.  If the FIRST operation
// fails, it rolls back to a state that predates the second operation's
// mutation — silently erasing it.
//
// Fix (Phase B): Replace full-state snapshot with per-item snapshots so a
// failure only reverts the single item that failed, leaving other concurrent
// mutations intact.
//
// These tests demonstrate the broken isolation by triggering concurrent
// operations and asserting that independent items are never clobbered.
// They will FAIL on the current implementation and PASS after Phase B.
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/conversation_unread_repository.dart';
import 'package:slock_app/features/inbox/data/conversation_unread_repository_provider.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';

void main() {
  // ---------------------------------------------------------------------------
  // markAsUnread × markAsUnread — concurrent on different channels
  // ---------------------------------------------------------------------------
  group('#807 — markAsUnread rollback isolation', () {
    test(
      'concurrent markAsUnread: failure of item A does NOT revert item B',
      () async {
        // Two channels — both start at unreadCount 0.
        final items = [
          const InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-A',
            channelName: 'Channel A',
            unreadCount: 0,
          ),
          const InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-B',
            channelName: 'Channel B',
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

        // Boot InboxStore and load seed data.
        container.read(realtimeServiceProvider);
        final store = container.read(inboxStoreProvider.notifier);
        await store.load();

        // Verify baseline: both items unread=0.
        expect(
          _unreadCountFor(container, 'ch-A'),
          equals(0),
          reason: 'Baseline: ch-A unreadCount should be 0',
        );
        expect(
          _unreadCountFor(container, 'ch-B'),
          equals(0),
          reason: 'Baseline: ch-B unreadCount should be 0',
        );

        // Launch markAsUnread for BOTH channels concurrently.
        final futureA = store.markAsUnread(channelId: 'ch-A');
        final futureB = store.markAsUnread(channelId: 'ch-B');

        // Both optimistic mutations should be visible immediately.
        expect(
          _unreadCountFor(container, 'ch-A'),
          equals(1),
          reason: 'Optimistic: ch-A unreadCount should be 1',
        );
        expect(
          _unreadCountFor(container, 'ch-B'),
          equals(1),
          reason: 'Optimistic: ch-B unreadCount should be 1',
        );

        // Complete B successfully FIRST.
        unreadRepo.complete('ch-B');
        await futureB;

        // Fail A AFTER B succeeded.
        unreadRepo.fail('ch-A', const NetworkFailure(message: 'timeout'));
        await futureA;

        // CRITICAL ASSERTION: B's mutation must survive A's rollback.
        // The bug: A's previousState was captured before B ran,
        // so rolling back A also erases B's unreadCount=1.
        expect(
          _unreadCountFor(container, 'ch-B'),
          equals(1),
          reason: 'ch-B mutation must survive ch-A rollback — '
              'rollback should be per-item, not full-state',
        );

        // A should be rolled back to 0.
        expect(
          _unreadCountFor(container, 'ch-A'),
          equals(0),
          reason: 'ch-A should be rolled back after failure',
        );
      },
    );

    test(
      'concurrent markAsUnread: failure of item B does NOT revert item A',
      () async {
        // Symmetric test — the OTHER item fails.
        final items = [
          const InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-X',
            channelName: 'Channel X',
            unreadCount: 0,
          ),
          const InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-Y',
            channelName: 'Channel Y',
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

        // Launch both concurrently.
        final futureX = store.markAsUnread(channelId: 'ch-X');
        final futureY = store.markAsUnread(channelId: 'ch-Y');

        // Complete X successfully.
        unreadRepo.complete('ch-X');
        await futureX;

        // Fail Y.
        unreadRepo.fail('ch-Y', const NetworkFailure(message: 'timeout'));
        await futureY;

        // X must survive Y's rollback.
        expect(
          _unreadCountFor(container, 'ch-X'),
          equals(1),
          reason: 'ch-X mutation must survive ch-Y rollback',
        );

        // Y should be rolled back.
        expect(
          _unreadCountFor(container, 'ch-Y'),
          equals(0),
          reason: 'ch-Y should be rolled back after failure',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // markDone × markDone — concurrent on different channels
  // ---------------------------------------------------------------------------
  group('#807 — markDone rollback isolation', () {
    test(
      'concurrent markDone: failure of item A does NOT revert item B removal',
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
            unreadCount: 3,
          ),
          const InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-C',
            channelName: 'Channel C',
            unreadCount: 1,
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

        // Baseline: 3 items visible.
        expect(_itemCount(container), equals(3));

        // Mark A and B as done concurrently.
        final futureA = store.markDone(channelId: 'ch-A');
        final futureB = store.markDone(channelId: 'ch-B');

        // Optimistic: both removed.
        expect(_itemCount(container), equals(1));
        expect(_findItem(container, 'ch-A'), isNull);
        expect(_findItem(container, 'ch-B'), isNull);
        expect(_findItem(container, 'ch-C'), isNotNull);

        // B succeeds.
        inboxRepo.completeDone('ch-B');
        await futureB;

        // A fails — should only roll back A.
        inboxRepo.failDone(
            'ch-A', const NetworkFailure(message: 'server error'));
        await futureA;

        // CRITICAL: B must remain removed (done succeeded).
        // A should be restored.
        expect(
          _findItem(container, 'ch-A'),
          isNotNull,
          reason: 'ch-A should be restored after markDone failure',
        );
        expect(
          _findItem(container, 'ch-B'),
          isNull,
          reason: 'ch-B must remain removed — its markDone succeeded. '
              'Rolling back A must NOT restore B.',
        );
        expect(
          _findItem(container, 'ch-C'),
          isNotNull,
          reason: 'ch-C was untouched and should still be visible',
        );
      },
    );

    test(
      'concurrent markDone both fail (A first): original order [A, B, C] restored',
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
            unreadCount: 3,
          ),
          const InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-C',
            channelName: 'Channel C',
            unreadCount: 1,
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

        // Mark A and B as done concurrently.
        final futureA = store.markDone(channelId: 'ch-A');
        final futureB = store.markDone(channelId: 'ch-B');

        // Both fail — A fails first, B fails second.
        inboxRepo.failDone(
            'ch-A', const NetworkFailure(message: 'server error'));
        await futureA;

        inboxRepo.failDone(
            'ch-B', const NetworkFailure(message: 'server error'));
        await futureB;

        // CRITICAL: original order must be restored regardless of failure order.
        expect(
          _channelIds(container),
          equals(['ch-A', 'ch-B', 'ch-C']),
          reason: 'Both failed — original order [A, B, C] must be restored '
              'regardless of which failure arrives first',
        );
      },
    );

    test(
      'concurrent markDone both fail (B first): original order [A, B, C] restored',
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
            unreadCount: 3,
          ),
          const InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-C',
            channelName: 'Channel C',
            unreadCount: 1,
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

        // Mark A and B as done concurrently.
        final futureA = store.markDone(channelId: 'ch-A');
        final futureB = store.markDone(channelId: 'ch-B');

        // Both fail — B fails first, A fails second (reverse order).
        inboxRepo.failDone(
            'ch-B', const NetworkFailure(message: 'server error'));
        await futureB;

        inboxRepo.failDone(
            'ch-A', const NetworkFailure(message: 'server error'));
        await futureA;

        // CRITICAL: original order must be restored regardless of failure order.
        expect(
          _channelIds(container),
          equals(['ch-A', 'ch-B', 'ch-C']),
          reason: 'Both failed — original order [A, B, C] must be restored '
              'regardless of which failure arrives first',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // markAsUnread × markDone — cross-method concurrent operations
  // ---------------------------------------------------------------------------
  group('#807 — cross-method rollback isolation', () {
    test(
      'markDone failure does NOT revert concurrent markAsUnread on another item',
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
            unreadCount: 0,
          ),
        ];

        final unreadRepo = _ControllableUnreadRepository();
        final inboxRepo = _ControllableInboxRepository(seedItems: items);

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

        // markDone on A + markAsUnread on B — concurrently.
        final doneA = store.markDone(channelId: 'ch-A');
        final unreadB = store.markAsUnread(channelId: 'ch-B');

        // Optimistic: A removed, B unread=1.
        expect(_findItem(container, 'ch-A'), isNull);
        expect(_unreadCountFor(container, 'ch-B'), equals(1));

        // markAsUnread(B) succeeds.
        unreadRepo.complete('ch-B');
        await unreadB;

        // markDone(A) FAILS — should only restore A.
        inboxRepo.failDone(
            'ch-A', const NetworkFailure(message: 'server error'));
        await doneA;

        // A restored, B's unread=1 intact.
        expect(
          _findItem(container, 'ch-A'),
          isNotNull,
          reason: 'ch-A should be restored after markDone failure',
        );
        expect(
          _unreadCountFor(container, 'ch-B'),
          equals(1),
          reason: 'ch-B markAsUnread must survive ch-A markDone rollback',
        );
      },
    );

    test(
      'markAsUnread failure does NOT revert concurrent markDone on another item',
      () async {
        final items = [
          const InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-A',
            channelName: 'Channel A',
            unreadCount: 0,
          ),
          const InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-B',
            channelName: 'Channel B',
            unreadCount: 3,
          ),
        ];

        final unreadRepo = _ControllableUnreadRepository();
        final inboxRepo = _ControllableInboxRepository(seedItems: items);

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

        // markAsUnread on A + markDone on B — concurrently.
        final unreadA = store.markAsUnread(channelId: 'ch-A');
        final doneB = store.markDone(channelId: 'ch-B');

        // Optimistic: A unread=1, B removed.
        expect(_unreadCountFor(container, 'ch-A'), equals(1));
        expect(_findItem(container, 'ch-B'), isNull);

        // markDone(B) succeeds.
        inboxRepo.completeDone('ch-B');
        await doneB;

        // markAsUnread(A) FAILS.
        unreadRepo.fail('ch-A', const NetworkFailure(message: 'timeout'));
        await unreadA;

        // A rolled back to 0, B remains removed.
        expect(
          _unreadCountFor(container, 'ch-A'),
          equals(0),
          reason: 'ch-A should be rolled back after markAsUnread failure',
        );
        expect(
          _findItem(container, 'ch-B'),
          isNull,
          reason: 'ch-B markDone must survive ch-A markAsUnread rollback',
        );
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

List<String> _channelIds(ProviderContainer container) {
  return container
      .read(inboxStoreProvider)
      .items
      .map((i) => i.channelId)
      .toList();
}

// =============================================================================
// Fakes
// =============================================================================

// ---------------------------------------------------------------------------
// _FakeRealtimeNotifier — minimal stub so InboxStore.build() can listen
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// _ControllableUnreadRepository — per-channelId completers for markAsUnread
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// _SeedableInboxRepository — returns seed items on fetchInbox, stubs other ops
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// _ControllableInboxRepository — per-channelId completers for markItemDone
// ---------------------------------------------------------------------------

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
