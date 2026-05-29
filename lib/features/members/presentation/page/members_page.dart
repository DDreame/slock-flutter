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
import 'package:slock_app/l10n/l10n.dart';

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
    // INV-MEMBERS-663-SELECT-1: Scaffold-level watch narrowed to status,
    // canManageMembers, isInvitingByEmail, and isEmpty. Member list content
    // changes (query, per-member mutation states) no longer rebuild the scaffold.
    final (:status, :canManageMembers, :isInvitingByEmail, :isEmpty) =
        ref.watch(
      memberListStoreProvider.select(
        (s) => (
          status: s.status,
          canManageMembers: s.canManageMembers,
          isInvitingByEmail: s.isInvitingByEmail,
          isEmpty: s.members.isEmpty,
        ),
      ),
    );
    final serverId = ref.read(currentMembersServerIdProvider);
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.membersTitle),
        actions: status == MemberListStatus.success && canManageMembers
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: isInvitingByEmail
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
                          tooltip: context.l10n.membersInviteHumanTooltip,
                        ),
                ),
              ]
            : null,
      ),
      body: switch (status) {
        MemberListStatus.initial || MemberListStatus.loading => const Center(
            key: ValueKey('members-loading'),
            child: CircularProgressIndicator(),
          ),
        MemberListStatus.failure => FriendlyErrorState(
            key: const ValueKey('members-error'),
            title: context.l10n.membersErrorTitle,
            message: context.l10n.membersErrorMessage,
            onRetry: ref.read(memberListStoreProvider.notifier).load,
            onShareDiagnostics: () => DiagnosticShareSheet.show(context),
          ),
        MemberListStatus.success when isEmpty => _EmptyState(
            key: const ValueKey('members-empty'),
            icon: Icons.group_outlined,
            message: context.l10n.membersEmptyMessage,
            colors: colors,
          ),
        // INV-MEMBERS-663-SELECT-2: Success body is a separate consumer leaf
        // that watches full memberListStoreProvider state independently.
        // This isolates member list/query/mutation rebuilds from the scaffold.
        MemberListStatus.success => _MembersBody(
            serverId: serverId,
            canManageMembers: canManageMembers,
          ),
      },
    );
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
                  context.l10n.membersInviteSent(email),
                ),
              ),
            );
          } on AppFailure catch (failure) {
            if (!mounted) return;
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  failure.userMessage(context.l10n),
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
                  failure.userMessage(context.l10n),
                ),
              ),
            );
            return null;
          }
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// INV-MEMBERS-663-SELECT-2: Body consumer leaf — watches full member list
// state (query, members, mutation flags) independently from the scaffold.
// ---------------------------------------------------------------------------

class _MembersBody extends ConsumerStatefulWidget {
  const _MembersBody({
    required this.serverId,
    required this.canManageMembers,
  });

  final ServerScopeId serverId;
  final bool canManageMembers;

  @override
  ConsumerState<_MembersBody> createState() => _MembersBodyState();
}

class _MembersBodyState extends ConsumerState<_MembersBody> {
  // Hoisted BorderRadius for search field (Scan #49).
  static final _kSearchBorderRadius =
      BorderRadius.circular(AppSpacing.radiusMd);

  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // #820 Item 2: .select() narrowing — only rebuild when status, members,
    // or query change. Mutation fields (isInvitingByEmail,
    // updatingRoleMemberIds, removingMemberIds) do not affect this subtree.
    final (:status, :members, :query) = ref.watch(
      memberListStoreProvider.select(
        (s) => (status: s.status, members: s.members, query: s.query),
      ),
    );
    final colors = Theme.of(context).extension<AppColors>()!;

    return _buildMemberList(
      MemberListState(status: status, members: members, query: query),
      colors,
    );
  }

  Widget _buildMemberList(MemberListState state, AppColors colors) {
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
              hintText: context.l10n.membersSearchHint,
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
                      tooltip: context.l10n.searchClearTooltip,
                      onPressed: () {
                        _searchController.clear();
                        ref.read(memberListStoreProvider.notifier).setQuery('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: colors.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: _kSearchBorderRadius,
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
                  message: context.l10n.membersSearchEmpty,
                  colors: colors,
                )
              : _buildMemberListView(
                  humans: humans,
                  agents: agents,
                  state: state,
                ),
        ),
      ],
    );
  }

  /// INV-MEMBERS-CACHE-1: ListView.builder for on-demand member tile
  /// construction. Section headers are interleaved as flat items.
  Widget _buildMemberListView({
    required List<MemberProfile> humans,
    required List<MemberProfile> agents,
    required MemberListState state,
  }) {
    final colors = Theme.of(context).extension<AppColors>()!;
    // Build flat item list: [humanHeader, ...humans, agentHeader, ...agents]
    final hasHumans = humans.isNotEmpty;
    final hasAgents = agents.isNotEmpty;
    final itemCount = (hasHumans ? 1 + humans.length : 0) +
        (hasAgents ? 1 + agents.length : 0);

    return ListView.builder(
      key: const ValueKey('members-list'),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        var offset = 0;
        if (hasHumans) {
          if (index == offset) {
            return _SectionHeader(
              key: const ValueKey('members-section-humans'),
              label: context.l10n.membersSectionHumans,
              count: humans.length,
              colors: colors,
            );
          }
          offset++;
          if (index < offset + humans.length) {
            return _buildMemberTile(
              humans[index - offset],
              state,
            );
          }
          offset += humans.length;
        }
        if (hasAgents) {
          if (index == offset) {
            return _SectionHeader(
              key: const ValueKey('members-section-agents'),
              label: context.l10n.membersSectionAgents,
              count: agents.length,
              colors: colors,
            );
          }
          offset++;
          if (index < offset + agents.length) {
            return _buildMemberTile(
              agents[index - offset],
              state,
            );
          }
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildMemberTile(
    MemberProfile member,
    MemberListState state,
  ) {
    return MemberListItem(
      member: member,
      isOpeningDirectMessage: state.isOpeningDirectMessage(member.id),
      isUpdatingRole: state.isUpdatingRole(member.id),
      isRemoving: state.isRemovingMember(member.id),
      canManageMember: widget.canManageMembers,
      onTap: () => showMemberProfileSheet(
        context: context,
        member: member,
      ),
      onMessage: () => _openDirectMessage(member.id, widget.serverId),
      onChangeRole: (role) => _changeMemberRole(member, role),
      onRemove: () => _removeMember(member),
    );
  }

  Future<void> _openDirectMessage(
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
            failure.userMessage(context.l10n),
          ),
        ),
      );
    } catch (_) {}
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
            context.l10n.membersRoleChanged(
              member.displayName,
              _localizedRoleLabel(newRole, context.l10n),
            ),
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
            failure.userMessage(context.l10n),
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _removeMember(MemberProfile member) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(context.l10n.membersRemoveTitle),
              content: Text(
                context.l10n.membersRemoveBody(member.displayName),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(context.l10n.membersCancel),
                ),
                FilledButton(
                  key: const ValueKey(
                    'members-confirm-remove',
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(context.l10n.membersRemove),
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
          content: Text(context.l10n.membersMemberRemoved(member.displayName)),
        ),
      );
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            failure.userMessage(context.l10n),
          ),
        ),
      );
    } catch (_) {}
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
  // Hoisted BorderRadius for invite sheet elements (Scan #49).
  static final _kPillBorderRadius =
      BorderRadius.circular(AppSpacing.radiusFull);
  static final _kLinkCardBorderRadius =
      BorderRadius.circular(AppSpacing.radiusMd);

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

  /// RFC 5322 simplified email regex — validates local@domain structure.
  static final _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );

  bool get _isValidEmail {
    final text = _emailController.text;
    if (text.contains('\n')) return false;
    final email = text.trim();
    if (email.isEmpty) return false;
    return _emailRegex.hasMatch(email);
  }

  /// Returns error text for inline TextField decoration, or null if valid/empty.
  String? get _emailErrorText {
    final email = _emailController.text.trim();
    if (email.isEmpty) return null;
    if (!_isValidEmail) return context.l10n.membersEmailValidationError;
    return null;
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
      SnackBar(
        content: Text(context.l10n.membersInviteCopied),
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
                  borderRadius: _kPillBorderRadius,
                ),
              ),
            ),
            Text(
              context.l10n.membersInviteTitle,
              style: AppTypography.headline.copyWith(
                color: colors.text,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // --- Email section ---
            Text(
              context.l10n.membersInviteEmailSection,
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
                    decoration: InputDecoration(
                      labelText: context.l10n.membersInviteEmailLabel,
                      hintText: context.l10n.membersInviteEmailHint,
                      errorText: _emailErrorText,
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
                      : Text(context.l10n.membersSend),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // --- Link section ---
            Text(
              context.l10n.membersInviteLinkSection,
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
                  borderRadius: _kLinkCardBorderRadius,
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
                      tooltip: context.l10n.membersInviteCopyLink,
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
                label: Text(context.l10n.membersGenerateLink),
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
      title: Text(context.l10n.membersChangeRole),
      content: RadioGroup<String>(
        groupValue: _selectedRole,
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedRole = value);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              key: const ValueKey(
                'members-role-option-admin',
              ),
              title: Text(context.l10n.membersRoleAdmin),
              subtitle: Text(
                context.l10n.membersRoleAdminSubtitle,
              ),
              value: 'admin',
            ),
            RadioListTile<String>(
              key: const ValueKey(
                'members-role-option-member',
              ),
              title: Text(context.l10n.membersRoleMember),
              subtitle: Text(
                context.l10n.membersRoleMemberSubtitle,
              ),
              value: 'member',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.membersCancel),
        ),
        FilledButton(
          key: const ValueKey(
            'members-change-role-confirm',
          ),
          onPressed: _selectedRole == widget.currentRole
              ? null
              : () => Navigator.of(context).pop(_selectedRole),
          child: Text(context.l10n.membersConfirm),
        ),
      ],
    );
  }
}

String _localizedRoleLabel(String role, AppLocalizations l10n) {
  return switch (role) {
    'owner' => l10n.membersRoleOwner,
    'admin' => l10n.membersRoleAdmin,
    'member' => l10n.membersRoleMember,
    _ => role,
  };
}
