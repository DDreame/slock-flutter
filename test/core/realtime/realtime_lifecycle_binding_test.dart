import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/stores/session/session_store.dart';

import '../../stores/session/session_store_persistence_test.dart'
    show FakeSecureStorage;

void main() {
  test('does not connect until bootstrap is ready, then connects once',
      () async {
    final ingress = RealtimeReductionIngress();
    final socket = _FakeRealtimeSocketClient();
    final storage = FakeSecureStorage();
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
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

    expect(socket.connectCalls, 0);

    container.read(appReadyProvider.notifier).state = true;
    await Future<void>.delayed(Duration.zero);

    expect(socket.connectCalls, 1);
  });

  test('disconnects when authenticated session becomes unauthenticated',
      () async {
    final ingress = RealtimeReductionIngress();
    final socket = _FakeRealtimeSocketClient();
    final storage = FakeSecureStorage();
    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        realtimeReductionIngressProvider.overrideWithValue(ingress),
        realtimeSocketClientProvider.overrideWithValue(socket),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await ingress.dispose();
    });

    container.read(realtimeLifecycleBindingProvider);
    container.read(appReadyProvider.notifier).state = true;
    await container
        .read(sessionStoreProvider.notifier)
        .login(email: 'test@example.com', password: 'password');
    await Future<void>.delayed(Duration.zero);

    expect(socket.connectCalls, 1);

    await container.read(sessionStoreProvider.notifier).logout();
    await Future<void>.delayed(Duration.zero);

    expect(socket.disconnectCalls, 1);
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

  @override
  Future<void> dispose() async {
    await _signalsController.close();
  }
}
