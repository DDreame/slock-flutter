import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/notifications/background_notification_entrypoint.dart';
import 'package:slock_app/core/network/auth_token_provider.dart'
    show selectedServerIdProvider;
import 'package:slock_app/core/notifications/foreground_service_manager.dart';
import 'package:slock_app/core/realtime/providers.dart'
    show realtimeSocketOptionsProvider;
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/stores/session/session_store.dart';

/// Persists auth credentials to SharedPreferences whenever the
/// session, selected server, or realtime URL changes, so the
/// background notification worker (running in a separate Dart
/// isolate) can read them on startup or refresh.
///
/// After persisting, signals the running headless worker to reload
/// credentials via [ForegroundServiceManager.refreshWorkerAuth].
///
/// On logout, clears the persisted credentials.
final backgroundWorkerAuthBindingProvider = Provider<void>((ref) {
  final diagnostics = ref.read(diagnosticsCollectorProvider);

  /// Persist current credentials and signal the background worker.
  Future<void> persistAndRefresh() async {
    try {
      final session = ref.read(sessionStoreProvider);
      if (!session.isAuthenticated ||
          session.token == null ||
          session.token!.isEmpty) {
        return;
      }

      final options = ref.read(realtimeSocketOptionsProvider);
      final serverId = ref.read(selectedServerIdProvider) ?? '';
      await BackgroundWorkerAuthPersistence.persist(
        token: session.token!,
        userId: session.userId ?? '',
        serverId: serverId,
        realtimeUrl: options.uri,
      );
      diagnostics.info(
        'background-worker-auth',
        'Persisted credentials for background worker',
      );

      // Signal the running headless worker to reload credentials
      // and reconnect with the fresh token/server.
      final manager = ref.read(foregroundServiceManagerProvider);
      final running = await manager.isRunning;
      if (running) {
        await manager.refreshWorkerAuth();
        diagnostics.info(
          'background-worker-auth',
          'Signalled background worker to refresh auth',
        );
      }
    } catch (e) {
      diagnostics.error(
        'background-worker-auth',
        'Failed to persist/refresh credentials: $e',
      );
    }
  }

  // Listen to session changes (token refresh, login/logout).
  ref.listen(sessionStoreProvider, (previous, next) async {
    if (next.isAuthenticated && next.token != null && next.token!.isNotEmpty) {
      await persistAndRefresh();
    } else if (next.isUnauthenticated) {
      try {
        await BackgroundWorkerAuthPersistence.clear();
        diagnostics.info(
          'background-worker-auth',
          'Cleared background worker credentials',
        );
      } catch (e) {
        diagnostics.error(
          'background-worker-auth',
          'Failed to clear credentials: $e',
        );
      }
    }
  });

  // Listen to server selection changes (pure server switch without
  // session mutation).
  ref.listen<String?>(selectedServerIdProvider, (previous, next) {
    if (previous != next) {
      persistAndRefresh();
    }
  });

  // Listen to realtime socket options changes (URL change without
  // session mutation).
  ref.listen(
    realtimeSocketOptionsProvider.select((opts) => opts.uri),
    (previous, next) {
      if (previous != next) {
        persistAndRefresh();
      }
    },
  );
});
