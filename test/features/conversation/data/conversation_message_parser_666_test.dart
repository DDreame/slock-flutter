import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';

void main() {
  group('parseConversationIncomingMessage', () {
    test('parses a minimal valid payload', () {
      final result = parseConversationIncomingMessage(
        {
          'channelId': 'ch-1',
          'id': 'msg-1',
          'content': 'hello',
          'createdAt': '2024-01-01T00:00:00Z',
        },
        payloadName: 'test',
      );
      expect(result.conversationId, 'ch-1');
      expect(result.message.id, 'msg-1');
      expect(result.message.content, 'hello');
      expect(result.message.createdAt, DateTime.utc(2024, 1, 1));
      expect(result.message.senderType, 'system'); // default
      expect(result.message.messageType, 'message'); // default
      expect(result.senderId, isNull);
    });

    test('extracts senderId when present', () {
      final result = parseConversationIncomingMessage(
        {
          'channelId': 'ch-1',
          'id': 'msg-1',
          'content': 'hi',
          'createdAt': '2024-01-01T00:00:00Z',
          'senderId': 'user-42',
        },
        payloadName: 'test',
      );
      expect(result.senderId, 'user-42');
    });

    test('throws SerializationFailure on null payload', () {
      expect(
        () => parseConversationIncomingMessage(null, payloadName: 'test'),
        throwsA(isA<SerializationFailure>()),
      );
    });

    test('throws SerializationFailure on missing channelId', () {
      expect(
        () => parseConversationIncomingMessage(
          {'id': 'msg-1', 'content': 'x', 'createdAt': '2024-01-01T00:00:00Z'},
          payloadName: 'test',
        ),
        throwsA(isA<SerializationFailure>()),
      );
    });

    test('throws SerializationFailure on missing id', () {
      expect(
        () => parseConversationIncomingMessage(
          {
            'channelId': 'ch-1',
            'content': 'x',
            'createdAt': '2024-01-01T00:00:00Z',
          },
          payloadName: 'test',
        ),
        throwsA(isA<SerializationFailure>()),
      );
    });

    test('throws SerializationFailure on missing createdAt', () {
      expect(
        () => parseConversationIncomingMessage(
          {'channelId': 'ch-1', 'id': 'msg-1', 'content': 'x'},
          payloadName: 'test',
        ),
        throwsA(isA<SerializationFailure>()),
      );
    });

    test('throws SerializationFailure on invalid createdAt (not ISO)', () {
      expect(
        () => parseConversationIncomingMessage(
          {
            'channelId': 'ch-1',
            'id': 'msg-1',
            'content': 'x',
            'createdAt': 'not-a-date',
          },
          payloadName: 'test',
        ),
        throwsA(isA<SerializationFailure>()),
      );
    });
  });

  group('tryParseConversationIncomingMessage', () {
    test('returns null on invalid payload', () {
      expect(
        tryParseConversationIncomingMessage(null, payloadName: 'test'),
        isNull,
      );
    });

    test('returns null on missing required fields', () {
      expect(
        tryParseConversationIncomingMessage(
          {'channelId': 'ch-1'},
          payloadName: 'test',
        ),
        isNull,
      );
    });

    test('returns parsed message on valid payload', () {
      final result = tryParseConversationIncomingMessage(
        {
          'channelId': 'ch-1',
          'id': 'msg-1',
          'content': 'hi',
          'createdAt': '2024-06-15T12:30:00Z',
        },
        payloadName: 'test',
      );
      expect(result, isNotNull);
      expect(result!.conversationId, 'ch-1');
      expect(result.message.content, 'hi');
    });
  });

  group('parseConversationMessageSummary', () {
    test('parses full payload with all fields', () {
      final result = parseConversationMessageSummary(
        {
          'id': 'msg-full',
          'content': 'full message',
          'createdAt': '2024-03-10T08:00:00Z',
          'senderType': 'human',
          'messageType': 'message',
          'senderId': 'user-1',
          'senderName': 'Alice',
          'seq': 42,
          'threadId': 'thread-1',
          'replyCount': 3,
          'linkedTaskId': 'task-1',
          'isPinned': true,
          'isDeleted': false,
          'attachments': [
            {'name': 'file.pdf', 'type': 'application/pdf', 'url': 'https://x'},
          ],
          'reactions': [
            {
              'emoji': '👍',
              'count': 2,
              'userIds': ['u1', 'u2'],
            },
          ],
          'replyTo': {
            'id': 'reply-msg-1',
            'content': 'original',
            'senderName': 'Bob',
            'senderType': 'human',
          },
        },
        payloadName: 'test',
      );

      expect(result.id, 'msg-full');
      expect(result.content, 'full message');
      expect(result.createdAt, DateTime.utc(2024, 3, 10, 8));
      expect(result.senderType, 'human');
      expect(result.messageType, 'message');
      expect(result.senderId, 'user-1');
      expect(result.senderName, 'Alice');
      expect(result.seq, 42);
      expect(result.threadId, 'thread-1');
      expect(result.replyCount, 3);
      expect(result.linkedTaskId, 'task-1');
      expect(result.isPinned, isTrue);
      expect(result.isDeleted, isFalse);
      expect(result.attachments, hasLength(1));
      expect(result.reactions, hasLength(1));
      expect(result.replyTo, isNotNull);
      expect(result.replyTo!.id, 'reply-msg-1');
      expect(result.replyTo!.content, 'original');
      expect(result.replyTo!.senderName, 'Bob');
    });

    test('defaults senderType to system and messageType to message', () {
      final result = parseConversationMessageSummary(
        {
          'id': 'msg-1',
          'content': '',
          'createdAt': '2024-01-01T00:00:00Z',
        },
        payloadName: 'test',
      );
      expect(result.senderType, 'system');
      expect(result.messageType, 'message');
    });

    test('content defaults to empty string when absent', () {
      final result = parseConversationMessageSummary(
        {'id': 'msg-1', 'createdAt': '2024-01-01T00:00:00Z'},
        payloadName: 'test',
      );
      expect(result.content, '');
    });

    test('isDeleted true when deletedAt is present', () {
      final result = parseConversationMessageSummary(
        {
          'id': 'msg-1',
          'content': 'x',
          'createdAt': '2024-01-01T00:00:00Z',
          'deletedAt': '2024-01-02T00:00:00Z',
        },
        payloadName: 'test',
      );
      expect(result.isDeleted, isTrue);
    });

    test('isDeleted true when isDeleted field is true', () {
      final result = parseConversationMessageSummary(
        {
          'id': 'msg-1',
          'content': 'x',
          'createdAt': '2024-01-01T00:00:00Z',
          'isDeleted': true,
        },
        payloadName: 'test',
      );
      expect(result.isDeleted, isTrue);
    });

    test('linkedTask parsed from nested object', () {
      final result = parseConversationMessageSummary(
        {
          'id': 'msg-1',
          'content': 'task msg',
          'createdAt': '2024-01-01T00:00:00Z',
          'linkedTask': {
            'id': 'lt-1',
            'taskNumber': 7,
            'status': 'in_progress',
            'claimedByName': 'Eve',
          },
        },
        payloadName: 'test',
      );
      expect(result.linkedTask, isNotNull);
      expect(result.linkedTask!.id, 'lt-1');
      expect(result.linkedTask!.taskNumber, 7);
      expect(result.linkedTask!.status, 'in_progress');
      expect(result.linkedTask!.claimedByName, 'Eve');
      // linkedTaskId falls back to linkedTask.id when direct field is null.
      expect(result.linkedTaskId, 'lt-1');
    });

    test('linkedTaskId prefers direct field over linkedTask.id', () {
      final result = parseConversationMessageSummary(
        {
          'id': 'msg-1',
          'content': 'x',
          'createdAt': '2024-01-01T00:00:00Z',
          'linkedTaskId': 'direct-id',
          'linkedTask': {'id': 'nested-id', 'taskNumber': 1, 'status': 'todo'},
        },
        payloadName: 'test',
      );
      expect(result.linkedTaskId, 'direct-id');
    });

    test('handles non-Map payload with error', () {
      expect(
        () => parseConversationMessageSummary('string', payloadName: 'test'),
        throwsA(isA<SerializationFailure>()),
      );
    });

    test('resolves senderName via nested sender identity', () {
      final result = parseConversationMessageSummary(
        {
          'id': 'msg-1',
          'content': 'x',
          'createdAt': '2024-01-01T00:00:00Z',
          'sender': {'displayName': 'NestedSender'},
        },
        payloadName: 'test',
      );
      expect(result.senderName, 'NestedSender');
    });
  });

  group('requireConversationPayloadList', () {
    test('returns list for valid list payload', () {
      final result = requireConversationPayloadList(
        [1, 2, 3],
        payloadName: 'test',
      );
      expect(result, [1, 2, 3]);
    });

    test('throws on non-list payload', () {
      expect(
        () => requireConversationPayloadList('hello', payloadName: 'test'),
        throwsA(isA<SerializationFailure>()),
      );
    });

    test('throws on null payload', () {
      expect(
        () => requireConversationPayloadList(null, payloadName: 'test'),
        throwsA(isA<SerializationFailure>()),
      );
    });
  });

  group('requireConversationPayloadMap', () {
    test('returns Map<String, dynamic> for typed map', () {
      final result = requireConversationPayloadMap(
        <String, dynamic>{'key': 'value'},
        payloadName: 'test',
      );
      expect(result, {'key': 'value'});
    });

    test('coerces untyped Map to Map<String, dynamic>', () {
      final Map<dynamic, dynamic> untyped = {'key': 123};
      final result = requireConversationPayloadMap(
        untyped,
        payloadName: 'test',
      );
      expect(result, isA<Map<String, dynamic>>());
      expect(result['key'], 123);
    });

    test('throws on non-map payload', () {
      expect(
        () => requireConversationPayloadMap(42, payloadName: 'test'),
        throwsA(isA<SerializationFailure>()),
      );
    });
  });

  group('requireConversationPayloadStringField', () {
    test('returns string for present non-empty field', () {
      final result = requireConversationPayloadStringField(
        {'name': 'Alice'},
        field: 'name',
        payloadName: 'test',
      );
      expect(result, 'Alice');
    });

    test('throws on missing field', () {
      expect(
        () => requireConversationPayloadStringField(
          <String, dynamic>{},
          field: 'name',
          payloadName: 'test',
        ),
        throwsA(isA<SerializationFailure>()),
      );
    });

    test('throws on empty string field', () {
      expect(
        () => requireConversationPayloadStringField(
          {'name': ''},
          field: 'name',
          payloadName: 'test',
        ),
        throwsA(isA<SerializationFailure>()),
      );
    });

    test('throws on non-string field', () {
      expect(
        () => requireConversationPayloadStringField(
          {'name': 123},
          field: 'name',
          payloadName: 'test',
        ),
        throwsA(isA<SerializationFailure>()),
      );
    });
  });

  group('requireConversationPayloadDateTimeField', () {
    test('parses valid ISO 8601 datetime', () {
      final result = requireConversationPayloadDateTimeField(
        {'ts': '2024-06-15T12:30:00Z'},
        field: 'ts',
        payloadName: 'test',
      );
      expect(result, DateTime.utc(2024, 6, 15, 12, 30));
    });

    test('throws on missing field', () {
      expect(
        () => requireConversationPayloadDateTimeField(
          <String, dynamic>{},
          field: 'ts',
          payloadName: 'test',
        ),
        throwsA(isA<SerializationFailure>()),
      );
    });

    test('throws on invalid datetime string', () {
      expect(
        () => requireConversationPayloadDateTimeField(
          {'ts': 'not-a-date'},
          field: 'ts',
          payloadName: 'test',
        ),
        throwsA(isA<SerializationFailure>()),
      );
    });

    test('throws on non-string value', () {
      expect(
        () => requireConversationPayloadDateTimeField(
          {'ts': 12345},
          field: 'ts',
          payloadName: 'test',
        ),
        throwsA(isA<SerializationFailure>()),
      );
    });
  });

  group('readOptionalConversationPayloadString', () {
    test('returns string for non-empty string', () {
      expect(readOptionalConversationPayloadString('hello'), 'hello');
    });

    test('returns null for empty string', () {
      expect(readOptionalConversationPayloadString(''), isNull);
    });

    test('returns null for non-string', () {
      expect(readOptionalConversationPayloadString(42), isNull);
    });

    test('returns null for null', () {
      expect(readOptionalConversationPayloadString(null), isNull);
    });
  });

  group('readOptionalConversationPayloadInt', () {
    test('returns int for int value', () {
      expect(readOptionalConversationPayloadInt(42), 42);
    });

    test('converts num to int', () {
      expect(readOptionalConversationPayloadInt(3.7), 3);
    });

    test('returns null for non-num', () {
      expect(readOptionalConversationPayloadInt('42'), isNull);
    });

    test('returns null for null', () {
      expect(readOptionalConversationPayloadInt(null), isNull);
    });
  });

  group('describeConversationPayloadType', () {
    test('returns Null for null', () {
      expect(describeConversationPayloadType(null), 'Null');
    });

    test('returns type name for non-null', () {
      expect(describeConversationPayloadType('hello'), 'String');
      expect(describeConversationPayloadType(42), 'int');
    });
  });

  group('tryParseMessageUpdatedPayload', () {
    test('parses valid payload', () {
      final result = tryParseMessageUpdatedPayload({
        'id': 'msg-1',
        'channelId': 'ch-1',
        'content': 'updated text',
      });
      expect(result, isNotNull);
      expect(result!.id, 'msg-1');
      expect(result.channelId, 'ch-1');
      expect(result.content, 'updated text');
    });

    test('returns null on non-map', () {
      expect(tryParseMessageUpdatedPayload('hello'), isNull);
      expect(tryParseMessageUpdatedPayload(null), isNull);
      expect(tryParseMessageUpdatedPayload(42), isNull);
    });

    test('returns null when id is missing', () {
      expect(
        tryParseMessageUpdatedPayload({
          'channelId': 'ch-1',
          'content': 'x',
        }),
        isNull,
      );
    });

    test('returns null when channelId is missing', () {
      expect(
        tryParseMessageUpdatedPayload({'id': 'msg-1', 'content': 'x'}),
        isNull,
      );
    });

    test('returns null when content is missing', () {
      expect(
        tryParseMessageUpdatedPayload({'id': 'msg-1', 'channelId': 'ch-1'}),
        isNull,
      );
    });

    test('coerces untyped Map', () {
      final Map<dynamic, dynamic> untyped = {
        'id': 'msg-1',
        'channelId': 'ch-1',
        'content': 'hi',
      };
      final result = tryParseMessageUpdatedPayload(untyped);
      expect(result, isNotNull);
      expect(result!.id, 'msg-1');
    });
  });

  group('tryParseMessageDeletedPayload', () {
    test('parses payload with id field', () {
      final result = tryParseMessageDeletedPayload({
        'id': 'msg-1',
        'channelId': 'ch-1',
      });
      expect(result, isNotNull);
      expect(result!.id, 'msg-1');
      expect(result.channelId, 'ch-1');
    });

    test('falls back to messageId field', () {
      final result = tryParseMessageDeletedPayload({
        'messageId': 'msg-2',
        'channelId': 'ch-1',
      });
      expect(result, isNotNull);
      expect(result!.id, 'msg-2');
    });

    test('prefers id over messageId', () {
      final result = tryParseMessageDeletedPayload({
        'id': 'primary',
        'messageId': 'fallback',
        'channelId': 'ch-1',
      });
      expect(result!.id, 'primary');
    });

    test('returns null on non-map', () {
      expect(tryParseMessageDeletedPayload(null), isNull);
      expect(tryParseMessageDeletedPayload('string'), isNull);
    });

    test('returns null when both id and messageId missing', () {
      expect(
        tryParseMessageDeletedPayload({'channelId': 'ch-1'}),
        isNull,
      );
    });

    test('returns null when channelId missing', () {
      expect(
        tryParseMessageDeletedPayload({'id': 'msg-1'}),
        isNull,
      );
    });
  });

  group('tryParseMessagePinnedPayload', () {
    test('parses valid pinned payload', () {
      final result = tryParseMessagePinnedPayload(
        {'id': 'msg-1', 'channelId': 'ch-1'},
        isPinned: true,
      );
      expect(result, isNotNull);
      expect(result!.id, 'msg-1');
      expect(result.channelId, 'ch-1');
      expect(result.isPinned, isTrue);
    });

    test('parses valid unpinned payload', () {
      final result = tryParseMessagePinnedPayload(
        {'id': 'msg-1', 'channelId': 'ch-1'},
        isPinned: false,
      );
      expect(result!.isPinned, isFalse);
    });

    test('falls back to messageId field', () {
      final result = tryParseMessagePinnedPayload(
        {'messageId': 'msg-3', 'channelId': 'ch-1'},
        isPinned: true,
      );
      expect(result!.id, 'msg-3');
    });

    test('returns null on non-map', () {
      expect(tryParseMessagePinnedPayload(null, isPinned: true), isNull);
      expect(tryParseMessagePinnedPayload(42, isPinned: true), isNull);
    });

    test('returns null when id and messageId both missing', () {
      expect(
        tryParseMessagePinnedPayload(
          {'channelId': 'ch-1'},
          isPinned: true,
        ),
        isNull,
      );
    });

    test('returns null when channelId missing', () {
      expect(
        tryParseMessagePinnedPayload({'id': 'msg-1'}, isPinned: true),
        isNull,
      );
    });
  });

  group('parseAttachments', () {
    test('returns null for null input', () {
      expect(parseAttachments(null), isNull);
    });

    test('returns null for empty list', () {
      expect(parseAttachments(<Object>[]), isNull);
    });

    test('returns null for non-list input', () {
      expect(parseAttachments('not a list'), isNull);
    });

    test('parses old-style payload (name/type/url)', () {
      final result = parseAttachments([
        {'name': 'file.pdf', 'type': 'application/pdf', 'url': 'https://x.com'},
      ]);
      expect(result, hasLength(1));
      expect(result![0].name, 'file.pdf');
      expect(result[0].type, 'application/pdf');
      expect(result[0].url, 'https://x.com');
    });

    test('parses new-style payload (filename/mimeType/thumbnailUrl)', () {
      final result = parseAttachments([
        {
          'filename': 'img.png',
          'mimeType': 'image/png',
          'thumbnailUrl': 'https://thumb.png',
        },
      ]);
      expect(result, hasLength(1));
      expect(result![0].name, 'img.png');
      expect(result[0].type, 'image/png');
      expect(result[0].url, 'https://thumb.png'); // falls back to thumbnailUrl
      expect(result[0].thumbnailUrl, 'https://thumb.png');
    });

    test('old fields take precedence over new fields', () {
      final result = parseAttachments([
        {
          'name': 'old.pdf',
          'filename': 'new.pdf',
          'type': 'application/pdf',
          'mimeType': 'image/png',
          'url': 'https://old.com',
          'thumbnailUrl': 'https://new.com',
        },
      ]);
      expect(result![0].name, 'old.pdf');
      expect(result[0].type, 'application/pdf');
      expect(result[0].url, 'https://old.com');
    });

    test('skips items without name or type', () {
      final result = parseAttachments([
        {'name': 'file.pdf'}, // missing type
        {'type': 'text/plain'}, // missing name
        {'name': 'valid.txt', 'type': 'text/plain', 'url': 'https://v.com'},
      ]);
      expect(result, hasLength(1));
      expect(result![0].name, 'valid.txt');
    });

    test('returns null when all items are invalid', () {
      final result = parseAttachments([
        {'name': 'file.pdf'}, // missing type
        'not a map',
      ]);
      expect(result, isNull);
    });

    test('parses optional fields (id, sizeBytes, createdAt)', () {
      final result = parseAttachments([
        {
          'name': 'file.pdf',
          'type': 'application/pdf',
          'id': 'att-1',
          'sizeBytes': 1024,
          'createdAt': '2024-01-01T00:00:00Z',
        },
      ]);
      expect(result![0].id, 'att-1');
      expect(result[0].sizeBytes, 1024);
      expect(result[0].createdAt, DateTime.utc(2024, 1, 1));
    });

    test('handles untyped Map items', () {
      final Map<dynamic, dynamic> untyped = {
        'name': 'file.txt',
        'type': 'text/plain',
      };
      final result = parseAttachments([untyped]);
      expect(result, hasLength(1));
      expect(result![0].name, 'file.txt');
    });

    test('skips non-map items in list', () {
      final result = parseAttachments([
        'string',
        42,
        null,
        {'name': 'file.txt', 'type': 'text/plain'},
      ]);
      expect(result, hasLength(1));
    });
  });

  group('parseReactions', () {
    test('returns empty list for null input', () {
      expect(parseReactions(null), isEmpty);
    });

    test('returns empty list for empty list', () {
      expect(parseReactions(<Object>[]), isEmpty);
    });

    test('returns empty list for non-list input', () {
      expect(parseReactions('not a list'), isEmpty);
    });

    test('parses valid reaction with userIds', () {
      final result = parseReactions([
        {
          'emoji': '👍',
          'count': 3,
          'userIds': ['u1', 'u2', 'u3'],
        },
      ]);
      expect(result, hasLength(1));
      expect(result[0].emoji, '👍');
      expect(result[0].count, 3);
      expect(result[0].userIds, ['u1', 'u2', 'u3']);
    });

    test('defaults count to 1 when absent', () {
      final result = parseReactions([
        {
          'emoji': '❤️',
          'userIds': ['u1'],
        },
      ]);
      expect(result[0].count, 1);
    });

    test('skips items without emoji', () {
      final result = parseReactions([
        {'count': 1, 'userIds': <String>[]},
        {'emoji': '🎉', 'count': 2, 'userIds': <String>[]},
      ]);
      expect(result, hasLength(1));
      expect(result[0].emoji, '🎉');
    });

    test('handles missing userIds gracefully', () {
      final result = parseReactions([
        {'emoji': '👍', 'count': 1},
      ]);
      expect(result[0].userIds, isEmpty);
    });

    test('filters invalid userIds entries', () {
      final result = parseReactions([
        {
          'emoji': '👍',
          'count': 2,
          'userIds': ['valid', '', null, 42],
        },
      ]);
      expect(result[0].userIds, ['valid']);
    });

    test('skips non-map items in list', () {
      final result = parseReactions([
        'invalid',
        {'emoji': '🔥', 'count': 1, 'userIds': <String>[]},
      ]);
      expect(result, hasLength(1));
      expect(result[0].emoji, '🔥');
    });
  });

  group('tryParseReactionEventPayload', () {
    test('parses valid payload', () {
      final result = tryParseReactionEventPayload({
        'messageId': 'msg-1',
        'channelId': 'ch-1',
        'emoji': '👍',
        'userId': 'u-1',
      });
      expect(result, isNotNull);
      expect(result!.messageId, 'msg-1');
      expect(result.channelId, 'ch-1');
      expect(result.emoji, '👍');
      expect(result.userId, 'u-1');
    });

    test('returns null on non-map', () {
      expect(tryParseReactionEventPayload(null), isNull);
      expect(tryParseReactionEventPayload('string'), isNull);
      expect(tryParseReactionEventPayload(42), isNull);
    });

    test('returns null when messageId missing', () {
      expect(
        tryParseReactionEventPayload({
          'channelId': 'ch-1',
          'emoji': '👍',
          'userId': 'u-1',
        }),
        isNull,
      );
    });

    test('returns null when channelId missing', () {
      expect(
        tryParseReactionEventPayload({
          'messageId': 'msg-1',
          'emoji': '👍',
          'userId': 'u-1',
        }),
        isNull,
      );
    });

    test('returns null when emoji missing', () {
      expect(
        tryParseReactionEventPayload({
          'messageId': 'msg-1',
          'channelId': 'ch-1',
          'userId': 'u-1',
        }),
        isNull,
      );
    });

    test('returns null when userId missing', () {
      expect(
        tryParseReactionEventPayload({
          'messageId': 'msg-1',
          'channelId': 'ch-1',
          'emoji': '👍',
        }),
        isNull,
      );
    });

    test('coerces untyped Map', () {
      final Map<dynamic, dynamic> untyped = {
        'messageId': 'msg-1',
        'channelId': 'ch-1',
        'emoji': '👍',
        'userId': 'u-1',
      };
      final result = tryParseReactionEventPayload(untyped);
      expect(result, isNotNull);
      expect(result!.messageId, 'msg-1');
    });
  });
}
