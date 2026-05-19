// =============================================================================
// #587 Phase A — Reconnect Refresh (test-only)
//
// Feature: Inbox automatically refreshes when WebSocket reconnects.
//
// Bug: No state-based listener on realtimeServiceProvider exists to trigger
// inbox refresh when the connection state transitions from
// reconnecting → connected. The existing event-stream binding depends on
// receiving a 'connect' event via the socket, which may not fire in all
// reconnect scenarios.
//
// Phase B: Add a ref.listen(realtimeServiceProvider, ...) binding that
// triggers inboxStore.refresh() on reconnecting → connected transitions.
//
// All tests skip:true — Phase A only.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';

void main() {
  group('Inbox reconnect refresh', () {
    test(
      'T1: Inbox refreshes when realtime state transitions from reconnecting → connected',
      () async {
        final trackingRepo = _TrackingInboxRepository();

        final container = ProviderContainer(
          overrides: [
            inboxRepositoryProvider.overrideWithValue(trackingRepo),
            activeServerScopeIdProvider
                .overrideWith((_) => const ServerScopeId('server-1')),
            realtimeServiceProvider.overrideWith(_FakeRealtimeNotifier.new),
          ],
        );
        addTearDown(container.dispose);

        // Initialize providers.
        container.read(realtimeServiceProvider);
        final fakeRealtime = container.read(realtimeServiceProvider.notifier)
            as _FakeRealtimeNotifier;

        // Trigger initial inbox load.
        await container.read(inboxStoreProvider.notifier).load();
        final initialFetchCount = trackingRepo.fetchCount;

        // Simulate: reconnecting → connected
        fakeRealtime.emitState(const RealtimeConnectionState(
          status: RealtimeConnectionStatus.reconnecting,
          reconnectAttempts: 1,
        ));
        await Future<void>.delayed(Duration.zero);

        fakeRealtime.emitState(const RealtimeConnectionState(
          status: RealtimeConnectionStatus.connected,
        ));
        await Future<void>.delayed(Duration.zero);

        // Inbox should have been refreshed after the reconnect.
        expect(trackingRepo.fetchCount, greaterThan(initialFetchCount),
            reason: 'Inbox must refresh when realtime transitions from '
                'reconnecting → connected.');
      },
    );

    test(
      'T2: No refresh when state is already connected (no spurious reloads)',
      () async {
        final trackingRepo = _TrackingInboxRepository();

        final container = ProviderContainer(
          overrides: [
            inboxRepositoryProvider.overrideWithValue(trackingRepo),
            activeServerScopeIdProvider
                .overrideWith((_) => const ServerScopeId('server-1')),
            realtimeServiceProvider.overrideWith(_FakeRealtimeNotifier.new),
          ],
        );
        addTearDown(container.dispose);

        // Initialize providers.
        container.read(realtimeServiceProvider);
        final fakeRealtime = container.read(realtimeServiceProvider.notifier)
            as _FakeRealtimeNotifier;

        // Start connected.
        fakeRealtime.emitState(const RealtimeConnectionState(
          status: RealtimeConnectionStatus.connected,
        ));
        await Future<void>.delayed(Duration.zero);

        // Trigger initial inbox load.
        await container.read(inboxStoreProvider.notifier).load();
        final countAfterLoad = trackingRepo.fetchCount;

        // Emit connected → connected (same state, no transition).
        fakeRealtime.emitState(const RealtimeConnectionState(
          status: RealtimeConnectionStatus.connected,
        ));
        await Future<void>.delayed(Duration.zero);

        // No spurious refresh should fire.
        expect(trackingRepo.fetchCount, equals(countAfterLoad),
            reason: 'Connected → connected should NOT trigger a refresh. '
                'Only reconnecting → connected should.');
      },
    );

    test(
      'T3: Refresh fires for disconnect → reconnecting → connected cycle',
      () async {
        final trackingRepo = _TrackingInboxRepository();

        final container = ProviderContainer(
          overrides: [
            inboxRepositoryProvider.overrideWithValue(trackingRepo),
            activeServerScopeIdProvider
                .overrideWith((_) => const ServerScopeId('server-1')),
            realtimeServiceProvider.overrideWith(_FakeRealtimeNotifier.new),
          ],
        );
        addTearDown(container.dispose);

        // Initialize providers.
        container.read(realtimeServiceProvider);
        final fakeRealtime = container.read(realtimeServiceProvider.notifier)
            as _FakeRealtimeNotifier;

        // Start connected.
        fakeRealtime.emitState(const RealtimeConnectionState(
          status: RealtimeConnectionStatus.connected,
        ));
        await Future<void>.delayed(Duration.zero);

        // Trigger initial inbox load.
        await container.read(inboxStoreProvider.notifier).load();

        // Full lifecycle: connected → disconnected → reconnecting → connected.
        fakeRealtime.emitState(const RealtimeConnectionState(
          status: RealtimeConnectionStatus.disconnected,
        ));
        await Future<void>.delayed(Duration.zero);

        fakeRealtime.emitState(const RealtimeConnectionState(
          status: RealtimeConnectionStatus.reconnecting,
          reconnectAttempts: 1,
        ));
        await Future<void>.delayed(Duration.zero);

        final countBeforeReconnect = trackingRepo.fetchCount;

        fakeRealtime.emitState(const RealtimeConnectionState(
          status: RealtimeConnectionStatus.connected,
        ));
        await Future<void>.delayed(Duration.zero);

        // Exactly 1 refresh on the final connected transition.
        expect(
          trackingRepo.fetchCount,
          equals(countBeforeReconnect + 1),
          reason: 'Exactly 1 refresh expected on reconnecting → connected. '
              'No refresh on disconnected or reconnecting states.',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Fake realtime notifier that allows manual state emission
// ---------------------------------------------------------------------------

class _FakeRealtimeNotifier extends RealtimeService {
  @override
  RealtimeConnectionState build() => const RealtimeConnectionState();

  void emitState(RealtimeConnectionState newState) {
    state = newState;
  }

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> forceReconnect({required String reason}) async {}
}

// ---------------------------------------------------------------------------
// Tracking repository for refresh count verification
// ---------------------------------------------------------------------------

class _TrackingInboxRepository implements InboxRepository {
  int fetchCount = 0;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    fetchCount++;
    return const InboxResponse(
      items: [],
      totalCount: 0,
      totalUnreadCount: 0,
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
}
