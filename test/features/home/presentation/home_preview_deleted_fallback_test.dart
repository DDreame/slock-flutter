// =============================================================================
// #597 — P0 Hotfix: Preview "消息已删除" Fallback Regression
//
// Invariant: INV-PREVIEW-DELETE-1
//   Only messages with isDeleted=true show "消息已删除" preview.
//   Null/empty preview on non-deleted messages shows generic fallback.
//
// Strategy:
// T1: Verify that null preview on non-deleted message shows previewFallback
//     (skip:true — current impl always returns previewDeleted for null).
// T2: Verify that already-resolved "deleted" preview passes through unchanged.
// T3: Verify that valid preview text passes through unchanged.
// T4: Anti-pattern proof — current code returns previewDeleted for null preview.
//
// Phase A: T1 skip:true — current resolvePreviewText has no isDeleted param.
//
// Phase B:
// 1. Change resolvePreviewText fallback from l10n.previewDeleted to
//    l10n.previewFallback — since deleted messages already have their preview
//    resolved to l10n.previewDeleted at the data layer (_parseLastMessage).
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/inbox/application/message_preview_resolver.dart';
import 'package:slock_app/l10n/app_localizations_en.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// A minimal AppLocalizations for testing. Uses English locale values.
final _l10n = AppLocalizationsEn();

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: Null/empty preview on non-deleted message should show previewFallback.
  //
  // When the home API returns null lastMessagePreview (new channel, backfill
  // not complete, race condition), the UI should show a neutral fallback
  // ("New message" / "新消息") — NOT "Message deleted" / "消息已删除".
  //
  // skip:true — current resolvePreviewText returns previewDeleted for null.
  // -------------------------------------------------------------------------
  test(
    'INV-PREVIEW-DELETE-1: null preview shows previewFallback (not previewDeleted)',
    skip: true,
    () {
      final result = resolvePreviewText(null, l10n: _l10n);
      expect(
        result,
        _l10n.previewFallback,
        reason: 'Null preview on non-deleted message must show generic '
            'fallback, not "Message deleted" (INV-PREVIEW-DELETE-1)',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T2: Already-resolved "deleted" preview string passes through unchanged.
  //
  // When a message IS deleted, _parseLastMessage() already resolves the
  // preview to l10n.previewDeleted at the data layer. resolvePreviewText()
  // receives this resolved string and passes it through (non-null, non-empty).
  //
  // This test passes now and after Phase B.
  // -------------------------------------------------------------------------
  test(
    'INV-PREVIEW-DELETE-1: resolved deleted preview passes through unchanged',
    () {
      final deletedText = _l10n.previewDeleted;
      final result = resolvePreviewText(deletedText, l10n: _l10n);
      expect(
        result,
        deletedText,
        reason: 'Already-resolved deleted preview must pass through unchanged',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T3: Valid preview text passes through unchanged.
  //
  // This test passes now and after Phase B.
  // -------------------------------------------------------------------------
  test(
    'INV-PREVIEW-DELETE-1: valid preview text passes through unchanged',
    () {
      const previewText = 'Hello everyone!';
      final result = resolvePreviewText(previewText, l10n: _l10n);
      expect(result, previewText);
    },
  );

  // -------------------------------------------------------------------------
  // T4: Empty string preview shows fallback (not deleted label).
  //
  // skip:true — current resolvePreviewText returns previewDeleted for empty.
  // -------------------------------------------------------------------------
  test(
    'INV-PREVIEW-DELETE-1: empty string preview shows previewFallback',
    skip: true,
    () {
      final result = resolvePreviewText('', l10n: _l10n);
      expect(
        result,
        _l10n.previewFallback,
        reason: 'Empty preview on non-deleted message must show generic '
            'fallback (INV-PREVIEW-DELETE-1)',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T5: Anti-pattern proof — current code returns previewDeleted for null.
  //
  // Demonstrates the bug: resolvePreviewText returns "Message deleted" for
  // null input regardless of whether the message was actually deleted.
  // -------------------------------------------------------------------------
  test(
    'current code returns previewDeleted for null preview (anti-pattern proof)',
    () {
      final result = resolvePreviewText(null, l10n: _l10n);
      expect(
        result,
        _l10n.previewDeleted,
        reason: 'Current fallback incorrectly shows previewDeleted for null '
            '(proving the bug)',
      );
    },
  );
}
