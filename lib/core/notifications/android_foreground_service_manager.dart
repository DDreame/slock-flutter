import 'package:flutter/services.dart';
import 'package:slock_app/core/notifications/foreground_service_manager.dart';

const _foregroundServiceChannelName = 'slock/notifications/foreground_service';

/// Platform bridge that abstracts the raw MethodChannel calls so the
/// [AndroidForegroundServiceManager] can be tested with a fake bridge.
abstract class AndroidForegroundServicePlatformBridge {
  Future<void> startService();
  Future<void> stopService();
  Future<bool> isRunning();
  Future<void> setAuthFlag(bool authenticated);
  Future<void> refreshWorkerAuth();
  Future<void> setWorkerForegroundActive(bool active);
}

class MethodChannelForegroundServiceBridge
    implements AndroidForegroundServicePlatformBridge {
  const MethodChannelForegroundServiceBridge();

  static const MethodChannel _channel = MethodChannel(
    _foregroundServiceChannelName,
  );

  @override
  Future<void> startService() async {
    await _channel.invokeMethod<void>('startForegroundService');
  }

  @override
  Future<void> stopService() async {
    await _channel.invokeMethod<void>('stopForegroundService');
  }

  @override
  Future<bool> isRunning() async {
    final result = await _channel.invokeMethod<bool>(
      'isForegroundServiceRunning',
    );
    return result ?? false;
  }

  @override
  Future<void> setAuthFlag(bool authenticated) async {
    await _channel.invokeMethod<void>(
      'setAuthFlag',
      authenticated,
    );
  }

  @override
  Future<void> refreshWorkerAuth() async {
    await _channel.invokeMethod<void>('refreshWorkerAuth');
  }

  @override
  Future<void> setWorkerForegroundActive(bool active) async {
    await _channel.invokeMethod<void>('setWorkerForegroundActive', active);
  }
}

class AndroidForegroundServiceManager implements ForegroundServiceManager {
  const AndroidForegroundServiceManager({
    AndroidForegroundServicePlatformBridge bridge =
        const MethodChannelForegroundServiceBridge(),
  }) : _bridge = bridge;

  final AndroidForegroundServicePlatformBridge _bridge;

  @override
  Future<void> startService() => _bridge.startService();

  @override
  Future<void> stopService() => _bridge.stopService();

  @override
  Future<bool> get isRunning => _bridge.isRunning();

  @override
  Future<void> setAuthFlag(bool authenticated) =>
      _bridge.setAuthFlag(authenticated);

  @override
  Future<void> refreshWorkerAuth() => _bridge.refreshWorkerAuth();

  @override
  Future<void> setWorkerForegroundActive(bool active) =>
      _bridge.setWorkerForegroundActive(active);
}
