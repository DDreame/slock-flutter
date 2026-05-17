import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/l10n/app_localizations.dart';

/// Send state of an outgoing message for preview resolution.
enum MessageSendState {
  /// Message was sent successfully (default / normal messages).
  sent,

  /// Message is currently being sent / queued.
  sending,

  /// Message failed to send.
  failed,
}

/// Pattern matching bare URLs for link-only message detection.
///
/// Matches content that is a single HTTP(S) URL with no surrounding text.
final _bareUrlPattern = RegExp(
  r'^\s*https?://\S+\s*$',
  caseSensitive: false,
);

/// Resolves a human-readable preview string from structured message metadata.
///
/// Used across all preview surfaces: Home sidebar, Inbox list, realtime event
/// updates, and push notifications.
///
/// All labels are resolved through the [AppLocalizations] l10n system.
///
/// Resolution priority:
///  1. Deleted → l10n.previewDeleted
///  2. Sending → l10n.previewSending
///  3. Failed  → l10n.previewFailed
///  4. System  → l10n.previewSystem
///  5. Non-empty text content (non-link) → content as-is
///  6. Link-only content → l10n.previewLink
///  7. Voice attachment (audio/*) → l10n.previewVoice
///  8. Image attachment (image/*) → l10n.previewImage
///  9. Video attachment (video/*) → l10n.previewVideo
/// 10. Other attachment → l10n.previewAttachment(filename)
/// 11. Fallback → l10n.previewFallback
class MessagePreviewResolver {
  const MessagePreviewResolver._();

  /// Resolves preview from structured message metadata.
  ///
  /// All labels are resolved through the [l10n] ARB localization system.
  static String resolve({
    required AppLocalizations l10n,
    String? content,
    String? messageType,
    bool isDeleted = false,
    List<MessageAttachment>? attachments,
    MessageSendState sendState = MessageSendState.sent,
  }) {
    if (isDeleted) return l10n.previewDeleted;
    if (sendState == MessageSendState.sending) return l10n.previewSending;
    if (sendState == MessageSendState.failed) return l10n.previewFailed;
    if (messageType == 'system') return l10n.previewSystem;
    if (content != null && content.trim().isNotEmpty) {
      if (_bareUrlPattern.hasMatch(content)) return l10n.previewLink;
      return content;
    }
    if (attachments != null && attachments.isNotEmpty) {
      return _resolveAttachmentPreview(attachments, l10n: l10n);
    }
    return l10n.previewFallback;
  }

  /// Convenience: resolves preview directly from a [ConversationMessageSummary].
  static String resolveFromMessage(
    ConversationMessageSummary message, {
    required AppLocalizations l10n,
    MessageSendState sendState = MessageSendState.sent,
  }) {
    return resolve(
      l10n: l10n,
      content: message.content,
      messageType: message.messageType,
      isDeleted: message.isDeleted,
      attachments: message.attachments,
      sendState: sendState,
    );
  }

  static String _resolveAttachmentPreview(
    List<MessageAttachment> attachments, {
    required AppLocalizations l10n,
  }) {
    final first = attachments.first;
    final mime = first.type;
    if (mime.startsWith('audio/')) return l10n.previewVoice;
    if (mime.startsWith('image/')) return l10n.previewImage;
    if (mime.startsWith('video/')) return l10n.previewVideo;
    return l10n.previewAttachment(first.name);
  }
}

/// Legacy top-level function kept for backward compatibility.
///
/// Used by Home row widgets that only have a raw preview string (already
/// resolved at the data layer). Provides a final safety-net fallback.
String resolvePreviewText(String? rawPreview,
    {required AppLocalizations l10n}) {
  if (rawPreview != null && rawPreview.trim().isNotEmpty) return rawPreview;
  return l10n.previewFallback;
}
