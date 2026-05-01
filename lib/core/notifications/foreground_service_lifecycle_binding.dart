import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/core/notifications/foreground_service_manager.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

/// Binds the foreground service lifecycle to the session state.
///
/// **Start condition**: user is authenticated AND app bootstrap is
/// complete AND the service is not already running.
///
/// **Stop condition**: user is explicitly unauthenticated (not just
/// unknown/bootstrapping) AND the service is currently running.  The
/// bootstrap flag and the `unknown` session state are intentionally
/// ignored for stop — a surviving service (e.g. after a process
/// restart where the OS kept the Android service alive) must not be
/// killed just because the Dart side hasn't finished bootstrapping
/// or hasn't determined auth status yet.
///
/// On each sync cycle the binding checks
/// [ForegroundServiceManager.isRunning] rather than relying on a
/// local boolean, so it correctly handles process restarts where
/// the OS-level service may still be alive while Dart state has
/// been reset.
final foregroundServiceLifecycleBindingProvider = Provider<void>((ref) {
  Future<void> sync() async {
    final session = ref.read(sessionStoreProvider);
    final appReady = ref.read(appReadyProvider);
    final manager = ref.read(foregroundServiceManagerProvider);
    final running = await manager.isRunning;

    final shouldStart = session.isAuthenticated && appReady && !running;
    final shouldStop = session.isUnauthenticated && running;

    if (shouldStart) {
      await manager.startService();
      return;
    }

    if (shouldStop) {
      await manager.stopService();
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
