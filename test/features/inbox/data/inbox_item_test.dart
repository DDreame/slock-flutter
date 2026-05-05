import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';

void main() {
  group('InboxItem.fromJson', () {
    test('parses channel item with all fields', () {
      final json = <String, dynamic>{
        'kind': 'channel',
        'channelId': 'ch-1',
        'channelName': 'general',
        'senderName': 'Alice',
        'preview': 'Hello everyone',
        'unreadCount': 5,
        'firstUnreadMessageId': 'msg-100',
        'lastActivityAt': '2026-05-01T12:00:00.000Z',
      };

      final item = InboxItem.fromJson(json);

      expect(item.kind, InboxItemKind.channel);
      expect(item.channelId, 'ch-1');
      expect(item.channelName, 'general');
      expect(item.senderName, 'Alice');
      expect(item.preview, 'Hello everyone');
      expect(item.unreadCount, 5);
      expect(item.firstUnreadMessageId, 'msg-100');
      expect(item.lastActivityAt, DateTime.utc(2026, 5, 1, 12));
      expect(item.threadChannelId, isNull);
      expect(item.parentChannelId, isNull);
      expect(item.parentMessageId, isNull);
      expect(item.threadTitle, isNull);
    });

    test('parses dm item', () {
      final json = <String, dynamic>{
        'kind': 'dm',
        'channelId': 'dm-1',
        'channelName': 'Bob',
        'senderName': 'Bob',
        'preview': 'Hey there',
        'unreadCount': 2,
        'firstUnreadMessageId': 'msg-200',
        'lastActivityAt': '2026-05-02T08:30:00.000Z',
      };

      final item = InboxItem.fromJson(json);

      expect(item.kind, InboxItemKind.dm);
      expect(item.channelId, 'dm-1');
      expect(item.channelName, 'Bob');
      expect(item.unreadCount, 2);
    });

    test('parses thread item with thread fields', () {
      final json = <String, dynamic>{
        'kind': 'thread',
        'channelId': 'thread-ch-1',
        'threadChannelId': 'thread-ch-1',
        'parentChannelId': 'ch-1',
        'parentMessageId': 'msg-50',
        'channelName': 'general',
        'threadTitle': 'Discussion about feature X',
        'senderName': 'Carol',
        'preview': 'I think we should...',
        'unreadCount': 3,
        'firstUnreadMessageId': 'msg-300',
        'lastActivityAt': '2026-05-03T14:00:00.000Z',
      };

      final item = InboxItem.fromJson(json);

      expect(item.kind, InboxItemKind.thread);
      expect(item.channelId, 'thread-ch-1');
      expect(item.threadChannelId, 'thread-ch-1');
      expect(item.parentChannelId, 'ch-1');
      expect(item.parentMessageId, 'msg-50');
      expect(item.channelName, 'general');
      expect(item.threadTitle, 'Discussion about feature X');
      expect(item.senderName, 'Carol');
      expect(item.preview, 'I think we should...');
      expect(item.unreadCount, 3);
    });

    test('handles missing optional fields gracefully', () {
      final json = <String, dynamic>{
        'kind': 'channel',
        'channelId': 'ch-2',
        'unreadCount': 1,
      };

      final item = InboxItem.fromJson(json);

      expect(item.kind, InboxItemKind.channel);
      expect(item.channelId, 'ch-2');
      expect(item.unreadCount, 1);
      expect(item.channelName, isNull);
      expect(item.senderName, isNull);
      expect(item.preview, isNull);
      expect(item.firstUnreadMessageId, isNull);
      expect(item.lastActivityAt, isNull);
    });

    test('defaults unreadCount to 0 when missing', () {
      final json = <String, dynamic>{
        'kind': 'channel',
        'channelId': 'ch-3',
      };

      final item = InboxItem.fromJson(json);

      expect(item.unreadCount, 0);
    });

    test('handles numeric unreadCount as double', () {
      final json = <String, dynamic>{
        'kind': 'dm',
        'channelId': 'dm-2',
        'unreadCount': 7.0,
      };

      final item = InboxItem.fromJson(json);

      expect(item.unreadCount, 7);
    });

    test('falls back to unknown kind for unrecognized value', () {
      final json = <String, dynamic>{
        'kind': 'something_else',
        'channelId': 'ch-4',
        'unreadCount': 1,
      };

      final item = InboxItem.fromJson(json);

      expect(item.kind, InboxItemKind.unknown);
    });

    test('handles null kind as unknown', () {
      final json = <String, dynamic>{
        'channelId': 'ch-5',
        'unreadCount': 1,
      };

      final item = InboxItem.fromJson(json);

      expect(item.kind, InboxItemKind.unknown);
    });

    test('parses lastActivityAt with timezone offset', () {
      final json = <String, dynamic>{
        'kind': 'channel',
        'channelId': 'ch-6',
        'lastActivityAt': '2026-05-04T10:30:00+08:00',
        'unreadCount': 1,
      };

      final item = InboxItem.fromJson(json);

      expect(item.lastActivityAt, isNotNull);
    });

    test('returns null lastActivityAt for invalid date string', () {
      final json = <String, dynamic>{
        'kind': 'channel',
        'channelId': 'ch-7',
        'lastActivityAt': 'not-a-date',
        'unreadCount': 1,
      };

      final item = InboxItem.fromJson(json);

      expect(item.lastActivityAt, isNull);
    });
  });

  group('InboxItem equality', () {
    test('equal items are equal', () {
      final a = InboxItem(
        kind: InboxItemKind.channel,
        channelId: 'ch-1',
        channelName: 'general',
        unreadCount: 5,
        lastActivityAt: DateTime.utc(2026, 5, 1),
      );
      final b = InboxItem(
        kind: InboxItemKind.channel,
        channelId: 'ch-1',
        channelName: 'general',
        unreadCount: 5,
        lastActivityAt: DateTime.utc(2026, 5, 1),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different items are not equal', () {
      const a = InboxItem(
        kind: InboxItemKind.channel,
        channelId: 'ch-1',
        unreadCount: 5,
      );
      const b = InboxItem(
        kind: InboxItemKind.channel,
        channelId: 'ch-2',
        unreadCount: 5,
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('InboxResponse.fromJson', () {
    test('parses full response with items, counts, pagination', () {
      final json = <String, dynamic>{
        'items': [
          {
            'kind': 'channel',
            'channelId': 'ch-1',
            'channelName': 'general',
            'unreadCount': 5,
            'lastActivityAt': '2026-05-01T12:00:00.000Z',
          },
          {
            'kind': 'dm',
            'channelId': 'dm-1',
            'channelName': 'Bob',
            'unreadCount': 2,
            'lastActivityAt': '2026-05-02T08:00:00.000Z',
          },
        ],
        'totalCount': 10,
        'totalUnreadCount': 7,
        'hasMore': true,
      };

      final response = InboxResponse.fromJson(json);

      expect(response.items, hasLength(2));
      expect(response.items[0].kind, InboxItemKind.channel);
      expect(response.items[1].kind, InboxItemKind.dm);
      expect(response.totalCount, 10);
      expect(response.totalUnreadCount, 7);
      expect(response.hasMore, isTrue);
    });

    test('handles missing items array', () {
      final json = <String, dynamic>{
        'totalCount': 0,
        'totalUnreadCount': 0,
        'hasMore': false,
      };

      final response = InboxResponse.fromJson(json);

      expect(response.items, isEmpty);
      expect(response.totalCount, 0);
      expect(response.hasMore, isFalse);
    });

    test('handles null response data', () {
      final response = InboxResponse.fromJson(null);

      expect(response.items, isEmpty);
      expect(response.totalCount, 0);
      expect(response.totalUnreadCount, 0);
      expect(response.hasMore, isFalse);
    });

    test('skips malformed items in array', () {
      final json = <String, dynamic>{
        'items': [
          {
            'kind': 'channel',
            'channelId': 'ch-1',
            'unreadCount': 5,
          },
          'not-a-map',
          42,
          null,
          {
            'kind': 'dm',
            'channelId': 'dm-1',
            'unreadCount': 2,
          },
        ],
        'totalCount': 5,
        'totalUnreadCount': 7,
        'hasMore': false,
      };

      final response = InboxResponse.fromJson(json);

      expect(response.items, hasLength(2));
      expect(response.items[0].channelId, 'ch-1');
      expect(response.items[1].channelId, 'dm-1');
    });

    test('defaults counts and hasMore when missing', () {
      final json = <String, dynamic>{
        'items': [],
      };

      final response = InboxResponse.fromJson(json);

      expect(response.totalCount, 0);
      expect(response.totalUnreadCount, 0);
      expect(response.hasMore, isFalse);
    });
  });
}
