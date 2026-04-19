import 'package:flutter/material.dart';
import 'package:slock_app/features/home/data/home_repository.dart';

class HomeChannelRow extends StatelessWidget {
  const HomeChannelRow({
    super.key,
    required this.channel,
    required this.onTap,
  });

  final HomeChannelSummary channel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.tag),
      title: Text(channel.name),
      onTap: onTap,
    );
  }
}
