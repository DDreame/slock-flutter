import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/notifications/foreground_notification_policy.dart';
import 'package:slock_app/core/notifications/notification_target.dart';

void main() {
  group('DefaultForegroundNotificationPolicy', () {
    late DefaultForegroundNotificationPolicy policy;

    setUp(() {
      policy = DefaultForegroundNotificationPolicy();
    });

    NotificationTarget makeTarget({
      String serverId = 's1',
      NotificationSurface surface = NotificationSurface.channel,
      String channelId = 'c1',
      String? threadId,
    }) {
      return NotificationTarget(
        serverId: serverId,
        surface: surface,
        channelId: channelId,
        threadId: threadId,
      );
    }

    VisibleTarget makeVisible({
      String serverId = 's1',
      NotificationSurface surface = NotificationSurface.channel,
      String channelId = 'c1',
      String? threadId,
    }) {
      return VisibleTarget(
        serverId: serverId,
        surface: surface,
        channelId: channelId,
        threadId: threadId,
      );
    }

    test('does not suppress when app is not resumed', () {
      final result = policy.shouldSuppress(
        lifecycleStatus: AppLifecycleStatus.paused,
        visibleTarget: makeVisible(),
        incomingTarget: makeTarget(),
      );
      expect(result, isFalse);
    });

    test('does not suppress when no visible target', () {
      final result = policy.shouldSuppress(
        lifecycleStatus: AppLifecycleStatus.resumed,
        visibleTarget: null,
        incomingTarget: makeTarget(),
      );
      expect(result, isFalse);
    });

    test('suppresses when visible target matches incoming', () {
      final result = policy.shouldSuppress(
        lifecycleStatus: AppLifecycleStatus.resumed,
        visibleTarget: makeVisible(),
        incomingTarget: makeTarget(),
      );
      expect(result, isTrue);
    });

    test('does not suppress when visible target differs by channel', () {
      final result = policy.shouldSuppress(
        lifecycleStatus: AppLifecycleStatus.resumed,
        visibleTarget: makeVisible(channelId: 'c2'),
        incomingTarget: makeTarget(channelId: 'c1'),
      );
      expect(result, isFalse);
    });

    test('does not suppress when visible target differs by server', () {
      final result = policy.shouldSuppress(
        lifecycleStatus: AppLifecycleStatus.resumed,
        visibleTarget: makeVisible(serverId: 's2'),
        incomingTarget: makeTarget(serverId: 's1'),
      );
      expect(result, isFalse);
    });

    test('does not suppress when visible target differs by surface', () {
      final result = policy.shouldSuppress(
        lifecycleStatus: AppLifecycleStatus.resumed,
        visibleTarget: makeVisible(surface: NotificationSurface.dm),
        incomingTarget: makeTarget(surface: NotificationSurface.channel),
      );
      expect(result, isFalse);
    });

    test('suppresses thread notification when viewing same thread', () {
      final result = policy.shouldSuppress(
        lifecycleStatus: AppLifecycleStatus.resumed,
        visibleTarget: makeVisible(
          surface: NotificationSurface.thread,
          threadId: 't1',
        ),
        incomingTarget: makeTarget(
          surface: NotificationSurface.thread,
          threadId: 't1',
        ),
      );
      expect(result, isTrue);
    });

    test('does not suppress thread notification when viewing different thread',
        () {
      final result = policy.shouldSuppress(
        lifecycleStatus: AppLifecycleStatus.resumed,
        visibleTarget: makeVisible(
          surface: NotificationSurface.thread,
          threadId: 't1',
        ),
        incomingTarget: makeTarget(
          surface: NotificationSurface.thread,
          threadId: 't2',
        ),
      );
      expect(result, isFalse);
    });

    test('does not suppress when app is inactive', () {
      final result = policy.shouldSuppress(
        lifecycleStatus: AppLifecycleStatus.inactive,
        visibleTarget: makeVisible(),
        incomingTarget: makeTarget(),
      );
      expect(result, isFalse);
    });
  });

  group('foregroundNotificationPolicyProvider', () {
    test('resolves to DefaultForegroundNotificationPolicy', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final policy = container.read(foregroundNotificationPolicyProvider);
      expect(policy, isA<DefaultForegroundNotificationPolicy>());
    });
  });
}
