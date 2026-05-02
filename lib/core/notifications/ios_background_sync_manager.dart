import 'package:flutter/services.dart';
import 'package:slock_app/core/notifications/background_sync_manager.dart';

const _backgroundSyncChannelName = 'slock/notifications/background_sync';

/// Platform bridge that abstracts the raw MethodChannel calls so the
/// [IosBackgroundSyncManager] can be tested with a fake bridge.
abstract class IosBackgroundSyncPlatformBridge {
  Future<void> schedulePeriodicSync();
  Future<void> cancelPeriodicSync();
  Future<void> persistSyncConfig(Map<String, String> config);
  Future<void> clearSyncConfig();
}

class MethodChannelBackgroundSyncBridge
    implements IosBackgroundSyncPlatformBridge {
  const MethodChannelBackgroundSyncBridge();

  static const MethodChannel _channel = MethodChannel(
    _backgroundSyncChannelName,
  );

  @override
  Future<void> schedulePeriodicSync() async {
    await _channel.invokeMethod<void>('schedulePeriodicSync');
  }

  @override
  Future<void> cancelPeriodicSync() async {
    await _channel.invokeMethod<void>('cancelPeriodicSync');
  }

  @override
  Future<void> persistSyncConfig(
    Map<String, String> config,
  ) async {
    await _channel.invokeMethod<void>(
      'persistSyncConfig',
      config,
    );
  }

  @override
  Future<void> clearSyncConfig() async {
    await _channel.invokeMethod<void>('clearSyncConfig');
  }
}

class IosBackgroundSyncManager implements BackgroundSyncManager {
  const IosBackgroundSyncManager({
    IosBackgroundSyncPlatformBridge bridge =
        const MethodChannelBackgroundSyncBridge(),
  }) : _bridge = bridge;

  final IosBackgroundSyncPlatformBridge _bridge;

  @override
  Future<void> schedulePeriodicSync() => _bridge.schedulePeriodicSync();

  @override
  Future<void> cancelPeriodicSync() => _bridge.cancelPeriodicSync();

  @override
  Future<void> persistSyncConfig({
    required String apiBaseUrl,
    required String serverId,
  }) =>
      _bridge.persistSyncConfig({
        'apiBaseUrl': apiBaseUrl,
        'serverId': serverId,
      });

  @override
  Future<void> clearSyncConfig() => _bridge.clearSyncConfig();
}
