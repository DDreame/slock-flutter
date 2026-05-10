import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/inbox/application/message_preview_resolver.dart';

void main() {
  group('MessagePreviewResolver.resolve', () {
    // ---------------------------------------------------------------
    // 1. Deleted messages
    // ---------------------------------------------------------------
    test('deleted message returns 消息已删除', () {
      expect(
        MessagePreviewResolver.resolve(
          content: 'Hello',
          isDeleted: true,
        ),
        '消息已删除',
      );
    });

    test('deleted message with attachments still returns 消息已删除', () {
      expect(
        MessagePreviewResolver.resolve(
          content: '',
          isDeleted: true,
          attachments: const [
            MessageAttachment(name: 'photo.jpg', type: 'image/jpeg'),
          ],
        ),
        '消息已删除',
      );
    });

    // ---------------------------------------------------------------
    // 2. Send state
    // ---------------------------------------------------------------
    test('sending message returns 正在发送...', () {
      expect(
        MessagePreviewResolver.resolve(
          content: 'Hello',
          sendState: MessageSendState.sending,
        ),
        '正在发送...',
      );
    });

    test('failed message returns 未发送，点击重试', () {
      expect(
        MessagePreviewResolver.resolve(
          content: 'Hello',
          sendState: MessageSendState.failed,
        ),
        '未发送，点击重试',
      );
    });

    test('sent message with content returns content', () {
      expect(
        MessagePreviewResolver.resolve(
          content: 'Hello',
          sendState: MessageSendState.sent,
        ),
        'Hello',
      );
    });

    test('deleted wins over sending', () {
      expect(
        MessagePreviewResolver.resolve(
          content: 'Hello',
          isDeleted: true,
          sendState: MessageSendState.sending,
        ),
        '消息已删除',
      );
    });

    test('sending wins over system', () {
      expect(
        MessagePreviewResolver.resolve(
          content: 'Event',
          messageType: 'system',
          sendState: MessageSendState.sending,
        ),
        '正在发送...',
      );
    });

    test('failed wins over content', () {
      expect(
        MessagePreviewResolver.resolve(
          content: 'Hello',
          sendState: MessageSendState.failed,
        ),
        '未发送，点击重试',
      );
    });

    // ---------------------------------------------------------------
    // 3. System messages
    // ---------------------------------------------------------------
    test('system message returns 系统消息', () {
      expect(
        MessagePreviewResolver.resolve(
          content: 'User joined the channel',
          messageType: 'system',
        ),
        '系统消息',
      );
    });

    test('system message without content returns 系统消息', () {
      expect(
        MessagePreviewResolver.resolve(
          content: '',
          messageType: 'system',
        ),
        '系统消息',
      );
    });

    // ---------------------------------------------------------------
    // 4. Text content (non-link)
    // ---------------------------------------------------------------
    test('non-empty content returns content as-is', () {
      expect(
        MessagePreviewResolver.resolve(content: 'Hello world'),
        'Hello world',
      );
    });

    test('content with leading/trailing whitespace is preserved', () {
      expect(
        MessagePreviewResolver.resolve(content: '  hello  '),
        '  hello  ',
      );
    });

    test('whitespace-only content falls through to fallback', () {
      expect(
        MessagePreviewResolver.resolve(content: '   '),
        '新消息',
      );
    });

    test('null content falls through to fallback', () {
      expect(
        MessagePreviewResolver.resolve(content: null),
        '新消息',
      );
    });

    test('empty content falls through to fallback', () {
      expect(
        MessagePreviewResolver.resolve(content: ''),
        '新消息',
      );
    });

    test('mixed text with URL returns content as-is', () {
      expect(
        MessagePreviewResolver.resolve(
          content: 'Check out https://example.com please',
        ),
        'Check out https://example.com please',
      );
    });

    // ---------------------------------------------------------------
    // 5. Link-only content
    // ---------------------------------------------------------------
    test('bare HTTP URL returns 链接', () {
      expect(
        MessagePreviewResolver.resolve(
          content: 'https://example.com/page',
        ),
        '链接',
      );
    });

    test('bare HTTP URL with leading/trailing whitespace returns 链接', () {
      expect(
        MessagePreviewResolver.resolve(
          content: '  https://example.com  ',
        ),
        '链接',
      );
    });

    test('http (non-https) URL returns 链接', () {
      expect(
        MessagePreviewResolver.resolve(
          content: 'http://example.com',
        ),
        '链接',
      );
    });

    test('URL with query string returns 链接', () {
      expect(
        MessagePreviewResolver.resolve(
          content: 'https://example.com/path?q=1&a=2',
        ),
        '链接',
      );
    });

    test('non-URL text is not treated as link', () {
      expect(
        MessagePreviewResolver.resolve(content: 'Hello world'),
        'Hello world',
      );
    });

    // ---------------------------------------------------------------
    // 6. Voice attachments (audio/* MIME)
    // ---------------------------------------------------------------
    test('voice attachment returns 语音消息', () {
      expect(
        MessagePreviewResolver.resolve(
          content: '',
          attachments: const [
            MessageAttachment(name: 'voice_123.m4a', type: 'audio/m4a'),
          ],
        ),
        '语音消息',
      );
    });

    test('audio/mpeg attachment returns 语音消息', () {
      expect(
        MessagePreviewResolver.resolve(
          content: '',
          attachments: const [
            MessageAttachment(name: 'recording.mp3', type: 'audio/mpeg'),
          ],
        ),
        '语音消息',
      );
    });

    // ---------------------------------------------------------------
    // 7. Image attachments (image/* MIME)
    // ---------------------------------------------------------------
    test('image attachment returns 图片', () {
      expect(
        MessagePreviewResolver.resolve(
          content: '',
          attachments: const [
            MessageAttachment(name: 'photo.jpg', type: 'image/jpeg'),
          ],
        ),
        '图片',
      );
    });

    test('image/png attachment returns 图片', () {
      expect(
        MessagePreviewResolver.resolve(
          content: '',
          attachments: const [
            MessageAttachment(name: 'screenshot.png', type: 'image/png'),
          ],
        ),
        '图片',
      );
    });

    // ---------------------------------------------------------------
    // 8. Video attachments
    // ---------------------------------------------------------------
    test('video attachment returns 视频', () {
      expect(
        MessagePreviewResolver.resolve(
          content: '',
          attachments: const [
            MessageAttachment(name: 'clip.mp4', type: 'video/mp4'),
          ],
        ),
        '视频',
      );
    });

    // ---------------------------------------------------------------
    // 9. Other file attachments
    // ---------------------------------------------------------------
    test('file attachment with name returns 附件: filename', () {
      expect(
        MessagePreviewResolver.resolve(
          content: '',
          attachments: const [
            MessageAttachment(name: 'report.pdf', type: 'application/pdf'),
          ],
        ),
        '附件: report.pdf',
      );
    });

    // ---------------------------------------------------------------
    // 10. Priority: content wins over attachments
    // ---------------------------------------------------------------
    test('non-empty content with attachments returns content', () {
      expect(
        MessagePreviewResolver.resolve(
          content: 'Check this out',
          attachments: const [
            MessageAttachment(name: 'photo.jpg', type: 'image/jpeg'),
          ],
        ),
        'Check this out',
      );
    });

    // ---------------------------------------------------------------
    // 11. Priority: deleted wins over everything
    // ---------------------------------------------------------------
    test('deleted system message returns 消息已删除', () {
      expect(
        MessagePreviewResolver.resolve(
          content: 'System event',
          messageType: 'system',
          isDeleted: true,
        ),
        '消息已删除',
      );
    });

    // ---------------------------------------------------------------
    // 12. Multiple attachments — first determines type
    // ---------------------------------------------------------------
    test('multiple attachments uses first for type resolution', () {
      expect(
        MessagePreviewResolver.resolve(
          content: '',
          attachments: const [
            MessageAttachment(name: 'photo.jpg', type: 'image/jpeg'),
            MessageAttachment(name: 'doc.pdf', type: 'application/pdf'),
          ],
        ),
        '图片',
      );
    });

    // ---------------------------------------------------------------
    // 13. Default message type
    // ---------------------------------------------------------------
    test('null messageType with content returns content', () {
      expect(
        MessagePreviewResolver.resolve(
          content: 'Hello',
          messageType: null,
        ),
        'Hello',
      );
    });

    test('messageType=message with content returns content', () {
      expect(
        MessagePreviewResolver.resolve(
          content: 'Hello',
          messageType: 'message',
        ),
        'Hello',
      );
    });

    // ---------------------------------------------------------------
    // 14. Empty attachments list treated as no attachments
    // ---------------------------------------------------------------
    test('empty attachments list falls to fallback', () {
      expect(
        MessagePreviewResolver.resolve(
          content: '',
          attachments: const [],
        ),
        '新消息',
      );
    });

    test('null attachments falls to fallback', () {
      expect(
        MessagePreviewResolver.resolve(
          content: '',
          attachments: null,
        ),
        '新消息',
      );
    });
  });

  group('MessagePreviewResolver.resolveFromMessage', () {
    test('resolves text message', () {
      final msg = ConversationMessageSummary(
        id: 'msg-1',
        content: 'Hello',
        createdAt: DateTime(2026),
        senderType: 'human',
        messageType: 'message',
        reactions: const [],
      );
      expect(MessagePreviewResolver.resolveFromMessage(msg), 'Hello');
    });

    test('resolves deleted message', () {
      final msg = ConversationMessageSummary(
        id: 'msg-1',
        content: 'Hello',
        createdAt: DateTime(2026),
        senderType: 'human',
        messageType: 'message',
        isDeleted: true,
        reactions: const [],
      );
      expect(MessagePreviewResolver.resolveFromMessage(msg), '消息已删除');
    });

    test('resolves system message', () {
      final msg = ConversationMessageSummary(
        id: 'msg-1',
        content: 'Alice joined',
        createdAt: DateTime(2026),
        senderType: 'system',
        messageType: 'system',
        reactions: const [],
      );
      expect(MessagePreviewResolver.resolveFromMessage(msg), '系统消息');
    });

    test('resolves attachment-only message', () {
      final msg = ConversationMessageSummary(
        id: 'msg-1',
        content: '',
        createdAt: DateTime(2026),
        senderType: 'human',
        messageType: 'message',
        attachments: const [
          MessageAttachment(name: 'photo.jpg', type: 'image/jpeg'),
        ],
        reactions: const [],
      );
      expect(MessagePreviewResolver.resolveFromMessage(msg), '图片');
    });

    test('resolves voice message', () {
      final msg = ConversationMessageSummary(
        id: 'msg-1',
        content: '',
        createdAt: DateTime(2026),
        senderType: 'human',
        messageType: 'message',
        attachments: const [
          MessageAttachment(name: 'voice_123.m4a', type: 'audio/m4a'),
        ],
        reactions: const [],
      );
      expect(MessagePreviewResolver.resolveFromMessage(msg), '语音消息');
    });

    test('resolves link-only message', () {
      final msg = ConversationMessageSummary(
        id: 'msg-1',
        content: 'https://example.com/article',
        createdAt: DateTime(2026),
        senderType: 'human',
        messageType: 'message',
        reactions: const [],
      );
      expect(MessagePreviewResolver.resolveFromMessage(msg), '链接');
    });

    test('resolves sending message', () {
      final msg = ConversationMessageSummary(
        id: 'msg-1',
        content: 'Hello',
        createdAt: DateTime(2026),
        senderType: 'human',
        messageType: 'message',
        reactions: const [],
      );
      expect(
        MessagePreviewResolver.resolveFromMessage(
          msg,
          sendState: MessageSendState.sending,
        ),
        '正在发送...',
      );
    });

    test('resolves failed message', () {
      final msg = ConversationMessageSummary(
        id: 'msg-1',
        content: 'Hello',
        createdAt: DateTime(2026),
        senderType: 'human',
        messageType: 'message',
        reactions: const [],
      );
      expect(
        MessagePreviewResolver.resolveFromMessage(
          msg,
          sendState: MessageSendState.failed,
        ),
        '未发送，点击重试',
      );
    });
  });

  group('resolvePreviewText (backward compat)', () {
    test('returns raw preview when non-null and non-empty', () {
      expect(resolvePreviewText('Hello world'), 'Hello world');
    });

    test('returns 新消息 when preview is null', () {
      expect(resolvePreviewText(null), '新消息');
    });

    test('returns 新消息 when preview is empty string', () {
      expect(resolvePreviewText(''), '新消息');
    });

    test('returns 新消息 when preview is whitespace-only', () {
      expect(resolvePreviewText('   '), '新消息');
    });

    test('preserves leading/trailing whitespace in non-empty preview', () {
      expect(resolvePreviewText('  hello  '), '  hello  ');
    });
  });
}
