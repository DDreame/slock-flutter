import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/friendly_error_state.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/members/application/member_list_state.dart';
import 'package:slock_app/features/members/application/member_list_store.dart';
import 'package:slock_app/features/members/application/members_realtime_binding.dart';
import 'package:slock_app/features/members/presentation/widgets/member_list_item.dart';
import 'package:slock_app/features/members/presentation/widgets/member_profile_sheet.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';

class MembersPage extends StatelessWidget {
  MembersPage({super.key, required String serverId})
      : _serverId = ServerScopeId(serverId);

  final ServerScopeId _serverId;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        currentMembersServerIdProvider.overrideWithValue(_serverId),
      ],
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
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    Future.microtask(
      () => ref.read(memberListStoreProvider.notifier).ensureLoaded(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(membersRealtimeBindingProvider);
    final state = ref.watch(memberListStoreProvider);
    final serverId = ref.read(currentMembersServerIdProvider);
    final colors = Theme.of(context).extension<AppColors>()!;
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
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
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
        MemberListStatus.success when state.members.isEmpty => _EmptyState(
            key: const ValueKey('members-empty'),
            icon: Icons.group_outlined,
            message: 'No members yet.',
            colors: colors,
          ),
        MemberListStatus.success => _buildMemberList(
            state,
            serverId,
            colors,
            canManageMembers,
          ),
      },
    );
  }

  Widget _buildMemberList(
    MemberListState state,
    ServerScopeId serverId,
    AppColors colors,
    bool canManageMembers,
  ) {
    final humans = state.humans;
    final agents = state.agents;
    final hasQuery = state.query.isNotEmpty;
    final allEmpty = humans.isEmpty && agents.isEmpty;

    return Column(
      children: [
        // --- Search bar ---
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal,
            vertical: AppSpacing.sm,
          ),
          child: TextField(
            key: const ValueKey('members-search'),
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search members…',
              prefixIcon: Icon(
                Icons.search,
                color: colors.textTertiary,
              ),
              suffixIcon: hasQuery
                  ? IconButton(
                      key: const ValueKey('members-search-clear'),
                      icon: Icon(
                        Icons.close,
                        color: colors.textTertiary,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(memberListStoreProvider.notifier).setQuery('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: colors.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md,
              ),
            ),
            onChanged: (value) =>
                ref.read(memberListStoreProvider.notifier).setQuery(value),
          ),
        ),

        // --- List content ---
        Expanded(
          child: allEmpty && hasQuery
              ? _EmptyState(
                  key: const ValueKey('members-search-empty'),
                  icon: Icons.search_off,
                  message: 'No members match your search.',
                  colors: colors,
                )
              : ListView(
                  key: const ValueKey('members-list'),
                  children: [
                    if (humans.isNotEmpty) ...[
                      _SectionHeader(
                        key: const ValueKey(
                          'members-section-humans',
                        ),
                        label: 'Humans',
                        count: humans.length,
                        colors: colors,
                      ),
                      for (final member in humans)
                        _buildMemberTile(
                          member,
                          serverId,
                          state,
                          canManageMembers,
                        ),
                    ],
                    if (agents.isNotEmpty) ...[
                      _SectionHeader(
                        key: const ValueKey(
                          'members-section-agents',
                        ),
                        label: 'Agents',
                        count: agents.length,
                        colors: colors,
                      ),
                      for (final member in agents)
                        _buildMemberTile(
                          member,
                          serverId,
                          state,
                          canManageMembers,
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildMemberTile(
    MemberProfile member,
    ServerScopeId serverId,
    MemberListState state,
    bool canManageMembers,
  ) {
    return MemberListItem(
      member: member,
      isOpeningDirectMessage: state.isOpeningDirectMessage(member.id),
      isUpdatingRole: state.isUpdatingRole(member.id),
      isRemoving: state.isRemovingMember(member.id),
      canManageMember: canManageMembers,
      onTap: () => showMemberProfileSheet(
        context: context,
        member: member,
      ),
      onMessage: () => _openDirectMessage(context, member.id, serverId),
      onChangeRole: (role) => _changeMemberRole(member, role),
      onRemove: () => _removeMember(member),
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
          content: Text(
            failure.message ?? 'Failed to send invite email.',
          ),
        ),
      );
    }
  }

  Future<void> _openDirectMessage(
    BuildContext context,
    String userId,
    ServerScopeId serverId,
  ) async {
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
          content: Text(
            failure.message ?? 'Failed to open direct message.',
          ),
        ),
      );
    }
  }

  Future<void> _changeMemberRole(
    MemberProfile member,
    String role,
  ) async {
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
            '${member.displayName} is now'
            ' ${formatMemberRoleLabel(role)}.',
          ),
        ),
      );
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            failure.message ?? 'Failed to update member role.',
          ),
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
              content: Text(
                'Remove ${member.displayName} from this server?',
              ),
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
        SnackBar(
          content: Text('${member.displayName} removed.'),
        ),
      );
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            failure.message ?? 'Failed to remove member.',
          ),
        ),
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

// --- Section header ---

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    super.key,
    required this.label,
    required this.count,
    required this.colors,
  });

  final String label;
  final int count;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.lg,
        AppSpacing.pageHorizontal,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Text(
            label,
            style: AppTypography.title.copyWith(
              color: colors.text,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$count',
            style: AppTypography.caption.copyWith(
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Styled empty state ---

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    super.key,
    required this.icon,
    required this.message,
    required this.colors,
  });

  final IconData icon;
  final String message;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colors.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: AppTypography.body.copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// --- Invite dialog ---

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
