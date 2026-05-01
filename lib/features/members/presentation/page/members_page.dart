import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/widgets/friendly_error_state.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/core/telemetry/diagnostic_share_sheet.dart';
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
        MemberListStatus.failure => FriendlyErrorState(
            key: const ValueKey('members-error'),
            title: 'Members unavailable',
            message: 'We could not load workspace members right now.',
            onRetry: ref.read(memberListStoreProvider.notifier).load,
            onShareDiagnostics: () => DiagnosticShareSheet.show(context),
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
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return const _InviteHumanDialog();
      },
    );
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

class _InviteHumanDialog extends StatefulWidget {
  const _InviteHumanDialog();

  @override
  State<_InviteHumanDialog> createState() => _InviteHumanDialogState();
}

class _InviteHumanDialogState extends State<_InviteHumanDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = _controller.text.trim();
    final isValid =
        email.isNotEmpty && email.contains('@') && !email.startsWith('@');
    return AlertDialog(
      title: const Text('Invite Human'),
      content: TextField(
        key: const ValueKey('members-invite-email-field'),
        controller: _controller,
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('members-invite-email-submit'),
          onPressed: isValid ? () => Navigator.of(context).pop(email) : null,
          child: const Text('Send Invite'),
        ),
      ],
    );
  }
}
