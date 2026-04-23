import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/notification_deep_link_helper.dart';
import 'package:slock_app/core/notifications/notification_target.dart';

void main() {
  group('resolveNotificationRoute', () {
    test('returns channel route', () {
      final route = resolveNotificationRoute({
        'type': 'channel',
        'serverId': 's1',
        'channelId': 'c1',
      });
      expect(route, '/servers/s1/channels/c1');
    });

    test('returns dm route', () {
      final route = resolveNotificationRoute({
        'type': 'dm',
        'serverId': 's1',
        'channelId': 'dm1',
      });
      expect(route, '/servers/s1/dms/dm1');
    });

    test('returns thread route', () {
      final route = resolveNotificationRoute({
        'type': 'thread',
        'serverId': 's1',
        'channelId': 'c1',
        'threadId': 't1',
      });
      expect(route, '/servers/s1/threads/t1/replies?channelId=c1');
    });

    test('returns agent route', () {
      final route = resolveNotificationRoute({
        'type': 'agent',
        'agentId': 'a1',
      });
      expect(route, '/agents/a1');
    });

    test('returns profile route', () {
      final route = resolveNotificationRoute({
        'type': 'profile',
        'userId': 'u1',
      });
      expect(route, '/profile/u1');
    });

    test('returns server-scoped profile route when serverId is present', () {
      final route = resolveNotificationRoute({
        'type': 'profile',
        'serverId': 's1',
        'userId': 'u1',
      });
      expect(route, '/servers/s1/profile/u1');
    });

    test('returns null for unknown type', () {
      final route = resolveNotificationRoute({'type': 'unknown'});
      expect(route, isNull);
    });

    test('returns null when type is missing', () {
      final route = resolveNotificationRoute({'serverId': 's1'});
      expect(route, isNull);
    });

    test('returns null for channel without serverId', () {
      final route = resolveNotificationRoute({
        'type': 'channel',
        'channelId': 'c1',
      });
      expect(route, isNull);
    });

    test('returns null for channel without channelId', () {
      final route = resolveNotificationRoute({
        'type': 'channel',
        'serverId': 's1',
      });
      expect(route, isNull);
    });

    test('returns null for thread without threadId', () {
      final route = resolveNotificationRoute({
        'type': 'thread',
        'serverId': 's1',
        'channelId': 'c1',
      });
      expect(route, isNull);
    });

    test('returns null for thread without serverId', () {
      final route = resolveNotificationRoute({
        'type': 'thread',
        'channelId': 'c1',
        'threadId': 't1',
      });
      expect(route, isNull);
    });

    test('returns null for thread without channelId', () {
      final route = resolveNotificationRoute({
        'type': 'thread',
        'serverId': 's1',
        'threadId': 't1',
      });
      expect(route, isNull);
    });

    test('returns null for agent without agentId', () {
      final route = resolveNotificationRoute({'type': 'agent'});
      expect(route, isNull);
    });

    test('returns null for profile without userId', () {
      final route = resolveNotificationRoute({'type': 'profile'});
      expect(route, isNull);
    });
  });

  group('parseNotificationTarget', () {
    test('parses channel target', () {
      final target = parseNotificationTarget({
        'type': 'channel',
        'serverId': 's1',
        'channelId': 'c1',
        'messageId': 'm1',
      });
      expect(target, isNotNull);
      expect(target!.surface, NotificationSurface.channel);
      expect(target.serverId, 's1');
      expect(target.channelId, 'c1');
      expect(target.messageId, 'm1');
      expect(target.threadId, isNull);
    });

    test('parses dm target', () {
      final target = parseNotificationTarget({
        'type': 'dm',
        'serverId': 's1',
        'channelId': 'dm1',
      });
      expect(target, isNotNull);
      expect(target!.surface, NotificationSurface.dm);
    });

    test('parses thread target with threadId', () {
      final target = parseNotificationTarget({
        'type': 'thread',
        'serverId': 's1',
        'channelId': 'c1',
        'threadId': 't1',
      });
      expect(target, isNotNull);
      expect(target!.surface, NotificationSurface.thread);
      expect(target.threadId, 't1');
    });

    test('parses agent target', () {
      final target = parseNotificationTarget({
        'type': 'agent',
        'serverId': 's1',
        'channelId': 'c1',
      });
      expect(target, isNotNull);
      expect(target!.surface, NotificationSurface.agent);
    });

    test('returns null for unknown type', () {
      final target = parseNotificationTarget({
        'type': 'unknown',
        'serverId': 's1',
        'channelId': 'c1',
      });
      expect(target, isNull);
    });

    test('returns null when type is missing', () {
      final target = parseNotificationTarget({
        'serverId': 's1',
        'channelId': 'c1',
      });
      expect(target, isNull);
    });

    test('returns null when serverId is missing', () {
      final target = parseNotificationTarget({
        'type': 'channel',
        'channelId': 'c1',
      });
      expect(target, isNull);
    });

    test('returns null when channelId is missing', () {
      final target = parseNotificationTarget({
        'type': 'channel',
        'serverId': 's1',
      });
      expect(target, isNull);
    });
  });

  group('NotificationTarget', () {
    test('equality', () {
      const a = NotificationTarget(
        serverId: 's1',
        surface: NotificationSurface.channel,
        channelId: 'c1',
      );
      const b = NotificationTarget(
        serverId: 's1',
        surface: NotificationSurface.channel,
        channelId: 'c1',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality on different fields', () {
      const a = NotificationTarget(
        serverId: 's1',
        surface: NotificationSurface.channel,
        channelId: 'c1',
      );
      const b = NotificationTarget(
        serverId: 's2',
        surface: NotificationSurface.channel,
        channelId: 'c1',
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('VisibleTarget', () {
    test('matches same channel', () {
      const visible = VisibleTarget(
        serverId: 's1',
        surface: NotificationSurface.channel,
        channelId: 'c1',
      );
      const target = NotificationTarget(
        serverId: 's1',
        surface: NotificationSurface.channel,
        channelId: 'c1',
      );
      expect(visible.matches(target), isTrue);
    });

    test('does not match different channel', () {
      const visible = VisibleTarget(
        serverId: 's1',
        surface: NotificationSurface.channel,
        channelId: 'c1',
      );
      const target = NotificationTarget(
        serverId: 's1',
        surface: NotificationSurface.channel,
        channelId: 'c2',
      );
      expect(visible.matches(target), isFalse);
    });

    test('matches when incoming has no threadId', () {
      const visible = VisibleTarget(
        serverId: 's1',
        surface: NotificationSurface.thread,
        channelId: 'c1',
        threadId: 't1',
      );
      const target = NotificationTarget(
        serverId: 's1',
        surface: NotificationSurface.thread,
        channelId: 'c1',
      );
      expect(visible.matches(target), isTrue);
    });

    test('does not match when threadIds differ', () {
      const visible = VisibleTarget(
        serverId: 's1',
        surface: NotificationSurface.thread,
        channelId: 'c1',
        threadId: 't1',
      );
      const target = NotificationTarget(
        serverId: 's1',
        surface: NotificationSurface.thread,
        channelId: 'c1',
        threadId: 't2',
      );
      expect(visible.matches(target), isFalse);
    });

    test('equality', () {
      const a = VisibleTarget(
        serverId: 's1',
        surface: NotificationSurface.channel,
        channelId: 'c1',
      );
      const b = VisibleTarget(
        serverId: 's1',
        surface: NotificationSurface.channel,
        channelId: 'c1',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
