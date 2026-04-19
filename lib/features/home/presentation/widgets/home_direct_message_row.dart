import 'package:flutter/material.dart';
import 'package:slock_app/features/home/data/home_repository.dart';

class HomeDirectMessageRow extends StatelessWidget {
  const HomeDirectMessageRow({
    super.key,
    required this.directMessage,
    required this.onTap,
  });

  final HomeDirectMessageSummary directMessage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.person_outline),
      title: Text(directMessage.title),
      onTap: onTap,
    );
  }
}
