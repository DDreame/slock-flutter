import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';

void main() {
  group('tryParseMessageUpdatedPayload', () {
    test('parses payload with required fields', () {
      final result = tryParseMessageUpdatedPayload({
        'id': 'msg-1',
        'channelId': 'ch-1',
        'content': 'Edited text',
      });

      expect(result, isNotNull);
      expect(result!.id, 'msg-1');
      expect(result.channelId, 'ch-1');
      expect(result.content, 'Edited text');
    });

    test('parses payload with extra fields ignored', () {
      final result = tryParseMessageUpdatedPayload({
        'id': 'msg-1',
        'channelId': 'ch-1',
        'content': 'Edited text',
        'senderType': 'human',
        'createdAt': '2026-04-20T01:00:00Z',
        'seq': 5,
      });

      expect(result, isNotNull);
      expect(result!.id, 'msg-1');
      expect(result.channelId, 'ch-1');
      expect(result.content, 'Edited text');
    });

    test('returns null when id is missing', () {
      final result = tryParseMessageUpdatedPayload({
        'channelId': 'ch-1',
        'content': 'Edited text',
      });

      expect(result, isNull);
    });

    test('returns null when channelId is missing', () {
      final result = tryParseMessageUpdatedPayload({
        'id': 'msg-1',
        'content': 'Edited text',
      });

      expect(result, isNull);
    });

    test('returns null when content is missing', () {
      final result = tryParseMessageUpdatedPayload({
        'id': 'msg-1',
        'channelId': 'ch-1',
      });

      expect(result, isNull);
    });

    test('returns null for non-map payload', () {
      expect(tryParseMessageUpdatedPayload('not a map'), isNull);
      expect(tryParseMessageUpdatedPayload(null), isNull);
      expect(tryParseMessageUpdatedPayload(42), isNull);
    });

    test('returns null when required field is empty string', () {
      final result = tryParseMessageUpdatedPayload({
        'id': '',
        'channelId': 'ch-1',
        'content': 'Edited text',
      });

      expect(result, isNull);
    });
  });
}
