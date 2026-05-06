import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/notifications/apns_payload_normalizer.dart';
import 'package:slock_app/core/notifications/notification_deep_link_helper.dart';

/// Tests for APNs payload normalization contract.
///
/// These tests validate the exact payload shapes that the native Swift
/// normalization (AppDelegate.notificationPayload) must produce, and
/// confirm they route correctly through Dart deep-link/suppression logic.
void main() {
  group('normalizeApnsPayload', () {
    group('aps.alert extraction', () {
      test('extracts title and body from aps.alert dict', () {
        final result = normalizeApnsPayload({
          'aps': {
            'alert': {'title': 'New message', 'body': 'Hello world'},
            'sound': 'default',
          },
          'type': 'channel',
          'serverId': 's1',
          'channelId': 'c1',
        });

        expect(result, isNotNull);
        expect(result!['title'], 'New message');
        expect(result['body'], 'Hello world');
        expect(result['type'], 'channel');
        expect(result['serverId'], 's1');
        expect(result['channelId'], 'c1');
        // aps envelope must not leak through
        expect(result.containsKey('aps'), isFalse);
      });

      test('extracts body from aps.alert as plain string', () {
        final result = normalizeApnsPayload({
          'aps': {
            'alert': 'Simple notification text',
            'sound': 'default',
          },
          'type': 'dm',
          'serverId': 's1',
          'channelId': 'dm-1',
        });

        expect(result, isNotNull);
        expect(result!['title'], isNull);
        expect(result['body'], 'Simple notification text');
      });

      test('handles missing aps.alert gracefully', () {
        final result = normalizeApnsPayload({
          'aps': {'badge': 1},
          'type': 'channel',
          'serverId': 's1',
          'channelId': 'c1',
        });

        expect(result, isNotNull);
        expect(result!['title'], isNull);
        expect(result['body'], isNull);
        expect(result['type'], 'channel');
      });

      test('handles missing aps key entirely', () {
        final result = normalizeApnsPayload({
          'type': 'channel',
          'serverId': 's1',
          'channelId': 'c1',
          'title': 'Fallback title',
          'body': 'Fallback body',
        });

        expect(result, isNotNull);
        expect(result!['title'], 'Fallback title');
        expect(result['body'], 'Fallback body');
      });
    });

    group('non-Slock payload rejection', () {
      test('returns null for empty map', () {
        expect(normalizeApnsPayload({}), isNull);
      });

      test('returns null for null input', () {
        expect(normalizeApnsPayload(null), isNull);
      });

      test('returns null when type field is missing', () {
        final result = normalizeApnsPayload({
          'aps': {
            'alert': {'title': 'Spam', 'body': 'Not ours'},
          },
          'serverId': 's1',
          'channelId': 'c1',
        });

        expect(result, isNull);
      });

      test('returns null when type field is not a string', () {
        final result = normalizeApnsPayload({
          'aps': {
            'alert': {'title': 'Bad', 'body': 'Type'},
          },
          'type': 123,
          'serverId': 's1',
        });

        expect(result, isNull);
      });
    });

    group('thread parent-id remapping', () {
      test('remaps parentChannelId to channelId for thread type', () {
        final result = normalizeApnsPayload({
          'aps': {
            'alert': {'title': 'Thread reply', 'body': 'New reply'},
          },
          'type': 'thread',
          'serverId': 's1',
          'parentChannelId': 'parent-channel-1',
          'parentMessageId': 'msg-abc-123',
        });

        expect(result, isNotNull);
        expect(result!['type'], 'thread');
        expect(result['channelId'], 'parent-channel-1');
        expect(result['threadId'], 'msg-abc-123');
        // Original keys should be removed
        expect(result.containsKey('parentChannelId'), isFalse);
        expect(result.containsKey('parentMessageId'), isFalse);
      });

      test('does not remap for channel type', () {
        final result = normalizeApnsPayload({
          'aps': {
            'alert': {'title': 'Msg', 'body': 'Hi'},
          },
          'type': 'channel',
          'serverId': 's1',
          'channelId': 'c1',
          'parentChannelId': 'should-not-overwrite',
        });

        expect(result, isNotNull);
        expect(result!['channelId'], 'c1');
        // parentChannelId stays as-is for non-thread types
        expect(result['parentChannelId'], 'should-not-overwrite');
      });

      test('does not remap for dm type', () {
        final result = normalizeApnsPayload({
          'aps': {
            'alert': {'title': 'DM', 'body': 'Hi'},
          },
          'type': 'dm',
          'serverId': 's1',
          'channelId': 'dm-1',
        });

        expect(result, isNotNull);
        expect(result!['channelId'], 'dm-1');
      });

      test('handles thread with missing parentChannelId gracefully', () {
        final result = normalizeApnsPayload({
          'aps': {
            'alert': {'title': 'Thread', 'body': 'Reply'},
          },
          'type': 'thread',
          'serverId': 's1',
          'channelId': 'existing-channel',
          'parentMessageId': 'msg-1',
        });

        expect(result, isNotNull);
        // channelId remains from the raw payload since no parentChannelId
        expect(result!['channelId'], 'existing-channel');
        expect(result['threadId'], 'msg-1');
      });
    });

    group('deep-link routing integration', () {
      test('normalized channel payload routes correctly', () {
        final normalized = normalizeApnsPayload({
          'aps': {
            'alert': {'title': 'Channel', 'body': 'New message'},
          },
          'type': 'channel',
          'serverId': 'server-1',
          'channelId': 'channel-1',
        });

        final route = resolveNotificationRoute(normalized!);
        expect(route, '/servers/server-1/channels/channel-1');
      });

      test('normalized DM payload routes correctly', () {
        final normalized = normalizeApnsPayload({
          'aps': {
            'alert': {'title': 'DM', 'body': 'Hey'},
          },
          'type': 'dm',
          'serverId': 'server-1',
          'channelId': 'dm-channel-1',
        });

        final route = resolveNotificationRoute(normalized!);
        expect(route, '/servers/server-1/dms/dm-channel-1');
      });

      test('normalized thread payload with parent remapping routes correctly',
          () {
        final normalized = normalizeApnsPayload({
          'aps': {
            'alert': {'title': 'Thread', 'body': 'Reply'},
          },
          'type': 'thread',
          'serverId': 'server-1',
          'parentChannelId': 'parent-channel-1',
          'parentMessageId': 'msg-abc-123',
        });

        final route = resolveNotificationRoute(normalized!);
        expect(
            route, contains('/servers/server-1/threads/msg-abc-123/replies'));
        expect(route, contains('channelId=parent-channel-1'));
      });

      test('normalized thread payload produces valid NotificationTarget', () {
        final normalized = normalizeApnsPayload({
          'aps': {
            'alert': {'title': 'Thread', 'body': 'Reply'},
          },
          'type': 'thread',
          'serverId': 'server-1',
          'parentChannelId': 'parent-channel-1',
          'parentMessageId': 'msg-abc-123',
          'senderId': 'user-456',
        });

        final target = parseNotificationTarget(normalized!);
        expect(target, isNotNull);
        expect(target!.serverId, 'server-1');
        expect(target.channelId, 'parent-channel-1');
        expect(target.threadId, 'msg-abc-123');
      });
    });

    group('slock.localRepost marker', () {
      test('local repost marker is stripped from result', () {
        final result = normalizeApnsPayload({
          'type': 'channel',
          'serverId': 's1',
          'channelId': 'c1',
          'title': 'Test',
          'body': 'Body',
          'slock.localRepost': true,
        });

        expect(result, isNotNull);
        expect(result!.containsKey('slock.localRepost'), isFalse);
        expect(result['type'], 'channel');
        expect(result['title'], 'Test');
      });
    });

    group('senderId passthrough', () {
      test('senderId is preserved in normalized output', () {
        final result = normalizeApnsPayload({
          'aps': {
            'alert': {'title': 'Msg', 'body': 'Hi'},
          },
          'type': 'channel',
          'serverId': 's1',
          'channelId': 'c1',
          'senderId': 'user-abc',
        });

        expect(result, isNotNull);
        expect(result!['senderId'], 'user-abc');
      });
    });
  });
}
