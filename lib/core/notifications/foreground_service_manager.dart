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
}

class NoOpForegroundServiceManager implements ForegroundServiceManager {
  const NoOpForegroundServiceManager();

  @override
  Future<void> startService() async {}

  @override
  Future<void> stopService() async {}

  @override
  Future<bool> get isRunning async => false;
}

final foregroundServiceManagerProvider =
    Provider<ForegroundServiceManager>((ref) {
  return const NoOpForegroundServiceManager();
});
