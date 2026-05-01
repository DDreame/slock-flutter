import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/unread_badge.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/data/home_repository.dart';

enum _HomeDmAction { togglePin, hide, moveUp, moveDown }

class HomeDirectMessageRow extends StatelessWidget {
  const HomeDirectMessageRow({
    super.key,
    required this.directMessage,
    required this.onTap,
    this.unreadCount = 0,
    this.isPinned = false,
    this.onTogglePin,
    this.onHide,
    this.onMoveUp,
    this.onMoveDown,
  });

  final HomeDirectMessageSummary directMessage;
  final VoidCallback onTap;
  final int unreadCount;
  final bool isPinned;
  final VoidCallback? onTogglePin;
  final VoidCallback? onHide;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

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
              if (isPinned)
                Icon(
                  Icons.push_pin,
                  size: 20,
                  color: hasUnread ? colors.primary : colors.textTertiary,
                )
              else
                CircleAvatar(
                  key: const ValueKey('dm-avatar'),
                  radius: 16,
                  backgroundColor: colors.primaryLight,
                  child: Text(
                    _initials(directMessage.title),
                    style: AppTypography.label.copyWith(
                      color: colors.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      directMessage.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        color: colors.text,
                        fontWeight:
                            hasUnread ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    if (directMessage.lastMessagePreview != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        directMessage.lastMessagePreview!,
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
                  if (directMessage.lastActivityAt != null)
                    Text(
                      formatRelativeTime(directMessage.lastActivityAt!),
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
      onTogglePin != null ||
      onHide != null ||
      onMoveUp != null ||
      onMoveDown != null;

  Widget _buildMenu(BuildContext context) {
    return PopupMenuButton<_HomeDmAction>(
      key: ValueKey('dm-menu-${directMessage.scopeId.routeParam}'),
      tooltip: 'Message actions',
      onSelected: (action) {
        switch (action) {
          case _HomeDmAction.togglePin:
            onTogglePin?.call();
          case _HomeDmAction.hide:
            onHide?.call();
          case _HomeDmAction.moveUp:
            onMoveUp?.call();
          case _HomeDmAction.moveDown:
            onMoveDown?.call();
        }
      },
      itemBuilder: (context) => [
        if (onMoveUp != null)
          const PopupMenuItem<_HomeDmAction>(
            value: _HomeDmAction.moveUp,
            child: Text('Move up'),
          ),
        if (onMoveDown != null)
          const PopupMenuItem<_HomeDmAction>(
            value: _HomeDmAction.moveDown,
            child: Text('Move down'),
          ),
        if (onTogglePin != null)
          PopupMenuItem<_HomeDmAction>(
            value: _HomeDmAction.togglePin,
            child: Text(isPinned ? 'Unpin conversation' : 'Pin conversation'),
          ),
        if (onHide != null)
          const PopupMenuItem<_HomeDmAction>(
            value: _HomeDmAction.hide,
            child: Text('Close conversation'),
          ),
      ],
    );
  }

  static String _initials(String title) {
    final words = title.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words[0].isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}
