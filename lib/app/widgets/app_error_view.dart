import 'package:flutter/material.dart';

/// Shared error state widget used across feature pages.
///
/// Renders an error message and a Retry button. Uses [ValueKey] `app-error-view`
/// for test discoverability.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    required this.message,
    required this.onRetry,
    super.key,
  });

  /// The error description shown to the user.
  final String message;

  /// Called when the user taps the Retry button.
  final VoidCallback onRetry;

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
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
