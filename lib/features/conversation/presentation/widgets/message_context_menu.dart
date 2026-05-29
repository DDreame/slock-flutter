import 'package:flutter/material.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/l10n/app_localizations.dart';

AppLocalizations _conversationL10n(BuildContext context) =>
    AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('en'));

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
  VoidCallback? onCopyLink,
  VoidCallback? onCopyMarkdown,
}) {
  final l10n = _conversationL10n(context);
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
                title: Text(l10n.conversationContextEditMessage),
                onTap: () {
                  Navigator.of(context).pop();
                  onEdit();
                },
              ),
            ListTile(
              key: const ValueKey('ctx-action-reply'),
              leading: const Icon(Icons.reply_outlined),
              title: Text(l10n.conversationContextReply),
              onTap: () {
                Navigator.of(context).pop();
                onReply();
              },
            ),
            if (onSelect != null)
              ListTile(
                key: const ValueKey('ctx-action-select'),
                leading: const Icon(Icons.checklist_outlined),
                title: Text(l10n.conversationContextSelect),
                onTap: () {
                  Navigator.of(context).pop();
                  onSelect();
                },
              ),
            ListTile(
              key: const ValueKey('ctx-action-react'),
              leading: const Icon(Icons.emoji_emotions_outlined),
              title: Text(l10n.conversationContextReact),
              onTap: () {
                Navigator.of(context).pop();
                onReact();
              },
            ),
            if (onTranslate != null)
              ListTile(
                key: const ValueKey('ctx-action-translate'),
                leading: const Icon(Icons.translate),
                title: Text(l10n.conversationContextTranslate),
                onTap: () {
                  Navigator.of(context).pop();
                  onTranslate();
                },
              ),
            ListTile(
              key: const ValueKey('ctx-action-copy'),
              leading: const Icon(Icons.copy_outlined),
              title: Text(l10n.conversationContextCopyText),
              onTap: () {
                Navigator.of(context).pop();
                onCopy();
              },
            ),
            if (onCopyMarkdown != null)
              ListTile(
                key: const ValueKey('ctx-action-copy-markdown'),
                leading: const Icon(Icons.code_outlined),
                title: Text(l10n.conversationContextCopyMarkdown),
                onTap: () {
                  Navigator.of(context).pop();
                  onCopyMarkdown();
                },
              ),
            if (onCopyLink != null)
              ListTile(
                key: const ValueKey('ctx-action-copy-link'),
                leading: const Icon(Icons.link),
                title: Text(l10n.conversationContextCopyLink),
                onTap: () {
                  Navigator.of(context).pop();
                  onCopyLink();
                },
              ),
            ListTile(
              key: const ValueKey('ctx-action-forward'),
              leading: const Icon(Icons.shortcut_outlined),
              title: Text(l10n.conversationContextForward),
              onTap: () {
                Navigator.of(context).pop();
                onForward();
              },
            ),
            ListTile(
              key: const ValueKey('ctx-action-save'),
              leading:
                  Icon(isSaved ? Icons.bookmark_remove : Icons.bookmark_add),
              title: Text(isSaved
                  ? l10n.conversationContextUnsaveMessage
                  : l10n.conversationContextSaveMessage),
              onTap: () {
                Navigator.of(context).pop();
                onSave();
              },
            ),
            ListTile(
              key: const ValueKey('ctx-action-pin'),
              leading: Icon(
                  message.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(message.isPinned
                  ? l10n.conversationContextUnpinMessage
                  : l10n.conversationContextPinMessage),
              onTap: () {
                Navigator.of(context).pop();
                onPin();
              },
            ),
            if (isChannel && onReplyInThread != null)
              ListTile(
                key: const ValueKey('ctx-action-reply-thread'),
                leading: const Icon(Icons.forum_outlined),
                title: Text(l10n.conversationContextReplyInThread),
                onTap: () {
                  Navigator.of(context).pop();
                  onReplyInThread();
                },
              ),
            if (isChannel && onCreateTask != null)
              ListTile(
                key: const ValueKey('ctx-action-create-task'),
                leading: const Icon(Icons.task_alt),
                title: Text(l10n.conversationContextCreateTask),
                onTap: () {
                  Navigator.of(context).pop();
                  onCreateTask();
                },
              ),
            if (isOwn && onDelete != null)
              ListTile(
                key: const ValueKey('ctx-action-delete'),
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.conversationContextDeleteMessage),
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
