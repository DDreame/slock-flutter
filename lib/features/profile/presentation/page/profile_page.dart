import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/profile/application/profile_detail_store.dart';
import 'package:slock_app/features/profile/presentation/widgets/profile_avatar.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, this.userId, this.serverId});

  final String? userId;
  final String? serverId;

  @override
  Widget build(BuildContext context) {
    final target = ProfileTarget(
      userId: userId,
      serverId: serverId == null ? null : ServerScopeId(serverId!),
    );
    return ProviderScope(
      overrides: [currentProfileTargetProvider.overrideWithValue(target)],
      child: const _ProfileDetailScreen(),
    );
  }
}

class _ProfileDetailScreen extends ConsumerStatefulWidget {
  const _ProfileDetailScreen();

  @override
  ConsumerState<_ProfileDetailScreen> createState() =>
      _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends ConsumerState<_ProfileDetailScreen> {
  Future<void> _openDirectMessage(ProfileTarget target) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final channelId = await ref
          .read(profileDetailStoreProvider.notifier)
          .openDirectMessage();
      if (!mounted || target.serverId == null) {
        return;
      }
      context.push('/servers/${target.serverId!.value}/dms/$channelId');
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(failure.message ?? 'Failed to open direct message.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileDetailStoreProvider);
    final target = ref.watch(currentProfileTargetProvider);
    final theme = Theme.of(context);
    final profile = state.profile;

    return Scaffold(
      appBar: AppBar(
        title: Text(profile?.isSelf == true ? 'My Profile' : 'Profile'),
      ),
      body: switch (state.status) {
        ProfileDetailStatus.initial ||
        ProfileDetailStatus.loading => const Center(
          key: ValueKey('profile-loading'),
          child: CircularProgressIndicator(),
        ),
        ProfileDetailStatus.failure => Center(
          key: const ValueKey('profile-error'),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.failure?.message ?? 'Profile not available.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.read(profileDetailStoreProvider.notifier).retry(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        ProfileDetailStatus.success when profile != null => Center(
          key: const ValueKey('profile-success'),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ProfileAvatar(
                  displayName: profile.displayName,
                  avatarUrl: profile.avatarUrl,
                ),
                const SizedBox(height: 16),
                Text(
                  profile.displayName,
                  key: const ValueKey('profile-display-name'),
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                if (profile.presence != null) ...[
                  const SizedBox(height: 12),
                  DecoratedBox(
                    key: const ValueKey('profile-presence'),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        profile.presence!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                ],
                _ProfileInfoRow(
                  infoKey: const ValueKey('profile-user-id'),
                  label: 'User ID',
                  value: profile.id,
                ),
                if (profile.username != null)
                  _ProfileInfoRow(
                    infoKey: const ValueKey('profile-username'),
                    label: 'Username',
                    value: '@${profile.username!}',
                  ),
                if (profile.email != null)
                  _ProfileInfoRow(
                    infoKey: const ValueKey('profile-email'),
                    label: 'Email',
                    value: profile.email!,
                  ),
                if (profile.role != null)
                  _ProfileInfoRow(
                    infoKey: const ValueKey('profile-role'),
                    label: 'Role',
                    value: profile.role!,
                  ),
                if (profile.isSelf) ...[
                  const SizedBox(height: 8),
                  Text(
                    'This is you',
                    key: const ValueKey('profile-self-badge'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ] else if (target.canLoadRemote) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const ValueKey('profile-message-button'),
                    onPressed: state.isOpeningDirectMessage
                        ? null
                        : () => _openDirectMessage(target),
                    icon: state.isOpeningDirectMessage
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chat_bubble_outline),
                    label: const Text('Message'),
                  ),
                ],
              ],
            ),
          ),
        ),
        _ => const Center(
          key: ValueKey('profile-empty'),
          child: Text('Profile not available.'),
        ),
      },
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.infoKey,
    required this.label,
    required this.value,
  });

  final Key infoKey;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      key: infoKey,
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
