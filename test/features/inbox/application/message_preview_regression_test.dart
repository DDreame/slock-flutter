import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/inbox/application/message_preview_resolver.dart';
import 'package:slock_app/l10n/app_localizations.dart';

/// Thin regression tests for MessagePreviewResolver edge cases
/// that should never produce `[No preview]` or empty strings.
///
/// The main test file (message_preview_resolver_test.dart) covers
/// all 10 priority tiers exhaustively. These regression tests focus
/// on boundary scenarios that previously caused preview drift.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  group('MessagePreviewResolver regression', () {
    test('non-http URL in content is NOT treated as link', () {
      final preview = MessagePreviewResolver.resolve(
        l10n: l10n,
        content: 'ftp://files.example.com/readme.txt',
      );
      // Non-http(s) URLs are treated as regular text, not links
      expect(preview, 'ftp://files.example.com/readme.txt');
      expect(preview, isNot(l10n.previewLink));
    });

    test('mixed text + URL returns the full text, not link preview', () {
      final preview = MessagePreviewResolver.resolve(
        l10n: l10n,
        content: 'Check this: https://example.com',
      );
      expect(preview, 'Check this: https://example.com');
      expect(preview, isNot(l10n.previewLink));
    });

    test('bare URL-only content returns link preview', () {
      final preview = MessagePreviewResolver.resolve(
        l10n: l10n,
        content: 'https://example.com',
      );
      expect(preview, l10n.previewLink);
    });

    test('empty content with no attachments returns fallback', () {
      final preview = MessagePreviewResolver.resolve(
        l10n: l10n,
        content: '',
      );
      expect(preview, l10n.previewFallback);
      expect(preview, isNotEmpty);
    });

    test('null content with no attachments returns fallback', () {
      final preview = MessagePreviewResolver.resolve(l10n: l10n);
      expect(preview, l10n.previewFallback);
      expect(preview, isNotEmpty);
    });

    test('whitespace-only content with attachment falls through to attachment',
        () {
      final preview = MessagePreviewResolver.resolve(
        l10n: l10n,
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
        l10n: l10n,
        content: 'This message has text',
        isDeleted: true,
        attachments: const [
          MessageAttachment(
            name: 'photo.jpg',
            type: 'image/jpeg',
          ),
        ],
      );
      expect(preview, l10n.previewDeleted);
    });

    test('failed send state wins over text content', () {
      final preview = MessagePreviewResolver.resolve(
        l10n: l10n,
        content: 'Hello world',
        sendState: MessageSendState.failed,
      );
      expect(preview, l10n.previewFailed);
    });

    test('voice message (audio/*) returns voice preview', () {
      final preview = MessagePreviewResolver.resolve(
        l10n: l10n,
        attachments: const [
          MessageAttachment(
            name: 'recording.m4a',
            type: 'audio/m4a',
          ),
        ],
      );
      expect(preview, l10n.previewVoice);
    });

    test('image attachment returns image preview', () {
      final preview = MessagePreviewResolver.resolve(
        l10n: l10n,
        attachments: const [
          MessageAttachment(
            name: 'photo.png',
            type: 'image/png',
          ),
        ],
      );
      expect(preview, l10n.previewImage);
    });

    test('video attachment returns video preview', () {
      final preview = MessagePreviewResolver.resolve(
        l10n: l10n,
        attachments: const [
          MessageAttachment(
            name: 'clip.mp4',
            type: 'video/mp4',
          ),
        ],
      );
      expect(preview, l10n.previewVideo);
    });

    test('system message returns system preview', () {
      final preview = MessagePreviewResolver.resolve(
        l10n: l10n,
        content: 'System event content',
        messageType: 'system',
      );
      expect(preview, l10n.previewSystem);
    });

    test('no preview text is ever empty or [No preview]', () {
      // Exercise every branch and confirm no empty/placeholder output
      final scenarios = <String>[
        MessagePreviewResolver.resolve(l10n: l10n),
        MessagePreviewResolver.resolve(l10n: l10n, content: ''),
        MessagePreviewResolver.resolve(l10n: l10n, content: null),
        MessagePreviewResolver.resolve(l10n: l10n, content: '   '),
        MessagePreviewResolver.resolve(l10n: l10n, isDeleted: true),
        MessagePreviewResolver.resolve(
            l10n: l10n, sendState: MessageSendState.sending),
        MessagePreviewResolver.resolve(
            l10n: l10n, sendState: MessageSendState.failed),
        MessagePreviewResolver.resolve(l10n: l10n, messageType: 'system'),
        MessagePreviewResolver.resolve(l10n: l10n, content: 'https://x.com'),
        MessagePreviewResolver.resolve(
          l10n: l10n,
          attachments: const [
            MessageAttachment(
              name: 'f.m4a',
              type: 'audio/m4a',
            ),
          ],
        ),
        MessagePreviewResolver.resolve(
          l10n: l10n,
          attachments: const [
            MessageAttachment(
              name: 'f.jpg',
              type: 'image/jpeg',
            ),
          ],
        ),
        MessagePreviewResolver.resolve(
          l10n: l10n,
          attachments: const [
            MessageAttachment(
              name: 'f.mp4',
              type: 'video/mp4',
            ),
          ],
        ),
        MessagePreviewResolver.resolve(
          l10n: l10n,
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
