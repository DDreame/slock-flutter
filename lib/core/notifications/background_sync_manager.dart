import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstraction for managing periodic background sync on iOS.
///
/// On iOS the concrete implementation uses a platform channel to
/// schedule/cancel [BGAppRefreshTask]s that run a lightweight
/// native HTTP check for new messages and post a local notification
/// summary.
///
/// **Important:** iOS Background App Refresh is not guaranteed by the
/// system. iOS may throttle, delay, or skip scheduled tasks entirely
/// based on battery, network conditions, and app usage patterns.
/// The primary reliable sync path is WebSocket reconnection on
/// foreground resume — background sync is a best-effort supplement.
///
/// On other platforms the no-op fallback is used.
abstract class BackgroundSyncManager {
  /// Schedule a periodic background sync task.
  ///
  /// On iOS this registers a [BGAppRefreshTask] with the system.
  /// The system decides when to actually run the task.
  Future<void> schedulePeriodicSync();

  /// Cancel any pending background sync tasks.
  Future<void> cancelPeriodicSync();

  /// Persist sync configuration that native code needs to perform
  /// a background HTTP check (API base URL, server ID, etc.).
  ///
  /// Called before [schedulePeriodicSync] so the native handler
  /// has everything it needs without the Flutter engine running.
  Future<void> persistSyncConfig({
    required String apiBaseUrl,
    required String serverId,
  });

  /// Clear persisted sync configuration (e.g. on logout).
  Future<void> clearSyncConfig();
}

class NoOpBackgroundSyncManager implements BackgroundSyncManager {
  const NoOpBackgroundSyncManager();

  @override
  Future<void> schedulePeriodicSync() async {}

  @override
  Future<void> cancelPeriodicSync() async {}

  @override
  Future<void> persistSyncConfig({
    required String apiBaseUrl,
    required String serverId,
  }) async {}

  @override
  Future<void> clearSyncConfig() async {}
}

final backgroundSyncManagerProvider = Provider<BackgroundSyncManager>((ref) {
  return const NoOpBackgroundSyncManager();
});
