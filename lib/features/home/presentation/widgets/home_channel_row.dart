import 'package:flutter/material.dart';
import 'package:slock_app/features/home/data/home_repository.dart';

enum _HomeChannelAction { edit, delete, leave }

class HomeChannelRow extends StatelessWidget {
  const HomeChannelRow({
    super.key,
    required this.channel,
    required this.onTap,
    this.unreadCount = 0,
    this.onEdit,
    this.onDelete,
    this.onLeave,
    this.isMutating = false,
  });

  final HomeChannelSummary channel;
  final VoidCallback onTap;
  final int unreadCount;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onLeave;
  final bool isMutating;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.tag),
      title: Text(
        channel.name,
        style: unreadCount > 0
            ? const TextStyle(fontWeight: FontWeight.bold)
            : null,
      ),
      subtitle: channel.lastMessagePreview != null
          ? Text(
              channel.lastMessagePreview!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: _buildTrailing(context),
      onTap: onTap,
    );
  }

  Widget? _buildTrailing(BuildContext context) {
    final showMenu = onEdit != null || onDelete != null || onLeave != null;
    if (!showMenu && unreadCount == 0) {
      return null;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (unreadCount > 0) _UnreadBadge(count: unreadCount),
        if (showMenu)
          PopupMenuButton<_HomeChannelAction>(
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
              }
            },
            itemBuilder: (context) => [
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
          ),
      ],
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
