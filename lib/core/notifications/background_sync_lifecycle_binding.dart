import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/bootstrap/app_ready_provider.dart';
import 'package:slock_app/core/network/network_config.dart';
import 'package:slock_app/core/notifications/background_sync_manager.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/stores/notification/notification_state.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/server_selection/server_selection_state.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

/// Binds the iOS background sync lifecycle to session, bootstrap,
/// and app lifecycle state.
///
/// **Schedule condition**: user is authenticated AND app bootstrap
/// is complete AND the app is paused (backgrounded) AND a server
/// is selected AND sync is not already scheduled.
///
/// **Cancel condition**: user is explicitly unauthenticated, OR the
/// app returns to foreground (resumed).
///
/// Before scheduling, the binding persists the sync configuration
/// (API base URL, server ID) so the native iOS BGAppRefreshTask
/// handler has everything it needs to make HTTP calls without the
/// Flutter engine running.
///
/// **Important:** iOS Background App Refresh is not guaranteed by
/// the system. iOS may throttle, delay, or skip scheduled tasks
/// based on battery, network, and app usage patterns. The primary
/// reliable sync path remains WebSocket reconnection on foreground
/// resume.
final backgroundSyncLifecycleBindingProvider = Provider<void>((ref) {
  // Serialize sync calls to avoid races (same pattern as
  // foreground service lifecycle binding).
  Future<void> pending = Future<void>.value();
  bool _scheduled = false;

  Future<void> sync() async {
    final session = ref.read(sessionStoreProvider);
    final appReady = ref.read(appReadyProvider);
    final lifecycle = ref.read(notificationStoreProvider).lifecycleStatus;
    final serverSelection = ref.read(serverSelectionStoreProvider);
    final manager = ref.read(backgroundSyncManagerProvider);

    final isPaused = lifecycle == AppLifecycleStatus.paused;
    final hasServer = serverSelection.selectedServerId != null;

    // Cancel on unauthenticated — always clear config.
    if (session.isUnauthenticated) {
      if (_scheduled) {
        await manager.cancelPeriodicSync();
        _scheduled = false;
      }
      await manager.clearSyncConfig();
      return;
    }

    // Cancel when app returns to foreground.
    if (!isPaused && _scheduled) {
      await manager.cancelPeriodicSync();
      _scheduled = false;
      return;
    }

    // Schedule when all conditions are met.
    final shouldSchedule = session.isAuthenticated &&
        appReady &&
        isPaused &&
        hasServer &&
        !_scheduled;

    if (shouldSchedule) {
      final config = ref.read(networkConfigProvider);
      await manager.persistSyncConfig(
        apiBaseUrl: config.baseUrl,
        serverId: serverSelection.selectedServerId!,
      );
      await manager.schedulePeriodicSync();
      _scheduled = true;
    }
  }

  void scheduleSync() {
    pending =
        pending.then((_) => sync()).catchError((_) {}); // keep chain alive
  }

  ref.listen<SessionState>(
    sessionStoreProvider,
    (_, __) => scheduleSync(),
  );
  ref.listen<bool>(
    appReadyProvider,
    (_, __) => scheduleSync(),
  );
  ref.listen<NotificationState>(
    notificationStoreProvider,
    (_, __) => scheduleSync(),
  );
  ref.listen<ServerSelectionState>(
    serverSelectionStoreProvider,
    (_, __) => scheduleSync(),
  );

  scheduleSync();
});
