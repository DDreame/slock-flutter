import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstraction for managing the Android foreground service that keeps
/// real-time push delivery alive while the app is in use.
///
/// On Android the concrete implementation uses a platform channel to
/// start/stop a persistent foreground [Service]; on other platforms
/// the no-op fallback is used.
abstract class ForegroundServiceManager {
  /// Start the foreground service with a persistent notification.
  Future<void> startService();

  /// Stop the foreground service and dismiss the notification.
  Future<void> stopService();

  /// Whether the service is currently running.
  Future<bool> get isRunning;

  /// Persist a native-readable auth flag so the boot receiver and
  /// START_STICKY restart path can determine whether to restore the
  /// service without reading flutter_secure_storage keys directly.
  Future<void> setAuthFlag(bool authenticated);

  /// Signal the background worker to reload auth credentials from
  /// SharedPreferences and reconnect with fresh token/server.
  Future<void> refreshWorkerAuth();

  /// Signal the background worker whether the app foreground is active.
  /// When active, the worker suppresses notifications to avoid
  /// duplicates with the main isolate's notification bridge.
  Future<void> setWorkerForegroundActive(bool active);

  /// Retrieve the background worker's diagnostic snapshot.
  /// Returns null when the service is not running or diagnostics
  /// are unavailable (e.g. on non-Android platforms).
  Future<Map<String, dynamic>?> getWorkerDiagnostics();
}

class NoOpForegroundServiceManager implements ForegroundServiceManager {
  const NoOpForegroundServiceManager();

  @override
  Future<void> startService() async {}

  @override
  Future<void> stopService() async {}

  @override
  Future<bool> get isRunning async => false;

  @override
  Future<void> setAuthFlag(bool authenticated) async {}

  @override
  Future<void> refreshWorkerAuth() async {}

  @override
  Future<void> setWorkerForegroundActive(bool active) async {}

  @override
  Future<Map<String, dynamic>?> getWorkerDiagnostics() async => null;
}

final foregroundServiceManagerProvider =
    Provider<ForegroundServiceManager>((ref) {
  return const NoOpForegroundServiceManager();
});
