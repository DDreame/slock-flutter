import 'package:flutter/material.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

/// Shows a modal bottom sheet with message context menu actions.
///
/// This replaces the inline `_showMessageActions` implementation in
/// `conversation_detail_page.dart`, extracting it into a standalone
/// function for testability and reuse.
///
/// Channel-only actions ([onReplyInThread], [onCreateTask]) are shown
/// only when [isChannel] is `true`. Owner-only actions ([onEdit],
/// [onDelete]) are shown only when [isOwn] is `true`.
void showMessageContextMenu({
  required BuildContext context,
  required ConversationMessageSummary message,
  required bool isOwn,
  required bool isSaved,
  required bool isChannel,
  required VoidCallback onReply,
  required VoidCallback onReact,
  required VoidCallback onCopy,
  required VoidCallback onSave,
  required VoidCallback onPin,
  required VoidCallback onForward,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  VoidCallback? onReplyInThread,
  VoidCallback? onCreateTask,
  VoidCallback? onTranslate,
  VoidCallback? onSelect,
}) {
  showModalBottomSheet<void>(
    context: context,
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwn && onEdit != null)
              ListTile(
                key: const ValueKey('ctx-action-edit'),
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit message'),
                onTap: () {
                  Navigator.of(context).pop();
                  onEdit();
                },
              ),
            ListTile(
              key: const ValueKey('ctx-action-reply'),
              leading: const Icon(Icons.reply_outlined),
              title: const Text('Reply'),
              onTap: () {
                Navigator.of(context).pop();
                onReply();
              },
            ),
            if (onSelect != null)
              ListTile(
                key: const ValueKey('ctx-action-select'),
                leading: const Icon(Icons.checklist_outlined),
                title: const Text('Select'),
                onTap: () {
                  Navigator.of(context).pop();
                  onSelect();
                },
              ),
            ListTile(
              key: const ValueKey('ctx-action-react'),
              leading: const Icon(Icons.emoji_emotions_outlined),
              title: const Text('React'),
              onTap: () {
                Navigator.of(context).pop();
                onReact();
              },
            ),
            if (onTranslate != null)
              ListTile(
                key: const ValueKey('ctx-action-translate'),
                leading: const Icon(Icons.translate),
                title: const Text('Translate'),
                onTap: () {
                  Navigator.of(context).pop();
                  onTranslate();
                },
              ),
            ListTile(
              key: const ValueKey('ctx-action-copy'),
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy text'),
              onTap: () {
                Navigator.of(context).pop();
                onCopy();
              },
            ),
            ListTile(
              key: const ValueKey('ctx-action-forward'),
              leading: const Icon(Icons.shortcut_outlined),
              title: const Text('Forward'),
              onTap: () {
                Navigator.of(context).pop();
                onForward();
              },
            ),
            ListTile(
              key: const ValueKey('ctx-action-save'),
              leading:
                  Icon(isSaved ? Icons.bookmark_remove : Icons.bookmark_add),
              title: Text(isSaved ? 'Unsave message' : 'Save message'),
              onTap: () {
                Navigator.of(context).pop();
                onSave();
              },
            ),
            ListTile(
              key: const ValueKey('ctx-action-pin'),
              leading: Icon(
                  message.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(message.isPinned ? 'Unpin message' : 'Pin message'),
              onTap: () {
                Navigator.of(context).pop();
                onPin();
              },
            ),
            if (isChannel && onReplyInThread != null)
              ListTile(
                key: const ValueKey('ctx-action-reply-thread'),
                leading: const Icon(Icons.forum_outlined),
                title: const Text('Reply in thread'),
                onTap: () {
                  Navigator.of(context).pop();
                  onReplyInThread();
                },
              ),
            if (isChannel && onCreateTask != null)
              ListTile(
                key: const ValueKey('ctx-action-create-task'),
                leading: const Icon(Icons.task_alt),
                title: const Text('Create task'),
                onTap: () {
                  Navigator.of(context).pop();
                  onCreateTask();
                },
              ),
            if (isOwn && onDelete != null)
              ListTile(
                key: const ValueKey('ctx-action-delete'),
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete message'),
                onTap: () {
                  Navigator.of(context).pop();
                  onDelete();
                },
              ),
          ],
        ),
      ),
    ),
  );
}
