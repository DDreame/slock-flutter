import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/core/notifications/foreground_service_manager.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

/// Binds the foreground service lifecycle to the session state.
///
/// Starts the Android foreground service when the user is authenticated
/// **and** the app bootstrap is complete.  Stops the service when the
/// user logs out or the session becomes unauthenticated.
final foregroundServiceLifecycleBindingProvider = Provider<void>((ref) {
  bool serviceRunning = false;

  Future<void> sync() async {
    final session = ref.read(sessionStoreProvider);
    final appReady = ref.read(appReadyProvider);
    final shouldRun = session.isAuthenticated && appReady;
    final manager = ref.read(foregroundServiceManagerProvider);

    if (shouldRun && !serviceRunning) {
      await manager.startService();
      serviceRunning = true;
      return;
    }

    if (!shouldRun && serviceRunning) {
      await manager.stopService();
      serviceRunning = false;
    }
  }

  ref.listen<SessionState>(sessionStoreProvider, (_, __) {
    unawaited(sync());
  });
  ref.listen<bool>(appReadyProvider, (_, __) {
    unawaited(sync());
  });

  unawaited(sync());
});
