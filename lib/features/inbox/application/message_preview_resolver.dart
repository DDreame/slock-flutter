import 'package:slock_app/features/conversation/data/conversation_repository.dart';

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
/// Resolution priority:
///  1. Deleted → `消息已删除`
///  2. Sending → `正在发送...`
///  3. Failed  → `未发送，点击重试`
///  4. System  → `系统消息`
///  5. Non-empty text content (non-link) → content as-is
///  6. Link-only content → `链接`
///  7. Voice attachment (audio/*) → `语音消息`
///  8. Image attachment (image/*) → `图片`
///  9. Video attachment (video/*) → `视频`
/// 10. Other attachment → `附件: filename`
/// 11. Fallback → `新消息`
class MessagePreviewResolver {
  const MessagePreviewResolver._();

  /// Semantic preview labels.
  static const deletedPreview = '消息已删除';
  static const sendingPreview = '正在发送...';
  static const failedPreview = '未发送，点击重试';
  static const systemPreview = '系统消息';
  static const linkPreview = '链接';
  static const voicePreview = '语音消息';
  static const imagePreview = '图片';
  static const videoPreview = '视频';
  static const fallbackPreview = '新消息';

  /// Resolves preview from structured message metadata.
  static String resolve({
    String? content,
    String? messageType,
    bool isDeleted = false,
    List<MessageAttachment>? attachments,
    MessageSendState sendState = MessageSendState.sent,
  }) {
    if (isDeleted) return deletedPreview;
    if (sendState == MessageSendState.sending) return sendingPreview;
    if (sendState == MessageSendState.failed) return failedPreview;
    if (messageType == 'system') return systemPreview;
    if (content != null && content.trim().isNotEmpty) {
      if (_bareUrlPattern.hasMatch(content)) return linkPreview;
      return content;
    }
    if (attachments != null && attachments.isNotEmpty) {
      return _resolveAttachmentPreview(attachments);
    }
    return fallbackPreview;
  }

  /// Convenience: resolves preview directly from a [ConversationMessageSummary].
  static String resolveFromMessage(
    ConversationMessageSummary message, {
    MessageSendState sendState = MessageSendState.sent,
  }) {
    return resolve(
      content: message.content,
      messageType: message.messageType,
      isDeleted: message.isDeleted,
      attachments: message.attachments,
      sendState: sendState,
    );
  }

  static String _resolveAttachmentPreview(List<MessageAttachment> attachments) {
    final first = attachments.first;
    final mime = first.type;
    if (mime.startsWith('audio/')) return voicePreview;
    if (mime.startsWith('image/')) return imagePreview;
    if (mime.startsWith('video/')) return videoPreview;
    return '附件: ${first.name}';
  }
}

/// Legacy top-level function kept for backward compatibility.
///
/// Used by Home row widgets that only have a raw preview string (already
/// resolved at the data layer). Provides a final safety-net fallback.
String resolvePreviewText(String? rawPreview) {
  if (rawPreview != null && rawPreview.trim().isNotEmpty) return rawPreview;
  return MessagePreviewResolver.fallbackPreview;
}
