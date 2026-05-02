import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/core/notifications/foreground_service_manager.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

/// Binds the foreground service lifecycle to the session state.
///
/// **Start condition**: user is authenticated AND app bootstrap is
/// complete AND the service is not already running.
///
/// **Stop condition**: user is explicitly unauthenticated (not just
/// unknown/bootstrapping). The auth flag is always cleared on
/// unauthentication (even if the service is not currently running)
/// so native boot/restart never restores a stale flag. The service
/// is only actually stopped when it is running.
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
  final diagnostics = ref.read(diagnosticsCollectorProvider);

  Future<void> sync() async {
    final session = ref.read(sessionStoreProvider);
    final appReady = ref.read(appReadyProvider);
    final manager = ref.read(foregroundServiceManagerProvider);
    final running = await manager.isRunning;

    final shouldStart = session.isAuthenticated && appReady && !running;

    diagnostics.info(
      'foreground-service',
      'sync: authenticated=${session.isAuthenticated}, '
          'appReady=$appReady, running=$running, '
          'shouldStart=$shouldStart',
    );

    if (shouldStart) {
      await manager.setAuthFlag(true);
      await manager.startService();
      diagnostics.info(
        'foreground-service',
        'Started foreground service',
      );
      return;
    }

    // Always clear the auth flag on explicit unauthentication so
    // native boot/restart never restores a stale `true` flag.
    // Only stop the service when it is actually running.
    if (session.isUnauthenticated) {
      await manager.setAuthFlag(false);
      if (running) {
        await manager.stopService();
        diagnostics.info(
          'foreground-service',
          'Stopped foreground service (unauthenticated)',
        );
      }
    }
  }

  void scheduleSync() {
    pending = pending.then((_) => sync()).catchError((Object e) {
      diagnostics.error(
        'foreground-service',
        'sync error: $e',
      );
    });
  }

  ref.listen<SessionState>(sessionStoreProvider, (_, __) {
    scheduleSync();
  });
  ref.listen<bool>(appReadyProvider, (_, __) {
    scheduleSync();
  });

  scheduleSync();
});
