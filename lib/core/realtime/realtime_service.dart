import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/realtime/providers.dart';
import 'package:slock_app/core/realtime/realtime_connection_state.dart';
import 'package:slock_app/core/realtime/realtime_event_envelope.dart';
import 'package:slock_app/core/realtime/realtime_reduction_ingress.dart';
import 'package:slock_app/core/realtime/realtime_socket_client.dart';
import 'package:slock_app/core/realtime/realtime_watchdog.dart';

typedef Clock = DateTime Function();
typedef RealtimePeriodicTimerFactory = Timer Function(
    Duration interval, void Function() onTick);

class RealtimeService extends Notifier<RealtimeConnectionState> {
  /// INV-839-BACKOFF: Computes exponential backoff delay with jitter.
  ///
  /// Formula: min(baseDelay * 2^attempt, maxDelay) + random(0, 1000ms).
  /// Prevents reconnection storms when multiple clients lose connection
  /// simultaneously.
  static Duration computeBackoffDelay({
    required int attempt,
    required Duration baseDelay,
    required Duration maxDelay,
    required Random random,
  }) {
    final exponentialMs = (baseDelay.inMilliseconds * pow(2, attempt)).toInt();
    final cappedMs = min(exponentialMs, maxDelay.inMilliseconds);
    final jitterMs = random.nextInt(1000);
    return Duration(milliseconds: cappedMs + jitterMs);
  }

  RealtimeSocketClient get _socketClient =>
      ref.read(realtimeSocketClientProvider);
  RealtimeReductionIngress get _ingress =>
      ref.read(realtimeReductionIngressProvider);
  RealtimeWatchdog get _watchdog => ref.read(realtimeWatchdogProvider);
  RealtimeSocketOptions get _socketOptions =>
      ref.read(realtimeSocketOptionsProvider);
  RealtimeEventNormalizer get _normalizer =>
      ref.read(realtimeEventNormalizerProvider);
  Clock get _clock => ref.read(realtimeClockProvider);
  RealtimePeriodicTimerFactory get _createWatchdogTimer =>
      ref.read(realtimeWatchdogTimerFactoryProvider);

  StreamSubscription<RealtimeSocketSignal>? _signalsSubscription;
  RealtimeSocketClient? _boundSocketClient;
  Timer? _watchdogTimer;
  bool _isReconnecting = false;

  @override
  RealtimeConnectionState build() {
    ref.onDispose(_disposeResources);

    // #775: Detect socket client provider rebuild (token refresh or server
    // switch). Clear stale _boundSocketClient so connect/forceReconnect
    // operates on the fresh client instead of the disposed one.
    ref.listen<RealtimeSocketClient>(realtimeSocketClientProvider, (_, next) {
      if (_boundSocketClient != null && !identical(_boundSocketClient, next)) {
        final previousSub = _signalsSubscription;
        _signalsSubscription = null;
        if (previousSub != null) {
          unawaited(previousSub.cancel());
        }
        _boundSocketClient = null;
        // INV-839-SEQ-RESET: Clear stale seq tracking on server/token switch
        // so events from the new connection aren't rejected as duplicates.
        _ingress.reset();
      }
    });

    return const RealtimeConnectionState();
  }

  Future<void> connect() async {
    final socketClient = _socketClient;
    _bindSignalsIfNeeded(socketClient);
    _ensureWatchdogRunning();
    state = state.copyWith(
      status: socketClient.isConnected
          ? RealtimeConnectionStatus.connected
          : RealtimeConnectionStatus.connecting,
      clearDisconnectReason: true,
    );
    await socketClient.connect();
  }

  Future<void> disconnect() async {
    _stopWatchdog();
    await (_boundSocketClient ?? _socketClient).disconnect();
    state = state.copyWith(
      status: RealtimeConnectionStatus.disconnected,
      lastDisconnectedAt: _clock(),
    );
  }

  Future<void> forceReconnect({required String reason}) async {
    if (_isReconnecting) return;
    _isReconnecting = true;
    final socketClient = _boundSocketClient ?? _socketClient;
    try {
      _bindSignalsIfNeeded(socketClient);
      state = state.copyWith(
        status: RealtimeConnectionStatus.reconnecting,
        reconnectAttempts: state.reconnectAttempts + 1,
        lastForcedReconnectAt: _clock(),
        disconnectReason: reason,
      );
      await socketClient.disconnect();
      await socketClient.connect();
    } finally {
      _isReconnecting = false;
    }
  }

  void _disposeResources() {
    _isReconnecting = false;
    _stopWatchdog();

    final signalsSubscription = _signalsSubscription;
    _signalsSubscription = null;
    if (signalsSubscription != null) {
      unawaited(signalsSubscription.cancel());
    }

    final socketClient = _boundSocketClient;
    _boundSocketClient = null;
    if (socketClient != null) {
      unawaited(socketClient.disconnect());
    }
  }

  void _bindSignalsIfNeeded(RealtimeSocketClient socketClient) {
    if (_signalsSubscription != null &&
        identical(_boundSocketClient, socketClient)) {
      return;
    }

    final previousSubscription = _signalsSubscription;
    if (previousSubscription != null) {
      unawaited(previousSubscription.cancel());
    }

    _boundSocketClient = socketClient;
    _signalsSubscription = socketClient.signals.listen((signal) {
      switch (signal) {
        case RealtimeSocketConnected():
          _onConnected();
        case RealtimeSocketDisconnected():
          _onDisconnected(signal.reason);
        case RealtimeSocketError():
          _onSocketError(signal.error);
        case RealtimeSocketRawEvent():
          _onRawEvent(signal);
      }
    });
  }

  void _ensureWatchdogRunning() {
    _watchdogTimer ??= _createWatchdogTimer(_watchdog.config.interval, () {
      final decision = _watchdog.evaluate(state: state, now: _clock());
      if (decision.shouldForceReconnect) {
        unawaited(
          forceReconnect(reason: decision.reason ?? 'watchdog reconnect'),
        );
      }
    });
  }

  void _stopWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  void _onConnected() {
    final now = _clock();
    state = state.copyWith(
      status: RealtimeConnectionStatus.connected,
      lastConnectedAt: now,
      lastAnyEventAt: now,
      clearDisconnectReason: true,
    );

    final lastSeqByScope = _ingress.lastSeqByScope;
    if (lastSeqByScope.isNotEmpty) {
      (_boundSocketClient ?? _socketClient)
          .emit(_socketOptions.resumeEventName, {
        'lastSeqByScope': lastSeqByScope,
      });
    }
  }

  void _onDisconnected(String? reason) {
    state = state.copyWith(
      status: RealtimeConnectionStatus.disconnected,
      lastDisconnectedAt: _clock(),
      disconnectReason: reason,
    );
  }

  void _onSocketError(Object error) {
    state = state.copyWith(
      status: RealtimeConnectionStatus.reconnecting,
      reconnectAttempts: state.reconnectAttempts + 1,
      disconnectReason: error.toString(),
    );
  }

  void _onRawEvent(RealtimeSocketRawEvent signal) {
    final now = _clock();
    final lastAnyEventAt = now;

    if (_socketOptions.heartbeatEventNames.contains(signal.eventName)) {
      state = state.copyWith(
        lastHeartbeatAt: now,
        lastAnyEventAt: lastAnyEventAt,
      );
      return;
    }

    final envelope = _normalizer(signal.eventName, signal.payload, now);
    if (envelope == null) {
      state = state.copyWith(lastAnyEventAt: lastAnyEventAt);
      return;
    }

    final accepted = _ingress.accept(envelope);
    state = state.copyWith(lastAnyEventAt: lastAnyEventAt);
    if (!accepted) {
      return;
    }
  }
}
