import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/skeleton_list_item.dart';
import 'package:slock_app/app/widgets/swipe_to_mark_read.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/dms/presentation/page/new_dm_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/dm_sort_preference.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/persisted_agent_names.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/presentation/widgets/home_direct_message_row.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/features/unread/application/mark_read_use_case.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';

/// Narrowed select projection for DmsTabPage — only fields consumed by build().
typedef _DmsTabProjection = ({
  HomeListStatus status,
  AppFailure? failure,
  List<HomeDirectMessageSummary> directMessages,
  List<HomeDirectMessageSummary> pinnedDirectMessages,
  List<HomeDirectMessageSummary> hiddenDirectMessages,
});

/// INV-DMS-AGENT-SET-CACHE-1: Narrowed select for agent name sets.
/// Separated from _DmsTabProjection so DM data changes (directMessages,
/// unread counts) do NOT trigger agent set re-derivation.
typedef _DmsAgentProjection = ({
  List<AgentItem> agents,
  List<AgentItem> pinnedAgents,
});

/// DMs tab — extracts the DM list from [HomePage].
///
/// Reuses [HomeListStore] for data and [HomeDirectMessageRow] for rendering.
/// Adds unread-first sorting, local search filtering, online-status dots,
/// hidden-DM management, and a "new message" action.
class DmsTabPage extends ConsumerStatefulWidget {
  const DmsTabPage({super.key});

  @override
  ConsumerState<DmsTabPage> createState() => _DmsTabPageState();
}

class _DmsTabPageState extends ConsumerState<DmsTabPage> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      homeListStoreProvider.select(
        (s) => (
          status: s.status,
          failure: s.failure,
          directMessages: s.directMessages,
          pinnedDirectMessages: s.pinnedDirectMessages,
          hiddenDirectMessages: s.hiddenDirectMessages,
        ),
      ),
    );
    // INV-DMS-AGENT-SET-CACHE-1: Separate narrow select for agent data.
    // DM list changes (directMessages, unread) do NOT trigger agent name
    // set re-derivation.
    final agentData = ref.watch(
      homeListStoreProvider.select(
        (s) => (agents: s.agents, pinnedAgents: s.pinnedAgents),
      ),
    );
    // INV-NET-DEGRADE-2: surface refresh failure via snackbar only when a
    // refresh completes with failure — not on mutation errors.
    ref.listen(
      homeListStoreProvider.select((s) => s.isRefreshing),
      (prev, next) {
        if (prev == true && next == false) {
          final s = ref.read(homeListStoreProvider);
          if (s.failure != null && s.status == HomeListStatus.success) {
            _showRefreshFailedSnackBar();
          }
        }
      },
    );
    final homeStore = ref.read(homeListStoreProvider.notifier);
    // INV-TAB-UNREAD-SELECT-2: Only consume dmUnreadCounts — channel unread
    // changes must NOT rebuild the DMs tab.
    final dmUnreadCounts = ref.watch(
      unreadSourceProjectionProvider.select((s) => s.dmUnreadCounts),
    );
    final dmUnreadTotal = dmUnreadCounts.values.fold(0, (sum, c) => sum + c);
    final sortPreference = ref.watch(dmSortPreferenceProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dmsTabTitle),
        actions: [
          IconButton(
            key: const ValueKey('dms-sort-toggle'),
            icon: Icon(
              sortPreference == DmSortPreference.recentActivity
                  ? Icons.sort_by_alpha
                  : Icons.access_time,
            ),
            tooltip: sortPreference == DmSortPreference.recentActivity
                ? 'Sort A-Z'
                : 'Sort by recent',
            onPressed: () {
              final notifier = ref.read(dmSortPreferenceProvider.notifier);
              notifier.setSortPreference(
                sortPreference == DmSortPreference.recentActivity
                    ? DmSortPreference.alphabetical
                    : DmSortPreference.recentActivity,
              );
            },
          ),
          if (state.status == HomeListStatus.success && dmUnreadTotal > 0)
            IconButton(
              key: const ValueKey('dms-tab-mark-all-read'),
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all read',
              onPressed: () {
                ref.read(inboxStoreProvider.notifier).markAllRead();
              },
            ),
          IconButton(
            key: const ValueKey('dms-tab-create-button'),
            icon: const Icon(Icons.add),
            tooltip: l10n.homeNewMessageTooltip,
            onPressed: _showNewDmDialog,
          ),
        ],
      ),
      body: switch (state.status) {
        HomeListStatus.noActiveServer => _DmsNoServerState(
            message: l10n.dmsTabEmpty,
          ),
        HomeListStatus.initial || HomeListStatus.loading => ListView(
            key: const ValueKey('dms-skeleton'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontal,
              vertical: AppSpacing.sm,
            ),
            children: const [
              SkeletonListItem(key: ValueKey('dms-skeleton-item-0')),
              SkeletonListItem(key: ValueKey('dms-skeleton-item-1')),
              SkeletonListItem(key: ValueKey('dms-skeleton-item-2')),
              SkeletonListItem(key: ValueKey('dms-skeleton-item-3')),
              SkeletonListItem(key: ValueKey('dms-skeleton-item-4')),
            ],
          ),
        HomeListStatus.failure => _DmsErrorState(
            message: state.failure?.message ?? l10n.homeLoadFailedFallback,
            onRetry: homeStore.retry,
          ),
        HomeListStatus.success => RefreshIndicator(
            key: const ValueKey('dms-tab-refresh'),
            onRefresh: homeStore.load,
            child: _buildDmList(
              state: state,
              agentData: agentData,
              homeStore: homeStore,
              dmUnreadCounts: dmUnreadCounts,
              l10n: l10n,
            ),
          ),
      },
    );
  }

  Widget _buildDmList({
    required _DmsTabProjection state,
    required _DmsAgentProjection agentData,
    required HomeListStore homeStore,
    required Map<DirectMessageScopeId, int> dmUnreadCounts,
    required AppLocalizations l10n,
  }) {
    final colors = Theme.of(context).extension<AppColors>()!;

    // INV-DMS-AGENT-SET-CACHE-1: Agent name sets derived from the separate
    // agentData select. When DM data changes but agents don't, the select
    // returns the cached value and these sets use identical input.
    final onlineAgentNames = <String>{
      for (final agent in agentData.agents)
        if (agent.isActive) agent.label,
      for (final agent in agentData.pinnedAgents)
        if (agent.isActive) agent.label,
    };

    // Build all-agent name lookup for AGENT badge.
    // Combines live agents from state with persisted agent names (from
    // SharedPreferences) so the badge survives cached/offline loads even
    // when the agents API call hasn't completed or failed.
    final persistedNames = ref.watch(persistedAgentNamesProvider);
    final allAgentNames = <String>{
      for (final agent in agentData.agents) agent.label,
      for (final agent in agentData.pinnedAgents) agent.label,
      ...persistedNames,
    };

    // Combine pinned + unpinned DMs.
    final allDms = [
      ...state.pinnedDirectMessages,
      ...state.directMessages,
    ];

    // Apply search filter.
    final filtered = _searchQuery.isEmpty
        ? allDms
        : () {
            final queryLower = _searchQuery.toLowerCase();
            return allDms
                .where((dm) => dm.title.toLowerCase().contains(queryLower))
                .toList();
          }();

    // INV-TAB-SORT-CACHE-2: Inline sort instead of Provider.family.
    // Provider.family with List arg never caches (reference equality),
    // causing unconditional re-sort and stale provider slot accumulation.
    final sortPreference = ref.watch(dmSortPreferenceProvider);
    final sorted = List<HomeDirectMessageSummary>.of(filtered);
    switch (sortPreference) {
      case DmSortPreference.recentActivity:
        sorted.sort((a, b) {
          final aTime = a.lastActivityAt;
          final bTime = b.lastActivityAt;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });
      case DmSortPreference.alphabetical:
        sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
    }

    final pinnedIds =
        state.pinnedDirectMessages.map((dm) => dm.scopeId.value).toSet();

    if (sorted.isEmpty && _searchQuery.isEmpty) {
      return ListView(
        children: [
          _buildSearchField(l10n, colors),
          if (state.hiddenDirectMessages.isNotEmpty)
            _buildHiddenDmsTile(
              state: state,
              homeStore: homeStore,
              l10n: l10n,
            ),
          Padding(
            key: const ValueKey('dms-tab-empty'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontal,
              vertical: AppSpacing.lg,
            ),
            child: Center(
              child: Text(
                l10n.dmsTabEmpty,
                style: AppTypography.body.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      children: [
        _buildSearchField(l10n, colors),
        if (sorted.isEmpty && _searchQuery.isNotEmpty)
          Padding(
            key: const ValueKey('dms-tab-search-empty'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontal,
              vertical: AppSpacing.lg,
            ),
            child: Center(
              child: Text(
                l10n.dmsTabEmpty,
                style: AppTypography.body.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
        for (final dm in sorted)
          _buildDmRow(
            dm: dm,
            isPinned: pinnedIds.contains(dm.scopeId.value),
            isOnline: onlineAgentNames.contains(dm.title),
            isAgent: dm.isAgent || allAgentNames.contains(dm.title),
            homeStore: homeStore,
            dmUnreadCounts: dmUnreadCounts,
          ),
        if (state.hiddenDirectMessages.isNotEmpty && _searchQuery.isEmpty)
          _buildHiddenDmsTile(
            state: state,
            homeStore: homeStore,
            l10n: l10n,
          ),
      ],
    );
  }

  Widget _buildSearchField(AppLocalizations l10n, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
      ),
      child: TextField(
        key: const ValueKey('dms-tab-search'),
        controller: _searchController,
        decoration: InputDecoration(
          hintText: l10n.dmsTabSearchHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? Tooltip(
                  message: 'Clear search',
                  child: IconButton(
                    key: const ValueKey('search-clear-button'),
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  ),
                )
              : null,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildDmRow({
    required HomeDirectMessageSummary dm,
    required bool isPinned,
    required bool isOnline,
    required bool isAgent,
    required HomeListStore homeStore,
    required Map<DirectMessageScopeId, int> dmUnreadCounts,
  }) {
    final unreadCount = dmUnreadCounts[dm.scopeId] ?? 0;

    // Move actions are suppressed in this tab because the unread-first
    // merged view does not match the persisted sidebar order.
    return SwipeToMarkRead(
      itemKey: dm.scopeId.routeParam,
      enabled: unreadCount > 0,
      onMarkRead: () {
        ref.read(markDmReadUseCaseProvider)(dm.scopeId);
      },
      child: HomeDirectMessageRow(
        key: ValueKey('dms-tab-${dm.scopeId.routeParam}'),
        directMessage: dm,
        unreadCount: unreadCount,
        isPinned: isPinned,
        isOnline: isOnline,
        isAgent: isAgent,
        onTap: () {
          context.push(homeStore.directMessageRoutePath(dm.scopeId));
          // Deferred mark-read: brief delay before clearing unread
          // so the user sees the conversation before the count drops.
          Future.delayed(const Duration(seconds: 1), () {
            if (!mounted) return;
            ref.read(markDmReadUseCaseProvider)(dm.scopeId);
          });
        },
        onTogglePin: () => isPinned
            ? homeStore.unpinDirectMessage(dm.scopeId)
            : homeStore.pinDirectMessage(dm.scopeId),
        onHide: () => homeStore.hideDm(dm.scopeId),
      ),
    );
  }

  Widget _buildHiddenDmsTile({
    required _DmsTabProjection state,
    required HomeListStore homeStore,
    required AppLocalizations l10n,
  }) {
    return ListTile(
      key: const ValueKey('dms-tab-hidden'),
      leading: const Icon(Icons.visibility_off_outlined),
      title: Text(
        l10n.homeHiddenConversationsCount(
          state.hiddenDirectMessages.length,
        ),
      ),
      onTap: () => _showHiddenDmsSheet(homeStore),
    );
  }

  void _showHiddenDmsSheet(
    HomeListStore homeStore,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return Consumer(
          builder: (_, ref, __) {
            final hiddenDms = ref.watch(
              homeListStoreProvider.select((s) => s.hiddenDirectMessages),
            );
            if (hiddenDms.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop();
                }
              });
              return const SizedBox.shrink();
            }
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        context.l10n.homeHiddenConversationsTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final dm in hiddenDms)
                            ListTile(
                              key: ValueKey(
                                'hidden-dm-${dm.scopeId.routeParam}',
                              ),
                              leading: const Icon(Icons.person_outline),
                              title: Text(dm.title),
                              trailing: TextButton(
                                key: ValueKey(
                                  'unhide-dm-${dm.scopeId.routeParam}',
                                ),
                                onPressed: () => homeStore.unhideDm(dm.scopeId),
                                child: Text(context.l10n.homeUnhide),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showNewDmDialog() async {
    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) return;
    final pageContext = context;

    final channelId = await Navigator.of(pageContext).push<String>(
      MaterialPageRoute(
        builder: (_) => NewDmPage(serverId: serverId),
      ),
    );

    if (channelId != null && mounted && pageContext.mounted) {
      // Push instead of go to preserve the DMs tab in the back stack.
      // context.go() replaces the entire stack, making back exit the app.
      pageContext.push('/servers/${serverId.value}/dms/$channelId');
    }
  }

  void _showRefreshFailedSnackBar() {
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l10n.refreshFailedSnackbar),
        action: SnackBarAction(
          label: l10n.refreshFailedRetry,
          onPressed: () => ref.read(homeListStoreProvider.notifier).refresh(),
        ),
      ));
  }
}

class _DmsNoServerState extends StatelessWidget {
  const _DmsNoServerState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Center(
      child: Text(
        message,
        style: AppTypography.body.copyWith(
          color: colors.textSecondary,
        ),
      ),
    );
  }
}

class _DmsErrorState extends StatelessWidget {
  const _DmsErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: Text(l10n.homeRetry),
            ),
          ],
        ),
      ),
    );
  }
}
