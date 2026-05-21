import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

class EditMessageDialog extends StatefulWidget {
  const EditMessageDialog({
    super.key,
    required this.initialContent,
    required this.onSave,
  });

  final String initialContent;
  final Future<void> Function(String newContent) onSave;

  @override
  State<EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<EditMessageDialog> {
  late final TextEditingController _controller;
  bool _hasChanged = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final changed = _controller.text.trim() != widget.initialContent &&
        _controller.text.trim().isNotEmpty;
    if (changed != _hasChanged) {
      setState(() => _hasChanged = changed);
    }
  }

  Future<void> _onSave() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(_controller.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Message edited.')));
    } on AppFailure catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Failed to edit message.'),
          ),
        );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('edit-message-dialog'),
      title: const Text('Edit message'),
      content: TextField(
        key: const ValueKey('edit-message-field'),
        controller: _controller,
        autofocus: true,
        maxLines: null,
        textInputAction: TextInputAction.newline,
        enabled: !_saving,
      ),
      actions: [
        TextButton(
          key: const ValueKey('edit-message-cancel'),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey('edit-message-save'),
          onPressed: _hasChanged && !_saving ? _onSave : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Curated set of common reaction emojis.
const reactionEmojis = [
  '👍',
  '❤️',
  '😂',
  '😮',
  '😢',
  '🎉',
  '🔥',
  '👀',
  '🙏',
  '💯',
  '✅',
  '❌',
  '👏',
  '🤔',
  '😍',
  '🚀',
  '💪',
  '⭐',
  '🤝',
  '💡',
];

class EmojiPickerSheet extends StatelessWidget {
  const EmojiPickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'React with emoji',
                style: AppTypography.title,
              ),
            ),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: reactionEmojis.map((emoji) {
                return InkWell(
                  key: ValueKey('emoji-$emoji'),
                  onTap: () => Navigator.of(context).pop(emoji),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class ReactionRow extends ConsumerWidget {
  const ReactionRow({
    super.key,
    required this.reactions,
    required this.messageId,
    required this.currentUserId,
  });

  final List<MessageReaction> reactions;
  final String messageId;
  final String? currentUserId;

  /// Named handler for reaction toggle tap — avoids creating a new closure
  /// on every rebuild, enabling future memoization of [_ReactionChip].
  Future<void> _handleReactionTap(
    BuildContext context,
    WidgetRef ref,
    String emoji,
  ) async {
    try {
      await ref
          .read(conversationDetailStoreProvider.notifier)
          .toggleReaction(messageId, emoji);
    } on AppFailure catch (failure) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(failure.message ?? 'Failed to update reaction.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: reactions.map((reaction) {
          final isOwn =
              currentUserId != null && reaction.reactedByUser(currentUserId!);
          return _ReactionChip(
            key: ValueKey('reaction-${reaction.emoji}'),
            emoji: reaction.emoji,
            count: reaction.count,
            isOwn: isOwn,
            colors: colors,
            onTap: () => _handleReactionTap(context, ref, reaction.emoji),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    super.key,
    required this.emoji,
    required this.count,
    required this.isOwn,
    required this.colors,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool isOwn;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isOwn
              ? colors.primary.withValues(alpha: 0.15)
              : colors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: isOwn ? colors.primary : colors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: AppTypography.caption.copyWith(
                color: isOwn ? colors.primary : colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
