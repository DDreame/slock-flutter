// =============================================================================
// #624 — Server switcher + new DM page .select() narrows
//
// Invariant: INV-SERVER-SWITCHER-SELECT-1
//   server_switcher_sheet.dart L33 calls
//   ref.watch(serverListStoreProvider) — the full ~8-field state.
//   The sheet only consumes: isCreating, isJoiningInvite, status, failure,
//   servers. Mutations to savingServerIds, deletingServerIds, leavingServerIds
//   MUST NOT trigger a sheet rebuild.
//
// Invariant: INV-NEW-DM-AGENTS-SELECT-1
//   new_dm_page.dart L68 calls ref.watch(agentsStoreProvider) — keep-alive
//   pattern. Only needs status for SWR triggering. Mutations to items,
//   machines, activityLogs, isRefreshing, isCreating MUST NOT fire.
//   L236 calls ref.watch(agentsStoreProvider) in agent list widget —
//   only needs status, items, failure. Mutations to machines, activityLogs,
//   isRefreshing, isCreating MUST NOT fire.
//
// Strategy:
// T1: savingServerIds change must NOT fire server switcher select (skip:true).
// T2: isCreating change DOES fire server switcher select (active).
// T3: isRefreshing change must NOT fire new DM keep-alive select (skip:true).
// T4: status change DOES fire new DM keep-alive select (active).
// T5: machines change must NOT fire new DM agent list select (skip:true).
// T6: items change DOES fire new DM agent list select (active).
//
// Phase A: T1/T3/T5 skip:true — current impl watches full state.
//          T2/T4/T6 active — correctness proof.
//
// Phase B:
// - server_switcher_sheet.dart L33: .select((s) => (isCreating, isJoiningInvite, status, failure, servers))
// - new_dm_page.dart L68: .select((s) => s.status)
// - new_dm_page.dart L236: .select((s) => (status, items, failure))
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/machines/data/machine_item.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableServerListStore extends ServerListStore {
  @override
  ServerListState build() => const ServerListState(
        status: ServerListStatus.success,
      );

  void setSavingServerIdsDirect(Set<String> ids) {
    state = state.copyWith(savingServerIds: ids);
  }

  void setIsCreatingDirect(bool value) {
    state = state.copyWith(isCreating: value);
  }
}

class _ControllableAgentsStore extends AgentsStore {
  @override
  AgentsState build() => const AgentsState(
        status: AgentsStatus.success,
        items: [
          AgentItem(
            id: 'agent-1',
            name: 'bot',
            model: 'claude',
            runtime: 'claude-code',
            status: 'online',
            activity: 'idle',
          ),
        ],
      );

  void setIsRefreshingDirect(bool value) {
    state = state.copyWith(isRefreshing: value);
  }

  void setStatusDirect(AgentsStatus status) {
    state = state.copyWith(status: status);
  }

  void setMachinesDirect(List<MachineItem> machines) {
    state = state.copyWith(machines: machines);
  }

  void setItemsDirect(List<AgentItem> items) {
    state = state.copyWith(items: items);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // Server switcher — INV-SERVER-SWITCHER-SELECT-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T1: savingServerIds change must NOT fire server switcher select.
  // -------------------------------------------------------------------------
  test(
    'INV-SERVER-SWITCHER-SELECT-1: savingServerIds change does NOT notify '
    'server switcher select',
    skip: true,
    () async {
      final container = ProviderContainer(
        overrides: [
          serverListStoreProvider
              .overrideWith(() => _ControllableServerListStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(serverListStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        serverListStoreProvider.select(
          (s) => (
            isCreating: s.isCreating,
            isJoiningInvite: s.isJoiningInvite,
            status: s.status,
            failure: s.failure,
            servers: s.servers,
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(serverListStoreProvider.notifier)
          as _ControllableServerListStore;
      store.setSavingServerIdsDirect({'srv-1'});

      expect(
        selectNotifyCount,
        0,
        reason: 'savingServerIds change must not notify server switcher select '
            '(INV-SERVER-SWITCHER-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: isCreating change DOES fire server switcher select.
  // -------------------------------------------------------------------------
  test(
    'INV-SERVER-SWITCHER-SELECT-1: isCreating change DOES notify '
    'server switcher select',
    () async {
      final container = ProviderContainer(
        overrides: [
          serverListStoreProvider
              .overrideWith(() => _ControllableServerListStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(serverListStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        serverListStoreProvider.select(
          (s) => (
            isCreating: s.isCreating,
            isJoiningInvite: s.isJoiningInvite,
            status: s.status,
            failure: s.failure,
            servers: s.servers,
          ),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(serverListStoreProvider.notifier)
          as _ControllableServerListStore;
      store.setIsCreatingDirect(true);

      expect(
        selectNotifyCount,
        1,
        reason: 'isCreating change must notify server switcher select',
      );

      keepAlive.close();
    },
  );

  // =========================================================================
  // New DM page — INV-NEW-DM-AGENTS-SELECT-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T3: isRefreshing change must NOT fire new DM keep-alive select.
  // -------------------------------------------------------------------------
  test(
    'INV-NEW-DM-AGENTS-SELECT-1: isRefreshing change does NOT notify '
    'status-only select',
    skip: true,
    () async {
      final container = ProviderContainer(
        overrides: [
          agentsStoreProvider.overrideWith(() => _ControllableAgentsStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(agentsStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        agentsStoreProvider.select((s) => s.status),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(agentsStoreProvider.notifier)
          as _ControllableAgentsStore;
      store.setIsRefreshingDirect(true);

      expect(
        selectNotifyCount,
        0,
        reason: 'isRefreshing change must not notify status-only select '
            '(INV-NEW-DM-AGENTS-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T4: status change DOES fire new DM keep-alive select.
  // -------------------------------------------------------------------------
  test(
    'INV-NEW-DM-AGENTS-SELECT-1: status change DOES notify '
    'status-only select',
    () async {
      final container = ProviderContainer(
        overrides: [
          agentsStoreProvider.overrideWith(() => _ControllableAgentsStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(agentsStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        agentsStoreProvider.select((s) => s.status),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(agentsStoreProvider.notifier)
          as _ControllableAgentsStore;
      store.setStatusDirect(AgentsStatus.loading);

      expect(
        selectNotifyCount,
        1,
        reason: 'status change must notify status-only select',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T5: machines change must NOT fire new DM agent list select.
  // -------------------------------------------------------------------------
  test(
    'INV-NEW-DM-AGENTS-SELECT-1: machines change does NOT notify '
    '(status, items, failure) select',
    skip: true,
    () async {
      final container = ProviderContainer(
        overrides: [
          agentsStoreProvider.overrideWith(() => _ControllableAgentsStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(agentsStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        agentsStoreProvider.select(
          (s) => (status: s.status, items: s.items, failure: s.failure),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(agentsStoreProvider.notifier)
          as _ControllableAgentsStore;
      store.setMachinesDirect([
        const MachineItem(id: 'machine-1', name: 'runner'),
      ]);

      expect(
        selectNotifyCount,
        0,
        reason: 'machines change must not notify '
            '(status, items, failure) select '
            '(INV-NEW-DM-AGENTS-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T6: items change DOES fire new DM agent list select.
  // -------------------------------------------------------------------------
  test(
    'INV-NEW-DM-AGENTS-SELECT-1: items change DOES notify '
    '(status, items, failure) select',
    () async {
      final container = ProviderContainer(
        overrides: [
          agentsStoreProvider.overrideWith(() => _ControllableAgentsStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(agentsStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        agentsStoreProvider.select(
          (s) => (status: s.status, items: s.items, failure: s.failure),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(agentsStoreProvider.notifier)
          as _ControllableAgentsStore;
      store.setItemsDirect([
        const AgentItem(
          id: 'agent-2',
          name: 'helper',
          model: 'claude',
          runtime: 'claude-code',
          status: 'offline',
          activity: 'idle',
        ),
      ]);

      expect(
        selectNotifyCount,
        1,
        reason: 'items change must notify (status, items, failure) select',
      );

      keepAlive.close();
    },
  );
}
