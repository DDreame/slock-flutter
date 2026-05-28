import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/core/realtime/realtime_connection_state.dart';
import 'package:slock_app/core/realtime/realtime_socket_client.dart';
import 'package:slock_app/core/realtime/providers.dart';
import 'package:slock_app/stores/session/session_store.dart';

final realtimeLifecycleBindingProvider = Provider<void>((ref) {
  // Generation counter to detect stale syncConnection() invocations.
  // If another sync is triggered while one is awaiting, the earlier one
  // should bail out after its await completes (#732 TOCTOU fix).
  var syncGeneration = 0;

  Future<void> syncConnection({bool clientChanged = false}) async {
    final generation = ++syncGeneration;

    final session = ref.read(sessionStoreProvider);
    final appReady = ref.read(appReadyProvider);
    final shouldConnect = session.isAuthenticated && appReady;
    final connectionState = ref.read(realtimeServiceProvider);
    final service = ref.read(realtimeServiceProvider.notifier);

    if (shouldConnect) {
      // #775: When the socket client provider rebuilt (token refresh or
      // server switch), the old connection is dead regardless of what
      // service state currently says. Disconnect stale state first, then
      // reconnect with the new client.
      if (clientChanged &&
          connectionState.status != RealtimeConnectionStatus.disconnected) {
        await service.disconnect();
        if (generation != syncGeneration) return;
        await service.connect();
        if (generation != syncGeneration) {
          await service.disconnect();
          return;
        }
      } else if (connectionState.status ==
          RealtimeConnectionStatus.disconnected) {
        await service.connect();
        // Stale — a newer sync has superseded this one; undo the connect
        // so the stale connection doesn't linger in "connected" state (#732).
        if (generation != syncGeneration) {
          await service.disconnect();
          return;
        }
      }
      return;
    }

    if (connectionState.status != RealtimeConnectionStatus.disconnected) {
      await service.disconnect();
      // Bail out if a newer sync was triggered during disconnect().
      if (generation != syncGeneration) return;
    }
  }

  ref.listen<bool>(
    sessionStoreProvider.select((s) => s.isAuthenticated),
    (_, __) {
      unawaited(syncConnection());
    },
  );
  ref.listen<bool>(appReadyProvider, (_, __) {
    unawaited(syncConnection());
  });

  // #775: Token refresh rebuilds realtimeSocketClientProvider (via options
  // dependency chain) without changing isAuthenticated or appReady. Listen
  // for socket client identity changes so we reconnect with the new client.
  ref.listen<RealtimeSocketClient>(realtimeSocketClientProvider, (_, __) {
    unawaited(syncConnection(clientChanged: true));
  });

  // #859: On AppLifecycleState.resumed, immediately attempt reconnect if
  // currently disconnected. Fixes: OS kills WebSocket during backgrounding
  // (>30s). Without this, banner stays until watchdog fires (up to 10s).
  final lifecycleObserver = _RealtimeLifecycleObserver(
    onResumed: () => unawaited(syncConnection()),
  );
  WidgetsBinding.instance.addObserver(lifecycleObserver);
  ref.onDispose(
      () => WidgetsBinding.instance.removeObserver(lifecycleObserver));

  unawaited(syncConnection());
});

/// #859: WidgetsBindingObserver that triggers reconnect on app resume.
class _RealtimeLifecycleObserver extends WidgetsBindingObserver {
  _RealtimeLifecycleObserver({required this.onResumed});

  final VoidCallback onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}
