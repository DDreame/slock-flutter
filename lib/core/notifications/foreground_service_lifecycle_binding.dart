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
/// unknown/bootstrapping) AND the service is currently running.
///
/// On start the binding also persists a native-readable auth flag
/// via [ForegroundServiceManager.setAuthFlag] so the Android boot
/// receiver and START_STICKY restart path can determine whether to
/// restore the service — without reading flutter_secure_storage keys
/// directly (which use internal key prefixing).
///
/// On each sync cycle the binding checks
/// [ForegroundServiceManager.isRunning] rather than relying on a
/// local boolean, so it correctly handles process restarts where
/// the OS-level service may still be alive while Dart state has
/// been reset.
final foregroundServiceLifecycleBindingProvider = Provider<void>((ref) {
  // Serialize sync calls so concurrent state changes don't race
  // (e.g. _hydrateAuthenticatedSession sets state twice in quick
  // succession, which would otherwise let two syncs both read
  // isRunning = false before either completes startService).
  Future<void> pending = Future<void>.value();

  Future<void> sync() async {
    final session = ref.read(sessionStoreProvider);
    final appReady = ref.read(appReadyProvider);
    final manager = ref.read(foregroundServiceManagerProvider);
    final running = await manager.isRunning;

    final shouldStart = session.isAuthenticated && appReady && !running;
    final shouldStop = session.isUnauthenticated && running;

    if (shouldStart) {
      await manager.setAuthFlag(true);
      await manager.startService();
      return;
    }

    if (shouldStop) {
      await manager.setAuthFlag(false);
      await manager.stopService();
    }
  }

  void scheduleSync() {
    pending = pending
        .then((_) => sync())
        .catchError((_) {}); // keep chain alive on error
  }

  ref.listen<SessionState>(sessionStoreProvider, (_, __) {
    scheduleSync();
  });
  ref.listen<bool>(appReadyProvider, (_, __) {
    scheduleSync();
  });

  scheduleSync();
});
