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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
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
          ),
      },
    );
  }

  Widget _buildMemberList(
    MemberListState state,
    ServerScopeId serverId,
    AppColors colors,
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
  ) {
    return MemberListItem(
      member: member,
      isOpeningDirectMessage: state.isOpeningDirectMessage(member.id),
      canManageMember: false,
      onTap: () => showMemberProfileSheet(
        context: context,
        member: member,
      ),
      onMessage: () => _openDirectMessage(context, member.id, serverId),
      onChangeRole: (_) {},
      onRemove: () {},
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
