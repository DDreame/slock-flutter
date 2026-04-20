import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/core/realtime/realtime_connection_state.dart';
import 'package:slock_app/core/realtime/providers.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

final realtimeLifecycleBindingProvider = Provider<void>((ref) {
  Future<void> syncConnection() async {
    final session = ref.read(sessionStoreProvider);
    final appReady = ref.read(appReadyProvider);
    final shouldConnect = session.isAuthenticated && appReady;
    final connectionState = ref.read(realtimeServiceProvider);
    final service = ref.read(realtimeServiceProvider.notifier);

    if (shouldConnect) {
      if (connectionState.status == RealtimeConnectionStatus.disconnected) {
        await service.connect();
      }
      return;
    }

    if (connectionState.status != RealtimeConnectionStatus.disconnected) {
      await service.disconnect();
    }
  }

  ref.listen<SessionState>(sessionStoreProvider, (_, __) {
    unawaited(syncConnection());
  });
  ref.listen<bool>(appReadyProvider, (_, __) {
    unawaited(syncConnection());
  });

  unawaited(syncConnection());
});
