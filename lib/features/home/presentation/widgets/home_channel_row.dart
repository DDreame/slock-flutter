import 'package:flutter/material.dart';
import 'package:slock_app/features/home/data/home_repository.dart';

class HomeChannelRow extends StatelessWidget {
  const HomeChannelRow({
    super.key,
    required this.channel,
    required this.onTap,
    this.unreadCount = 0,
  });

  final HomeChannelSummary channel;
  final VoidCallback onTap;
  final int unreadCount;

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
