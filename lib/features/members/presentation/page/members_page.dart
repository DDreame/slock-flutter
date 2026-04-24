import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/members/application/member_list_state.dart';
import 'package:slock_app/features/members/application/member_list_store.dart';
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
                  child: state.isCreatingInvite
                      ? const Center(
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          key: const ValueKey('members-create-invite'),
                          onPressed: _createInvite,
                          icon: const Icon(Icons.person_add_alt_1),
                          tooltip: 'Create invite',
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
                onTap: () => context
                    .go('/servers/${serverId.value}/profile/${member.id}'),
                onMessage: () => _openDirectMessage(context, member.id),
                onChangeRole: (role) => _changeMemberRole(member, role),
                onRemove: () => _removeMember(member),
              );
            },
          ),
      },
    );
  }

  Future<void> _createInvite() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final inviteCode =
          await ref.read(memberListStoreProvider.notifier).createInvite();
      if (!mounted) {
        return;
      }
      await _showInviteDialog(inviteCode);
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(failure.message ?? 'Failed to create invite.')),
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
      router.go('/servers/${serverId.value}/dms/$channelId');
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

  Future<void> _showInviteDialog(String inviteCode) async {
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Invite Created'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Copy this invite code or link and share it.'),
              const SizedBox(height: 16),
              SelectableText(
                inviteCode,
                key: const ValueKey('members-invite-code'),
              ),
            ],
          ),
          actions: [
            TextButton(
              key: const ValueKey('members-copy-invite'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: inviteCode));
                if (!context.mounted) {
                  return;
                }
                messenger.showSnackBar(
                  const SnackBar(content: Text('Invite copied.')),
                );
              },
              child: const Text('Copy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  bool _canManageMembers(List<MemberProfile> members) {
    for (final member in members) {
      if (member.isSelf) {
        return member.role == 'admin';
      }
    }
    return false;
  }
}
