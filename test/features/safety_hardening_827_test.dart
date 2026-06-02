// =============================================================================
// #827 — Safety Hardening (3 items)
//
// A. Outbox hydration race: merge instead of replace
// B. Unawaited persistConversationActivity: catchError prevents unhandled
// C. BackgroundNotificationWorker.refreshAuth: try/catch wrapping
// =============================================================================

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/background_notification_worker.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';

void main() {
  // ===========================================================================
  // C. BackgroundNotificationWorker.refreshAuth — try/catch wrapping
  //
  // Verifies that refreshAuth() does not propagate exceptions from the
  // auth refresher callback or socket connect, since the worker must
  // remain alive regardless of transient network/auth failures.
  // ===========================================================================
  group('#827C — BackgroundNotificationWorker.refreshAuth error resilience',
      () {
    late _FakeSocket fakeSocket;
    late _FakeSink fakeSink;
    late _FakeAuth fakeAuth;

    setUp(() {
      fakeSocket = _FakeSocket();
      fakeSink = _FakeSink();
      fakeAuth = _FakeAuth(
        token: 'test-token',
        userId: 'user-1',
        serverId: 'srv-1',
      );
    });

    test('refreshAuth swallows auth refresher exception', () async {
      final diagnostics = DiagnosticsCollector();
      final worker = BackgroundNotificationWorker(
        socket: fakeSocket,
        notificationSink: fakeSink,
        authProvider: fakeAuth,
        authRefresher: () async => throw Exception('network timeout'),
        diagnostics: diagnostics,
      );
      await worker.start();

      // Should NOT throw.
      await worker.refreshAuth();

      // Worker remains alive.
      expect(worker.isActive, isTrue);

      // Diagnostics should capture the error.
      expect(
        diagnostics.entries,
        contains(
          isA<DiagnosticsEntry>()
              .having((e) => e.tag, 'tag', 'BackgroundWorker')
              .having(
                  (e) => e.message, 'message', contains('refreshAuth failed')),
        ),
      );

      await worker.dispose();
    });

    test('refreshAuth swallows socket connect exception', () async {
      final refreshedAuth = _FakeAuth(
        token: 'new-token',
        userId: 'user-1',
        serverId: 'srv-2',
      );
      final diagnostics = DiagnosticsCollector();
      final worker = BackgroundNotificationWorker(
        socket: fakeSocket,
        notificationSink: fakeSink,
        authProvider: fakeAuth,
        authRefresher: () async => refreshedAuth,
        diagnostics: diagnostics,
      );
      await worker.start();

      // Make the next connect throw.
      fakeSocket.throwOnNextConnect = Exception('connection refused');

      // Should NOT throw.
      await worker.refreshAuth();

      // Worker remains alive.
      expect(worker.isActive, isTrue);

      // Diagnostics captured.
      expect(
        diagnostics.entries,
        contains(
          isA<DiagnosticsEntry>()
              .having((e) => e.tag, 'tag', 'BackgroundWorker')
              .having(
                  (e) => e.message, 'message', contains('refreshAuth failed')),
        ),
      );

      await worker.dispose();
    });

    test('refreshAuth succeeds normally when no error', () async {
      final refreshedAuth = _FakeAuth(
        token: 'fresh-token',
        userId: 'user-1',
        serverId: 'srv-new',
      );
      final worker = BackgroundNotificationWorker(
        socket: fakeSocket,
        notificationSink: fakeSink,
        authProvider: fakeAuth,
        authRefresher: () async => refreshedAuth,
      );
      await worker.start();

      final connectCountBefore = fakeSocket.connectCallCount;
      await worker.refreshAuth();

      expect(fakeSocket.connectCallCount, greaterThan(connectCountBefore));
      expect(fakeSocket.lastConnectToken, 'fresh-token');
      expect(fakeSocket.lastConnectServerId, 'srv-new');

      await worker.dispose();
    });
  });
}

// =============================================================================
// Test Doubles
// =============================================================================

class _FakeSocket implements BackgroundSocketConnection {
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController =
      StreamController<BackgroundSocketStatus>.broadcast();
  bool _connected = false;
  int _connectCallCount = 0;
  String? _lastConnectToken;
  String? _lastConnectServerId;
  Object? throwOnNextConnect;

  int get connectCallCount => _connectCallCount;
  String? get lastConnectToken => _lastConnectToken;
  String? get lastConnectServerId => _lastConnectServerId;

  @override
  bool get isConnected => _connected;

  @override
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  @override
  Stream<BackgroundSocketStatus> get statusChanges => _statusController.stream;

  @override
  Future<void> connect({
    required String uri,
    required String token,
    String? serverId,
  }) async {
    _connectCallCount++;
    _lastConnectToken = token;
    _lastConnectServerId = serverId;
    final error = throwOnNextConnect;
    if (error != null) {
      throwOnNextConnect = null;
      throw error;
    }
    _connected = true;
    _statusController.add(BackgroundSocketStatus.connected);
  }

  @override
  void disconnect() {
    _connected = false;
  }

  @override
  Future<void> dispose() async {
    _connected = false;
    await _eventController.close();
    await _statusController.close();
  }
}

class _FakeSink implements BackgroundNotificationSink {
  @override
  Future<void> showNotification(Map<String, dynamic> payload) async {}
}

class _FakeAuth implements BackgroundAuthProvider {
  _FakeAuth({
    required this.token,
    required this.userId,
    required this.serverId,
  });

  @override
  final String? token;

  @override
  final String? userId;

  @override
  final String? serverId;

  @override
  String get realtimeUrl => 'wss://realtime.example.com';

  @override
  String get apiBaseUrl => 'https://api.example.com';
}
