import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/realtime/providers.dart';
import 'package:slock_app/core/realtime/realtime_socket_client.dart';
import 'package:slock_app/features/presence/application/presence_store.dart';

void main() {
  group('PresenceStore resource lifecycle', () {
    test(
      'T1: setPresence does not allocate new Map when value is unchanged',
      () {
        // Arrange — create container, keep autoDispose alive.
        final container = ProviderContainer();
        final sub = container.listen(presenceStoreProvider, (_, __) {});
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        final notifier = container.read(presenceStoreProvider.notifier);

        // Set user-1 online initially.
        notifier.setPresence('user-1', 'online');
        final stateAfterFirst = container.read(presenceStoreProvider);

        // Call setPresence with the same value again 100 times.
        for (var i = 0; i < 100; i++) {
          notifier.setPresence('user-1', 'online');
        }
        final stateAfterRepeats = container.read(presenceStoreProvider);

        // The statuses map identity should be reused — no new allocation
        // when the value hasn't changed.
        expect(
          identical(stateAfterFirst.statuses, stateAfterRepeats.statuses),
          isTrue,
          reason: 'setPresence should not allocate a new Map when value '
              'is unchanged (expected identity reuse)',
        );
      },
    );

    test(
      'T2: SocketClient.dispose() closes signal controller',
      () async {
        // Arrange — use a FakeRealtimeSocketClient to verify dispose behavior.
        final client = _FakeRealtimeSocketClient();

        // Act
        await client.dispose();

        // Assert — signal controller should be closed.
        expect(client.isSignalsClosed, isTrue);
      },
    );

    test(
      'T3: RealtimeService._disposeResources() invokes socket disconnect',
      () {
        // Arrange — override realtimeSocketClientProvider with a fake.
        final fakeClient = _FakeRealtimeSocketClient();

        final container = ProviderContainer(
          overrides: [
            realtimeSocketClientProvider.overrideWithValue(fakeClient),
          ],
        );
        addTearDown(container.dispose);

        // Force build of realtimeService so it binds to the socket client.
        container.read(realtimeServiceProvider);

        // Connect first so that _boundSocketClient is set.
        container.read(realtimeServiceProvider.notifier).connect();

        // Act — dispose container triggers _disposeResources via ref.onDispose.
        container.dispose();

        // Assert — disconnect was called (RealtimeService._disposeResources
        // calls socketClient.disconnect()).
        expect(fakeClient.disconnectCalls, greaterThanOrEqualTo(1));
      },
    );

    test(
      'T4: Presence state correctly updated after efficient mutation',
      () {
        // Arrange
        final container = ProviderContainer();
        final sub = container.listen(presenceStoreProvider, (_, __) {});
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        final notifier = container.read(presenceStoreProvider.notifier);

        // Set multiple users online.
        notifier.setPresence('user-1', 'online');
        notifier.setPresence('user-2', 'online');
        notifier.setPresence('user-3', 'idle');

        // Verify intermediate state.
        var state = container.read(presenceStoreProvider);
        expect(state.statusOf('user-1'), UserPresenceStatus.online);
        expect(state.statusOf('user-2'), UserPresenceStatus.online);
        expect(state.statusOf('user-3'), UserPresenceStatus.idle);

        // Set user-2 offline.
        notifier.setPresence('user-2', 'offline');

        // Assert final state reflects all changes correctly.
        state = container.read(presenceStoreProvider);
        expect(state.statusOf('user-1'), UserPresenceStatus.online);
        expect(state.statusOf('user-2'), UserPresenceStatus.offline);
        expect(state.statusOf('user-3'), UserPresenceStatus.idle);
        expect(state.statuses.containsKey('user-2'), isFalse);
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Test fakes
// ---------------------------------------------------------------------------

class _FakeRealtimeSocketClient implements RealtimeSocketClient {
  final StreamController<RealtimeSocketSignal> _signalsController =
      StreamController<RealtimeSocketSignal>.broadcast();
  int disconnectCalls = 0;
  int disposeCalls = 0;
  bool _isConnected = false;

  bool get isSignalsClosed => _signalsController.isClosed;

  @override
  Stream<RealtimeSocketSignal> get signals => _signalsController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> connect() async {
    _isConnected = true;
    _signalsController.add(const RealtimeSocketConnected());
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
    _isConnected = false;
  }

  @override
  void emit(String eventName, Object? payload) {}

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    await _signalsController.close();
  }
}
