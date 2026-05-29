import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/auth/application/auth_providers_controller.dart';
import 'package:slock_app/features/auth/data/auth_provider.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Displays available OAuth/SSO provider buttons with a divider.
///
/// Renders nothing when no providers are available (loading, error, or empty).
/// Used on both the login and register pages.
class SocialLoginButtons extends ConsumerWidget {
  const SocialLoginButtons({
    super.key,
    required this.onProviderTap,
  });

  /// Called when the user taps a provider button.
  final ValueChanged<AuthProvider> onProviderTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providersAsync = ref.watch(authProvidersProvider);

    return providersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (providers) {
        if (providers.isEmpty) return const SizedBox.shrink();
        return _SocialLoginButtonsContent(
          key: const ValueKey('social-login-buttons'),
          providers: providers,
          onProviderTap: onProviderTap,
        );
      },
    );
  }
}

class _SocialLoginButtonsContent extends StatelessWidget {
  const _SocialLoginButtonsContent({
    super.key,
    required this.providers,
    required this.onProviderTap,
  });

  final List<AuthProvider> providers;
  final ValueChanged<AuthProvider> onProviderTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.oauthDividerLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        ...providers.map((provider) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton.icon(
                key: ValueKey('oauth-provider-${provider.id}'),
                onPressed: () => onProviderTap(provider),
                icon: Icon(_iconForProvider(provider.id)),
                label: Text(
                  l10n.oauthProviderButton(provider.name),
                ),
              ),
            )),
      ],
    );
  }

  IconData _iconForProvider(String providerId) {
    switch (providerId) {
      case 'google':
        return Icons.g_mobiledata;
      case 'github':
        return Icons.code;
      case 'apple':
        return Icons.apple;
      case 'microsoft':
        return Icons.window;
      default:
        return Icons.login;
    }
  }
}
