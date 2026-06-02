import 'package:flutter/material.dart';
import 'package:slock_app/l10n/l10n.dart';

/// State machine for quote-jump UI feedback (#649).
///
/// Separates "loading" (spinner during loadOlder) from "not found" (error
/// shown only after load completes and target message is missing).
enum QuoteJumpState { idle, loading, notFound }

/// Overlay widget rendered during quote-jump loading or not-found states.
///
/// Exposed as public API for Phase A testability.
class QuoteJumpOverlay extends StatelessWidget {
  const QuoteJumpOverlay({super.key, required this.state});

  final QuoteJumpState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      QuoteJumpState.idle => const SizedBox.shrink(),
      QuoteJumpState.loading => Center(
          child: Card(
            key: const ValueKey('quote-jump-loading'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(context.l10n.conversationQuoteLoading),
                ],
              ),
            ),
          ),
        ),
      QuoteJumpState.notFound => Center(
          child: Card(
            key: const ValueKey('quote-jump-not-found'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, size: 16),
                  const SizedBox(width: 12),
                  Text(context.l10n.conversationQuoteNotFound),
                ],
              ),
            ),
          ),
        ),
    };
  }
}

/// Dismissible overlay shell wrapping [QuoteJumpOverlay] with Semantics.
///
/// When [state] is [QuoteJumpState.notFound], the overlay becomes a tappable
/// dismiss button with an accessible label. Extracted for widget-level
/// testability (#851).
class QuoteJumpDismissibleOverlay extends StatelessWidget {
  const QuoteJumpDismissibleOverlay({
    super.key,
    required this.state,
    this.onDismiss,
  });

  final QuoteJumpState state;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final isDismissible = state == QuoteJumpState.notFound;
    // Use opaque hit-test only when the overlay is dismissible (notFound).
    // During loading, use deferToChild so scroll gestures pass through.
    return Semantics(
      button: isDismissible,
      label: isDismissible ? context.l10n.quoteJumpDismissSemantics : null,
      child: GestureDetector(
        behavior: isDismissible
            ? HitTestBehavior.opaque
            : HitTestBehavior.deferToChild,
        onTap: isDismissible ? onDismiss : null,
        child: QuoteJumpOverlay(
          key: const ValueKey('quote-jump-overlay'),
          state: state,
        ),
      ),
    );
  }
}
