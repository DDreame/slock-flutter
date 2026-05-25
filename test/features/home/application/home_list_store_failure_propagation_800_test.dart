// =============================================================================
// #800 — HomeListStore Failure Propagation + ThreadReplies/Tasks .select()
//
// P2-3: HomeListStore.load() silently swallowed API failure when cached data
// existed. Now propagates failure alongside success status for UI indicator.
//
// P2-4: ThreadRepliesPage .select() — verified by code review (perf-only,
// no observable state change to assert in unit tests).
//
// P2-5: TasksPage .select() — verified by code review (includes failure
// in select record, uses local var instead of ref.read).
//
// Invariants verified:
//   INV-800-1: Load with cache + API failure → success status + failure set
//   INV-800-2: Load without cache + API failure → failure status (unchanged)
//   INV-800-3: Load with cache + API success → success status, no failure
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';

import '../../../support/support.dart';

void main() {
  group('#800 — HomeListStore failure propagation when cached', () {
    // -------------------------------------------------------------------------
    // INV-800-1: Cache exists + API fails → failure propagated (not swallowed)
    // -------------------------------------------------------------------------
    test(
      'load with cache + API failure → success status + failure set '
      '(INV-800-1)',
      () async {
        const failure = ServerFailure(
          message: 'Service unavailable',
          statusCode: 503,
        );
        final fixture = RuntimeAppFixture();
        // Seed cache so HomeListStore enters the cached path.
        fixture.homeRepository.cachedSnapshot = const HomeWorkspaceSnapshot(
          serverId: ServerScopeId('server-1'),
          channels: [
            HomeChannelSummary(
              scopeId: ChannelScopeId(
                serverId: ServerScopeId('server-1'),
                value: 'general',
              ),
              name: 'general',
            ),
          ],
          directMessages: [],
        );
        // API call fails.
        fixture.homeRepository.failure = failure;
        await fixture.boot();
        addTearDown(fixture.dispose);

        await fixture.container.read(homeListStoreProvider.notifier).load();
        final state = fixture.container.read(homeListStoreProvider);

        // Status remains success (cached data displayed).
        expect(state.status, HomeListStatus.success);
        // Failure is now propagated — not silently swallowed.
        expect(state.failure, failure,
            reason: 'Failure should be propagated alongside cached data');
        // Cached data is still present.
        expect(state.channels.single.name, 'general');
      },
    );

    // -------------------------------------------------------------------------
    // INV-800-2: No cache + API fails → failure status (existing behavior)
    // -------------------------------------------------------------------------
    test(
      'load without cache + API failure → failure status (INV-800-2)',
      () async {
        const failure = ServerFailure(
          message: 'Service unavailable',
          statusCode: 503,
        );
        final fixture = RuntimeAppFixture();
        // No cached snapshot.
        fixture.homeRepository.cachedSnapshot = null;
        fixture.homeRepository.failure = failure;
        await fixture.boot();
        addTearDown(fixture.dispose);

        await fixture.container.read(homeListStoreProvider.notifier).load();
        final state = fixture.container.read(homeListStoreProvider);

        expect(state.status, HomeListStatus.failure);
        expect(state.failure, failure);
      },
    );

    // -------------------------------------------------------------------------
    // INV-800-3: Cache exists + API succeeds → no failure, fresh data
    // -------------------------------------------------------------------------
    test(
      'load with cache + API success → success status, no failure '
      '(INV-800-3)',
      () async {
        final fixture = RuntimeAppFixture();
        fixture.homeRepository.cachedSnapshot = const HomeWorkspaceSnapshot(
          serverId: ServerScopeId('server-1'),
          channels: [
            HomeChannelSummary(
              scopeId: ChannelScopeId(
                serverId: ServerScopeId('server-1'),
                value: 'stale-channel',
              ),
              name: 'stale-channel',
            ),
          ],
          directMessages: [],
        );
        fixture.homeRepository.snapshot = const HomeWorkspaceSnapshot(
          serverId: ServerScopeId('server-1'),
          channels: [
            HomeChannelSummary(
              scopeId: ChannelScopeId(
                serverId: ServerScopeId('server-1'),
                value: 'fresh-channel',
              ),
              name: 'fresh-channel',
            ),
          ],
          directMessages: [],
        );
        await fixture.boot();
        addTearDown(fixture.dispose);

        await fixture.container.read(homeListStoreProvider.notifier).load();
        final state = fixture.container.read(homeListStoreProvider);

        expect(state.status, HomeListStatus.success);
        expect(state.failure, isNull);
        expect(state.channels.single.name, 'fresh-channel');
      },
    );
  });
}
