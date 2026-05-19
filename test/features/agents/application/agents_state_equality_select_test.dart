// =============================================================================
// #634 — AgentsState ==/hashCode + page + projection .select()
//
// Invariant: INV-AGENTS-STATE-EQUALITY-1
//   agents_state.dart:
//   AgentsState is @immutable but has no operator == / hashCode override.
//   Riverpod falls back to reference equality — every copyWith() that returns
//   a new instance notifies all watchers even if data is logically unchanged.
//   Phase B adds == / hashCode using listEquals/setEquals/mapEquals.
//
// Invariant: INV-AGENTS-PROJECTION-SELECT-1
//   agent_status_group_projection.dart L14:
//   ref.watch(agentsStoreProvider) watches full state.
//   Projection only needs status + items. activityLogs/savingAgentIds/etc
//   mutations must NOT trigger recomputation.
//   Phase B narrows to .select((s) => (status: s.status, items: s.items)).
//
// Invariant: INV-AGENTS-PAGE-SELECT-1
//   agents_page.dart L46:
//   ref.watch(agentsStoreProvider) watches full state.
//   Page list view only needs status + items + isCreating.
//   activityLogs mutations must NOT trigger page rebuild.
//   Phase B narrows page watch to consumed fields.
//
// Strategy:
// T1: AgentsState with identical fields must be == (skip:true — no == impl).
// T2: AgentsState.hashCode must match for equal instances (skip:true).
// T3: activityLogs change must NOT fire projection (status,items) select
//     (skip:true — currently watches full state).
// T4: status change DOES fire projection (status,items) select (active).
// T5: activityLogs change must NOT fire page (status,items,isCreating) select
//     (skip:true — currently watches full state).
// T6: items change DOES fire page select (active).
//
// Phase A: T1-T3/T5 skip:true, T4/T6 active.
// Phase B: Add ==/hashCode, narrow watches, un-skip T1-T3/T5.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableAgentsStore extends AgentsStore {
  @override
  AgentsState build() {
    return const AgentsState(
      status: AgentsStatus.success,
      items: _items,
    );
  }

  static const _items = [
    AgentItem(
      id: 'agent-1',
      name: 'testbot',
      model: 'claude-4',
      runtime: 'claude-code',
      status: 'active',
      activity: 'idle',
    ),
  ];

  void setActivityLogsDirect(Map<String, List<AgentActivityLogEntry>> logs) {
    state = state.copyWith(activityLogs: logs);
  }

  void setStatusDirect(AgentsStatus status) {
    state = state.copyWith(status: status);
  }

  void setItemsDirect(List<AgentItem> items) {
    state = state.copyWith(items: items);
  }

  void setIsCreatingDirect(bool value) {
    state = state.copyWith(isCreating: value);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // INV-AGENTS-STATE-EQUALITY-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T1: AgentsState with identical fields must be ==.
  // -------------------------------------------------------------------------
  test(
    'INV-AGENTS-STATE-EQUALITY-1: AgentsState with identical fields is ==',
    () {
      const item = AgentItem(
        id: 'agent-1',
        name: 'bot',
        model: 'claude-4',
        runtime: 'claude-code',
        status: 'active',
        activity: 'idle',
      );
      final items = [item];
      final a = AgentsState(status: AgentsStatus.success, items: items);
      final b = AgentsState(status: AgentsStatus.success, items: items);

      expect(a == b, true,
          reason: 'AgentsState with same fields must be equal '
              '(INV-AGENTS-STATE-EQUALITY-1)');
    },
  );

  // -------------------------------------------------------------------------
  // T2: hashCode must match for equal instances.
  // -------------------------------------------------------------------------
  test(
    'INV-AGENTS-STATE-EQUALITY-1: hashCode matches for equal instances',
    () {
      const item = AgentItem(
        id: 'agent-1',
        name: 'bot',
        model: 'claude-4',
        runtime: 'claude-code',
        status: 'active',
        activity: 'idle',
      );
      final items = [item];
      final a = AgentsState(status: AgentsStatus.success, items: items);
      final b = AgentsState(status: AgentsStatus.success, items: items);

      expect(a.hashCode, b.hashCode,
          reason: 'equal AgentsState instances must have equal hashCodes');
    },
  );

  // =========================================================================
  // INV-AGENTS-PROJECTION-SELECT-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T3: activityLogs change must NOT fire projection (status,items) select.
  // -------------------------------------------------------------------------
  test(
    'INV-AGENTS-PROJECTION-SELECT-1: activityLogs change does NOT notify '
    '(status,items) select',
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
        agentsStoreProvider.select((s) => (status: s.status, items: s.items)),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(agentsStoreProvider.notifier)
          as _ControllableAgentsStore;
      store.setActivityLogsDirect({
        'agent-1': [
          AgentActivityLogEntry(
            timestamp: DateTime.parse('2026-05-19T12:00:00Z'),
            entry: 'Did something',
          ),
        ],
      });

      expect(
        selectNotifyCount,
        0,
        reason: 'activityLogs change must not notify (status,items) select '
            '(INV-AGENTS-PROJECTION-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T4: status change DOES fire projection (status,items) select.
  // -------------------------------------------------------------------------
  test(
    'INV-AGENTS-PROJECTION-SELECT-1: status change DOES notify '
    '(status,items) select',
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
        agentsStoreProvider.select((s) => (status: s.status, items: s.items)),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(agentsStoreProvider.notifier)
          as _ControllableAgentsStore;
      store.setStatusDirect(AgentsStatus.loading);

      expect(
        selectNotifyCount,
        1,
        reason: 'status change must notify (status,items) select',
      );

      keepAlive.close();
    },
  );

  // =========================================================================
  // INV-AGENTS-PAGE-SELECT-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T5: activityLogs change must NOT fire page (status,items,isCreating) select.
  // -------------------------------------------------------------------------
  test(
    'INV-AGENTS-PAGE-SELECT-1: activityLogs change does NOT notify '
    '(status,items,isCreating) select',
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
        agentsStoreProvider.select((s) =>
            (status: s.status, items: s.items, isCreating: s.isCreating)),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(agentsStoreProvider.notifier)
          as _ControllableAgentsStore;
      store.setActivityLogsDirect({
        'agent-1': [
          AgentActivityLogEntry(
            timestamp: DateTime.parse('2026-05-19T12:00:00Z'),
            entry: 'Activity log update',
          ),
        ],
      });

      expect(
        selectNotifyCount,
        0,
        reason: 'activityLogs change must not notify page select '
            '(INV-AGENTS-PAGE-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T6: items change DOES fire page (status,items,isCreating) select.
  // -------------------------------------------------------------------------
  test(
    'INV-AGENTS-PAGE-SELECT-1: items change DOES notify '
    '(status,items,isCreating) select',
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
        agentsStoreProvider.select((s) =>
            (status: s.status, items: s.items, isCreating: s.isCreating)),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(agentsStoreProvider.notifier)
          as _ControllableAgentsStore;
      store.setItemsDirect(const [
        AgentItem(
          id: 'agent-1',
          name: 'testbot',
          model: 'claude-4',
          runtime: 'claude-code',
          status: 'active',
          activity: 'idle',
        ),
        AgentItem(
          id: 'agent-2',
          name: 'newbot',
          model: 'claude-4',
          runtime: 'claude-code',
          status: 'active',
          activity: 'thinking',
        ),
      ]);

      expect(
        selectNotifyCount,
        1,
        reason: 'items change must notify page select',
      );

      keepAlive.close();
    },
  );
}
