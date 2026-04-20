import 'package:flutter/material.dart';
import 'package:slock_app/features/home/data/home_repository.dart';

class HomeDirectMessageRow extends StatelessWidget {
  const HomeDirectMessageRow({
    super.key,
    required this.directMessage,
    required this.onTap,
    this.unreadCount = 0,
  });

  final HomeDirectMessageSummary directMessage;
  final VoidCallback onTap;
  final int unreadCount;

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
      trailing: unreadCount > 0 ? _UnreadBadge(count: unreadCount) : null,
      onTap: onTap,
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
