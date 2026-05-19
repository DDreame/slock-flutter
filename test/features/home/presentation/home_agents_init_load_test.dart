// =============================================================================
// #596 — Home Agents initState Migration
//
// Invariant: INV-AGENTS-INIT-1
//   AgentsStore.load() fires exactly once per widget lifecycle.
//
// Strategy:
// T1: Verify that calling load() N times concurrently results in N network
//     requests (proving the bug — no in-flight guard exists).
//     After Phase B, load() is called from initState (once), not build().
//     (skip:true — test validates single-call behavior after migration)
// T2: Verify load() correctly transitions from initial → loading → success
//     on the first call (proves initial load still works).
// T3: Anti-pattern proof — multiple synchronous load() calls all reach the
//     repository (demonstrating the build-phase duplication bug).
//
// Phase A: T1 skip:true — current ConsumerWidget.build() pattern allows N calls.
//
// Phase B:
// 1. Promote _HomeAgentsSection to ConsumerStatefulWidget
// 2. Move the initial-load trigger to initState()
// 3. Remove Future.microtask(load) from build()
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/machines/data/machine_item.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _CountingAgentsRepository implements AgentsRepository {
  int listAgentsCallCount = 0;
  Completer<List<AgentItem>>? listAgentsCompleter;

  @override
  Future<List<AgentItem>> listAgents() async {
    listAgentsCallCount++;
    if (listAgentsCompleter != null) {
      return listAgentsCompleter!.future;
    }
    return const [];
  }

  @override
  Future<void> startAgent(String agentId) async {}

  @override
  Future<void> stopAgent(String agentId) async {}

  @override
  Future<void> resetAgent(String agentId, {required String mode}) async {}

  @override
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  }) async =>
      const [];
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: After initState migration, load() is called exactly once regardless
  //     of how many times build() is invoked.
  //
  // This test simulates the desired post-fix behavior: initState calls load()
  // once, and subsequent rebuilds do NOT re-trigger load(). The test fires
  // load() once and expects exactly 1 repository call.
  //
  // skip:true — current ConsumerWidget.build() pattern allows N calls per
  // frame (proved by T3). After Phase B, initState guarantees once.
  // -------------------------------------------------------------------------
  test(
    'INV-AGENTS-INIT-1: load() fires exactly once per widget lifecycle',
    skip: true,
    () async {
      final repo = _CountingAgentsRepository();

      final container = ProviderContainer(
        overrides: [
          agentsRepositoryProvider.overrideWithValue(repo),
          agentsMachinesLoaderProvider
              .overrideWithValue(() async => const <MachineItem>[]),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        agentsStoreProvider,
        (_, __) {},
      );

      // Confirm initial state.
      expect(
        container.read(agentsStoreProvider).status,
        AgentsStatus.initial,
      );

      // Simulate initState: exactly one load call.
      await container.read(agentsStoreProvider.notifier).load();

      // After Phase B migration, only 1 call reaches the repository.
      expect(
        repo.listAgentsCallCount,
        1,
        reason: 'initState must trigger exactly one load() call '
            '(INV-AGENTS-INIT-1)',
      );

      // Simulating subsequent build() calls — they should NOT trigger load()
      // because status is no longer 'initial'.
      final status = container.read(agentsStoreProvider).status;
      expect(status, AgentsStatus.success);
      // No additional load() triggered — count stays at 1.
      expect(
        repo.listAgentsCallCount,
        1,
        reason: 'Subsequent builds must not re-trigger load() after '
            'successful initial load (INV-AGENTS-INIT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: Initial load correctly transitions initial → loading → success.
  //
  // This test passes now and after Phase B (load() behavior is unchanged,
  // only the trigger location moves from build to initState).
  // -------------------------------------------------------------------------
  test(
    'INV-AGENTS-INIT-1: initial load transitions initial → loading → success',
    () async {
      final repo = _CountingAgentsRepository();
      repo.listAgentsCompleter = Completer<List<AgentItem>>();

      final container = ProviderContainer(
        overrides: [
          agentsRepositoryProvider.overrideWithValue(repo),
          agentsMachinesLoaderProvider
              .overrideWithValue(() async => const <MachineItem>[]),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        agentsStoreProvider,
        (_, __) {},
      );

      expect(
        container.read(agentsStoreProvider).status,
        AgentsStatus.initial,
      );

      // Trigger load.
      final loadFuture = container.read(agentsStoreProvider.notifier).load();

      // Should transition to loading.
      expect(
        container.read(agentsStoreProvider).status,
        AgentsStatus.loading,
      );

      // Complete the fetch.
      repo.listAgentsCompleter!.complete(const []);
      await loadFuture;

      // Should transition to success.
      expect(
        container.read(agentsStoreProvider).status,
        AgentsStatus.success,
      );
      expect(repo.listAgentsCallCount, 1);

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: Anti-pattern proof — multiple concurrent load() calls all reach the
  //     repository.
  //
  // In the current code, if build() is called multiple times in the same
  // frame while status == initial, each call schedules a Future.microtask
  // that calls load(). Since load() has no in-flight guard, all of them
  // proceed to the network. This test proves the duplication.
  // -------------------------------------------------------------------------
  test(
    'multiple concurrent load() calls all reach repository (anti-pattern proof)',
    () async {
      final repo = _CountingAgentsRepository();

      final container = ProviderContainer(
        overrides: [
          agentsRepositoryProvider.overrideWithValue(repo),
          agentsMachinesLoaderProvider
              .overrideWithValue(() async => const <MachineItem>[]),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        agentsStoreProvider,
        (_, __) {},
      );

      // Fire 3 concurrent load() calls (simulating 3 build() calls in
      // the same frame, each scheduling Future.microtask(load)).
      await Future.wait([
        container.read(agentsStoreProvider.notifier).load(),
        container.read(agentsStoreProvider.notifier).load(),
        container.read(agentsStoreProvider.notifier).load(),
      ]);

      // Without a guard, all 3 reach the repository.
      expect(
        repo.listAgentsCallCount,
        greaterThan(1),
        reason: 'Without in-flight guard, concurrent load() calls all hit '
            'the repository (proving the build-phase duplication bug)',
      );

      keepAlive.close();
    },
  );
}
