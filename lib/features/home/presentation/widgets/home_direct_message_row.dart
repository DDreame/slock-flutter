import 'package:flutter/material.dart';
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
    return ListTile(
      leading: Icon(isPinned ? Icons.push_pin : Icons.person_outline),
      title: Text(
        directMessage.title,
        style: unreadCount > 0
            ? const TextStyle(fontWeight: FontWeight.bold)
            : null,
      ),
      subtitle: directMessage.lastMessagePreview != null
          ? Text(
              directMessage.lastMessagePreview!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: _buildTrailing(context),
      onTap: onTap,
    );
  }

  Widget? _buildTrailing(BuildContext context) {
    final showMenu = onTogglePin != null ||
        onHide != null ||
        onMoveUp != null ||
        onMoveDown != null;
    if (!showMenu && unreadCount == 0) {
      return null;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (unreadCount > 0) _UnreadBadge(count: unreadCount),
        if (showMenu)
          PopupMenuButton<_HomeDmAction>(
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
                  child: Text(
                      isPinned ? 'Unpin conversation' : 'Pin conversation'),
                ),
              if (onHide != null)
                const PopupMenuItem<_HomeDmAction>(
                  value: _HomeDmAction.hide,
                  child: Text('Close conversation'),
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
