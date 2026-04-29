import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';

void main() {
  group('tryParseMessageDeletedPayload', () {
    test('parses payload with id and channelId', () {
      final result = tryParseMessageDeletedPayload({
        'id': 'msg-1',
        'channelId': 'ch-1',
      });

      expect(result, isNotNull);
      expect(result!.id, 'msg-1');
      expect(result.channelId, 'ch-1');
    });

    test('parses payload with messageId fallback', () {
      final result = tryParseMessageDeletedPayload({
        'messageId': 'msg-1',
        'channelId': 'ch-1',
      });

      expect(result, isNotNull);
      expect(result!.id, 'msg-1');
    });

    test('returns null when id is missing', () {
      final result = tryParseMessageDeletedPayload({'channelId': 'ch-1'});
      expect(result, isNull);
    });

    test('returns null when channelId is missing', () {
      final result = tryParseMessageDeletedPayload({'id': 'msg-1'});
      expect(result, isNull);
    });

    test('returns null for non-map payload', () {
      expect(tryParseMessageDeletedPayload('not a map'), isNull);
      expect(tryParseMessageDeletedPayload(null), isNull);
    });
  });

  group('tryParseMessagePinnedPayload', () {
    test('parses payload for pinned event', () {
      final result = tryParseMessagePinnedPayload(
        {'id': 'msg-1', 'channelId': 'ch-1'},
        isPinned: true,
      );

      expect(result, isNotNull);
      expect(result!.id, 'msg-1');
      expect(result.channelId, 'ch-1');
      expect(result.isPinned, isTrue);
    });

    test('parses payload for unpinned event', () {
      final result = tryParseMessagePinnedPayload(
        {'id': 'msg-1', 'channelId': 'ch-1'},
        isPinned: false,
      );

      expect(result, isNotNull);
      expect(result!.isPinned, isFalse);
    });

    test('parses payload with messageId fallback', () {
      final result = tryParseMessagePinnedPayload(
        {'messageId': 'msg-1', 'channelId': 'ch-1'},
        isPinned: true,
      );

      expect(result, isNotNull);
      expect(result!.id, 'msg-1');
    });

    test('returns null when id is missing', () {
      final result = tryParseMessagePinnedPayload(
        {'channelId': 'ch-1'},
        isPinned: true,
      );
      expect(result, isNull);
    });

    test('returns null for non-map payload', () {
      expect(
        tryParseMessagePinnedPayload('not a map', isPinned: true),
        isNull,
      );
    });
  });

  group('parseConversationMessageSummary isPinned', () {
    test('parses isPinned true from payload', () {
      final message = parseConversationMessageSummary(
        {
          'id': 'msg-1',
          'content': 'Pinned message',
          'createdAt': '2026-04-19T15:00:00Z',
          'senderType': 'human',
          'messageType': 'message',
          'isPinned': true,
        },
        payloadName: 'test',
      );

      expect(message.isPinned, isTrue);
    });

    test('defaults isPinned to false when absent', () {
      final message = parseConversationMessageSummary(
        {
          'id': 'msg-1',
          'content': 'Regular message',
          'createdAt': '2026-04-19T15:00:00Z',
          'senderType': 'human',
          'messageType': 'message',
        },
        payloadName: 'test',
      );

      expect(message.isPinned, isFalse);
    });
  });
}
