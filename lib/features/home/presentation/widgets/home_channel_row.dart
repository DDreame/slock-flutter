import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/list_action_sheet.dart';
import 'package:slock_app/app/widgets/unread_badge.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/inbox/application/conversation_projection.dart';

class HomeChannelRow extends StatelessWidget {
  const HomeChannelRow({
    super.key,
    required this.channel,
    required this.onTap,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    this.onEdit,
    this.onDelete,
    this.onLeave,
    this.onTogglePin,
    this.onMoveUp,
    this.onMoveDown,
    this.isMutating = false,
  });

  final HomeChannelSummary channel;
  final VoidCallback onTap;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onLeave;
  final VoidCallback? onTogglePin;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final bool isMutating;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final hasUnread = unreadCount > 0;

    return Material(
      color: hasUnread ? colors.primaryLight : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress:
            _hasActions && !isMutating ? () => _showActionSheet(context) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal,
            vertical: AppSpacing.listItemVertical,
          ),
          child: Row(
            children: [
              Icon(
                channel.isPrivate
                    ? Icons.lock
                    : isPinned
                        ? Icons.push_pin
                        : Icons.tag,
                key: channel.isPrivate
                    ? const ValueKey('channel-private-badge')
                    : null,
                size: 20,
                color: hasUnread ? colors.primary : colors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        color: colors.text,
                        fontWeight:
                            hasUnread ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      resolvePreviewText(channel.lastMessagePreview),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (channel.lastActivityAt != null)
                    Text(
                      formatRelativeTime(channel.lastActivityAt!),
                      style: AppTypography.caption.copyWith(
                        color: hasUnread ? colors.primary : colors.textTertiary,
                      ),
                    ),
                  if (isMuted)
                    Icon(
                      Icons.notifications_off,
                      size: 14,
                      color: colors.textTertiary,
                    ),
                  if (hasUnread) ...[
                    const SizedBox(height: 4),
                    UnreadBadge(count: unreadCount),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasActions =>
      onEdit != null ||
      onDelete != null ||
      onLeave != null ||
      onTogglePin != null ||
      onMoveUp != null ||
      onMoveDown != null;

  Future<void> _showActionSheet(BuildContext context) async {
    final actions = <ListActionItem>[
      if (onMoveUp != null)
        const ListActionItem(
          key: 'channel-action-move-up',
          label: 'Move up',
          icon: Icons.arrow_upward,
        ),
      if (onMoveDown != null)
        const ListActionItem(
          key: 'channel-action-move-down',
          label: 'Move down',
          icon: Icons.arrow_downward,
        ),
      if (onTogglePin != null)
        ListActionItem(
          key: 'channel-action-toggle-pin',
          label: isPinned ? 'Unpin channel' : 'Pin channel',
          icon: isPinned ? Icons.push_pin_outlined : Icons.push_pin,
        ),
      if (onEdit != null)
        const ListActionItem(
          key: 'channel-action-edit',
          label: 'Edit channel',
          icon: Icons.edit_outlined,
        ),
      if (onLeave != null)
        const ListActionItem(
          key: 'channel-action-leave',
          label: 'Leave channel',
          icon: Icons.exit_to_app,
        ),
      if (onDelete != null)
        const ListActionItem(
          key: 'channel-action-delete',
          label: 'Delete channel',
          icon: Icons.delete_outline,
          isDestructive: true,
        ),
    ];

    final result = await showListActionSheet(
      context: context,
      actions: actions,
      title: channel.name,
    );

    switch (result) {
      case 'channel-action-move-up':
        onMoveUp?.call();
      case 'channel-action-move-down':
        onMoveDown?.call();
      case 'channel-action-toggle-pin':
        onTogglePin?.call();
      case 'channel-action-edit':
        onEdit?.call();
      case 'channel-action-leave':
        onLeave?.call();
      case 'channel-action-delete':
        onDelete?.call();
    }
  }
}
