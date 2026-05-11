import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/inbox/application/message_preview_resolver.dart';

/// Thin regression tests for MessagePreviewResolver edge cases
/// that should never produce `[No preview]` or empty strings.
///
/// The main test file (message_preview_resolver_test.dart) covers
/// all 10 priority tiers exhaustively. These regression tests focus
/// on boundary scenarios that previously caused preview drift.
void main() {
  group('MessagePreviewResolver regression', () {
    test('non-http URL in content is NOT treated as link', () {
      final preview = MessagePreviewResolver.resolve(
        content: 'ftp://files.example.com/readme.txt',
      );
      // Non-http(s) URLs are treated as regular text, not links
      expect(preview, 'ftp://files.example.com/readme.txt');
      expect(preview, isNot(MessagePreviewResolver.linkPreview));
    });

    test('mixed text + URL returns the full text, not link preview', () {
      final preview = MessagePreviewResolver.resolve(
        content: 'Check this: https://example.com',
      );
      expect(preview, 'Check this: https://example.com');
      expect(preview, isNot(MessagePreviewResolver.linkPreview));
    });

    test('bare URL-only content returns link preview', () {
      final preview = MessagePreviewResolver.resolve(
        content: 'https://example.com',
      );
      expect(preview, MessagePreviewResolver.linkPreview);
    });

    test('empty content with no attachments returns fallback', () {
      final preview = MessagePreviewResolver.resolve(
        content: '',
      );
      expect(preview, MessagePreviewResolver.fallbackPreview);
      expect(preview, isNotEmpty);
    });

    test('null content with no attachments returns fallback', () {
      final preview = MessagePreviewResolver.resolve();
      expect(preview, MessagePreviewResolver.fallbackPreview);
      expect(preview, isNotEmpty);
    });

    test('whitespace-only content with attachment falls through to attachment',
        () {
      final preview = MessagePreviewResolver.resolve(
        content: '   \n  ',
        attachments: const [
          MessageAttachment(
            name: 'document.pdf',
            type: 'application/pdf',
          ),
        ],
      );
      // Whitespace-only content is treated as null, so attachment preview wins
      expect(preview, contains('document.pdf'));
    });

    test('deleted message always wins over other content', () {
      final preview = MessagePreviewResolver.resolve(
        content: 'This message has text',
        isDeleted: true,
        attachments: const [
          MessageAttachment(
            name: 'photo.jpg',
            type: 'image/jpeg',
          ),
        ],
      );
      expect(preview, MessagePreviewResolver.deletedPreview);
    });

    test('failed send state wins over text content', () {
      final preview = MessagePreviewResolver.resolve(
        content: 'Hello world',
        sendState: MessageSendState.failed,
      );
      expect(preview, MessagePreviewResolver.failedPreview);
    });

    test('voice message (audio/*) returns voice preview', () {
      final preview = MessagePreviewResolver.resolve(
        attachments: const [
          MessageAttachment(
            name: 'recording.m4a',
            type: 'audio/m4a',
          ),
        ],
      );
      expect(preview, MessagePreviewResolver.voicePreview);
    });

    test('image attachment returns image preview', () {
      final preview = MessagePreviewResolver.resolve(
        attachments: const [
          MessageAttachment(
            name: 'photo.png',
            type: 'image/png',
          ),
        ],
      );
      expect(preview, MessagePreviewResolver.imagePreview);
    });

    test('video attachment returns video preview', () {
      final preview = MessagePreviewResolver.resolve(
        attachments: const [
          MessageAttachment(
            name: 'clip.mp4',
            type: 'video/mp4',
          ),
        ],
      );
      expect(preview, MessagePreviewResolver.videoPreview);
    });

    test('system message returns system preview', () {
      final preview = MessagePreviewResolver.resolve(
        content: 'System event content',
        messageType: 'system',
      );
      expect(preview, MessagePreviewResolver.systemPreview);
    });

    test('no preview text is ever empty or [No preview]', () {
      // Exercise every branch and confirm no empty/placeholder output
      final scenarios = <String>[
        MessagePreviewResolver.resolve(),
        MessagePreviewResolver.resolve(content: ''),
        MessagePreviewResolver.resolve(content: null),
        MessagePreviewResolver.resolve(content: '   '),
        MessagePreviewResolver.resolve(isDeleted: true),
        MessagePreviewResolver.resolve(sendState: MessageSendState.sending),
        MessagePreviewResolver.resolve(sendState: MessageSendState.failed),
        MessagePreviewResolver.resolve(messageType: 'system'),
        MessagePreviewResolver.resolve(content: 'https://x.com'),
        MessagePreviewResolver.resolve(
          attachments: const [
            MessageAttachment(
              name: 'f.m4a',
              type: 'audio/m4a',
            ),
          ],
        ),
        MessagePreviewResolver.resolve(
          attachments: const [
            MessageAttachment(
              name: 'f.jpg',
              type: 'image/jpeg',
            ),
          ],
        ),
        MessagePreviewResolver.resolve(
          attachments: const [
            MessageAttachment(
              name: 'f.mp4',
              type: 'video/mp4',
            ),
          ],
        ),
        MessagePreviewResolver.resolve(
          attachments: const [
            MessageAttachment(
              name: 'f.pdf',
              type: 'application/pdf',
            ),
          ],
        ),
      ];

      for (final preview in scenarios) {
        expect(preview, isNotEmpty, reason: 'Preview should not be empty');
        expect(preview, isNot('[No preview]'),
            reason: 'Preview should never be [No preview]');
      }
    });
  });
}
