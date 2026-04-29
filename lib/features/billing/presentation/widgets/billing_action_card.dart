import 'package:flutter/material.dart';

class BillingActionCard extends StatelessWidget {
  const BillingActionCard({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
    this.cardKey,
    this.actionKey,
    this.actionLabel,
    this.onAction,
  });

  final Key? cardKey;
  final Key? actionKey;
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: cardKey,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(message),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: actionKey,
                      onPressed: onAction,
                      icon: const Icon(Icons.open_in_new),
                      label: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
