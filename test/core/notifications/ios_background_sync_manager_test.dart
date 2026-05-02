import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/ios_background_sync_manager.dart';

class FakeBackgroundSyncBridge implements IosBackgroundSyncPlatformBridge {
  int scheduleCalls = 0;
  int cancelCalls = 0;
  int clearConfigCalls = 0;
  Map<String, String>? lastPersistedConfig;

  @override
  Future<void> schedulePeriodicSync() async {
    scheduleCalls++;
  }

  @override
  Future<void> cancelPeriodicSync() async {
    cancelCalls++;
  }

  @override
  Future<void> persistSyncConfig(Map<String, String> config) async {
    lastPersistedConfig = config;
  }

  @override
  Future<void> clearSyncConfig() async {
    clearConfigCalls++;
  }
}

void main() {
  group('IosBackgroundSyncManager', () {
    late FakeBackgroundSyncBridge fakeBridge;
    late IosBackgroundSyncManager manager;

    setUp(() {
      fakeBridge = FakeBackgroundSyncBridge();
      manager = IosBackgroundSyncManager(bridge: fakeBridge);
    });

    test('delegates schedulePeriodicSync to bridge', () async {
      await manager.schedulePeriodicSync();

      expect(fakeBridge.scheduleCalls, 1);
    });

    test('delegates cancelPeriodicSync to bridge', () async {
      await manager.cancelPeriodicSync();

      expect(fakeBridge.cancelCalls, 1);
    });

    test('delegates persistSyncConfig with correct map', () async {
      await manager.persistSyncConfig(
        apiBaseUrl: 'https://api.test.com',
        serverId: 'srv-123',
      );

      expect(fakeBridge.lastPersistedConfig, {
        'apiBaseUrl': 'https://api.test.com',
        'serverId': 'srv-123',
      });
    });

    test('delegates clearSyncConfig to bridge', () async {
      await manager.clearSyncConfig();

      expect(fakeBridge.clearConfigCalls, 1);
    });
  });
}
