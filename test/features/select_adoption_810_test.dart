// =============================================================================
// #810 — .select() Adoption B: WorkspaceSettings + ServerSwitcherSheet
//
// Invariant: INV-SELECT-810
//   WorkspaceSettingsPage must only rebuild when status, servers, or failure
//   change.
//   _ServerList (server_switcher_sheet) must only rebuild when the per-server
//   busy sets change (savingServerIds, deletingServerIds, leavingServerIds).
//
// Strategy:
// T1: serverList: isCreating change must NOT fire workspace select.
// T2: serverList: isJoiningInvite change must NOT fire workspace select.
// T3: serverList: savingServerIds change must NOT fire workspace select.
// T4: serverList: status change DOES fire workspace select.
// T5: serverList: servers change DOES fire workspace select.
// T6: serverList: status change must NOT fire switcher busy-set select.
// T7: serverList: isCreating change must NOT fire switcher busy-set select.
// T8: serverList: savingServerIds change DOES fire switcher busy-set select.
// T9: serverList: deletingServerIds change DOES fire switcher busy-set select.
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
  ServerListState build() => const ServerListState(
        status: ServerListStatus.success,
        servers: [
          ServerSummary(
            id: 's1',
            name: 'Test Server',
            slug: 'test',
            role: 'owner',
          ),
        ],
      );

  void setIsCreatingDirect(bool value) {
    state = state.copyWith(isCreating: value);
  }

  void setIsJoiningInviteDirect(bool value) {
    state = state.copyWith(isJoiningInvite: value);
  }

  void setSavingServerIdsDirect(Set<String> ids) {
    state = state.copyWith(savingServerIds: ids);
  }

  void setDeletingServerIdsDirect(Set<String> ids) {
    state = state.copyWith(deletingServerIds: ids);
  }

  void setStatusDirect(ServerListStatus status) {
    state = state.copyWith(status: status);
  }

  void setServersDirect(List<ServerSummary> servers) {
    state = state.copyWith(servers: servers);
  }
}

// ---------------------------------------------------------------------------
// Tests — WorkspaceSettingsPage select narrowing
// ---------------------------------------------------------------------------

void main() {
  group('INV-SELECT-810: WorkspaceSettingsPage — serverListStore select', () {
    // -------------------------------------------------------------------------
    // T1: isCreating change must NOT fire workspace (status, servers, failure).
    // -------------------------------------------------------------------------
    test(
      'isCreating change does NOT notify (status, servers, failure) select',
      () {
        final container = ProviderContainer(
          overrides: [
            serverListStoreProvider
                .overrideWith(() => _ControllableServerListStore()),
          ],
        );
        addTearDown(container.dispose);

        container.listen(serverListStoreProvider, (_, __) {});

        int selectNotifyCount = 0;
        container.listen(
          serverListStoreProvider.select(
            (s) => (status: s.status, servers: s.servers, failure: s.failure),
          ),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(serverListStoreProvider.notifier)
            as _ControllableServerListStore;
        store.setIsCreatingDirect(true);

        expect(
          selectNotifyCount,
          0,
          reason: 'isCreating change must not notify consumed fields '
              '(INV-SELECT-810)',
        );
      },
    );

    // -------------------------------------------------------------------------
    // T2: isJoiningInvite change must NOT fire workspace select.
    // -------------------------------------------------------------------------
    test(
      'isJoiningInvite change does NOT notify (status, servers, failure) select',
      () {
        final container = ProviderContainer(
          overrides: [
            serverListStoreProvider
                .overrideWith(() => _ControllableServerListStore()),
          ],
        );
        addTearDown(container.dispose);

        container.listen(serverListStoreProvider, (_, __) {});

        int selectNotifyCount = 0;
        container.listen(
          serverListStoreProvider.select(
            (s) => (status: s.status, servers: s.servers, failure: s.failure),
          ),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(serverListStoreProvider.notifier)
            as _ControllableServerListStore;
        store.setIsJoiningInviteDirect(true);

        expect(
          selectNotifyCount,
          0,
          reason: 'isJoiningInvite change must not notify consumed fields '
              '(INV-SELECT-810)',
        );
      },
    );

    // -------------------------------------------------------------------------
    // T3: savingServerIds change must NOT fire workspace select.
    // -------------------------------------------------------------------------
    test(
      'savingServerIds change does NOT notify (status, servers, failure) select',
      () {
        final container = ProviderContainer(
          overrides: [
            serverListStoreProvider
                .overrideWith(() => _ControllableServerListStore()),
          ],
        );
        addTearDown(container.dispose);

        container.listen(serverListStoreProvider, (_, __) {});

        int selectNotifyCount = 0;
        container.listen(
          serverListStoreProvider.select(
            (s) => (status: s.status, servers: s.servers, failure: s.failure),
          ),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(serverListStoreProvider.notifier)
            as _ControllableServerListStore;
        store.setSavingServerIdsDirect({'s1'});

        expect(
          selectNotifyCount,
          0,
          reason: 'savingServerIds change must not notify consumed fields '
              '(INV-SELECT-810)',
        );
      },
    );

    // -------------------------------------------------------------------------
    // T4: status change DOES fire workspace select.
    // -------------------------------------------------------------------------
    test(
      'status change DOES notify (status, servers, failure) select',
      () {
        final container = ProviderContainer(
          overrides: [
            serverListStoreProvider
                .overrideWith(() => _ControllableServerListStore()),
          ],
        );
        addTearDown(container.dispose);

        container.listen(serverListStoreProvider, (_, __) {});

        int selectNotifyCount = 0;
        container.listen(
          serverListStoreProvider.select(
            (s) => (status: s.status, servers: s.servers, failure: s.failure),
          ),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(serverListStoreProvider.notifier)
            as _ControllableServerListStore;
        store.setStatusDirect(ServerListStatus.loading);

        expect(
          selectNotifyCount,
          1,
          reason: 'status change must notify consumed fields',
        );
      },
    );

    // -------------------------------------------------------------------------
    // T5: servers change DOES fire workspace select.
    // -------------------------------------------------------------------------
    test(
      'servers change DOES notify (status, servers, failure) select',
      () {
        final container = ProviderContainer(
          overrides: [
            serverListStoreProvider
                .overrideWith(() => _ControllableServerListStore()),
          ],
        );
        addTearDown(container.dispose);

        container.listen(serverListStoreProvider, (_, __) {});

        int selectNotifyCount = 0;
        container.listen(
          serverListStoreProvider.select(
            (s) => (status: s.status, servers: s.servers, failure: s.failure),
          ),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(serverListStoreProvider.notifier)
            as _ControllableServerListStore;
        store.setServersDirect(const [
          ServerSummary(
            id: 's1',
            name: 'Test Server',
            slug: 'test',
            role: 'owner',
          ),
          ServerSummary(
            id: 's2',
            name: 'New Server',
            slug: 'new',
            role: 'member',
          ),
        ]);

        expect(
          selectNotifyCount,
          1,
          reason: 'servers change must notify consumed fields',
        );
      },
    );
  });

  group(
      'INV-SELECT-810: ServerSwitcherSheet._ServerList — busy-set select narrowing',
      () {
    // -------------------------------------------------------------------------
    // T6: status change must NOT fire busy-set select.
    // -------------------------------------------------------------------------
    test(
      'status change does NOT notify busy-set select',
      () {
        final container = ProviderContainer(
          overrides: [
            serverListStoreProvider
                .overrideWith(() => _ControllableServerListStore()),
          ],
        );
        addTearDown(container.dispose);

        container.listen(serverListStoreProvider, (_, __) {});

        int selectNotifyCount = 0;
        container.listen(
          serverListStoreProvider.select(
            (s) => (
              savingServerIds: s.savingServerIds,
              deletingServerIds: s.deletingServerIds,
              leavingServerIds: s.leavingServerIds,
            ),
          ),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(serverListStoreProvider.notifier)
            as _ControllableServerListStore;
        store.setStatusDirect(ServerListStatus.loading);

        expect(
          selectNotifyCount,
          0,
          reason: 'status change must not notify busy-set fields '
              '(INV-SELECT-810)',
        );
      },
    );

    // -------------------------------------------------------------------------
    // T7: isCreating change must NOT fire busy-set select.
    // -------------------------------------------------------------------------
    test(
      'isCreating change does NOT notify busy-set select',
      () {
        final container = ProviderContainer(
          overrides: [
            serverListStoreProvider
                .overrideWith(() => _ControllableServerListStore()),
          ],
        );
        addTearDown(container.dispose);

        container.listen(serverListStoreProvider, (_, __) {});

        int selectNotifyCount = 0;
        container.listen(
          serverListStoreProvider.select(
            (s) => (
              savingServerIds: s.savingServerIds,
              deletingServerIds: s.deletingServerIds,
              leavingServerIds: s.leavingServerIds,
            ),
          ),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(serverListStoreProvider.notifier)
            as _ControllableServerListStore;
        store.setIsCreatingDirect(true);

        expect(
          selectNotifyCount,
          0,
          reason: 'isCreating change must not notify busy-set fields '
              '(INV-SELECT-810)',
        );
      },
    );

    // -------------------------------------------------------------------------
    // T8: savingServerIds change DOES fire busy-set select.
    // -------------------------------------------------------------------------
    test(
      'savingServerIds change DOES notify busy-set select',
      () {
        final container = ProviderContainer(
          overrides: [
            serverListStoreProvider
                .overrideWith(() => _ControllableServerListStore()),
          ],
        );
        addTearDown(container.dispose);

        container.listen(serverListStoreProvider, (_, __) {});

        int selectNotifyCount = 0;
        container.listen(
          serverListStoreProvider.select(
            (s) => (
              savingServerIds: s.savingServerIds,
              deletingServerIds: s.deletingServerIds,
              leavingServerIds: s.leavingServerIds,
            ),
          ),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(serverListStoreProvider.notifier)
            as _ControllableServerListStore;
        store.setSavingServerIdsDirect({'s1'});

        expect(
          selectNotifyCount,
          1,
          reason: 'savingServerIds change must notify busy-set fields',
        );
      },
    );

    // -------------------------------------------------------------------------
    // T9: deletingServerIds change DOES fire busy-set select.
    // -------------------------------------------------------------------------
    test(
      'deletingServerIds change DOES notify busy-set select',
      () {
        final container = ProviderContainer(
          overrides: [
            serverListStoreProvider
                .overrideWith(() => _ControllableServerListStore()),
          ],
        );
        addTearDown(container.dispose);

        container.listen(serverListStoreProvider, (_, __) {});

        int selectNotifyCount = 0;
        container.listen(
          serverListStoreProvider.select(
            (s) => (
              savingServerIds: s.savingServerIds,
              deletingServerIds: s.deletingServerIds,
              leavingServerIds: s.leavingServerIds,
            ),
          ),
          (_, __) => selectNotifyCount++,
        );

        final store = container.read(serverListStoreProvider.notifier)
            as _ControllableServerListStore;
        store.setDeletingServerIdsDirect({'s1'});

        expect(
          selectNotifyCount,
          1,
          reason: 'deletingServerIds change must notify busy-set fields',
        );
      },
    );
  });
}
