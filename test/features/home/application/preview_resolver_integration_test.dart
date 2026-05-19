// =============================================================================
// #585 Phase A — Preview Fallback Fix (test-only)
//
// Feature: Channel/inbox preview always routes through MessagePreviewResolver
// with full message metadata (attachments, isDeleted, messageType).
//
// Tests verify that MessagePreviewResolver.resolve() correctly handles
// attachment-only, deleted, and voice messages — while resolvePreviewText()
// correctly falls back to previewFallback for null/empty input.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/inbox/application/message_preview_resolver.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('Preview resolver integration', () {
    test(
      'T1: Attachment-only message resolves to attachment description via MessagePreviewResolver',
      () {
        // Attachment-only messages have empty content but non-empty attachments.
        // MessagePreviewResolver.resolve() routes through attachment logic.
        final preview = MessagePreviewResolver.resolve(
          l10n: l10n,
          content: '',
          attachments: [
            const MessageAttachment(name: 'photo.jpg', type: 'image/jpeg'),
          ],
        );

        // Must be the image label, not generic fallback.
        expect(preview, equals(l10n.previewImage),
            reason: 'Attachment-only messages must show image label via '
                'MessagePreviewResolver.resolve() with attachment metadata.');
      },
    );

    test(
      'T2: Deleted message resolves to deletion placeholder via MessagePreviewResolver',
      () {
        // Deleted messages have isDeleted=true. MessagePreviewResolver.resolve()
        // returns previewDeleted regardless of content.
        final preview = MessagePreviewResolver.resolve(
          l10n: l10n,
          content: '',
          isDeleted: true,
        );

        // Must be the deleted label.
        expect(preview, equals(l10n.previewDeleted),
            reason: 'Deleted messages must show deletion placeholder via '
                'MessagePreviewResolver.resolve() with isDeleted metadata.');
      },
    );

    test(
      'T3: Voice message resolves to voice label via MessagePreviewResolver',
      () {
        // Voice messages have empty content with audio attachment.
        // MessagePreviewResolver.resolve() routes through attachment logic.
        final preview = MessagePreviewResolver.resolve(
          l10n: l10n,
          content: '',
          attachments: [
            const MessageAttachment(name: 'voice.ogg', type: 'audio/ogg'),
          ],
        );

        // Must be the voice label, not generic fallback.
        expect(preview, equals(l10n.previewVoice),
            reason: 'Voice messages must show voice label via '
                'MessagePreviewResolver.resolve() with audio attachment.');
      },
    );

    test(
      'T4: Normal text message still resolves correctly',
      () {
        // Normal text messages work fine through the legacy path because
        // content is non-empty. This test confirms the happy path still works.
        const rawContent = 'Hello everyone, welcome!';
        final preview = resolvePreviewText(rawContent, l10n: l10n);

        expect(preview, equals('Hello everyone, welcome!'));
      },
    );

    test(
      'T5: resolvePreviewText returns previewFallback for empty content',
      () {
        // When resolvePreviewText receives null/empty, it returns the generic
        // fallback. Deleted messages are handled upstream via
        // MessagePreviewResolver.resolve(isDeleted: true).
        final preview = resolvePreviewText('', l10n: l10n);
        expect(preview, equals(l10n.previewFallback),
            reason: 'resolvePreviewText returns previewFallback for empty '
                'content — deleted handling is done upstream.');
      },
    );
  });
}
