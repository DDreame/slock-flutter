import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Purpose-built deep-link error surface for resources the user cannot open.
///
/// Used when a route resolves but its backing API returns 403/404. This avoids
/// showing generic retry failures for inaccessible/deleted resources and always
/// gives the user a clear way back to a safe screen.
class DeepLinkResourceErrorView extends StatelessWidget {
  const DeepLinkResourceErrorView({
    required this.failure,
    this.onBack,
    super.key,
  });

  final AppFailure failure;
  final VoidCallback? onBack;

  static bool handles(AppFailure? failure) =>
      failure is ForbiddenFailure || failure is NotFoundFailure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNotFound = failure is NotFoundFailure;
    final icon = isNotFound ? Icons.search_off_outlined : Icons.lock_outline;
    final title = isNotFound
        ? context.l10n.deepLinkNotFoundTitle
        : context.l10n.deepLinkAccessDeniedTitle;
    final message = isNotFound
        ? context.l10n.deepLinkNotFoundMessage
        : context.l10n.deepLinkAccessDeniedMessage;

    return Center(
      key: const ValueKey('deep-link-resource-error'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: theme.colorScheme.primary),
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
              FilledButton.icon(
                key: const ValueKey('deep-link-resource-error-back'),
                onPressed: onBack ?? () => _goBack(context),
                icon: const Icon(Icons.arrow_back),
                label: Text(context.l10n.deepLinkBackButton),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }
}
