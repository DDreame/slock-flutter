import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/role_badge.dart';
import 'package:slock_app/app/widgets/status_glow_ring.dart';
import 'package:slock_app/features/members/presentation/widgets/member_list_item.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/profile/presentation/widgets/profile_avatar.dart';

/// Shows a read-only profile bottom sheet for a member.
Future<void> showMemberProfileSheet({
  required BuildContext context,
  required MemberProfile member,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MemberProfileSheet(member: member),
  );
}

class _MemberProfileSheet extends StatelessWidget {
  const _MemberProfileSheet({required this.member});

  final MemberProfile member;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    final avatar = ProfileAvatar(
      displayName: member.displayName,
      avatarUrl: member.avatarUrl,
      radius: 36,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              key: const ValueKey('profile-sheet-handle'),
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(
                bottom: AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: colors.textTertiary,
                borderRadius: BorderRadius.circular(
                  AppSpacing.radiusFull,
                ),
              ),
            ),

            // Avatar (with StatusGlowRing for agents)
            member.isAgent
                ? StatusGlowRing(
                    key: const ValueKey(
                      'profile-sheet-status-ring',
                    ),
                    status: _presenceToGlowStatus(
                      member.presence,
                    ),
                    size: 80,
                    child: avatar,
                  )
                : avatar,
            const SizedBox(height: AppSpacing.md),

            // Display name
            Text(
              member.displayName,
              key: const ValueKey('profile-sheet-name'),
              style: AppTypography.headline.copyWith(
                color: colors.text,
              ),
              textAlign: TextAlign.center,
            ),

            // Username
            if (member.username != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '@${member.username}',
                key: const ValueKey('profile-sheet-username'),
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),

            // Role badge
            if (member.role != null)
              RoleBadge(
                key: const ValueKey('profile-sheet-role'),
                label: formatMemberRoleLabel(member.role!),
                color: memberRoleColor(colors, member.role),
              ),

            // Description
            if (member.description != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                member.description!,
                key: const ValueKey(
                  'profile-sheet-description',
                ),
                style: AppTypography.body.copyWith(
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // Presence / status
            if (member.presence != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    key: const ValueKey(
                      'profile-sheet-presence-dot',
                    ),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _presenceColor(
                        colors,
                        member.presence,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _capitalizePresence(member.presence!),
                    key: const ValueKey(
                      'profile-sheet-presence',
                    ),
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

GlowRingStatus _presenceToGlowStatus(String? presence) {
  return switch (presence) {
    'online' => GlowRingStatus.online,
    'thinking' => GlowRingStatus.thinking,
    'working' => GlowRingStatus.working,
    'error' => GlowRingStatus.error,
    _ => GlowRingStatus.offline,
  };
}

Color _presenceColor(AppColors colors, String? presence) {
  return switch (presence) {
    'online' => colors.success,
    'thinking' => colors.warning,
    'working' => colors.primary,
    'error' => colors.error,
    _ => colors.textTertiary,
  };
}

String _capitalizePresence(String presence) {
  if (presence.isEmpty) return presence;
  return presence[0].toUpperCase() + presence.substring(1);
}
