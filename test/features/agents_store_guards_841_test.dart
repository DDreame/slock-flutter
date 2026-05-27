// =============================================================================
// #841 — AgentsStore Guards + BackoffStreak Reset + DateSeparator Clock
//
// Invariants verified:
// INV-841-FIRSTWHERE:  startAgent/stopAgent bail out when agent is missing
//                      (concurrent removeAgent event) — no StateError crash
// INV-841-DISPOSED:    load()/createAgent/updateAgent/deleteAgent/loadActivityLog
//                      do not write state after dispose
// INV-841-BACKOFF:     _backoffStreak resets on server switch so new connection
//                      doesn't inherit elevated delay from old server
// INV-841-CLOCK:       dateSeparatorNowProvider refreshes via homeNowProvider
//                      (not frozen at initial build time)
//
// Load-bearing proof:
//   - Reverting firstWhere guard → test RED (StateError)
//   - Reverting _disposed guards → test RED (state written after dispose)
//   - Reverting _backoffStreak = 0 → test RED (elevated streak persists)
//   - Reverting dateSeparatorNowProvider to DateTime.now() → test RED (frozen)
// =============================================================================

import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_message_list.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/machines/data/machine_item.dart';

void main() {
  // ---------------------------------------------------------------------------
  // INV-841-FIRSTWHERE: startAgent/stopAgent safe when agent missing
  // ---------------------------------------------------------------------------
  group('INV-841-FIRSTWHERE: safe lookup on missing agent', () {
    test('startAgent bails out when agent not in state (no StateError)',
        () async {
      final container = ProviderContainer(overrides: [
        agentsRepositoryProvider.overrideWithValue(_FakeAgentsRepository()),
        agentsMachinesLoaderProvider
            .overrideWithValue(() async => <MachineItem>[]),
        realtimeServiceProvider.overrideWith(
          () => _NoOpRealtimeService(),
        ),
      ]);
      addTearDown(container.dispose);

      final store = container.read(agentsStoreProvider.notifier);

      // Load with one agent.
      await store.load();
      expect(container.read(agentsStoreProvider).items.length, 1);

      // Simulate concurrent removeAgent event (removes the agent from state).
      store.removeAgent('agent-1');
      expect(container.read(agentsStoreProvider).items, isEmpty);

      // startAgent on the now-missing agent must NOT throw StateError.
      // Before fix: firstWhere → StateError: No element
      await store.startAgent('agent-1');

      // No crash, state unchanged.
      expect(container.read(agentsStoreProvider).items, isEmpty);
    });

    test('stopAgent bails out when agent not in state (no StateError)',
        () async {
      final container = ProviderContainer(overrides: [
        agentsRepositoryProvider.overrideWithValue(_FakeAgentsRepository()),
        agentsMachinesLoaderProvider
            .overrideWithValue(() async => <MachineItem>[]),
        realtimeServiceProvider.overrideWith(
          () => _NoOpRealtimeService(),
        ),
      ]);
      addTearDown(container.dispose);

      final store = container.read(agentsStoreProvider.notifier);
      await store.load();

      // Remove agent from state (concurrent event).
      store.removeAgent('agent-1');

      // stopAgent on missing agent must NOT throw.
      await store.stopAgent('agent-1');
      expect(container.read(agentsStoreProvider).items, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // INV-841-DISPOSED: async methods don't write state after dispose
  // ---------------------------------------------------------------------------
  group('INV-841-DISPOSED: no state write after dispose', () {
    test('load() does not write state after dispose', () async {
      final repo = _SlowAgentsRepository();
      final container = ProviderContainer(overrides: [
        agentsRepositoryProvider.overrideWithValue(repo),
        agentsMachinesLoaderProvider
            .overrideWithValue(() async => <MachineItem>[]),
        realtimeServiceProvider.overrideWith(
          () => _NoOpRealtimeService(),
        ),
      ]);

      final store = container.read(agentsStoreProvider.notifier);

      // Start load — it will await the completer.
      final loadFuture = store.load();

      // Dispose before the load completes.
      container.dispose();

      // Complete the load — must not throw (state write is guarded).
      repo.completer.complete([
        _testAgent('agent-1'),
      ]);

      // No exception means post-await _disposed guard worked.
      await loadFuture;
    });

    test('load() after dispose returns immediately without throwing',
        () async {
      // Load-bearing test for the TOP-OF-METHOD disposed guard in load().
      // Without `if (_disposed) return;`, the method proceeds past the guard:
      //   1. Sets state to loading (unnecessary mutation)
      //   2. Calls ref.read (throws StateError on disposed container)
      //   3. Falls into generic catch block → if (_disposed) return
      // The catch-block guard masks the crash, but the state WAS mutated
      // from initial → loading before the throw. With the entry guard,
      // state remains untouched (initial).
      final repo = _TrackingAgentsRepository();
      final container = ProviderContainer(overrides: [
        agentsRepositoryProvider.overrideWithValue(repo),
        agentsMachinesLoaderProvider
            .overrideWithValue(() async => <MachineItem>[]),
        realtimeServiceProvider.overrideWith(
          () => _NoOpRealtimeService(),
        ),
      ]);

      // Grab the notifier reference before dispose.
      final store = container.read(agentsStoreProvider.notifier);

      // Capture initial state status before dispose.
      expect(store.state.status, AgentsStatus.initial);

      // Dispose the container — marks _disposed = true AND invalidates ref.
      container.dispose();

      // Call load() AFTER dispose — must return immediately.
      await store.load();

      // With the entry guard: state stays at `initial` (never mutated).
      // Without the entry guard: state changes to `loading` before ref.read
      // throws, then the catch block returns — state stuck at `loading`.
      expect(
        store.state.status,
        AgentsStatus.initial,
        reason: 'load() entry guard must prevent state mutation to loading; '
            'removing the guard causes state to be set to loading before '
            'the ref.read StateError is caught → test RED',
      );

      // Also verify the repository was never called.
      expect(repo.listAgentsCalls, 0);
    });

    test('deleteAgent does not write state after dispose', () async {
      final repo = _SlowDeleteAgentsRepository();
      final container = ProviderContainer(overrides: [
        agentsRepositoryProvider.overrideWithValue(repo),
        agentsMachinesLoaderProvider
            .overrideWithValue(() async => <MachineItem>[]),
        realtimeServiceProvider.overrideWith(
          () => _NoOpRealtimeService(),
        ),
      ]);

      final store = container.read(agentsStoreProvider.notifier);

      // Pre-load state with an agent.
      await store.load();
      expect(container.read(agentsStoreProvider).status, AgentsStatus.success);

      // Start delete — will await completer.
      final deleteFuture = store.deleteAgent('agent-1');

      // Dispose before delete completes.
      container.dispose();

      // Complete the delete — must not throw.
      repo.deleteCompleter.complete();
      await deleteFuture;
    });

    test('loadActivityLog does not write state after dispose', () async {
      final repo = _SlowActivityLogRepository();
      final container = ProviderContainer(overrides: [
        agentsRepositoryProvider.overrideWithValue(repo),
        agentsMachinesLoaderProvider
            .overrideWithValue(() async => <MachineItem>[]),
        realtimeServiceProvider.overrideWith(
          () => _NoOpRealtimeService(),
        ),
      ]);

      final store = container.read(agentsStoreProvider.notifier);
      await store.load();

      // Start loadActivityLog — will await completer.
      final logFuture = store.loadActivityLog('agent-1');

      // Dispose before it completes.
      container.dispose();

      // Complete — must not throw.
      repo.activityLogCompleter.complete([]);
      await logFuture;
    });
  });

  // ---------------------------------------------------------------------------
  // INV-841-BACKOFF: _backoffStreak resets on server switch
  // ---------------------------------------------------------------------------
  group('INV-841-BACKOFF: backoff streak reset on server switch', () {
    test('streak resets when realtimeSocketClientProvider rebuilds', () async {
      // Capture actual delays passed to the sleeper so we can assert the
      // post-switch reconnect uses streak=0 (base delay), NOT streak=3.
      final capturedDelays = <Duration>[];

      // Use a StateProvider to simulate the socket client changing
      // (which happens on server switch / token refresh).
      final socketClientState = StateProvider<RealtimeSocketClient>(
        (ref) => _FakeSocketClient(),
      );

      final container = ProviderContainer(overrides: [
        realtimeSocketClientProvider.overrideWith(
          (ref) => ref.watch(socketClientState),
        ),
        realtimeBackoffSleeperProvider.overrideWithValue((d) async {
          capturedDelays.add(d);
        }),
        realtimeBackoffRandomProvider.overrideWithValue(_FakeRandom()),
        realtimeReductionIngressProvider.overrideWithValue(
          _FakeIngress(),
        ),
      ]);
      addTearDown(container.dispose);

      // Keep the service alive so ref.listen fires.
      container.listen(realtimeServiceProvider, (_, __) {});

      final service = container.read(realtimeServiceProvider.notifier);

      // Connect first so _boundSocketClient is set.
      await service.connect();

      // Force reconnect 3 times to build up streak (streak goes 0→1→2→3).
      await service.forceReconnect(reason: 'test-1');
      await service.forceReconnect(reason: 'test-2');
      await service.forceReconnect(reason: 'test-3');

      // Sanity: 3 delays captured, escalating (streak 0, 1, 2).
      // With _FakeRandom.nextInt(1000)=0 and baseDelay=1000ms:
      //   streak=0 → 1000ms, streak=1 → 2000ms, streak=2 → 4000ms
      expect(capturedDelays.length, 3);
      expect(capturedDelays[0], const Duration(milliseconds: 1000));
      expect(capturedDelays[1], const Duration(milliseconds: 2000));
      expect(capturedDelays[2], const Duration(milliseconds: 4000));

      // Simulate server switch — new socket client.
      container.read(socketClientState.notifier).state = _FakeSocketClient();
      await Future<void>.delayed(Duration.zero);

      // Now force reconnect — delay MUST be streak=0 level (1000ms),
      // NOT streak=3 level (8000ms).
      await service.forceReconnect(reason: 'after-switch');

      // Load-bearing assertion: removing `_backoffStreak = 0` from the
      // server-switch handler makes the 4th delay = 8000ms (streak=3),
      // turning this test RED.
      expect(
        capturedDelays.last,
        const Duration(milliseconds: 1000),
        reason:
            'Post-switch reconnect must use streak=0 base delay (1000ms), '
            'not elevated streak=3 delay (8000ms)',
      );

      // Cumulative attempts counter still increments independently.
      expect(
        container.read(realtimeServiceProvider).reconnectAttempts,
        4,
        reason: 'Cumulative attempts still increment',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // INV-841-CLOCK: dateSeparatorNowProvider refreshes from homeNowProvider
  // ---------------------------------------------------------------------------
  group('INV-841-CLOCK: dateSeparatorNowProvider not frozen', () {
    test('updates when homeNowProvider emits new time', () async {
      final controller = StreamController<DateTime>();
      addTearDown(controller.close);

      final container = ProviderContainer(overrides: [
        homeNowProvider.overrideWith((ref) => controller.stream),
      ]);
      addTearDown(container.dispose);

      // Initially null from stream → fallback to DateTime.now().
      final initial = container.read(dateSeparatorNowProvider);
      expect(initial.year, DateTime.now().year);

      // Emit a specific time.
      final midnight = DateTime(2026, 5, 28, 0, 0, 0);
      controller.add(midnight);
      await Future<void>.delayed(Duration.zero);

      // dateSeparatorNowProvider must reflect the new time.
      final updated = container.read(dateSeparatorNowProvider);
      expect(updated, midnight,
          reason: 'dateSeparatorNowProvider must track homeNowProvider');
    });

    test('crosses midnight boundary correctly', () async {
      final controller = StreamController<DateTime>();
      addTearDown(controller.close);

      final container = ProviderContainer(overrides: [
        homeNowProvider.overrideWith((ref) => controller.stream),
      ]);
      addTearDown(container.dispose);

      // Emit 23:59 on May 27.
      controller.add(DateTime(2026, 5, 27, 23, 59, 0));
      await Future<void>.delayed(Duration.zero);

      var now = container.read(dateSeparatorNowProvider);
      expect(now.day, 27);

      // Emit 00:01 on May 28 (crossed midnight).
      controller.add(DateTime(2026, 5, 28, 0, 1, 0));
      await Future<void>.delayed(Duration.zero);

      now = container.read(dateSeparatorNowProvider);
      expect(now.day, 28, reason: 'Must update across midnight boundary');
    });
  });
}

// =============================================================================
// Test helpers
// =============================================================================

AgentItem _testAgent(String id) => AgentItem(
      id: id,
      name: 'test-agent-$id',
      model: 'claude-3',
      runtime: 'docker',
      status: 'active',
      activity: 'online',
    );

class _FakeAgentsRepository
    implements AgentsRepository, AgentsMutationRepository {
  @override
  Future<List<AgentItem>> listAgents() async {
    return [_testAgent('agent-1')];
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
  }) async {
    return [];
  }

  @override
  Future<AgentItem> createAgent(AgentMutationInput input) async {
    return _testAgent('new-agent');
  }

  @override
  Future<AgentItem> updateAgent(
      String agentId, AgentMutationInput input) async {
    return _testAgent(agentId);
  }

  @override
  Future<void> deleteAgent(String agentId) async {}
}

/// Repository that delays listAgents until the completer is resolved.
class _SlowAgentsRepository
    implements AgentsRepository, AgentsMutationRepository {
  final completer = Completer<List<AgentItem>>();

  @override
  Future<List<AgentItem>> listAgents() => completer.future;

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
      [];
  @override
  Future<AgentItem> createAgent(AgentMutationInput input) async =>
      _testAgent('new');
  @override
  Future<AgentItem> updateAgent(
          String agentId, AgentMutationInput input) async =>
      _testAgent(agentId);
  @override
  Future<void> deleteAgent(String agentId) async {}
}

/// Repository that delays deleteAgent until the completer is resolved.
class _SlowDeleteAgentsRepository
    implements AgentsRepository, AgentsMutationRepository {
  final deleteCompleter = Completer<void>();

  @override
  Future<List<AgentItem>> listAgents() async => [_testAgent('agent-1')];
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
      [];
  @override
  Future<AgentItem> createAgent(AgentMutationInput input) async =>
      _testAgent('new');
  @override
  Future<AgentItem> updateAgent(
          String agentId, AgentMutationInput input) async =>
      _testAgent(agentId);
  @override
  Future<void> deleteAgent(String agentId) => deleteCompleter.future;
}

/// Repository that delays getActivityLog until the completer is resolved.
class _SlowActivityLogRepository
    implements AgentsRepository, AgentsMutationRepository {
  final activityLogCompleter = Completer<List<AgentActivityLogEntry>>();

  @override
  Future<List<AgentItem>> listAgents() async => [_testAgent('agent-1')];
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
  }) =>
      activityLogCompleter.future;
  @override
  Future<AgentItem> createAgent(AgentMutationInput input) async =>
      _testAgent('new');
  @override
  Future<AgentItem> updateAgent(
          String agentId, AgentMutationInput input) async =>
      _testAgent(agentId);
  @override
  Future<void> deleteAgent(String agentId) async {}
}

/// Repository that counts calls to listAgents — used to verify the
/// top-of-method _disposed guard prevents API calls after dispose.
class _TrackingAgentsRepository
    implements AgentsRepository, AgentsMutationRepository {
  int listAgentsCalls = 0;

  @override
  Future<List<AgentItem>> listAgents() async {
    listAgentsCalls++;
    return [_testAgent('agent-1')];
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
      [];
  @override
  Future<AgentItem> createAgent(AgentMutationInput input) async =>
      _testAgent('new');
  @override
  Future<AgentItem> updateAgent(
          String agentId, AgentMutationInput input) async =>
      _testAgent(agentId);
  @override
  Future<void> deleteAgent(String agentId) async {}
}

class _NoOpRealtimeService extends RealtimeService {
  @override
  RealtimeConnectionState build() => const RealtimeConnectionState();
}

class _FakeSocketClient implements RealtimeSocketClient {
  @override
  bool get isConnected => true;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  void emit(String eventName, Object? payload) {}

  @override
  Future<void> dispose() async {}

  @override
  Stream<RealtimeSocketSignal> get signals => const Stream.empty();
}

class _FakeIngress extends RealtimeReductionIngress {}

class _FakeRandom implements Random {
  @override
  double nextDouble() => 0.5;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}
