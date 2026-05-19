// =============================================================================
// #585 Phase A — Preview Fallback Fix (test-only)
//
// Feature: Channel/inbox preview always routes through MessagePreviewResolver
// with full message metadata (attachments, isDeleted, messageType).
//
// Bug: The preview backfill path (PreviewBackfillService) extracts only
// msg['content'] from the API response, losing attachment/deleted/voice info.
// Home rows then call resolvePreviewText(emptyString) which falls back to
// the generic "New message" label.
//
// Phase B: Make the backfill path call MessagePreviewResolver.resolve() with
// full metadata so previews are always semantically correct.
//
// All tests skip:true — Phase A only.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/inbox/application/message_preview_resolver.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('Preview resolver integration', () {
    test(
      'T1: Attachment-only message resolves to attachment description (not empty/fallback)',
      () {
        // Simulate the current backfill path: PreviewBackfillService extracts
        // msg['content'] from the API response. For attachment-only messages,
        // content is empty. The legacy resolvePreviewText is used as the
        // final safety net by Home row widgets.
        //
        // Expected: preview shows "Image" (attachment label)
        // Actual (bug): preview shows previewFallback ("New message")
        const rawContent = ''; // Attachment-only message has empty content
        final preview = resolvePreviewText(rawContent, l10n: l10n);

        // Must NOT be the generic fallback — should be an attachment label.
        expect(preview, isNot(equals(l10n.previewFallback)),
            reason: 'Attachment-only messages must not show generic fallback. '
                'The backfill path should route through MessagePreviewResolver '
                'with attachment metadata.');
      },
    );

    test(
      'T2: Deleted message resolves to deletion placeholder',
      () {
        // Simulate the current backfill path for a deleted message:
        // API returns msg['content'] = '' (or original text) with isDeleted=true.
        // The backfill only passes content through, losing isDeleted metadata.
        //
        // Expected: preview shows "Message deleted"
        // Actual (bug): preview shows the raw content or fallback
        const rawContent =
            ''; // Deleted message content may be cleared server-side
        final preview = resolvePreviewText(rawContent, l10n: l10n);

        // Must be the deleted label, not generic fallback.
        expect(preview, equals(l10n.previewDeleted),
            reason: 'Deleted messages must show deletion placeholder. '
                'The backfill path should route through MessagePreviewResolver '
                'with isDeleted metadata.');
      },
    );

    test(
      'T3: Voice message resolves to voice label',
      () {
        // Simulate the current backfill path for a voice message:
        // API returns msg['content'] = '' with audio attachment.
        // The backfill only extracts content, losing attachment metadata.
        //
        // Expected: preview shows "Voice message"
        // Actual (bug): preview shows generic fallback
        const rawContent = ''; // Voice messages have no text content
        final preview = resolvePreviewText(rawContent, l10n: l10n);

        // Must NOT be the generic fallback — should be voice label.
        expect(preview, isNot(equals(l10n.previewFallback)),
            reason: 'Voice messages must not show generic fallback. '
                'The backfill path should route through MessagePreviewResolver '
                'with voice attachment metadata.');
      },
    );

    test(
      'T4: Normal text message still resolves correctly',
      () {
        // Normal text messages work fine through the legacy path because
        // content is non-empty. This test confirms the happy path still works
        // after the fix.
        const rawContent = 'Hello everyone, welcome!';
        final preview = resolvePreviewText(rawContent, l10n: l10n);

        expect(preview, equals('Hello everyone, welcome!'));
      },
    );
  });
}
