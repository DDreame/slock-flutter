import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/profile/application/profile_detail_store.dart';
import 'package:slock_app/features/profile/presentation/widgets/profile_avatar.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context) {
    final target = ProfileTarget(userId: userId);
    return ProviderScope(
      overrides: [
        currentProfileTargetProvider.overrideWithValue(target),
      ],
      child: const _ProfileDetailScreen(),
    );
  }
}

class _ProfileDetailScreen extends ConsumerWidget {
  const _ProfileDetailScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileDetailStoreProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.profile?.isSelf == true ? 'My Profile' : 'Profile',
        ),
      ),
      body: switch (state.status) {
        ProfileDetailStatus.initial => const Center(
            key: ValueKey('profile-loading'),
            child: CircularProgressIndicator(),
          ),
        ProfileDetailStatus.success when state.profile != null => Center(
            key: const ValueKey('profile-success'),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProfileAvatar(
                    displayName: state.profile!.displayName,
                    avatarUrl: state.profile!.avatarUrl,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.profile!.displayName,
                    key: const ValueKey('profile-display-name'),
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.profile!.id,
                    key: const ValueKey('profile-user-id'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (state.profile!.isSelf) ...[
                    const SizedBox(height: 8),
                    Text(
                      'This is you',
                      key: const ValueKey('profile-self-badge'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
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
