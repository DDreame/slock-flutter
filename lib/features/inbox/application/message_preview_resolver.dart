import 'package:slock_app/features/conversation/data/conversation_repository.dart';

/// Resolves a human-readable preview string from structured message metadata.
///
/// Used across all preview surfaces: Home sidebar, Inbox list, realtime event
/// updates, and push notifications.
///
/// Resolution priority:
/// 1. Deleted → `消息已删除`
/// 2. System message → `系统消息`
/// 3. Non-empty text content → content as-is
/// 4. Voice attachment (audio/*) → `语音消息`
/// 5. Image attachment (image/*) → `图片`
/// 6. Video attachment (video/*) → `视频`
/// 7. Other attachment → `附件: filename`
/// 8. Fallback → `新消息`
class MessagePreviewResolver {
  const MessagePreviewResolver._();

  /// Semantic preview labels.
  static const deletedPreview = '消息已删除';
  static const systemPreview = '系统消息';
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
  }) {
    if (isDeleted) return deletedPreview;
    if (messageType == 'system') return systemPreview;
    if (content != null && content.trim().isNotEmpty) return content;
    if (attachments != null && attachments.isNotEmpty) {
      return _resolveAttachmentPreview(attachments);
    }
    return fallbackPreview;
  }

  /// Convenience: resolves preview directly from a [ConversationMessageSummary].
  static String resolveFromMessage(ConversationMessageSummary message) {
    return resolve(
      content: message.content,
      messageType: message.messageType,
      isDeleted: message.isDeleted,
      attachments: message.attachments,
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
/// Used by Inbox projection and Home row widgets that only have a raw
/// preview string. The preview string is expected to already be resolved
/// at the data layer; this function provides a final safety-net fallback.
String resolvePreviewText(String? rawPreview) {
  if (rawPreview != null && rawPreview.trim().isNotEmpty) return rawPreview;
  return MessagePreviewResolver.fallbackPreview;
}
