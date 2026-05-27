// =============================================================================
// #839 — P2 Integration Safety
//
// Invariants verified:
// INV-839-SEQ-RESET: RealtimeReductionIngress resets seq tracking on
//                    server switch so events aren't rejected as stale
// INV-839-BACKOFF:   RealtimeService exponential backoff on reconnect
//                    failures prevents reconnection storms
// INV-839-FILTER:    InboxStore discards stale filter responses when user
//                    rapidly switches filters (epoch pattern)
// =============================================================================

import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';

void main() {
  // ---------------------------------------------------------------------------
  // INV-839-SEQ-RESET: RealtimeReductionIngress resets on server switch
  // ---------------------------------------------------------------------------
  group('INV-839-SEQ-RESET: ingress seq reset on server switch', () {
    test('after reset(), previously rejected seq is accepted', () {
      final ingress = RealtimeReductionIngress();
      addTearDown(() => ingress.dispose());

      // Accept seq=10 for a global scope.
      final firstEvent = RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: 'global',
        receivedAt: DateTime.now(),
        seq: 10,
      );
      expect(ingress.accept(firstEvent), isTrue);

      // seq=5 would normally be rejected (5 <= 10).
      final staleEvent = RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: 'global',
        receivedAt: DateTime.now(),
        seq: 5,
      );
      expect(ingress.accept(staleEvent), isFalse,
          reason: 'Pre-reset: lower seq should be rejected');

      // After reset (simulating server switch), seq=5 must be accepted.
      ingress.reset();

      final postResetEvent = RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: 'global',
        receivedAt: DateTime.now(),
        seq: 5,
      );
      expect(ingress.accept(postResetEvent), isTrue,
          reason: 'Post-reset: same seq must be accepted (fresh server)');
    });

    test('reset() clears all scope keys', () {
      final ingress = RealtimeReductionIngress();
      addTearDown(() => ingress.dispose());

      // Accept events for multiple scopes.
      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: 'server:abc/channel:xyz',
        receivedAt: DateTime.now(),
        seq: 100,
      ));
      ingress.accept(RealtimeEventEnvelope(
        eventType: 'task:update',
        scopeKey: 'global',
        receivedAt: DateTime.now(),
        seq: 50,
      ));

      expect(ingress.lastSeqByScope.length, 2);

      ingress.reset();

      expect(ingress.lastSeqByScope, isEmpty);
    });

    test('events after reset do not trigger gap detection', () async {
      final ingress = RealtimeReductionIngress();
      addTearDown(() => ingress.dispose());

      // Set up a high seq for a scope.
      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: 'global',
        receivedAt: DateTime.now(),
        seq: 100,
      ));

      ingress.reset();

      // After reset, seq=1 should be accepted without gap detection
      // (since there's no "last seq" to compare against).
      final accepted = <RealtimeEventEnvelope>[];
      ingress.acceptedEvents.listen(accepted.add);

      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: 'global',
        receivedAt: DateTime.now(),
        seq: 1,
      ));

      // Allow broadcast stream delivery to complete.
      await Future<void>.delayed(Duration.zero);

      expect(accepted, hasLength(1));
      expect(accepted.first.gapDetected, isFalse,
          reason: 'First event after reset should not flag a gap');
    });

    test('server switch via RealtimeService resets ingress (load-bearing)',
        () async {
      // This test exercises the real ref.listen(realtimeSocketClientProvider)
      // path in RealtimeService.build(). Removing _ingress.reset() from the
      // production listener MUST cause this test to fail.

      final ingress = RealtimeReductionIngress();
      addTearDown(() => ingress.dispose());

      // StateProvider to control which socket client instance is returned.
      final socketVersionProvider = StateProvider<int>((_) => 1);

      final container = ProviderContainer(overrides: [
        realtimeReductionIngressProvider.overrideWithValue(ingress),
        realtimeClockProvider.overrideWithValue(DateTime.now),
        realtimeBackoffRandomProvider.overrideWithValue(Random(42)),
        realtimeWatchdogTimerFactoryProvider.overrideWithValue(
          (interval, onTick) => Timer(const Duration(hours: 99), () {}),
        ),
        realtimeSocketClientProvider.overrideWith((ref) {
          // Watch the version — rebuild produces a new instance on change.
          ref.watch(socketVersionProvider);
          return _FakeSocketClient();
        }),
      ]);
      addTearDown(container.dispose);

      // Build the RealtimeService to activate ref.listen.
      container.read(realtimeServiceProvider);

      // Seed the ingress with event data.
      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: 'global',
        receivedAt: DateTime.now(),
        seq: 50,
      ));
      expect(ingress.lastSeqByScope, isNotEmpty,
          reason: 'Pre-switch: ingress has tracked seq');

      // Trigger a connect so _boundSocketClient is set (listener requires it).
      await container.read(realtimeServiceProvider.notifier).connect();

      // Simulate server switch: change socket version → new client instance.
      container.read(socketVersionProvider.notifier).state = 2;

      // The ref.listen callback fires synchronously — ingress should be reset.
      expect(ingress.lastSeqByScope, isEmpty,
          reason:
              'Post server-switch: ingress must be cleared by _ingress.reset()');

      // Verify events with previously-stale seq are now accepted.
      final accepted = ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: 'global',
        receivedAt: DateTime.now(),
        seq: 5,
      ));
      expect(accepted, isTrue,
          reason: 'After reset, seq=5 (lower than old 50) must be accepted');
    });
  });

  // ---------------------------------------------------------------------------
  // INV-839-BACKOFF: Exponential backoff on reconnect failures
  // ---------------------------------------------------------------------------
  group('INV-839-BACKOFF: exponential backoff for reconnect', () {
    test('consecutive failures produce increasing delays', () {
      // Verify the backoff calculation directly.
      final delays = <Duration>[];
      for (var attempt = 0; attempt < 6; attempt++) {
        delays.add(RealtimeService.computeBackoffDelay(
          attempt: attempt,
          baseDelay: const Duration(seconds: 1),
          maxDelay: const Duration(seconds: 60),
          // Use fixed seed for deterministic test.
          random: Random(42),
        ));
      }

      // Each delay must be >= previous (modulo jitter, but with fixed seed
      // the base grows exponentially: 1s, 2s, 4s, 8s, 16s, 32s).
      for (var i = 1; i < delays.length; i++) {
        expect(
            delays[i].inMilliseconds, greaterThan(delays[i - 1].inMilliseconds),
            reason: 'Delay at attempt $i must exceed attempt ${i - 1}');
      }
    });

    test('backoff is capped at maxDelay', () {
      final delay = RealtimeService.computeBackoffDelay(
        attempt: 20, // 2^20 * 1s = way over max
        baseDelay: const Duration(seconds: 1),
        maxDelay: const Duration(seconds: 60),
        random: Random(42),
      );

      // Max is 60s + up to 1000ms jitter = 61s max.
      expect(delay.inSeconds, lessThanOrEqualTo(61));
      expect(delay.inSeconds, greaterThanOrEqualTo(60));
    });

    test('delay resets to base after successful connection', () {
      // attempt=0 should give base delay (1s + jitter).
      final firstDelay = RealtimeService.computeBackoffDelay(
        attempt: 0,
        baseDelay: const Duration(seconds: 1),
        maxDelay: const Duration(seconds: 60),
        random: Random(42),
      );

      // Must be close to base (1s + 0-1000ms jitter).
      expect(firstDelay.inMilliseconds, lessThanOrEqualTo(2000));
      expect(firstDelay.inMilliseconds, greaterThanOrEqualTo(1000));
    });

    test('forceReconnect() delays before connect — wired to production path',
        () {
      fakeAsync((async) {
        // Seeded Random(42) produces deterministic jitter.
        final mockClient = _FakeSocketClient();
        final container = ProviderContainer(overrides: [
          realtimeReductionIngressProvider.overrideWithValue(
            RealtimeReductionIngress(),
          ),
          realtimeClockProvider.overrideWithValue(
            () => async.getClock(DateTime(2026)).now(),
          ),
          realtimeBackoffRandomProvider.overrideWithValue(Random(42)),
          realtimeWatchdogTimerFactoryProvider.overrideWithValue(
            (interval, onTick) => Timer(const Duration(hours: 99), () {}),
          ),
          realtimeSocketClientProvider.overrideWithValue(mockClient),
        ]);

        // Build service + connect so _boundSocketClient is set.
        final service = container.read(realtimeServiceProvider.notifier);
        service.connect();
        async.flushMicrotasks();
        expect(mockClient.connectCalls, 1);

        // First forceReconnect — attempt=0, expect ~1s delay.
        mockClient.connectCalls = 0;
        service.forceReconnect(reason: 'test');
        async.flushMicrotasks();

        // Before 1 second elapses, connect should NOT have been called.
        expect(mockClient.connectCalls, 0,
            reason: 'Backoff delay must elapse before connect');

        // Advance past the backoff (base 1s + up to 1000ms jitter).
        async.elapse(const Duration(seconds: 2));
        expect(mockClient.connectCalls, 1,
            reason: 'Connect must fire after backoff delay elapses');

        // Second forceReconnect — attempt=1, expect ~2s delay.
        mockClient.connectCalls = 0;
        service.forceReconnect(reason: 'test-2');
        async.flushMicrotasks();

        // 1.5 seconds: should still be waiting (delay is ~2s + jitter).
        async.elapse(const Duration(milliseconds: 1500));
        expect(mockClient.connectCalls, 0,
            reason: 'Second attempt backoff (~2s) should not have fired yet');

        // 2 more seconds: should have connected.
        async.elapse(const Duration(seconds: 2));
        expect(mockClient.connectCalls, 1,
            reason: 'Second attempt must connect after longer delay');

        container.dispose();
      });
    });

    test('reconnectAttempts resets on successful connection', () {
      fakeAsync((async) {
        final mockClient = _FakeSocketClient();
        final container = ProviderContainer(overrides: [
          realtimeReductionIngressProvider.overrideWithValue(
            RealtimeReductionIngress(),
          ),
          realtimeClockProvider.overrideWithValue(
            () => async.getClock(DateTime(2026)).now(),
          ),
          realtimeBackoffRandomProvider.overrideWithValue(Random(42)),
          realtimeWatchdogTimerFactoryProvider.overrideWithValue(
            (interval, onTick) => Timer(const Duration(hours: 99), () {}),
          ),
          realtimeSocketClientProvider.overrideWithValue(mockClient),
        ]);

        final service = container.read(realtimeServiceProvider.notifier);
        service.connect();
        async.flushMicrotasks();

        // Force 3 reconnects to increase attempt counter.
        for (var i = 0; i < 3; i++) {
          service.forceReconnect(reason: 'test-$i');
          async.elapse(const Duration(minutes: 2)); // Let all complete.
        }

        expect(
          container.read(realtimeServiceProvider).reconnectAttempts,
          3,
        );

        // Simulate successful connection signal.
        mockClient.emitSignal(const RealtimeSocketConnected());
        async.flushMicrotasks();

        // Attempts must be reset to 0.
        expect(
          container.read(realtimeServiceProvider).reconnectAttempts,
          0,
          reason:
              'reconnectAttempts must reset on successful connection (_onConnected)',
        );

        container.dispose();
      });
    });
  });

  // ---------------------------------------------------------------------------
  // INV-839-FILTER: InboxStore filter epoch — stale response discarded
  // ---------------------------------------------------------------------------
  group('INV-839-FILTER: InboxStore filter epoch', () {
    late _FilterTestInboxRepository fakeRepo;
    late ProviderContainer container;
    late StateProvider<ServerScopeId?> serverIdProvider;

    setUp(() {
      fakeRepo = _FilterTestInboxRepository();
      serverIdProvider = StateProvider<ServerScopeId?>(
        (_) => const ServerScopeId('server-1'),
      );
      container = ProviderContainer(overrides: [
        activeServerScopeIdProvider.overrideWith((ref) {
          return ref.watch(serverIdProvider);
        }),
        inboxRepositoryProvider.overrideWithValue(fakeRepo),
      ]);
      // Trigger build to kick off auto-load.
      container.read(inboxStoreProvider);
    });

    tearDown(() => container.dispose());

    InboxState state() => container.read(inboxStoreProvider);
    InboxStore store() => container.read(inboxStoreProvider.notifier);

    test('rapid filter switch: stale slow response discarded', () async {
      // Initial load completes with "all" filter.
      fakeRepo.nextResponse = InboxResponse(
        items: [_makeItem('ch-all-1')],
        totalCount: 1,
        totalUnreadCount: 0,
        hasMore: false,
      );
      await Future<void>.delayed(Duration.zero); // Let auto-load fire.
      await Future<void>.delayed(Duration.zero); // Let async complete.
      expect(state().status, InboxStatus.success);
      expect(state().filter, InboxFilter.all);

      // Set up: "unread" response is slow, "all" response is fast.
      final unreadCompleter = Completer<InboxResponse>();
      final allCompleter = Completer<InboxResponse>();

      fakeRepo.responseHandler = (filter) {
        if (filter == InboxFilter.unread) return unreadCompleter.future;
        return allCompleter.future;
      };

      // User taps: All → Unread → All (rapidly).
      final switchToUnread = store().setFilter(InboxFilter.unread);
      await Future<void>.delayed(Duration.zero); // Let microtask schedule.
      final switchBackToAll = store().setFilter(InboxFilter.all);
      await Future<void>.delayed(Duration.zero);

      // "All" response arrives first (it's faster).
      allCompleter.complete(InboxResponse(
        items: [_makeItem('ch-all-fresh')],
        totalCount: 1,
        totalUnreadCount: 0,
        hasMore: false,
      ));
      await switchBackToAll;

      // "Unread" response arrives later (stale — user already switched back).
      unreadCompleter.complete(InboxResponse(
        items: [_makeItem('ch-unread-stale')],
        totalCount: 1,
        totalUnreadCount: 1,
        hasMore: false,
      ));
      await switchToUnread;

      // State must reflect "All" (the latest filter), not the stale "Unread".
      expect(state().filter, InboxFilter.all);
      expect(state().items.first.channelId, 'ch-all-fresh',
          reason: 'Stale unread response must be discarded');
    });

    test('sequential filter switches both apply correctly', () async {
      // Initial load.
      fakeRepo.nextResponse = InboxResponse(
        items: [_makeItem('ch-initial')],
        totalCount: 1,
        totalUnreadCount: 0,
        hasMore: false,
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // Switch to unread — completes synchronously.
      fakeRepo.nextResponse = InboxResponse(
        items: [_makeItem('ch-unread')],
        totalCount: 1,
        totalUnreadCount: 1,
        hasMore: false,
      );
      await store().setFilter(InboxFilter.unread);
      expect(state().filter, InboxFilter.unread);
      expect(state().items.first.channelId, 'ch-unread');

      // Switch to all — completes synchronously.
      fakeRepo.nextResponse = InboxResponse(
        items: [_makeItem('ch-all-2')],
        totalCount: 1,
        totalUnreadCount: 0,
        hasMore: false,
      );
      await store().setFilter(InboxFilter.all);
      expect(state().filter, InboxFilter.all);
      expect(state().items.first.channelId, 'ch-all-2');
    });
  });
}

// =============================================================================
// Test helpers
// =============================================================================

InboxItem _makeItem(String channelId) {
  return InboxItem(
    kind: InboxItemKind.channel,
    channelId: channelId,
    channelName: channelId,
    unreadCount: 1,
    lastActivityAt: DateTime(2026, 5, 27),
  );
}

class _FilterTestInboxRepository implements InboxRepository {
  InboxResponse? nextResponse;
  Future<InboxResponse> Function(InboxFilter filter)? responseHandler;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    final handler = responseHandler;
    if (handler != null) return handler(filter);
    return nextResponse ??
        const InboxResponse(
          items: [],
          totalCount: 0,
          totalUnreadCount: 0,
          hasMore: false,
        );
  }

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}
}

/// Minimal fake socket client for testing RealtimeService wiring.
class _FakeSocketClient implements RealtimeSocketClient {
  final StreamController<RealtimeSocketSignal> _signalsController =
      StreamController<RealtimeSocketSignal>.broadcast();
  int connectCalls = 0;
  int disconnectCalls = 0;

  @override
  Stream<RealtimeSocketSignal> get signals => _signalsController.stream;

  @override
  bool get isConnected => connectCalls > disconnectCalls;

  @override
  Future<void> connect() async {
    connectCalls++;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }

  @override
  void emit(String eventName, Object? payload) {}

  @override
  Future<void> dispose() async {
    await _signalsController.close();
  }

  /// Inject a signal (e.g. RealtimeSocketConnected) into the stream.
  void emitSignal(RealtimeSocketSignal signal) {
    _signalsController.add(signal);
  }
}
