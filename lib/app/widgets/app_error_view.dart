import 'package:flutter/material.dart';

/// Shared error state widget used across feature pages.
///
/// Renders an error message and an optional Retry button. Uses [ValueKey]
/// `app-error-view` for test discoverability.
///
/// When [onRetry] is null, only the message is shown (no-retry error state).
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    required this.message,
    this.onRetry,
    super.key,
  });

  /// The error description shown to the user.
  final String message;

  /// Called when the user taps the Retry button. When null, the button
  /// is not rendered.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('app-error-view'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
