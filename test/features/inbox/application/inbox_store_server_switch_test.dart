// =============================================================================
// #564 Phase A — InboxStore Server-Switch Bug
//
// Root cause: InboxStore.build() does not ref.watch(activeServerScopeIdProvider)
// so the store never rebuilds on server switch — shows stale data.
//
// Phase B fix: add ref.watch(activeServerScopeIdProvider) in build() so
// the Notifier rebuilds (state resets) whenever the selected server changes.
//
// Phase B — all tests active.
// =============================================================================
//
// #572 Phase A → Phase B — InboxStore Server-Switch Auto-Load
//
// Root cause: InboxStore.build() resets state on server switch but does NOT
// schedule load() after reset. Since InboxPage uses indexedStack, initState()
// never re-fires — inbox shows empty skeleton until manual pull-to-refresh.
//
// Phase B fix: add Future.microtask(() { if (state.status == InboxStatus.initial)
// load(); }) in build(), same pattern as HomeListStore.
//
// Phase B — all tests active.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';

import '../../../support/support.dart';

void main() {
  group('InboxStore — server-switch rebuild', () {
    // T1: Store rebuilds when activeServerScopeId changes
    test(
      'build() is re-invoked when activeServerScopeId changes',
      () async {
        final inboxRepo = FakeInboxRepository();
        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            inboxRepositoryProvider.overrideWithValue(inboxRepo),
          ],
        );
        addTearDown(container.dispose);

        // Select server A and load inbox.
        await container
            .read(serverSelectionStoreProvider.notifier)
            .selectServer('server-a');

        inboxRepo.fetchResponse = const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-a1',
              channelName: 'general-a',
              unreadCount: 3,
            ),
          ],
          totalCount: 1,
          totalUnreadCount: 3,
          hasMore: false,
        );

        await container.read(inboxStoreProvider.notifier).load();
        expect(container.read(inboxStoreProvider).status, InboxStatus.success);
        expect(container.read(inboxStoreProvider).items, hasLength(1));

        // Track build() calls via state resets.
        var buildCount = 0;
        container.listen(inboxStoreProvider, (prev, next) {
          if (next.status == InboxStatus.initial) buildCount++;
        });

        // Switch to server B — build() should re-fire, resetting state.
        await container
            .read(serverSelectionStoreProvider.notifier)
            .selectServer('server-b');

        // After rebuild, state should be reset to initial.
        final stateAfterSwitch = container.read(inboxStoreProvider);
        expect(stateAfterSwitch.status, InboxStatus.initial);
        expect(stateAfterSwitch.items, isEmpty);
        expect(buildCount, greaterThanOrEqualTo(1));
      },
    );

    // T2: load() fetches data for new server after switch
    test(
      'load() after server switch fetches data for the new server',
      () async {
        final inboxRepo = _TrackingInboxRepository();
        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            inboxRepositoryProvider.overrideWithValue(inboxRepo),
          ],
        );
        addTearDown(container.dispose);

        // Select server A and load.
        await container
            .read(serverSelectionStoreProvider.notifier)
            .selectServer('server-a');

        inboxRepo.fetchResponse = const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-a1',
              channelName: 'general-a',
              unreadCount: 2,
            ),
          ],
          totalCount: 1,
          totalUnreadCount: 2,
          hasMore: false,
        );
        await container.read(inboxStoreProvider.notifier).load();
        expect(inboxRepo.lastFetchServerId?.value, 'server-a');

        // Switch to server B.
        await container
            .read(serverSelectionStoreProvider.notifier)
            .selectServer('server-b');

        // Prepare server-B response.
        inboxRepo.fetchResponse = const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-b1',
              channelName: 'Bob',
              unreadCount: 5,
            ),
          ],
          totalCount: 1,
          totalUnreadCount: 5,
          hasMore: false,
        );

        // load() should now use server-b context.
        await container.read(inboxStoreProvider.notifier).load();
        expect(inboxRepo.lastFetchServerId?.value, 'server-b');

        final state = container.read(inboxStoreProvider);
        expect(state.items, hasLength(1));
        expect(state.items.first.channelId, 'dm-b1');
      },
    );

    // T3: Stale items from previous server are cleared
    test(
      'stale items from previous server are cleared on switch',
      () async {
        final inboxRepo = FakeInboxRepository();
        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            inboxRepositoryProvider.overrideWithValue(inboxRepo),
          ],
        );
        addTearDown(container.dispose);

        // Select server A and load items.
        await container
            .read(serverSelectionStoreProvider.notifier)
            .selectServer('server-a');

        inboxRepo.fetchResponse = const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-a1',
              channelName: 'general-a',
              unreadCount: 10,
            ),
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-a2',
              channelName: 'random-a',
              unreadCount: 4,
            ),
          ],
          totalCount: 2,
          totalUnreadCount: 14,
          hasMore: false,
        );
        await container.read(inboxStoreProvider.notifier).load();

        expect(container.read(inboxStoreProvider).items, hasLength(2));
        expect(
          container.read(inboxStoreProvider).items.first.channelId,
          'ch-a1',
        );

        // Switch to server B — stale items must NOT remain.
        await container
            .read(serverSelectionStoreProvider.notifier)
            .selectServer('server-b');

        final stateAfterSwitch = container.read(inboxStoreProvider);
        // State should be reset — no items from server A visible.
        expect(stateAfterSwitch.items, isEmpty);
        expect(stateAfterSwitch.status, InboxStatus.initial);
      },
    );

    // T4: Rapid server switches — final state reflects last server only
    test(
      'rapid server switches — final state reflects last server only',
      () async {
        final inboxRepo = _TrackingInboxRepository();
        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            inboxRepositoryProvider.overrideWithValue(inboxRepo),
          ],
        );
        addTearDown(container.dispose);

        // Select server A.
        await container
            .read(serverSelectionStoreProvider.notifier)
            .selectServer('server-a');
        await container.read(inboxStoreProvider.notifier).load();

        // Rapid switches: A → B → C
        await container
            .read(serverSelectionStoreProvider.notifier)
            .selectServer('server-b');
        await container
            .read(serverSelectionStoreProvider.notifier)
            .selectServer('server-c');

        // Prepare response for server C.
        inboxRepo.fetchResponse = const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-c1',
              channelName: 'general-c',
              unreadCount: 7,
            ),
          ],
          totalCount: 1,
          totalUnreadCount: 7,
          hasMore: false,
        );

        // Load after settling — should only reflect server C.
        await container.read(inboxStoreProvider.notifier).load();

        expect(inboxRepo.lastFetchServerId?.value, 'server-c');
        final state = container.read(inboxStoreProvider);
        expect(state.status, InboxStatus.success);
        expect(state.items, hasLength(1));
        expect(state.items.first.channelId, 'ch-c1');
      },
    );
  });

  // ---------------------------------------------------------------------------
  // #572 — InboxStore auto-load after server-switch
  // ---------------------------------------------------------------------------
  group('InboxStore — auto-load after server-switch', () {
    // T1: After server switch rebuild, state transitions initial → loading →
    // success WITHOUT any external load() call.
    test(
      'InboxStore schedules load after server-switch reset',
      () async {
        final inboxRepo = FakeInboxRepository();
        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            inboxRepositoryProvider.overrideWithValue(inboxRepo),
          ],
        );
        addTearDown(container.dispose);

        // Keep provider alive during microtask resolution.
        final sub = container.listen(inboxStoreProvider, (_, __) {});

        // Select server A.
        await container
            .read(serverSelectionStoreProvider.notifier)
            .selectServer('server-a');

        // Load initial data for server A.
        inboxRepo.fetchResponse = const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-a1',
              channelName: 'general-a',
              unreadCount: 3,
            ),
          ],
          totalCount: 1,
          totalUnreadCount: 3,
          hasMore: false,
        );
        await container.read(inboxStoreProvider.notifier).load();
        expect(container.read(inboxStoreProvider).status, InboxStatus.success);

        // Prepare response for server B.
        inboxRepo.fetchResponse = const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-b1',
              channelName: 'Bob',
              unreadCount: 5,
            ),
          ],
          totalCount: 1,
          totalUnreadCount: 5,
          hasMore: false,
        );

        // Switch to server B — should auto-load without manual load().
        await container
            .read(serverSelectionStoreProvider.notifier)
            .selectServer('server-b');

        // Allow Future.microtask to resolve.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // State should have transitioned to success automatically.
        final state = container.read(inboxStoreProvider);
        expect(state.status, InboxStatus.success,
            reason: 'InboxStore should auto-load after server-switch reset');
        expect(state.items, hasLength(1));
        expect(state.items.first.channelId, 'dm-b1');

        sub.close();
      },
    );

    // T2: After server switch, the auto-load microtask fires exactly once —
    // the guard prevents a redundant second load() from the same rebuild.
    test(
      'InboxStore does not double-load if already loaded',
      () async {
        final inboxRepo = _LoadCountingInboxRepository();
        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(FakeSecureStorage()),
            inboxRepositoryProvider.overrideWithValue(inboxRepo),
          ],
        );
        addTearDown(container.dispose);

        // Keep provider alive during microtask resolution.
        final sub = container.listen(inboxStoreProvider, (_, __) {});

        // Select server A.
        await container
            .read(serverSelectionStoreProvider.notifier)
            .selectServer('server-a');

        inboxRepo.fetchResponse = const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-a1',
              channelName: 'general-a',
              unreadCount: 1,
            ),
          ],
          totalCount: 1,
          totalUnreadCount: 1,
          hasMore: false,
        );

        // Allow auto-load microtask to fire for server A.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Verify server A loaded successfully.
        expect(
          container.read(inboxStoreProvider).status,
          InboxStatus.success,
        );

        // Record load count after server A auto-load.
        final countBeforeSwitch = inboxRepo.loadCount;

        // Prepare response for server B.
        inboxRepo.fetchResponse = const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-b1',
              channelName: 'Bob',
              unreadCount: 2,
            ),
          ],
          totalCount: 1,
          totalUnreadCount: 2,
          hasMore: false,
        );

        // Switch to server B — build() fires, state resets to initial,
        // auto-load microtask should fire exactly ONCE.
        await container
            .read(serverSelectionStoreProvider.notifier)
            .selectServer('server-b');

        // Allow microtasks to resolve fully.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // The auto-load guard should have triggered exactly 1 fetch for
        // server B — not 0 (broken) and not 2 (double-load).
        final countAfterSwitch = inboxRepo.loadCount;
        expect(
          countAfterSwitch - countBeforeSwitch,
          1,
          reason: 'Server switch should trigger exactly 1 auto-load, '
              'not double-load',
        );

        // Verify state reached success for server B.
        final state = container.read(inboxStoreProvider);
        expect(state.status, InboxStatus.success);
        expect(state.items.first.channelId, 'dm-b1');

        sub.close();
      },
    );
  });
}

// -----------------------------------------------------------------------------
// Local fake that also tracks the serverId passed to fetchInbox.
// Extends FakeInboxRepository to reuse all other behavior.
// -----------------------------------------------------------------------------
class _TrackingInboxRepository extends FakeInboxRepository {
  ServerScopeId? lastFetchServerId;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) {
    lastFetchServerId = serverId;
    return super
        .fetchInbox(serverId, filter: filter, limit: limit, offset: offset);
  }
}

// -----------------------------------------------------------------------------
// Fake that counts the number of fetchInbox calls.
// Used by T2 to verify the auto-load guard prevents double-loading.
// -----------------------------------------------------------------------------
class _LoadCountingInboxRepository extends FakeInboxRepository {
  int loadCount = 0;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) {
    loadCount++;
    return super
        .fetchInbox(serverId, filter: filter, limit: limit, offset: offset);
  }
}
