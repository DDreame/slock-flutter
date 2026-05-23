import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/router/pending_deep_link_provider.dart';
import 'package:slock_app/app/widgets/section_card.dart';
import 'package:slock_app/features/onboarding/application/onboarding_store.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/stores/notification/notification_store.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  var _step = 0;
  var _requestingNotifications = false;

  Future<void> _requestNotifications() async {
    setState(() => _requestingNotifications = true);
    try {
      await ref.read(notificationStoreProvider.notifier).requestPermission();
    } finally {
      if (mounted) setState(() => _requestingNotifications = false);
    }
  }

  Future<void> _finish() async {
    await ref.read(onboardingStoreProvider.notifier).complete();
    if (!mounted) return;

    final pending = ref.read(pendingDeepLinkProvider);
    if (pending != null) {
      ref.read(pendingDeepLinkProvider.notifier).state = null;
    }
    final target = resolvePendingDeepLinkTarget(
      pending,
      memberServerIds:
          ref.read(serverListStoreProvider).servers.map((server) => server.id),
    );
    context.go(target ?? '/home');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to Slock')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                key: const ValueKey('onboarding-progress'),
                value: (_step + 1) / 3,
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _OnboardingStep(
                    key: ValueKey('onboarding-step-$_step'),
                    step: _step,
                    colors: colors,
                    requestingNotifications: _requestingNotifications,
                    onRequestNotifications: _requestNotifications,
                    onEditProfile: () => context.push('/profile/edit'),
                  ),
                ),
              ),
              Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      key: const ValueKey('onboarding-back'),
                      onPressed: () => setState(() => _step--),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  TextButton(
                    key: const ValueKey('onboarding-skip'),
                    onPressed: _finish,
                    child: const Text('Skip'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    key: const ValueKey('onboarding-next'),
                    onPressed:
                        _step == 2 ? _finish : () => setState(() => _step++),
                    child: Text(_step == 2 ? 'Finish' : 'Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({
    super.key,
    required this.step,
    required this.colors,
    required this.requestingNotifications,
    required this.onRequestNotifications,
    required this.onEditProfile,
  });

  final int step;
  final AppColors colors;
  final bool requestingNotifications;
  final VoidCallback onRequestNotifications;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return switch (step) {
      0 => _StepCard(
          key: const ValueKey('onboarding-welcome-step'),
          icon: Icons.handshake_outlined,
          title: 'Set up your workspace',
          body:
              'Slock is ready. Take a minute to configure notifications and your profile before jumping in.',
          colors: colors,
        ),
      1 => _StepCard(
          key: const ValueKey('onboarding-notifications-step'),
          icon: Icons.notifications_active_outlined,
          title: 'Stay in the loop',
          body:
              'Enable notifications so mentions, replies, and tasks reach you quickly.',
          colors: colors,
          action: OutlinedButton.icon(
            key: const ValueKey('onboarding-request-notifications'),
            onPressed: requestingNotifications ? null : onRequestNotifications,
            icon: requestingNotifications
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.notifications_outlined),
            label: const Text('Enable notifications'),
          ),
        ),
      _ => _StepCard(
          key: const ValueKey('onboarding-profile-step'),
          icon: Icons.account_circle_outlined,
          title: 'Complete your profile',
          body:
              'Add your display name, bio, or avatar so teammates can recognize you.',
          colors: colors,
          action: OutlinedButton.icon(
            key: const ValueKey('onboarding-edit-profile'),
            onPressed: onEditProfile,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit profile'),
          ),
        ),
    };
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.colors,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final AppColors colors;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: colors.primary),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.headline.copyWith(color: colors.text),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}
