import 'package:flutter/material.dart';
import 'package:slock_app/features/home/data/home_repository.dart';

enum _HomeDmAction { hide }

class HomeDirectMessageRow extends StatelessWidget {
  const HomeDirectMessageRow({
    super.key,
    required this.directMessage,
    required this.onTap,
    this.unreadCount = 0,
    this.onHide,
  });

  final HomeDirectMessageSummary directMessage;
  final VoidCallback onTap;
  final int unreadCount;
  final VoidCallback? onHide;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.person_outline),
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
    final showMenu = onHide != null;
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
                case _HomeDmAction.hide:
                  onHide?.call();
              }
            },
            itemBuilder: (context) => [
              if (onHide != null)
                const PopupMenuItem<_HomeDmAction>(
                  value: _HomeDmAction.hide,
                  child: Text('Hide conversation'),
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
