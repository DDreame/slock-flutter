import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/role_badge.dart';
import 'package:slock_app/app/widgets/status_glow_ring.dart';
import 'package:slock_app/core/hero/hero_tags.dart';
import 'package:slock_app/features/presence/presentation/widgets/presence_avatar.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Returns the [AppColors] token color for a given role string.
///
/// - owner → amber ([AppColors.warning])
/// - admin → indigo ([AppColors.primary])
/// - member / unknown → gray ([AppColors.textTertiary])
Color memberRoleColor(AppColors colors, String? role) {
  return switch (role) {
    'owner' => colors.warning,
    'admin' => colors.primary,
    _ => colors.textTertiary,
  };
}

/// Maps a presence string to a [GlowRingStatus] for agent members.
GlowRingStatus _presenceToGlowStatus(String? presence) {
  return switch (presence) {
    'online' => GlowRingStatus.online,
    'thinking' => GlowRingStatus.thinking,
    'working' => GlowRingStatus.working,
    'error' => GlowRingStatus.error,
    _ => GlowRingStatus.offline,
  };
}

class MemberListItem extends StatelessWidget {
  const MemberListItem({
    super.key,
    required this.member,
    required this.canManageMember,
    required this.onTap,
    required this.onMessage,
    required this.onChangeRole,
    required this.onRemove,
    this.isOpeningDirectMessage = false,
    this.isUpdatingRole = false,
    this.isRemoving = false,
  });

  final MemberProfile member;
  final bool canManageMember;
  final VoidCallback onTap;
  final VoidCallback onMessage;
  final ValueChanged<String> onChangeRole;
  final VoidCallback onRemove;
  final bool isOpeningDirectMessage;
  final bool isUpdatingRole;
  final bool isRemoving;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final canManageTarget =
        canManageMember && !member.isSelf && member.role != 'owner';

    final avatar = Hero(
      tag: HeroTags.avatar(member.id),
      child: ProfileAvatar(
        displayName: member.displayName,
        avatarUrl: member.avatarUrl,
        radius: 20,
      ),
    );

    return ListTile(
      key: ValueKey('member-${member.id}'),
      leading: member.isAgent
          ? StatusGlowRing(
              key: ValueKey('member-status-${member.id}'),
              status: _presenceToGlowStatus(member.presence),
              size: 48,
              child: avatar,
            )
          : PresenceAvatar(
              key: ValueKey('member-presence-${member.id}'),
              userId: member.id,
              child: avatar,
            ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              member.displayName,
              style: AppTypography.body.copyWith(color: colors.text),
            ),
          ),
          if (member.role != null)
            RoleBadge(
              key: ValueKey('member-role-${member.id}'),
              label: formatMemberRoleLabel(member.role!),
              color: memberRoleColor(colors, member.role),
            ),
        ],
      ),
      subtitle: Text(
        _subtitle,
        style: AppTypography.caption.copyWith(
          color: colors.textSecondary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: ValueKey('member-message-${member.id}'),
            icon: isOpeningDirectMessage
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.chat_bubble_outline,
                    color: colors.textTertiary,
                  ),
            onPressed: isOpeningDirectMessage ? null : onMessage,
            tooltip: 'Message',
          ),
          if (canManageTarget)
            isUpdatingRole || isRemoving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : PopupMenuButton<_MemberAction>(
                    key: ValueKey('member-actions-${member.id}'),
                    icon: Icon(
                      Icons.more_vert,
                      color: colors.textTertiary,
                    ),
                    tooltip: 'Member admin actions',
                    onSelected: (action) {
                      switch (action) {
                        case _MemberAction.makeAdmin:
                          onChangeRole('admin');
                          break;
                        case _MemberAction.makeMember:
                          onChangeRole('member');
                          break;
                        case _MemberAction.remove:
                          onRemove();
                          break;
                      }
                    },
                    itemBuilder: (context) {
                      return [
                        if (member.role != 'admin')
                          PopupMenuItem<_MemberAction>(
                            value: _MemberAction.makeAdmin,
                            child: Text(context.l10n.membersMakeAdmin),
                          ),
                        if (member.role != 'member')
                          PopupMenuItem<_MemberAction>(
                            value: _MemberAction.makeMember,
                            child: Text(context.l10n.membersMakeMember),
                          ),
                        PopupMenuItem<_MemberAction>(
                          value: _MemberAction.remove,
                          child: Text(context.l10n.membersRemoveMember),
                        ),
                      ];
                    },
                  ),
        ],
      ),
      onTap: onTap,
    );
  }

  String get _subtitle {
    final parts = <String>[
      if (member.description != null) member.description!,
      if (member.presence != null) member.presence!,
      if (member.username != null) '@${member.username}',
    ];
    return parts.isEmpty ? member.id : parts.join(' · ');
  }
}

enum _MemberAction { makeAdmin, makeMember, remove }

String formatMemberRoleLabel(String role) {
  switch (role) {
    case 'owner':
      return 'Owner';
    case 'admin':
      return 'Admin';
    case 'member':
      return 'Member';
    default:
      return role;
  }
}
