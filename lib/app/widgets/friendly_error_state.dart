import 'package:flutter/material.dart';

class FriendlyErrorState extends StatelessWidget {
  const FriendlyErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
    this.onShareDiagnostics,
    super.key,
  });

  final String title;
  final String message;
  final Future<void> Function() onRetry;

  /// Optional callback to open the diagnostic share sheet.
  ///
  /// When non-null, a "Share diagnostics" button is shown below the retry
  /// button. Callers are responsible for opening the appropriate share
  /// surface (e.g. [DiagnosticShareSheet]).
  final VoidCallback? onShareDiagnostics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => onRetry(),
                child: const Text('Retry'),
              ),
              if (onShareDiagnostics != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const ValueKey('error-share-diagnostics'),
                  onPressed: onShareDiagnostics,
                  icon: const Icon(
                    Icons.bug_report_outlined,
                    size: 18,
                  ),
                  label: const Text('Share diagnostics'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
