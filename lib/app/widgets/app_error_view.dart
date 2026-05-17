import 'package:flutter/material.dart';

/// Shared error-state widget used across all features.
///
/// Replaces feature-specific private error widgets
/// (`_ThreadsFailureView`, `_HomeErrorState`, etc.) with a consistent
/// error UI: centered message text + retry button.
///
/// Phase B will flesh out the full layout. This placeholder ensures
/// Phase A tests compile.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // Phase B: implement full error layout.
    throw UnimplementedError('AppErrorView not yet implemented');
  }
}
