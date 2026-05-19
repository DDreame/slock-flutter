// =============================================================================
// #602 — HomeAppBarTitle serverListStore Select
//
// Invariant: INV-APPBAR-1
//   App bar title rebuilds only on servers+status changes.
//
// Phase B: lib fix applied — ref.watch uses .select() on
// (status, servers) record. All tests active.
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
  );

  // -------------------------------------------------------------------------
  // T2: Changing savingServerIds must NOT notify per-field select.
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
  );

  // -------------------------------------------------------------------------
  // T3: Changing servers DOES notify per-field select.
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
}
