import 'dart:async';

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

  Future<void> syncConnection() async {
    final generation = ++syncGeneration;

    final session = ref.read(sessionStoreProvider);
    final appReady = ref.read(appReadyProvider);
    final shouldConnect = session.isAuthenticated && appReady;
    final connectionState = ref.read(realtimeServiceProvider);
    final service = ref.read(realtimeServiceProvider.notifier);

    if (shouldConnect) {
      if (connectionState.status == RealtimeConnectionStatus.disconnected) {
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
    unawaited(syncConnection());
  });

  unawaited(syncConnection());
});
