import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/network/connectivity_service.dart';

void main() {
  group('ConnectivityService', () {
    test('initial state reflects provided connectivity', () {
      final service = ConnectivityService.withInitialStatus(
        ConnectivityStatus.online,
        controller: StreamController<ConnectivityStatus>.broadcast(),
      );
      expect(service.isOnline, isTrue);

      final offlineService = ConnectivityService.withInitialStatus(
        ConnectivityStatus.offline,
        controller: StreamController<ConnectivityStatus>.broadcast(),
      );
      expect(offlineService.isOnline, isFalse);
    });

    test('emits online/offline events from stream', () async {
      final controller = StreamController<ConnectivityStatus>.broadcast();
      final service = ConnectivityService.withInitialStatus(
        ConnectivityStatus.online,
        controller: controller,
      );

      final events = <ConnectivityStatus>[];
      final sub = service.statusStream.listen(events.add);

      controller.add(ConnectivityStatus.offline);
      await Future<void>.delayed(Duration.zero);
      expect(service.isOnline, isFalse);
      expect(events, [ConnectivityStatus.offline]);

      controller.add(ConnectivityStatus.online);
      await Future<void>.delayed(Duration.zero);
      expect(service.isOnline, isTrue);
      expect(events, [ConnectivityStatus.offline, ConnectivityStatus.online]);

      await sub.cancel();
      await controller.close();
    });

    test('does not emit duplicate consecutive statuses', () async {
      final controller = StreamController<ConnectivityStatus>.broadcast();
      final service = ConnectivityService.withInitialStatus(
        ConnectivityStatus.online,
        controller: controller,
      );

      final events = <ConnectivityStatus>[];
      final sub = service.statusStream.listen(events.add);

      controller.add(ConnectivityStatus.online); // same as initial
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty, reason: 'Should not emit duplicate status');

      controller.add(ConnectivityStatus.offline);
      controller.add(ConnectivityStatus.offline); // duplicate
      await Future<void>.delayed(Duration.zero);
      expect(events, [ConnectivityStatus.offline],
          reason: 'Should deduplicate consecutive offline');

      await sub.cancel();
      await controller.close();
    });
  });

  group('connectivityServiceProvider', () {
    test('provider is accessible', () {
      final container = ProviderContainer(
        overrides: [
          connectivityServiceProvider.overrideWithValue(
            ConnectivityService.withInitialStatus(
              ConnectivityStatus.online,
              controller: StreamController<ConnectivityStatus>.broadcast(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(connectivityServiceProvider);
      expect(service.isOnline, isTrue);
    });
  });
}
