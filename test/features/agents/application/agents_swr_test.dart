import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';

// ---------------------------------------------------------------------------
// #488 Phase A: AgentListStore SWR + Lifecycle Invariant Tests
//
// Invariants verified:
// INV-CACHE-SWR-1: Stale agent list remains visible during refresh.
// INV-CACHE-SWR-2: Agent list is never cleared then reloaded.
// INV-NET-DEGRADE-1: Network error during refresh preserves stale data.
// INV-LIFECYCLE-1: AgentsStore must use keepAlive (session-scoped).
//
// Active tests establish the current behavior baseline.
// Skip+TODO tests define target behavior for Phase B.
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // Seed data
  // -----------------------------------------------------------------------

  AgentItem makeAgent({
    String id = 'agent-1',
    String name = 'Bot',
    String status = 'active',
    String activity = 'online',
  }) {
    return AgentItem(
      id: id,
      name: name,
      model: 'sonnet',
      runtime: 'claude',
      status: status,
      activity: activity,
    );
  }

  final seedAgents = [
    makeAgent(id: 'a1', name: 'Alpha'),
    makeAgent(id: 'a2', name: 'Beta', status: 'stopped', activity: 'offline'),
    makeAgent(id: 'a3', name: 'Gamma', activity: 'working'),
  ];

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  ProviderContainer createContainer(_ControllableAgentsRepository repo) {
    return ProviderContainer(
      overrides: [
        agentsRepositoryProvider.overrideWithValue(repo),
        agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Baseline: initial load transitions
  // -----------------------------------------------------------------------
  group('Baseline: initial load behavior', () {
    test('initial load transitions from initial → loading → success', () async {
      final repo = _ControllableAgentsRepository();
      final container = createContainer(repo);
      addTearDown(container.dispose);

      final sub = container.listen(agentsStoreProvider, (_, __) {});

      // State starts as initial.
      expect(container.read(agentsStoreProvider).status, AgentsStatus.initial);

      // Start load — grab completer to control timing.
      final completer = repo.nextListCall();
      final loadFuture = container.read(agentsStoreProvider.notifier).load();

      // Mid-flight: status should be loading.
      expect(container.read(agentsStoreProvider).status, AgentsStatus.loading);

      // Complete the fetch.
      completer.complete(seedAgents);
      await loadFuture;

      // Final: success with data.
      final state = container.read(agentsStoreProvider);
      expect(state.status, AgentsStatus.success);
      expect(state.items, hasLength(3));
      expect(state.items.map((a) => a.name), ['Alpha', 'Beta', 'Gamma']);
      expect(repo.loadCount, 1);
      sub.close();
    });

    test('initial load failure transitions to failure status', () async {
      final repo = _ControllableAgentsRepository();
      final container = createContainer(repo);
      addTearDown(container.dispose);

      final sub = container.listen(agentsStoreProvider, (_, __) {});

      final completer = repo.nextListCall();
      final loadFuture = container.read(agentsStoreProvider.notifier).load();

      // Mid-flight: loading.
      expect(container.read(agentsStoreProvider).status, AgentsStatus.loading);

      // Fail the fetch.
      completer.completeError(
        const ServerFailure(message: 'Server error', statusCode: 500),
      );
      await loadFuture;

      // Final: failure with error.
      final state = container.read(agentsStoreProvider);
      expect(state.status, AgentsStatus.failure);
      expect(state.failure, isA<ServerFailure>());
      expect(state.items, isEmpty,
          reason: 'No stale data to preserve on initial load failure');
      sub.close();
    });

    test('load count tracks repository calls', () async {
      final repo = _ControllableAgentsRepository();
      final container = createContainer(repo);
      addTearDown(container.dispose);

      final sub = container.listen(agentsStoreProvider, (_, __) {});

      // First load.
      final c1 = repo.nextListCall();
      final f1 = container.read(agentsStoreProvider.notifier).load();
      c1.complete(seedAgents);
      await f1;
      expect(repo.loadCount, 1);

      // Second load.
      final c2 = repo.nextListCall();
      final f2 = container.read(agentsStoreProvider.notifier).load();
      c2.complete(seedAgents);
      await f2;
      expect(repo.loadCount, 2);
      sub.close();
    });
  });

  // -----------------------------------------------------------------------
  // INV-CACHE-SWR-1 / INV-CACHE-SWR-2: SWR refresh behavior
  // -----------------------------------------------------------------------
  group('INV-CACHE-SWR: SWR refresh preserves stale data', () {
    test(
      'stale agent list remains present during refresh '
      '(INV-CACHE-SWR-1 — data preservation)',
      () async {
        final repo = _ControllableAgentsRepository();
        final container = createContainer(repo);
        addTearDown(container.dispose);

        final sub = container.listen(agentsStoreProvider, (_, __) {});

        // Initial load — seed stale data.
        final c1 = repo.nextListCall();
        final f1 = container.read(agentsStoreProvider.notifier).load();
        c1.complete(seedAgents);
        await f1;
        expect(
            container.read(agentsStoreProvider).status, AgentsStatus.success);
        expect(container.read(agentsStoreProvider).items, hasLength(3));

        // Start second load (refresh).
        final c2 = repo.nextListCall();
        // ignore: unawaited_futures
        container.read(agentsStoreProvider.notifier).load();

        // Mid-flight: stale items must remain in state.
        // load() changes status but does NOT clear items.
        final midState = container.read(agentsStoreProvider);
        expect(midState.items, hasLength(3),
            reason: 'INV-CACHE-SWR-1: stale agent list must remain '
                'present during refresh — load() must not clear items');
        expect(midState.items.map((a) => a.name), ['Alpha', 'Beta', 'Gamma']);

        // Complete refresh with updated data.
        final updatedAgents = [
          makeAgent(id: 'a1', name: 'Alpha-v2'),
          makeAgent(id: 'a4', name: 'Delta'),
        ];
        c2.complete(updatedAgents);
        await Future.delayed(Duration.zero);

        // Final: new data replaces stale.
        final finalState = container.read(agentsStoreProvider);
        expect(finalState.items, hasLength(2));
        expect(finalState.items.map((a) => a.name), ['Alpha-v2', 'Delta']);
        sub.close();
      },
    );

    test(
      'refresh exposes SWR status signal instead of full-screen loading '
      '(INV-CACHE-SWR-1 — status signal)',
      () async {
        final repo = _ControllableAgentsRepository();
        final container = createContainer(repo);
        addTearDown(container.dispose);

        final sub = container.listen(agentsStoreProvider, (_, __) {});

        // Initial load — seed stale data.
        final c1 = repo.nextListCall();
        final f1 = container.read(agentsStoreProvider.notifier).load();
        c1.complete(seedAgents);
        await f1;

        // Start second load (refresh).
        final c2 = repo.nextListCall();
        // ignore: unawaited_futures
        container.read(agentsStoreProvider.notifier).load();

        // Mid-flight: status should remain success (not revert to loading).
        // Phase B adds isRefreshing field as the SWR signal.
        final midState = container.read(agentsStoreProvider);
        expect(midState.status, AgentsStatus.success,
            reason: 'INV-CACHE-SWR-1: status must remain success during '
                'SWR refresh — use isRefreshing for loading signal');

        c2.complete(seedAgents);
        await Future.delayed(Duration.zero);
        sub.close();
      },
      skip: 'TODO: AgentsStore.load() sets status=loading on every call. '
          'Phase B must keep status=success when stale data exists and '
          'expose isRefreshing as the SWR loading signal.',
    );

    test(
      'agent list is never cleared during refresh (INV-CACHE-SWR-2)',
      () async {
        final repo = _ControllableAgentsRepository();
        final container = createContainer(repo);
        addTearDown(container.dispose);

        final sub = container.listen(agentsStoreProvider, (_, __) {});

        // Initial load.
        final c1 = repo.nextListCall();
        final f1 = container.read(agentsStoreProvider.notifier).load();
        c1.complete(seedAgents);
        await f1;

        // Start refresh — capture states during load.
        final states = <AgentsState>[];
        container.listen(agentsStoreProvider, (_, next) => states.add(next));

        final c2 = repo.nextListCall();
        final f2 = container.read(agentsStoreProvider.notifier).load();
        c2.complete(seedAgents);
        await f2;

        // No intermediate state should have an empty items list.
        for (final s in states) {
          expect(s.items, isNotEmpty,
              reason: 'INV-CACHE-SWR-2: agent list must never be cleared '
                  'during refresh — found empty items in intermediate state '
                  '(status=${s.status})');
        }
        sub.close();
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-NET-DEGRADE-1: error during refresh preserves stale data
  // -----------------------------------------------------------------------
  group('INV-NET-DEGRADE-1: error during refresh', () {
    test(
      'stale agent list survives refresh error (data preservation)',
      () async {
        final repo = _ControllableAgentsRepository();
        final container = createContainer(repo);
        addTearDown(container.dispose);

        final sub = container.listen(agentsStoreProvider, (_, __) {});

        // Initial load — seed stale data.
        final c1 = repo.nextListCall();
        final f1 = container.read(agentsStoreProvider.notifier).load();
        c1.complete(seedAgents);
        await f1;
        expect(container.read(agentsStoreProvider).items, hasLength(3));

        // Start refresh, then fail it.
        final c2 = repo.nextListCall();
        final f2 = container.read(agentsStoreProvider.notifier).load();
        c2.completeError(
          const ServerFailure(message: 'Refresh failed', statusCode: 503),
        );
        await f2;

        // Stale items must survive the error.
        // load() sets status=failure but does NOT clear items.
        final state = container.read(agentsStoreProvider);
        expect(state.items, hasLength(3),
            reason: 'INV-NET-DEGRADE-1: stale agent list must survive '
                'refresh error — load() must not clear items');
        expect(state.items.map((a) => a.name), ['Alpha', 'Beta', 'Gamma'],
            reason: 'Agent data from initial load must be preserved');
        sub.close();
      },
    );

    test(
      'refresh error keeps success status with failure overlay '
      '(INV-NET-DEGRADE-1 — error overlay signal)',
      () async {
        final repo = _ControllableAgentsRepository();
        final container = createContainer(repo);
        addTearDown(container.dispose);

        final sub = container.listen(agentsStoreProvider, (_, __) {});

        // Initial load.
        final c1 = repo.nextListCall();
        final f1 = container.read(agentsStoreProvider.notifier).load();
        c1.complete(seedAgents);
        await f1;

        // Refresh with error.
        final c2 = repo.nextListCall();
        final f2 = container.read(agentsStoreProvider.notifier).load();
        c2.completeError(
          const ServerFailure(message: 'Network timeout', statusCode: 504),
        );
        await f2;

        // Status should remain success (not flip to failure) when
        // stale data exists. Error is surfaced via state.failure
        // as an overlay.
        final state = container.read(agentsStoreProvider);
        expect(state.status, AgentsStatus.success,
            reason: 'INV-NET-DEGRADE-1: status must remain success when '
                'stale data exists after refresh error');
        expect(state.failure, isA<ServerFailure>(),
            reason: 'Error must be surfaced via state.failure for '
                'error overlay display');
        sub.close();
      },
      skip: 'TODO: AgentsStore.load() sets status=failure on any error, '
          'even when stale data exists. Phase B must keep '
          'status=success and surface error via state.failure '
          'as overlay when stale data is available.',
    );
  });

  // -----------------------------------------------------------------------
  // INV-LIFECYCLE-1: keepAlive behavior
  // -----------------------------------------------------------------------
  group('INV-LIFECYCLE-1: AgentsStore lifecycle', () {
    test(
      'provider retains state after listener removal (keepAlive)',
      () async {
        final repo = _ControllableAgentsRepository();
        final container = createContainer(repo);
        addTearDown(container.dispose);

        // Add listener and load.
        final sub = container.listen(agentsStoreProvider, (_, __) {});
        final c1 = repo.nextListCall();
        final f1 = container.read(agentsStoreProvider.notifier).load();
        c1.complete(seedAgents);
        await f1;
        expect(
            container.read(agentsStoreProvider).status, AgentsStatus.success);
        expect(container.read(agentsStoreProvider).items, hasLength(3));

        // Simulate tab switch: close listener.
        sub.close();
        await Future.delayed(Duration.zero);

        // keepAlive: state should be retained.
        final state = container.read(agentsStoreProvider);
        expect(state.status, AgentsStatus.success,
            reason: 'INV-LIFECYCLE-1: AgentsStore must retain state '
                'after listener removal (keepAlive)');
        expect(state.items, hasLength(3),
            reason: 'Agent data must persist across tab switches');
      },
      skip: 'TODO: AgentsStore uses autoDispose — state is disposed on '
          'listener removal. Phase B must change '
          'NotifierProvider.autoDispose → NotifierProvider and '
          'AutoDisposeNotifier → Notifier.',
    );

    test(
      'no re-fetch on tab return (keepAlive retains data)',
      () async {
        final repo = _ControllableAgentsRepository();
        final container = createContainer(repo);
        addTearDown(container.dispose);

        // First tab visit: load data.
        final sub1 = container.listen(agentsStoreProvider, (_, __) {});
        final c1 = repo.nextListCall();
        final f1 = container.read(agentsStoreProvider.notifier).load();
        c1.complete(seedAgents);
        await f1;
        expect(repo.loadCount, 1);
        sub1.close();

        await Future.delayed(Duration.zero);

        // Second tab visit: state should already have data.
        final sub2 = container.listen(agentsStoreProvider, (_, __) {});
        final state = container.read(agentsStoreProvider);
        expect(state.status, AgentsStatus.success,
            reason: 'keepAlive: state survives between tab visits');
        expect(state.items, hasLength(3),
            reason: 'Agent data persists without re-fetch');
        expect(repo.loadCount, 1,
            reason: 'No re-fetch on tab return — keepAlive retains data');
        sub2.close();
      },
      skip: 'TODO: AgentsStore uses autoDispose — provider resets on '
          'listener removal. Phase B must migrate to keepAlive so '
          'tab return does not trigger re-fetch.',
    );
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Completer-based agents repository for SWR timing tests.
///
/// Call [nextListCall] to arm a [Completer] before triggering [listAgents].
/// The completer controls when the async call resolves, allowing mid-flight
/// state assertions.
class _ControllableAgentsRepository implements AgentsRepository {
  Completer<List<AgentItem>>? _listCompleter;
  int loadCount = 0;

  /// Arm a new completer for the next [listAgents] call.
  Completer<List<AgentItem>> nextListCall() {
    _listCompleter = Completer<List<AgentItem>>();
    return _listCompleter!;
  }

  @override
  Future<List<AgentItem>> listAgents() async {
    loadCount++;
    if (_listCompleter != null) {
      final completer = _listCompleter!;
      _listCompleter = null;
      return completer.future;
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
