// =============================================================================
// #595 — Home Agents agentsStore Select Optimization
//
// Invariant: INV-HOME-AGENTS-SELECT-1
//   Home agents section rebuilds only on count+status fields.
//
// Strategy:
// T1: Verify that changing `activityLogs` does NOT notify count+status select
//     (skip:true — current impl watches full state).
// T2: Verify that changing `savingAgentIds` does NOT notify count+status select
//     (skip:true — current impl watches full state).
// T3: Verify that changing `items.length` DOES notify the select.
// T4: Verify that changing `status` DOES notify the select.
// T5: Anti-pattern proof — full-state watch fires on activityLogs change.
//
// Phase A: T1/T2 skip:true — current implementation has no select().
//
// Phase B:
// 1. Replace ref.watch(agentsStoreProvider) with
//    ref.watch(agentsStoreProvider.select(
//      (s) => (count: s.items.length, status: s.status),
//    ))
// 2. Update references to use the narrowed record.
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
  AgentsState build() => const AgentsState();

  void setActivityLogs(Map<String, List<AgentActivityLogEntry>> logs) {
    state = state.copyWith(activityLogs: logs);
  }

  void setSavingAgentIds(Set<String> ids) {
    state = state.copyWith(savingAgentIds: ids);
  }

  void setItems(List<AgentItem> items) {
    state = state.copyWith(items: items);
  }

  void setStatus(AgentsStatus status) {
    state = state.copyWith(status: status);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: Changing activityLogs must NOT notify count+status select.
  //
  // With the current full-state watch, any mutation (including activityLogs)
  // causes rebuilds. After Phase B fix (count+status select), only
  // items.length and status changes notify.
  //
  // skip:true — requires Phase B per-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-HOME-AGENTS-SELECT-1: activityLogs change does NOT notify '
    'count+status select',
    () async {
      final container = ProviderContainer(
        overrides: [
          agentsStoreProvider.overrideWith(() => _ControllableAgentsStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        agentsStoreProvider,
        (_, __) {},
      );

      // Count+status select (the Phase B pattern).
      int selectNotifyCount = 0;
      container.listen(
        agentsStoreProvider
            .select((s) => (count: s.items.length, status: s.status)),
        (_, __) => selectNotifyCount++,
      );

      // Mutate activityLogs.
      final store = container.read(agentsStoreProvider.notifier)
          as _ControllableAgentsStore;
      store.setActivityLogs({
        'agent-1': [
          AgentActivityLogEntry(
            entry: 'Running task',
            timestamp: DateTime.parse('2026-05-19T10:00:00Z'),
          ),
        ],
      });

      // Count+status select must NOT fire.
      expect(
        selectNotifyCount,
        0,
        reason: 'activityLogs change must not notify count+status select '
            '(INV-HOME-AGENTS-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: Changing savingAgentIds must NOT notify count+status select.
  //
  // skip:true — requires Phase B per-field select.
  // -------------------------------------------------------------------------
  test(
    'INV-HOME-AGENTS-SELECT-1: savingAgentIds change does NOT notify '
    'count+status select',
    () async {
      final container = ProviderContainer(
        overrides: [
          agentsStoreProvider.overrideWith(() => _ControllableAgentsStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        agentsStoreProvider,
        (_, __) {},
      );

      int selectNotifyCount = 0;
      container.listen(
        agentsStoreProvider
            .select((s) => (count: s.items.length, status: s.status)),
        (_, __) => selectNotifyCount++,
      );

      // Mutate savingAgentIds.
      final store = container.read(agentsStoreProvider.notifier)
          as _ControllableAgentsStore;
      store.setSavingAgentIds({'agent-1', 'agent-2'});

      // Count+status select must NOT fire.
      expect(
        selectNotifyCount,
        0,
        reason: 'savingAgentIds change must not notify count+status select '
            '(INV-HOME-AGENTS-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: Changing items.length DOES notify count+status select.
  //
  // This test passes now and after Phase B (consumed fields always fire).
  // -------------------------------------------------------------------------
  test(
    'INV-HOME-AGENTS-SELECT-1: items.length change DOES notify select',
    () async {
      final container = ProviderContainer(
        overrides: [
          agentsStoreProvider.overrideWith(() => _ControllableAgentsStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        agentsStoreProvider,
        (_, __) {},
      );

      int selectNotifyCount = 0;
      container.listen(
        agentsStoreProvider
            .select((s) => (count: s.items.length, status: s.status)),
        (_, __) => selectNotifyCount++,
      );

      // Add an agent (changes items.length from 0 → 1).
      final store = container.read(agentsStoreProvider.notifier)
          as _ControllableAgentsStore;
      store.setItems([
        const AgentItem(
          id: 'agent-1',
          name: 'test-agent',
          model: 'claude-sonnet',
          runtime: 'docker',
          status: 'active',
          activity: 'idle',
        ),
      ]);

      expect(
        selectNotifyCount,
        1,
        reason: 'items.length change must notify count+status select',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T4: Changing status DOES notify count+status select.
  //
  // This test passes now and after Phase B.
  // -------------------------------------------------------------------------
  test(
    'INV-HOME-AGENTS-SELECT-1: status change DOES notify select',
    () async {
      final container = ProviderContainer(
        overrides: [
          agentsStoreProvider.overrideWith(() => _ControllableAgentsStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        agentsStoreProvider,
        (_, __) {},
      );

      int selectNotifyCount = 0;
      container.listen(
        agentsStoreProvider
            .select((s) => (count: s.items.length, status: s.status)),
        (_, __) => selectNotifyCount++,
      );

      // Change status from initial → loading.
      final store = container.read(agentsStoreProvider.notifier)
          as _ControllableAgentsStore;
      store.setStatus(AgentsStatus.loading);

      expect(
        selectNotifyCount,
        1,
        reason: 'status change must notify count+status select',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T5: Full-state watch fires on activityLogs change (anti-pattern proof).
  //
  // Demonstrates the bug: watching the full state causes rebuilds on
  // activityLogs changes which have zero visible impact on the home agents
  // section (it only shows count and load status).
  // -------------------------------------------------------------------------
  test(
    'full-state watch fires on activityLogs change (anti-pattern proof)',
    () async {
      final container = ProviderContainer(
        overrides: [
          agentsStoreProvider.overrideWith(() => _ControllableAgentsStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        agentsStoreProvider,
        (_, __) {},
      );

      // Full-state watch (current pattern).
      int fullStateNotifyCount = 0;
      container.listen(
        agentsStoreProvider,
        (_, __) => fullStateNotifyCount++,
      );

      // Mutate activityLogs.
      final store = container.read(agentsStoreProvider.notifier)
          as _ControllableAgentsStore;
      store.setActivityLogs({
        'agent-1': [
          AgentActivityLogEntry(
            entry: 'Processing',
            timestamp: DateTime.parse('2026-05-19T10:00:00Z'),
          ),
        ],
      });

      expect(
        fullStateNotifyCount,
        greaterThanOrEqualTo(1),
        reason: 'Full-state watch fires on any mutation (proving the bug)',
      );

      keepAlive.close();
    },
  );
}
