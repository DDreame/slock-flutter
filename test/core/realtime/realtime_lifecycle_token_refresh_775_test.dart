// =============================================================================
// #775 — P1 Realtime Lifecycle: Token Refresh Severs WebSocket + Stale Binding
//
// Verifies:
// A. Token refresh (socket client provider rebuild) triggers automatic
//    reconnection via the lifecycle binding — WebSocket does NOT stay
//    permanently disconnected.
// B. After provider rebuild (server switch), forceReconnect operates on the
//    NEW socket client, not the stale disposed one.
// C. Existing behavior preserved: initial connect still works after
//    isAuthenticated + appReady.
//
// Load-bearing proof:
//   Reverting the `ref.listen<RealtimeSocketClient>(...)` in
//   realtime_lifecycle_binding.dart causes test A to fail (no reconnect
//   after provider rebuild).
//   Reverting the `ref.listen<RealtimeSocketClient>(...)` in
//   realtime_service.dart causes test B to fail (forceReconnect uses stale
//   client).
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/auth/data/auth_repository_provider.dart';
import 'package:slock_app/stores/session/session_store.dart';

import '../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage, FakeAuthRepository;

void main() {
  group('#775 — Token refresh reconnects WebSocket (lifecycle binding)', () {
    // -----------------------------------------------------------------------
    // A: Token refresh (provider rebuild) → automatic reconnection.
    // THIS IS THE LOAD-BEARING TEST for Item 1.
    // Removing ref.listen<RealtimeSocketClient> from lifecycle binding
    // causes this test to fail.
    // -----------------------------------------------------------------------
    test(
      'socket client provider rebuild triggers syncConnection → reconnects',
      () async {
        final ingress = RealtimeReductionIngress();
        final socket1 = _FakeRealtimeSocketClient();
        final socket2 = _FakeRealtimeSocketClient();
        final storage = FakeSecureStorage();

        // Use a StateProvider to simulate provider rebuild.
        final fakeSocketState =
            StateProvider<RealtimeSocketClient>((ref) => socket1);

        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(storage),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            realtimeReductionIngressProvider.overrideWithValue(ingress),
            // Socket client provider watches our state provider —
            // changing state simulates token-refresh rebuild.
            realtimeSocketClientProvider.overrideWith((ref) {
              return ref.watch(fakeSocketState);
            }),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await ingress.dispose();
        });

        // Activate lifecycle binding.
        container.read(realtimeLifecycleBindingProvider);

        // Login + appReady → initial connect on socket1.
        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'test@example.com', password: 'password');
        container.read(appReadyProvider.notifier).state = true;
        await Future<void>.delayed(Duration.zero);

        expect(socket1.connectCalls, 1,
            reason: 'Initial connect should use socket1');

        // Emit connected signal so service state = connected.
        socket1.push(const RealtimeSocketConnected());
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(realtimeServiceProvider).status,
          RealtimeConnectionStatus.connected,
        );

        // In production, token refresh causes old client to disconnect
        // (ref.onDispose → client.dispose() → socket fires disconnect).
        // Simulate: old client fires disconnect before provider rebuilds.
        socket1.push(
          const RealtimeSocketDisconnected(reason: 'transport close'),
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(realtimeServiceProvider).status,
          RealtimeConnectionStatus.disconnected,
        );

        // Now provider rebuilds with new client (simulates token refresh).
        // Without #775 fix: nothing triggers syncConnection → stays dead.
        // With #775 fix: ref.listen<RealtimeSocketClient> fires → reconnects.
        container.read(fakeSocketState.notifier).state = socket2;
        await Future<void>.delayed(Duration.zero);

        expect(socket2.connectCalls, 1,
            reason: '#775: token refresh must trigger reconnect on new client');
      },
    );

    // -----------------------------------------------------------------------
    // A2: Provider rebuild while service state is still CONNECTED (race case).
    // THIS CATCHES THE RACE: old disconnect event hasn't arrived yet, but
    // provider already rebuilt. syncConnection(clientChanged: true) must
    // disconnect stale state + reconnect regardless of current status.
    // -----------------------------------------------------------------------
    test(
      'provider rebuild while still connected triggers disconnect+reconnect',
      () async {
        final ingress = RealtimeReductionIngress();
        final socket1 = _FakeRealtimeSocketClient();
        final socket2 = _FakeRealtimeSocketClient();
        final storage = FakeSecureStorage();

        final fakeSocketState =
            StateProvider<RealtimeSocketClient>((ref) => socket1);

        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(storage),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            realtimeReductionIngressProvider.overrideWithValue(ingress),
            realtimeSocketClientProvider.overrideWith((ref) {
              return ref.watch(fakeSocketState);
            }),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await ingress.dispose();
        });

        container.read(realtimeLifecycleBindingProvider);

        // Login + appReady → initial connect on socket1.
        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'test@example.com', password: 'password');
        container.read(appReadyProvider.notifier).state = true;
        await Future<void>.delayed(Duration.zero);

        expect(socket1.connectCalls, 1);

        // Emit connected so service state = connected.
        socket1.push(const RealtimeSocketConnected());
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(realtimeServiceProvider).status,
          RealtimeConnectionStatus.connected,
        );

        // Provider rebuilds WHILE STATE IS STILL CONNECTED.
        // No disconnect event from old socket — this is the race.
        container.read(fakeSocketState.notifier).state = socket2;
        await Future<void>.delayed(Duration.zero);

        // Must disconnect stale state then reconnect on new client.
        expect(socket2.connectCalls, 1,
            reason: '#775: rebuild while connected must still reconnect '
                'on new client');
      },
    );

    // -----------------------------------------------------------------------
    // B: After provider rebuild, forceReconnect uses the NEW client.
    // THIS IS THE LOAD-BEARING TEST for Item 2.
    // Removing ref.listen<RealtimeSocketClient> from realtime_service.dart
    // causes this test to fail (forceReconnect uses stale _boundSocketClient).
    // -----------------------------------------------------------------------
    test(
      'forceReconnect after provider rebuild operates on new client',
      () async {
        final ingress = RealtimeReductionIngress();
        final socket1 = _FakeRealtimeSocketClient();
        final socket2 = _FakeRealtimeSocketClient();

        final fakeSocketState =
            StateProvider<RealtimeSocketClient>((ref) => socket1);

        final container = ProviderContainer(
          overrides: [
            realtimeReductionIngressProvider.overrideWithValue(ingress),
            realtimeBackoffSleeperProvider.overrideWithValue((_) async {}),
            realtimeSocketClientProvider.overrideWith((ref) {
              return ref.watch(fakeSocketState);
            }),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await ingress.dispose();
        });

        final service = container.read(realtimeServiceProvider.notifier);

        // Initial connect binds to socket1.
        await service.connect();
        expect(socket1.connectCalls, 1);

        // Simulate server switch: provider rebuilds → new socket client.
        container.read(fakeSocketState.notifier).state = socket2;
        await Future<void>.delayed(Duration.zero);

        // forceReconnect should now use socket2 (not stale socket1).
        await service.forceReconnect(reason: 'test server switch');

        expect(socket2.disconnectCalls, 1,
            reason: '#775: forceReconnect must disconnect NEW client');
        expect(socket2.connectCalls, 1,
            reason: '#775: forceReconnect must connect NEW client');
        // socket1 should NOT get any new calls after rebuild.
        expect(socket1.connectCalls, 1,
            reason: '#775: old client must not receive new operations');
        expect(socket1.disconnectCalls, 0,
            reason:
                '#775: old client disconnect is handled by provider dispose');
      },
    );

    // -----------------------------------------------------------------------
    // C: Existing behavior preserved — initial connect still works.
    // -----------------------------------------------------------------------
    test(
      'initial connect after auth+appReady still works (regression guard)',
      () async {
        final ingress = RealtimeReductionIngress();
        final socket = _FakeRealtimeSocketClient();
        final storage = FakeSecureStorage();
        final container = ProviderContainer(
          overrides: [
            secureStorageProvider.overrideWithValue(storage),
            authRepositoryProvider
                .overrideWithValue(const FakeAuthRepository()),
            realtimeReductionIngressProvider.overrideWithValue(ingress),
            realtimeSocketClientProvider.overrideWithValue(socket),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await ingress.dispose();
        });

        container.read(realtimeLifecycleBindingProvider);
        await container
            .read(sessionStoreProvider.notifier)
            .login(email: 'test@example.com', password: 'password');
        await Future<void>.delayed(Duration.zero);

        // Not connected yet — appReady is false.
        expect(socket.connectCalls, 0);

        container.read(appReadyProvider.notifier).state = true;
        await Future<void>.delayed(Duration.zero);

        expect(socket.connectCalls, 1);
      },
    );
  });
}

class _FakeRealtimeSocketClient implements RealtimeSocketClient {
  final StreamController<RealtimeSocketSignal> _signalsController =
      StreamController<RealtimeSocketSignal>.broadcast();

  bool _isConnected = false;
  int connectCalls = 0;
  int disconnectCalls = 0;

  @override
  Stream<RealtimeSocketSignal> get signals => _signalsController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> connect() async {
    connectCalls += 1;
    _isConnected = true;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
    _isConnected = false;
  }

  @override
  void emit(String eventName, Object? payload) {}

  void push(RealtimeSocketSignal signal) {
    _signalsController.add(signal);
  }

  @override
  Future<void> dispose() async {
    await _signalsController.close();
  }
}
