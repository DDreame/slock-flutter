import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

void main() {
  group('parseConversationMessageSummary replyTo', () {
    test('parses replyTo with all fields', () {
      final message = parseConversationMessageSummary(
        {
          'id': 'msg-1',
          'content': 'Hello',
          'createdAt': '2026-05-01T10:00:00Z',
          'senderType': 'human',
          'messageType': 'message',
          'replyTo': {
            'id': 'parent-msg-1',
            'content': 'Original message',
            'senderName': 'Alice',
            'senderType': 'human',
          },
        },
        payloadName: 'test',
      );

      expect(message.replyTo, isNotNull);
      expect(message.replyTo!.id, 'parent-msg-1');
      expect(message.replyTo!.content, 'Original message');
      expect(message.replyTo!.senderName, 'Alice');
      expect(message.replyTo!.senderType, 'human');
      expect(message.replyTo!.senderLabel, 'Alice');
    });

    test('parses replyTo with only id and content', () {
      final message = parseConversationMessageSummary(
        {
          'id': 'msg-1',
          'content': 'Reply',
          'createdAt': '2026-05-01T10:00:00Z',
          'senderType': 'human',
          'messageType': 'message',
          'replyTo': {
            'id': 'parent-msg-2',
            'content': 'Short message',
          },
        },
        payloadName: 'test',
      );

      expect(message.replyTo, isNotNull);
      expect(message.replyTo!.id, 'parent-msg-2');
      expect(message.replyTo!.content, 'Short message');
      expect(message.replyTo!.senderName, isNull);
      expect(message.replyTo!.senderType, isNull);
    });

    test('returns null replyTo when field is absent', () {
      final message = parseConversationMessageSummary(
        {
          'id': 'msg-1',
          'content': 'No reply',
          'createdAt': '2026-05-01T10:00:00Z',
          'senderType': 'human',
          'messageType': 'message',
        },
        payloadName: 'test',
      );

      expect(message.replyTo, isNull);
    });

    test('returns null replyTo when field is null', () {
      final message = parseConversationMessageSummary(
        {
          'id': 'msg-1',
          'content': 'Null reply',
          'createdAt': '2026-05-01T10:00:00Z',
          'senderType': 'human',
          'messageType': 'message',
          'replyTo': null,
        },
        payloadName: 'test',
      );

      expect(message.replyTo, isNull);
    });

    test('returns null replyTo when replyTo map lacks id', () {
      final message = parseConversationMessageSummary(
        {
          'id': 'msg-1',
          'content': 'Bad reply',
          'createdAt': '2026-05-01T10:00:00Z',
          'senderType': 'human',
          'messageType': 'message',
          'replyTo': {
            'content': 'No id field',
          },
        },
        payloadName: 'test',
      );

      expect(message.replyTo, isNull);
    });

    test('defaults content to empty string when missing', () {
      final message = parseConversationMessageSummary(
        {
          'id': 'msg-1',
          'content': 'Reply to deleted',
          'createdAt': '2026-05-01T10:00:00Z',
          'senderType': 'human',
          'messageType': 'message',
          'replyTo': {
            'id': 'parent-msg-3',
          },
        },
        payloadName: 'test',
      );

      expect(message.replyTo, isNotNull);
      expect(message.replyTo!.id, 'parent-msg-3');
      expect(message.replyTo!.content, isEmpty);
    });

    test('replyTo resolves senderName from displayName fallback', () {
      final message = parseConversationMessageSummary(
        {
          'id': 'msg-1',
          'content': 'Reply',
          'createdAt': '2026-05-01T10:00:00Z',
          'senderType': 'human',
          'messageType': 'message',
          'replyTo': {
            'id': 'parent-msg-4',
            'content': 'Original',
            'displayName': 'Bob',
            'senderType': 'agent',
          },
        },
        payloadName: 'test',
      );

      expect(message.replyTo, isNotNull);
      // senderName falls back to resolveConversationSenderName which reads displayName
      expect(message.replyTo!.senderName, 'Bob');
      expect(message.replyTo!.senderType, 'agent');
    });
  });

  group('ReplyToSummary', () {
    test('senderLabel returns senderName when present', () {
      const summary = ReplyToSummary(
        id: 'id',
        content: 'text',
        senderName: 'Alice',
        senderType: 'human',
      );
      expect(summary.senderLabel, 'Alice');
    });

    test('senderLabel returns Agent for agent type without name', () {
      const summary = ReplyToSummary(
        id: 'id',
        content: 'text',
        senderType: 'agent',
      );
      expect(summary.senderLabel, 'Agent');
    });

    test('senderLabel returns Member for human type without name', () {
      const summary = ReplyToSummary(
        id: 'id',
        content: 'text',
        senderType: 'human',
      );
      expect(summary.senderLabel, 'Member');
    });

    test('senderLabel returns System for unknown type without name', () {
      const summary = ReplyToSummary(
        id: 'id',
        content: 'text',
        senderType: 'bot',
      );
      expect(summary.senderLabel, 'System');
    });

    test('senderLabel returns System when senderType is null', () {
      const summary = ReplyToSummary(
        id: 'id',
        content: 'text',
      );
      expect(summary.senderLabel, 'System');
    });

    test('equality and hashCode', () {
      const a = ReplyToSummary(
        id: 'id',
        content: 'text',
        senderName: 'Alice',
        senderType: 'human',
      );
      const b = ReplyToSummary(
        id: 'id',
        content: 'text',
        senderName: 'Alice',
        senderType: 'human',
      );
      const c = ReplyToSummary(
        id: 'id',
        content: 'different',
        senderName: 'Alice',
        senderType: 'human',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
