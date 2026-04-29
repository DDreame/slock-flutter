import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/members/application/member_list_state.dart';
import 'package:slock_app/features/members/application/member_list_store.dart';
import 'package:slock_app/features/members/application/members_realtime_binding.dart';
import 'package:slock_app/features/members/presentation/widgets/member_list_item.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';

class MembersPage extends StatelessWidget {
  MembersPage({super.key, required String serverId})
      : _serverId = ServerScopeId(serverId);

  final ServerScopeId _serverId;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [currentMembersServerIdProvider.overrideWithValue(_serverId)],
      child: const _MembersScreen(),
    );
  }
}

class _MembersScreen extends ConsumerStatefulWidget {
  const _MembersScreen();

  @override
  ConsumerState<_MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<_MembersScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(memberListStoreProvider.notifier).ensureLoaded(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(membersRealtimeBindingProvider);
    final state = ref.watch(memberListStoreProvider);
    final serverId = ref.read(currentMembersServerIdProvider);
    final canManageMembers = _canManageMembers(state.members);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
        actions: state.status == MemberListStatus.success && canManageMembers
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: state.isInvitingByEmail
                      ? const Center(
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          key: const ValueKey('members-invite-human'),
                          onPressed: _inviteHuman,
                          icon: const Icon(Icons.person_add_alt_1),
                          tooltip: 'Invite human',
                        ),
                ),
              ]
            : null,
      ),
      body: switch (state.status) {
        MemberListStatus.initial || MemberListStatus.loading => const Center(
            key: ValueKey('members-loading'),
            child: CircularProgressIndicator(),
          ),
        MemberListStatus.failure => Center(
            key: const ValueKey('members-error'),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.failure?.message ?? 'Could not load members.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () =>
                        ref.read(memberListStoreProvider.notifier).load(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        MemberListStatus.success when state.members.isEmpty => const Center(
            key: ValueKey('members-empty'),
            child: Text('No members found.'),
          ),
        MemberListStatus.success => ListView.builder(
            key: const ValueKey('members-list'),
            itemCount: state.members.length,
            itemBuilder: (context, index) {
              final member = state.members[index];
              return MemberListItem(
                member: member,
                isOpeningDirectMessage: state.isOpeningDirectMessage(member.id),
                isUpdatingRole: state.isUpdatingRole(member.id),
                isRemoving: state.isRemovingMember(member.id),
                canManageMember: canManageMembers,
                onTap: () => context.push(
                  '/servers/${serverId.value}/profile/${member.id}',
                ),
                onMessage: () => _openDirectMessage(context, member.id),
                onChangeRole: (role) => _changeMemberRole(member, role),
                onRemove: () => _removeMember(member),
              );
            },
          ),
      },
    );
  }

  Future<void> _inviteHuman() async {
    final messenger = ScaffoldMessenger.of(context);
    final email = await _promptInviteEmail();
    if (email == null) {
      return;
    }

    try {
      await ref.read(memberListStoreProvider.notifier).inviteByEmail(email);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Invite email sent to $email.')),
      );
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(failure.message ?? 'Failed to send invite email.'),
        ),
      );
    }
  }

  Future<void> _openDirectMessage(BuildContext context, String userId) async {
    final serverId = ref.read(currentMembersServerIdProvider);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final channelId = await ref
          .read(memberListStoreProvider.notifier)
          .openDirectMessage(userId);
      if (!mounted) {
        return;
      }
      router.push('/servers/${serverId.value}/dms/$channelId');
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(failure.message ?? 'Failed to open direct message.'),
        ),
      );
    }
  }

  Future<void> _changeMemberRole(MemberProfile member, String role) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(memberListStoreProvider.notifier)
          .updateMemberRole(member.id, role);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${member.displayName} is now ${formatMemberRoleLabel(role)}.',
          ),
        ),
      );
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(failure.message ?? 'Failed to update member role.'),
        ),
      );
    }
  }

  Future<void> _removeMember(MemberProfile member) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Remove Member?'),
              content: Text('Remove ${member.displayName} from this server?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const ValueKey('members-confirm-remove'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Remove'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) {
      return;
    }

    try {
      await ref.read(memberListStoreProvider.notifier).removeMember(member.id);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('${member.displayName} removed.')),
      );
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(failure.message ?? 'Failed to remove member.')),
      );
    }
  }

  Future<String?> _promptInviteEmail() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setState) {
              final email = controller.text.trim();
              final isValid = email.isNotEmpty &&
                  email.contains('@') &&
                  !email.startsWith('@');
              return AlertDialog(
                title: const Text('Invite Human'),
                content: TextField(
                  key: const ValueKey('members-invite-email-field'),
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'user@example.com',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    key: const ValueKey('members-invite-email-submit'),
                    onPressed: isValid
                        ? () => Navigator.of(dialogContext).pop(email)
                        : null,
                    child: const Text('Send Invite'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  bool _canManageMembers(List<MemberProfile> members) {
    for (final member in members) {
      if (member.isSelf) {
        return member.role == 'owner' || member.role == 'admin';
      }
    }
    return false;
  }
}
