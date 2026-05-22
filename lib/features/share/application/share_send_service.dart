import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/share/data/shared_content.dart';
import 'package:slock_app/features/share/presentation/page/share_target_picker_page.dart';

/// Orchestrates uploading attachments and sending a message for the
/// share-from-other-app flow.
class ShareSendService {
  const ShareSendService({required this.repository});

  final ConversationRepository repository;

  /// Uploads any attachment items, then sends a message with the combined
  /// text and attachment IDs to the chosen conversation.
  Future<void> send({
    required ShareTarget target,
    required SharedContent content,
  }) async {
    final detailTarget = target.isChannel
        ? ConversationDetailTarget.channel(
            ChannelScopeId(
              serverId: target.serverId,
              value: target.scopeId,
            ),
          )
        : ConversationDetailTarget.directMessage(
            DirectMessageScopeId(
              serverId: target.serverId,
              value: target.scopeId,
            ),
          );

    // Upload all attachments in sequence.
    final attachmentIds = <String>[];
    for (final item in content.attachmentItems) {
      final name = _extractFilename(item.path);
      final mimeType = item.mimeType ?? 'application/octet-stream';
      final id = await repository.uploadAttachment(
        detailTarget,
        PendingAttachment(path: item.path, name: name, mimeType: mimeType),
      );
      attachmentIds.add(id);
    }

    // Send the message.
    // Trim text so whitespace-only content doesn't create a blank line
    // above attachments when sharing files without text (#729).
    final text = content.combinedText.trim();
    await repository.sendMessage(
      detailTarget,
      text,
      attachmentIds: attachmentIds.isNotEmpty ? attachmentIds : null,
    );
  }
}

String _extractFilename(String path) {
  final lastSep = path.lastIndexOf('/');
  if (lastSep == -1) return path;
  return path.substring(lastSep + 1);
}

/// Provides a [ShareSendService] backed by the app's
/// [ConversationRepository].
final shareSendServiceProvider = Provider<ShareSendService>((ref) {
  return ShareSendService(
    repository: ref.read(conversationRepositoryProvider),
  );
});
