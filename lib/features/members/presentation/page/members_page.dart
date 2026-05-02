import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                          key: const ValueKey(
                            'members-invite-human',
                          ),
                          onPressed: _inviteHuman,
                          icon: const Icon(
                            Icons.person_add_alt_1,
                          ),
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

  Future<void> _inviteHuman() async {
    final messenger = ScaffoldMessenger.of(context);
    final store = ref.read(memberListStoreProvider.notifier);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InviteHumanSheet(
        onSendEmail: (email) async {
          try {
            await store.inviteByEmail(email);
            if (!mounted) return;
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Invite email sent to $email.',
                ),
              ),
            );
          } on AppFailure catch (failure) {
            if (!mounted) return;
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  failure.message ?? 'Failed to send invite email.',
                ),
              ),
            );
          }
        },
        onGenerateLink: () async {
          try {
            return await store.createInvite();
          } on AppFailure catch (failure) {
            if (!mounted) return null;
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  failure.message ?? 'Failed to generate invite link.',
                ),
              ),
            );
            return null;
          }
        },
      ),
    );
  }

  Future<void> _changeMemberRole(
    MemberProfile member,
    String suggestedRole,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final newRole = await showDialog<String>(
      context: context,
      builder: (_) => _ChangeRoleDialog(
        currentRole: member.role ?? 'member',
      ),
    );
    if (newRole == null) return;

    try {
      await ref
          .read(memberListStoreProvider.notifier)
          .updateMemberRole(member.id, newRole);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${member.displayName} is now'
            ' ${formatMemberRoleLabel(newRole)}.',
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
                'Remove ${member.displayName}'
                ' from this server?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const ValueKey(
                    'members-confirm-remove',
                  ),
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

// --- Invite bottom sheet ---

class _InviteHumanSheet extends StatefulWidget {
  const _InviteHumanSheet({
    required this.onSendEmail,
    required this.onGenerateLink,
  });

  final Future<void> Function(String email) onSendEmail;
  final Future<String?> Function() onGenerateLink;

  @override
  State<_InviteHumanSheet> createState() => _InviteHumanSheetState();
}

class _InviteHumanSheetState extends State<_InviteHumanSheet> {
  late final TextEditingController _emailController;
  bool _isSendingEmail = false;
  bool _isGeneratingLink = false;
  String? _inviteLink;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool get _isValidEmail {
    final email = _emailController.text.trim();
    return email.isNotEmpty && email.contains('@') && !email.startsWith('@');
  }

  Future<void> _sendEmail() async {
    final email = _emailController.text.trim();
    setState(() => _isSendingEmail = true);
    await widget.onSendEmail(email);
    if (!mounted) return;
    setState(() => _isSendingEmail = false);
    Navigator.of(context).pop();
  }

  Future<void> _generateLink() async {
    setState(() => _isGeneratingLink = true);
    final link = await widget.onGenerateLink();
    if (!mounted) return;
    setState(() {
      _isGeneratingLink = false;
      _inviteLink = link;
    });
  }

  Future<void> _copyLink() async {
    if (_inviteLink == null) return;
    await Clipboard.setData(
      ClipboardData(text: _inviteLink!),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite link copied.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
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
            ),
            Text(
              'Invite Human',
              style: AppTypography.headline.copyWith(
                color: colors.text,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // --- Email section ---
            Text(
              'Send email invite',
              style: AppTypography.title.copyWith(
                color: colors.text,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey(
                      'members-invite-email-field',
                    ),
                    controller: _emailController,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'user@example.com',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  key: const ValueKey(
                    'members-invite-email-submit',
                  ),
                  onPressed:
                      _isValidEmail && !_isSendingEmail ? _sendEmail : null,
                  child: _isSendingEmail
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Send'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // --- Link section ---
            Text(
              'Or share invite link',
              style: AppTypography.title.copyWith(
                color: colors.text,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_inviteLink != null) ...[
              Container(
                padding: const EdgeInsets.all(
                  AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(
                    AppSpacing.radiusMd,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _inviteLink!,
                        key: const ValueKey(
                          'members-invite-link-text',
                        ),
                        style: AppTypography.body.copyWith(
                          color: colors.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey(
                        'members-invite-link-copy',
                      ),
                      icon: const Icon(Icons.copy),
                      onPressed: _copyLink,
                      tooltip: 'Copy link',
                    ),
                  ],
                ),
              ),
            ] else
              FilledButton.icon(
                key: const ValueKey(
                  'members-invite-generate-link',
                ),
                onPressed: _isGeneratingLink ? null : _generateLink,
                icon: _isGeneratingLink
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.link),
                label: const Text('Generate Link'),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

// --- Change role dialog ---

class _ChangeRoleDialog extends StatefulWidget {
  const _ChangeRoleDialog({
    required this.currentRole,
  });

  final String currentRole;

  @override
  State<_ChangeRoleDialog> createState() => _ChangeRoleDialogState();
}

class _ChangeRoleDialogState extends State<_ChangeRoleDialog> {
  late String _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.currentRole;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('members-change-role-dialog'),
      title: const Text('Change Role'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<String>(
            key: const ValueKey(
              'members-role-option-admin',
            ),
            title: const Text('Admin'),
            subtitle: const Text(
              'Can manage members and invite',
            ),
            value: 'admin',
            groupValue: _selectedRole,
            onChanged: (value) => setState(() => _selectedRole = value!),
          ),
          RadioListTile<String>(
            key: const ValueKey(
              'members-role-option-member',
            ),
            title: const Text('Member'),
            subtitle: const Text('Standard workspace access'),
            value: 'member',
            groupValue: _selectedRole,
            onChanged: (value) => setState(() => _selectedRole = value!),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey(
            'members-change-role-confirm',
          ),
          onPressed: _selectedRole == widget.currentRole
              ? null
              : () => Navigator.of(context).pop(_selectedRole),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
