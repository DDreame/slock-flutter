import 'package:flutter/material.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/profile/presentation/widgets/profile_avatar.dart';

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
    final subtitle = [
      if (member.role != null) formatMemberRoleLabel(member.role!),
      if (member.presence != null) member.presence,
      if (member.username != null) '@${member.username}',
      member.id,
    ].join(' • ');

    return ListTile(
      key: ValueKey('member-${member.id}'),
      leading: ProfileAvatar(
        displayName: member.displayName,
        avatarUrl: member.avatarUrl,
        radius: 20,
      ),
      title: Row(
        children: [
          Expanded(child: Text(member.displayName)),
          if (member.role != null)
            _MemberRoleBadge(role: member.role!, userId: member.id),
        ],
      ),
      subtitle: Text(subtitle),
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
                : const Icon(Icons.chat_bubble_outline),
            onPressed: isOpeningDirectMessage ? null : onMessage,
            tooltip: 'Message',
          ),
          if (canManageMember && !member.isSelf)
            isUpdatingRole || isRemoving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : PopupMenuButton<_MemberAction>(
                    key: ValueKey('member-actions-${member.id}'),
                    icon: const Icon(Icons.more_vert),
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
                          const PopupMenuItem<_MemberAction>(
                            value: _MemberAction.makeAdmin,
                            child: Text('Make admin'),
                          ),
                        if (member.role != 'member')
                          const PopupMenuItem<_MemberAction>(
                            value: _MemberAction.makeMember,
                            child: Text('Make member'),
                          ),
                        const PopupMenuItem<_MemberAction>(
                          value: _MemberAction.remove,
                          child: Text('Remove member'),
                        ),
                      ];
                    },
                  ),
        ],
      ),
      onTap: onTap,
    );
  }
}

enum _MemberAction { makeAdmin, makeMember, remove }

class _MemberRoleBadge extends StatelessWidget {
  const _MemberRoleBadge({required this.role, required this.userId});

  final String role;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isAdmin = role == 'admin';
    return Container(
      key: ValueKey('member-role-$userId'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAdmin
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        formatMemberRoleLabel(role),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

String formatMemberRoleLabel(String role) {
  switch (role) {
    case 'admin':
      return 'Admin';
    case 'member':
      return 'Member';
    default:
      return role;
  }
}
