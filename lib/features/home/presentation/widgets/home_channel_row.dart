import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/unread_badge.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/data/home_repository.dart';

enum _HomeChannelAction { edit, delete, leave, togglePin, moveUp, moveDown }

class HomeChannelRow extends StatelessWidget {
  const HomeChannelRow({
    super.key,
    required this.channel,
    required this.onTap,
    this.unreadCount = 0,
    this.isPinned = false,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal,
            vertical: AppSpacing.listItemVertical,
          ),
          child: Row(
            children: [
              Icon(
                isPinned ? Icons.push_pin : Icons.tag,
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
                    if (channel.lastMessagePreview != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        channel.lastMessagePreview!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
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
                  if (hasUnread) ...[
                    const SizedBox(height: 4),
                    UnreadBadge(count: unreadCount),
                  ],
                ],
              ),
              if (_showMenu) _buildMenu(context),
            ],
          ),
        ),
      ),
    );
  }

  bool get _showMenu =>
      onEdit != null ||
      onDelete != null ||
      onLeave != null ||
      onTogglePin != null ||
      onMoveUp != null ||
      onMoveDown != null;

  Widget _buildMenu(BuildContext context) {
    return PopupMenuButton<_HomeChannelAction>(
      key: ValueKey('channel-menu-${channel.scopeId.routeParam}'),
      enabled: !isMutating,
      tooltip: 'Channel actions',
      onSelected: (action) {
        switch (action) {
          case _HomeChannelAction.edit:
            onEdit?.call();
          case _HomeChannelAction.delete:
            onDelete?.call();
          case _HomeChannelAction.leave:
            onLeave?.call();
          case _HomeChannelAction.togglePin:
            onTogglePin?.call();
          case _HomeChannelAction.moveUp:
            onMoveUp?.call();
          case _HomeChannelAction.moveDown:
            onMoveDown?.call();
        }
      },
      itemBuilder: (context) => [
        if (onMoveUp != null)
          const PopupMenuItem<_HomeChannelAction>(
            value: _HomeChannelAction.moveUp,
            child: Text('Move up'),
          ),
        if (onMoveDown != null)
          const PopupMenuItem<_HomeChannelAction>(
            value: _HomeChannelAction.moveDown,
            child: Text('Move down'),
          ),
        if (onTogglePin != null)
          PopupMenuItem<_HomeChannelAction>(
            value: _HomeChannelAction.togglePin,
            child: Text(isPinned ? 'Unpin channel' : 'Pin channel'),
          ),
        if (onEdit != null)
          const PopupMenuItem<_HomeChannelAction>(
            value: _HomeChannelAction.edit,
            child: Text('Edit channel'),
          ),
        if (onDelete != null)
          const PopupMenuItem<_HomeChannelAction>(
            value: _HomeChannelAction.delete,
            child: Text('Delete channel'),
          ),
        if (onLeave != null)
          const PopupMenuItem<_HomeChannelAction>(
            value: _HomeChannelAction.leave,
            child: Text('Leave channel'),
          ),
      ],
    );
  }
}
