import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/role_badge.dart';
import 'package:slock_app/app/widgets/section_card.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/core/hero/hero_tags.dart';
import 'package:slock_app/features/profile/application/avatar_upload_service.dart';
import 'package:slock_app/features/profile/application/profile_detail_store.dart';
import 'package:slock_app/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/l10n/l10n.dart';

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
            content: Text(failure.userMessage(context.l10n)),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(
      profileDetailStoreProvider.select((s) => s.status),
    );
    final failure = ref.watch(
      profileDetailStoreProvider.select((s) => s.failure),
    );
    final hasProfile = ref.watch(
      profileDetailStoreProvider.select((s) => s.profile != null),
    );
    final target = ref.watch(currentProfileTargetProvider);
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          ref.watch(
            profileDetailStoreProvider.select((s) => s.profile?.isSelf == true),
          )
              ? 'My Profile'
              : 'Profile',
        ),
      ),
      body: switch (status) {
        ProfileDetailStatus.initial ||
        ProfileDetailStatus.loading =>
          const Center(
            key: ValueKey('profile-loading'),
            child: CircularProgressIndicator(),
          ),
        ProfileDetailStatus.failure => Center(
            key: const ValueKey('profile-error'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    failure?.message ?? 'Profile not available.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () =>
                        ref.read(profileDetailStoreProvider.notifier).retry(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ProfileDetailStatus.success when hasProfile => _ProfileSuccessBody(
            target: target,
            colors: colors,
            onMessage: () => _openDirectMessage(target),
          ),
        _ => Center(
            key: const ValueKey('profile-empty'),
            child: Text(
              'Profile not available.',
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
          ),
      },
    );
  }
}

class _ProfileSuccessBody extends ConsumerWidget {
  const _ProfileSuccessBody({
    required this.target,
    required this.colors,
    required this.onMessage,
  });

  final ProfileTarget target;
  final AppColors colors;
  final VoidCallback onMessage;

  Future<void> _handleAvatarEdit(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final picker = ref.read(imagePickerProvider);
      final filePath = await picker.pickImage();
      if (filePath == null) return; // User cancelled.

      final uploadService = ref.read(avatarUploadServiceProvider);
      final newUrl = await uploadService.upload(filePath);

      ref.read(profileDetailStoreProvider.notifier).updateAvatarUrl(newUrl);
      // Persist to session so avatar survives page rebuild/reopen.
      ref.read(sessionStoreProvider.notifier).updateAvatarUrl(newUrl);
    } on AvatarUploadException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } on Exception catch (e) {
      ref.read(diagnosticsCollectorProvider).error(
            'ProfilePage',
            'Avatar upload failed: $e',
          );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Failed to update avatar.')),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(
      profileDetailStoreProvider.select((s) => s.profile),
    );
    final isOpeningDm = ref.watch(
      profileDetailStoreProvider.select((s) => s.isOpeningDirectMessage),
    );

    if (profile == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      key: const ValueKey('profile-success'),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            children: [
              // --- Avatar ---
              Stack(
                children: [
                  Hero(
                    tag: HeroTags.avatar(profile.id),
                    child: ProfileAvatar(
                      displayName: profile.displayName,
                      avatarUrl: profile.avatarUrl,
                      radius: 40,
                    ),
                  ),
                  if (profile.isSelf)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        key: const ValueKey('profile-avatar-edit-button'),
                        onTap: () => _handleAvatarEdit(context, ref),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: colors.primaryForeground,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // --- Display name ---
              Text(
                profile.displayName,
                key: const ValueKey('profile-display-name'),
                style: AppTypography.headline.copyWith(color: colors.text),
                textAlign: TextAlign.center,
              ),

              // --- Presence pill ---
              if (profile.presence != null) ...[
                const SizedBox(height: AppSpacing.md),
                DecoratedBox(
                  key: const ValueKey('profile-presence'),
                  decoration: BoxDecoration(
                    color: colors.primaryLight,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(
                      profile.presence!,
                      style: AppTypography.label.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xl),

              // --- Info card ---
              SectionCard(
                key: const ValueKey('profile-info-card'),
                child: Column(
                  children: [
                    _ProfileInfoRow(
                      infoKey: const ValueKey('profile-user-id'),
                      labelKey: const ValueKey('profile-user-id-label'),
                      valueKey: const ValueKey('profile-user-id-value'),
                      label: 'User ID',
                      value: profile.id,
                      colors: colors,
                    ),
                    if (profile.username != null) ...[
                      Divider(
                          height: AppSpacing.xl.toDouble(),
                          color: colors.border),
                      _ProfileInfoRow(
                        infoKey: const ValueKey('profile-username'),
                        label: 'Username',
                        value: '@${profile.username!}',
                        colors: colors,
                      ),
                    ],
                    if (profile.email != null) ...[
                      Divider(
                          height: AppSpacing.xl.toDouble(),
                          color: colors.border),
                      _ProfileInfoRow(
                        infoKey: const ValueKey('profile-email'),
                        label: 'Email',
                        value: profile.email!,
                        colors: colors,
                      ),
                    ],
                    if (profile.role != null) ...[
                      Divider(
                          height: AppSpacing.xl.toDouble(),
                          color: colors.border),
                      Padding(
                        key: const ValueKey('profile-role'),
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Row(
                          children: [
                            Text(
                              'Role',
                              style: AppTypography.label.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            RoleBadge(
                              label: _capitalizeRole(profile.role!),
                              color: colors.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (profile.joinedAt != null) ...[
                      Divider(
                          height: AppSpacing.xl.toDouble(),
                          color: colors.border),
                      _ProfileInfoRow(
                        infoKey: const ValueKey('profile-member-since'),
                        label: 'Member since',
                        value: _formatDate(profile.joinedAt!),
                        colors: colors,
                      ),
                    ],
                  ],
                ),
              ),

              // --- Edit profile button (self only) ---
              if (profile.isSelf) ...[
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const ValueKey('profile-edit-button'),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile editing coming soon'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Profile'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'This is you',
                  key: const ValueKey('profile-self-badge'),
                  style: AppTypography.label.copyWith(
                    color: colors.primary,
                  ),
                ),
              ]
              // --- Message button ---
              else if (target.canLoadRemote) ...[
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('profile-message-button'),
                    onPressed: isOpeningDm ? null : onMessage,
                    icon: isOpeningDm
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chat_bubble_outline),
                    label: const Text('Message'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _capitalizeRole(String role) {
    if (role.isEmpty) return role;
    return role[0].toUpperCase() + role.substring(1);
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.infoKey,
    this.labelKey,
    this.valueKey,
    required this.label,
    required this.value,
    required this.colors,
  });

  final Key infoKey;
  final Key? labelKey;
  final Key? valueKey;
  final String label;
  final String value;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: infoKey,
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Text(
            label,
            key: labelKey,
            style: AppTypography.label.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              key: valueKey,
              style: AppTypography.body.copyWith(
                color: colors.text,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
