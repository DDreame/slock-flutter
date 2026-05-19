// =============================================================================
// #602 — HomeAppBarTitle serverListStore Select
//
// Invariant: INV-APPBAR-1
//   App bar title rebuilds only on servers+status changes.
//
// Strategy:
// T1: Verify that changing `isCreating` does NOT notify per-field select
//     (skip:true — current impl watches full state).
// T2: Verify that changing `savingServerIds` does NOT notify per-field select
//     (skip:true — current impl watches full state).
// T3: Verify that changing `servers` DOES notify the per-field select.
// T4: Verify that changing `status` DOES notify the per-field select.
// T5: Anti-pattern proof — full-state watch fires on isCreating change.
//
// Phase A: T1/T2 skip:true — current implementation has no select().
//
// Phase B:
// 1. Replace ref.watch(serverListStoreProvider) with
//    ref.watch(serverListStoreProvider.select(
//      (s) => (status: s.status, servers: s.servers),
//    ))
// 2. Update subsequent references to use the narrowed record.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableServerListStore extends ServerListStore {
  @override
  ServerListState build() => const ServerListState();

  void setIsCreatingDirect(bool value) {
    state = state.copyWith(isCreating: value);
  }

  void setSavingServerIdsDirect(Set<String> ids) {
    state = state.copyWith(savingServerIds: ids);
  }

  void setServersDirect(List<ServerSummary> servers) {
    state = state.copyWith(servers: servers);
  }

  void setStatusDirect(ServerListStatus status) {
    state = state.copyWith(status: status);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: Changing isCreating must NOT notify per-field select.
  //
  // With the current full-state watch, any mutation (including isCreating)
  // causes rebuilds. After Phase B fix (per-field select on status+servers),
  // only those fields notify.
  //
  // skip:true — requires Phase B per-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-APPBAR-1: isCreating change does NOT notify status/servers select',
    () async {
      final container = ProviderContainer(
        overrides: [
          serverListStoreProvider
              .overrideWith(() => _ControllableServerListStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        serverListStoreProvider,
        (_, __) {},
      );

      // Per-field select (the Phase B pattern).
      int selectNotifyCount = 0;
      container.listen(
        serverListStoreProvider.select(
          (s) => (status: s.status, servers: s.servers),
        ),
        (_, __) => selectNotifyCount++,
      );

      // Mutate isCreating.
      final store = container.read(serverListStoreProvider.notifier)
          as _ControllableServerListStore;
      store.setIsCreatingDirect(true);

      // Per-field select must NOT fire.
      expect(
        selectNotifyCount,
        0,
        reason: 'isCreating change must not notify status/servers '
            'select (INV-APPBAR-1)',
      );

      keepAlive.close();
    },
    skip: 'Phase A: requires Phase B per-field select on '
        'serverListStoreProvider in home_page.dart',
  );

  // -------------------------------------------------------------------------
  // T2: Changing savingServerIds must NOT notify per-field select.
  //
  // skip:true — requires Phase B per-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-APPBAR-1: savingServerIds change does NOT notify status/servers '
    'select',
    () async {
      final container = ProviderContainer(
        overrides: [
          serverListStoreProvider
              .overrideWith(() => _ControllableServerListStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        serverListStoreProvider,
        (_, __) {},
      );

      int selectNotifyCount = 0;
      container.listen(
        serverListStoreProvider.select(
          (s) => (status: s.status, servers: s.servers),
        ),
        (_, __) => selectNotifyCount++,
      );

      // Mutate savingServerIds.
      final store = container.read(serverListStoreProvider.notifier)
          as _ControllableServerListStore;
      store.setSavingServerIdsDirect({'server-1'});

      // Per-field select must NOT fire.
      expect(
        selectNotifyCount,
        0,
        reason: 'savingServerIds change must not notify status/servers '
            'select (INV-APPBAR-1)',
      );

      keepAlive.close();
    },
    skip: 'Phase A: requires Phase B per-field select on '
        'serverListStoreProvider in home_page.dart',
  );

  // -------------------------------------------------------------------------
  // T3: Changing servers DOES notify per-field select.
  //
  // This test passes now and after Phase B (consumed fields always fire).
  // -------------------------------------------------------------------------
  test(
    'INV-APPBAR-1: servers change DOES notify select',
    () async {
      final container = ProviderContainer(
        overrides: [
          serverListStoreProvider
              .overrideWith(() => _ControllableServerListStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        serverListStoreProvider,
        (_, __) {},
      );

      int selectNotifyCount = 0;
      container.listen(
        serverListStoreProvider.select(
          (s) => (status: s.status, servers: s.servers),
        ),
        (_, __) => selectNotifyCount++,
      );

      // Mutate servers.
      final store = container.read(serverListStoreProvider.notifier)
          as _ControllableServerListStore;
      store.setServersDirect(const [
        ServerSummary(id: 'server-1', name: 'My Workspace'),
      ]);

      expect(
        selectNotifyCount,
        1,
        reason: 'servers change must notify per-field select',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T4: Changing status DOES notify per-field select.
  //
  // This test passes now and after Phase B.
  // -------------------------------------------------------------------------
  test(
    'INV-APPBAR-1: status change DOES notify select',
    () async {
      final container = ProviderContainer(
        overrides: [
          serverListStoreProvider
              .overrideWith(() => _ControllableServerListStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        serverListStoreProvider,
        (_, __) {},
      );

      int selectNotifyCount = 0;
      container.listen(
        serverListStoreProvider.select(
          (s) => (status: s.status, servers: s.servers),
        ),
        (_, __) => selectNotifyCount++,
      );

      // Mutate status.
      final store = container.read(serverListStoreProvider.notifier)
          as _ControllableServerListStore;
      store.setStatusDirect(ServerListStatus.success);

      expect(
        selectNotifyCount,
        1,
        reason: 'status change must notify per-field select',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T5: Full-state watch fires on isCreating change (anti-pattern proof).
  //
  // Demonstrates the bug: watching the full state causes app bar title
  // rebuilds when a server creation dialog is opened/closed — irrelevant.
  // -------------------------------------------------------------------------
  test(
    'full-state watch fires on isCreating change (anti-pattern proof)',
    () async {
      final container = ProviderContainer(
        overrides: [
          serverListStoreProvider
              .overrideWith(() => _ControllableServerListStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        serverListStoreProvider,
        (_, __) {},
      );

      // Full-state watch (current pattern).
      int fullStateNotifyCount = 0;
      container.listen(
        serverListStoreProvider,
        (_, __) => fullStateNotifyCount++,
      );

      // Mutate isCreating.
      final store = container.read(serverListStoreProvider.notifier)
          as _ControllableServerListStore;
      store.setIsCreatingDirect(true);

      expect(
        fullStateNotifyCount,
        greaterThanOrEqualTo(1),
        reason: 'Full-state watch fires on any mutation (proving the bug)',
      );

      keepAlive.close();
    },
  );
}
