// =============================================================================
// #706 — Problem A: Empty-edit parser fix
//
// tryParseMessageUpdatedPayload must distinguish "content field absent" from
// "content is empty string". Editing a message to empty is a valid operation.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';

void main() {
  group('#706 — tryParseMessageUpdatedPayload empty content', () {
    test('content: "" is parsed as valid empty string (not dropped)', () {
      final result = tryParseMessageUpdatedPayload({
        'id': 'msg-1',
        'channelId': 'ch-1',
        'content': '',
      });

      expect(result, isNotNull,
          reason:
              'Empty string content is a valid edit — must not return null');
      expect(result!.id, 'msg-1');
      expect(result.channelId, 'ch-1');
      expect(result.content, '');
    });

    test('content key absent from payload returns null', () {
      final result = tryParseMessageUpdatedPayload({
        'id': 'msg-1',
        'channelId': 'ch-1',
        // no 'content' key at all
      });

      expect(result, isNull,
          reason: 'Missing content field means the payload is malformed');
    });

    test('content: null returns null (null is not a valid string)', () {
      final result = tryParseMessageUpdatedPayload({
        'id': 'msg-1',
        'channelId': 'ch-1',
        'content': null,
      });

      expect(result, isNull,
          reason: 'Explicit null for content is treated as absent');
    });

    test('content: 42 (non-string) returns null', () {
      final result = tryParseMessageUpdatedPayload({
        'id': 'msg-1',
        'channelId': 'ch-1',
        'content': 42,
      });

      expect(result, isNull, reason: 'Non-string content is invalid');
    });

    test('normal non-empty content still works', () {
      final result = tryParseMessageUpdatedPayload({
        'id': 'msg-1',
        'channelId': 'ch-1',
        'content': 'Hello world',
      });

      expect(result, isNotNull);
      expect(result!.content, 'Hello world');
    });

    test('empty id still returns null (only content allows empty)', () {
      final result = tryParseMessageUpdatedPayload({
        'id': '',
        'channelId': 'ch-1',
        'content': 'some text',
      });

      expect(result, isNull, reason: 'Empty id is still invalid');
    });

    test('empty channelId still returns null', () {
      final result = tryParseMessageUpdatedPayload({
        'id': 'msg-1',
        'channelId': '',
        'content': 'some text',
      });

      expect(result, isNull, reason: 'Empty channelId is still invalid');
    });

    test('whitespace-only content is valid (not trimmed)', () {
      final result = tryParseMessageUpdatedPayload({
        'id': 'msg-1',
        'channelId': 'ch-1',
        'content': '   ',
      });

      expect(result, isNotNull);
      expect(result!.content, '   ',
          reason: 'Whitespace-only content should be preserved as-is');
    });
  });
}
