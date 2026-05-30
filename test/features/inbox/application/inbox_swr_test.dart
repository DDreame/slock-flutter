import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';

// ---------------------------------------------------------------------------
// Phase A: InboxStore SWR invariant tests (#484)
//
// Tests for INV-CACHE-SWR-1, INV-CACHE-SWR-2, INV-NET-DEGRADE-1 applied
// to InboxStore.
//
// Tests that pass on current implementation are active.
// Tests that require Phase B changes use skip+TODO.
// ---------------------------------------------------------------------------

void main() {
  const serverId = ServerScopeId('server-1');

  const baselineItems = [
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
  ];

  const baselineResponse = InboxResponse(
    items: baselineItems,
    totalCount: 2,
    totalUnreadCount: 7,
    hasMore: false,
  );

  ProviderContainer createContainer(_ControllableInboxRepository repo) {
    return ProviderContainer(
      overrides: [
        inboxRepositoryProvider.overrideWithValue(repo),
        activeServerScopeIdProvider.overrideWithValue(serverId),
      ],
    );
  }

  group('INV-CACHE-SWR-1: refresh keeps stale data visible', () {
    test('items remain visible during background refresh', () async {
      final repo = _ControllableInboxRepository();
      repo.nextResponse = baselineResponse;
      final container = createContainer(repo);
      addTearDown(container.dispose);

      // Initial load.
      await container.read(inboxStoreProvider.notifier).load();
      var state = container.read(inboxStoreProvider);
      expect(state.status, InboxStatus.success);
      expect(state.items, hasLength(2));

      // Start refresh with a delayed response.
      final refreshCompleter = Completer<InboxResponse>();
      repo.fetchCompleter = refreshCompleter;

      final refreshFuture =
          container.read(inboxStoreProvider.notifier).refresh();

      // Mid-flight: stale data must remain visible.
      state = container.read(inboxStoreProvider);
      expect(state.items, hasLength(2),
          reason: 'INV-CACHE-SWR-1: stale items must remain visible '
              'during refresh');
      expect(state.isRefreshing, isTrue,
          reason: 'isRefreshing flag signals background work');
      expect(state.status, InboxStatus.success,
          reason: 'status stays success during SWR refresh');

      // Complete the refresh.
      refreshCompleter.complete(baselineResponse);
      await refreshFuture;

      state = container.read(inboxStoreProvider);
      expect(state.isRefreshing, isFalse);
      expect(state.items, hasLength(2));
    });

    test('refresh replaces stale data with fresh data on completion', () async {
      final repo = _ControllableInboxRepository();
      repo.nextResponse = baselineResponse;
      final container = createContainer(repo);
      addTearDown(container.dispose);

      await container.read(inboxStoreProvider.notifier).load();

      // Prepare updated response with a new item.
      repo.nextResponse = const InboxResponse(
        items: [
          ...baselineItems,
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-2',
            channelName: 'random',
            unreadCount: 1,
          ),
        ],
        totalCount: 3,
        totalUnreadCount: 8,
        hasMore: false,
      );

      await container.read(inboxStoreProvider.notifier).refresh();

      final state = container.read(inboxStoreProvider);
      expect(state.items, hasLength(3),
          reason: 'Fresh data replaces stale after refresh completes');
      expect(state.items.last.channelId, 'ch-2');
      expect(state.totalUnreadCount, 8);
    });
  });

  group('INV-CACHE-SWR-2: no clear-then-load on loaded store', () {
    test('load() on already-loaded store preserves items during fetch',
        () async {
      final repo = _ControllableInboxRepository();
      repo.nextResponse = baselineResponse;
      final container = createContainer(repo);
      addTearDown(container.dispose);

      // Initial load succeeds.
      await container.read(inboxStoreProvider.notifier).load();
      expect(
        container.read(inboxStoreProvider).items,
        hasLength(2),
      );

      // Second load with delayed response.
      final secondCompleter = Completer<InboxResponse>();
      repo.fetchCompleter = secondCompleter;

      final loadFuture = container.read(inboxStoreProvider.notifier).load();

      // Mid-flight: items must NOT be cleared.
      final midState = container.read(inboxStoreProvider);
      expect(midState.items, hasLength(2),
          reason: 'INV-CACHE-SWR-2: load() must not clear items when '
              'stale data exists');
      expect(midState.isRefreshing, isTrue,
          reason: 'SWR uses isRefreshing instead of clearing');

      secondCompleter.complete(baselineResponse);
      await loadFuture;
    });

    test(
      'load() on loaded-empty store preserves empty state during fetch',
      () async {
        final repo = _ControllableInboxRepository();
        repo.nextResponse = const InboxResponse(
          items: [],
          totalCount: 0,
          totalUnreadCount: 0,
          hasMore: false,
        );
        final container = createContainer(repo);
        addTearDown(container.dispose);

        // Initial load succeeds with empty inbox.
        await container.read(inboxStoreProvider.notifier).load();
        final state = container.read(inboxStoreProvider);
        expect(state.status, InboxStatus.success);
        expect(state.items, isEmpty);

        // Second load with delayed response.
        final secondCompleter = Completer<InboxResponse>();
        repo.fetchCompleter = secondCompleter;

        final loadFuture = container.read(inboxStoreProvider.notifier).load();

        // Mid-flight: loaded-empty must use SWR path, not full loading.
        final midState = container.read(inboxStoreProvider);
        expect(midState.status, InboxStatus.success,
            reason: 'INV-CACHE-SWR-2: loaded-empty is valid stale data; '
                'must not revert to loading status');
        expect(midState.isRefreshing, isTrue,
            reason: 'SWR uses isRefreshing for loaded-empty reload');

        secondCompleter.complete(const InboxResponse(
          items: [],
          totalCount: 0,
          totalUnreadCount: 0,
          hasMore: false,
        ));
        await loadFuture;
      },
      skip: 'TODO: InboxStore.load() SWR gate uses '
          'state.items.isNotEmpty which treats loaded-empty as '
          '"no prior data". Phase B must change the gate to '
          'state.status == InboxStatus.success so loaded-empty '
          'inbox is treated as valid stale data.',
    );

    test('load() with different filter clears items (not SWR)', () async {
      final repo = _ControllableInboxRepository();
      repo.nextResponse = baselineResponse;
      final container = createContainer(repo);
      addTearDown(container.dispose);

      // Load with default filter.
      await container.read(inboxStoreProvider.notifier).load();
      expect(
        container.read(inboxStoreProvider).items,
        hasLength(2),
      );

      // Load with different filter — should NOT use SWR.
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

      await container
          .read(inboxStoreProvider.notifier)
          .load(filter: InboxFilter.unread);

      final state = container.read(inboxStoreProvider);
      expect(state.filter, InboxFilter.unread);
      expect(state.items, hasLength(1),
          reason: 'Filter change must do a fresh load, not SWR');
    });
  });

  group('INV-NET-DEGRADE-1: network error overlays on existing data', () {
    test('refresh failure preserves stale items and sets failure', () async {
      final repo = _ControllableInboxRepository();
      repo.nextResponse = baselineResponse;
      final container = createContainer(repo);
      addTearDown(container.dispose);

      await container.read(inboxStoreProvider.notifier).load();
      expect(
        container.read(inboxStoreProvider).items,
        hasLength(2),
      );

      // Refresh fails.
      repo.nextLoadFailure = const UnknownFailure(message: 'Network error');

      await container.read(inboxStoreProvider.notifier).refresh();

      final state = container.read(inboxStoreProvider);
      expect(state.items, hasLength(2),
          reason: 'INV-NET-DEGRADE-1: stale items must survive '
              'refresh failure');
      expect(state.failure, isNotNull,
          reason: 'Failure must be surfaced for UI error overlay');
      expect(state.isRefreshing, isFalse);
      expect(state.status, InboxStatus.success,
          reason: 'Status stays success — data is still valid');
    });

    test('multiple consecutive refresh failures preserve stale data', () async {
      final repo = _ControllableInboxRepository();
      repo.nextResponse = baselineResponse;
      final container = createContainer(repo);
      addTearDown(container.dispose);

      await container.read(inboxStoreProvider.notifier).load();

      // Fail twice.
      repo.nextLoadFailure = const UnknownFailure(message: 'Network error');

      await container.read(inboxStoreProvider.notifier).refresh();
      await container.read(inboxStoreProvider.notifier).refresh();

      final state = container.read(inboxStoreProvider);
      expect(state.items, hasLength(2),
          reason: 'Stale data survives multiple refresh failures');
      expect(state.failure, isNotNull);
    });

    test('successful refresh after failure clears failure and updates data',
        () async {
      final repo = _ControllableInboxRepository();
      repo.nextResponse = baselineResponse;
      final container = createContainer(repo);
      addTearDown(container.dispose);

      await container.read(inboxStoreProvider.notifier).load();

      // Refresh fails.
      repo.nextLoadFailure = const UnknownFailure(message: 'Network error');
      await container.read(inboxStoreProvider.notifier).refresh();

      expect(
        container.read(inboxStoreProvider).failure,
        isNotNull,
      );

      // Refresh succeeds.
      repo.nextLoadFailure = null;
      repo.nextResponse = const InboxResponse(
        items: [
          ...baselineItems,
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-2',
            channelName: 'random',
            unreadCount: 1,
          ),
        ],
        totalCount: 3,
        totalUnreadCount: 8,
        hasMore: false,
      );

      await container.read(inboxStoreProvider.notifier).refresh();

      final state = container.read(inboxStoreProvider);
      expect(state.items, hasLength(3));
      expect(state.failure, isNull,
          reason: 'Successful refresh clears prior failure');
    });

    test(
      'load() failure after prior success preserves stale items',
      () async {
        final repo = _ControllableInboxRepository();
        repo.nextResponse = baselineResponse;
        final container = createContainer(repo);
        addTearDown(container.dispose);

        // Initial load succeeds.
        await container.read(inboxStoreProvider.notifier).load();
        expect(
          container.read(inboxStoreProvider).items,
          hasLength(2),
        );

        // Second load fails.
        repo.nextLoadFailure = const UnknownFailure(message: 'Network error');
        await container.read(inboxStoreProvider.notifier).load();

        final state = container.read(inboxStoreProvider);
        expect(state.items, hasLength(2),
            reason: 'INV-NET-DEGRADE-1: load() failure must preserve '
                'stale items when prior data exists');
        expect(state.failure, isNotNull);
        expect(state.status, InboxStatus.success,
            reason: 'Status stays success — stale data is still valid');
      },
    );
  });

  group('State distinguishes initialLoading vs refreshing', () {
    test('initial load uses loading status with empty items', () async {
      final repo = _ControllableInboxRepository();
      final loadCompleter = Completer<InboxResponse>();
      repo.fetchCompleter = loadCompleter;
      final container = createContainer(repo);
      addTearDown(container.dispose);

      final loadFuture = container.read(inboxStoreProvider.notifier).load();

      final state = container.read(inboxStoreProvider);
      expect(state.status, InboxStatus.loading,
          reason: 'Initial load uses loading status');
      expect(state.items, isEmpty, reason: 'No data yet during initial load');
      expect(state.isRefreshing, isFalse,
          reason: 'isRefreshing is false during initial load');

      loadCompleter.complete(baselineResponse);
      await loadFuture;
    });

    test('refresh uses isRefreshing flag with success status', () async {
      final repo = _ControllableInboxRepository();
      repo.nextResponse = baselineResponse;
      final container = createContainer(repo);
      addTearDown(container.dispose);

      await container.read(inboxStoreProvider.notifier).load();

      // Start refresh.
      final refreshCompleter = Completer<InboxResponse>();
      repo.fetchCompleter = refreshCompleter;

      final refreshFuture =
          container.read(inboxStoreProvider.notifier).refresh();

      final state = container.read(inboxStoreProvider);
      expect(state.status, InboxStatus.success,
          reason: 'Refresh keeps success status (not loading)');
      expect(state.isRefreshing, isTrue,
          reason: 'isRefreshing signals background work');
      expect(state.items, hasLength(2),
          reason: 'Stale data visible during refresh');

      refreshCompleter.complete(baselineResponse);
      await refreshFuture;
    });
  });
}

// ---------------------------------------------------------------------------
// Local fake: Completer-based controllable InboxRepository
//
// Justification: Phase A SWR tests need Completer-based timing control
// to observe mid-flight state (items visible while refresh in progress).
// The shared FakeInboxRepository does not support async response blocking.
// ---------------------------------------------------------------------------

class _ControllableInboxRepository implements InboxRepository {
  InboxResponse? nextResponse;
  Completer<InboxResponse>? fetchCompleter;
  AppFailure? nextLoadFailure;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    if (fetchCompleter != null) {
      return fetchCompleter!.future;
    }
    if (nextLoadFailure != null) {
      final failure = nextLoadFailure!;
      throw failure;
    }
    return nextResponse!;
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
