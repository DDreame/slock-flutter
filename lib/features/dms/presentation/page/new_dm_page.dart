import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/app_loading_indicator.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/members/application/member_list_state.dart';
import 'package:slock_app/features/members/application/member_list_store.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';

/// Full-page contact picker for starting a new direct message.
///
/// Shows a tabbed list of People and Agents with a search field.
/// Selecting a contact opens (or creates) a DM channel and pops
/// with the resulting channel ID.
class NewDmPage extends StatelessWidget {
  const NewDmPage({super.key, required this.serverId});

  final ServerScopeId serverId;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        currentMembersServerIdProvider.overrideWithValue(serverId),
      ],
      child: _NewDmPageContent(serverId: serverId),
    );
  }
}

class _NewDmPageContent extends ConsumerStatefulWidget {
  const _NewDmPageContent({required this.serverId});

  final ServerScopeId serverId;

  @override
  ConsumerState<_NewDmPageContent> createState() => _NewDmPageContentState();
}

class _NewDmPageContentState extends ConsumerState<_NewDmPageContent> {
  String? _openingId;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(memberListStoreProvider.notifier).ensureLoaded();
      ref.read(agentsStoreProvider.notifier).ensureLoaded();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // INV-NEW-DM-AGENTS-SELECT-1: Keep agents store alive while the page
    // is open. Only status is consumed for SWR triggering — mutations to
    // items, machines, activityLogs, isRefreshing, isCreating do not
    // rebuild this page.
    ref.watch(agentsStoreProvider.select((s) => s.status));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New message'),
          bottom: const TabBar(
            tabs: [
              Tab(
                key: ValueKey('new-dm-tab-people'),
                text: 'People',
              ),
              Tab(
                key: ValueKey('new-dm-tab-agents'),
                text: 'Agents',
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                key: const ValueKey('new-dm-search'),
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim()),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _PeopleTab(
                    searchQuery: _searchQuery,
                    openingId: _openingId,
                    onSelect: _openDirectMessage,
                  ),
                  _AgentsTab(
                    searchQuery: _searchQuery,
                    openingId: _openingId,
                    onSelect: _openAgentDirectMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDirectMessage(MemberProfile member) async {
    setState(() => _openingId = member.id);
    try {
      final channelId =
          await ref.read(memberRepositoryProvider).openDirectMessage(
                widget.serverId,
                userId: member.id,
              );
      if (!mounted) return;
      Navigator.of(context).pop(channelId);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _openingId = null);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(failure.message ?? 'Failed to open conversation.'),
          ),
        );
    }
  }

  Future<void> _openAgentDirectMessage(AgentItem agent) async {
    setState(() => _openingId = agent.id);
    try {
      final channelId =
          await ref.read(memberRepositoryProvider).openAgentDirectMessage(
                widget.serverId,
                agentId: agent.id,
              );
      if (!mounted) return;
      Navigator.of(context).pop(channelId);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _openingId = null);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(failure.message ?? 'Failed to open conversation.'),
          ),
        );
    }
  }
}

class _PeopleTab extends ConsumerWidget {
  const _PeopleTab({
    required this.searchQuery,
    required this.openingId,
    required this.onSelect,
  });

  final String searchQuery;
  final String? openingId;
  final void Function(MemberProfile) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(memberListStoreProvider);

    return switch (state.status) {
      MemberListStatus.initial ||
      MemberListStatus.loading =>
        const AppLoadingIndicator(),
      MemberListStatus.failure => _ErrorContent(
          message: state.failure?.message ?? 'Failed to load members.',
          onRetry: ref.read(memberListStoreProvider.notifier).load,
        ),
      MemberListStatus.success => _buildFilteredList(state),
    };
  }

  Widget _buildFilteredList(MemberListState state) {
    final nonSelfMembers = state.members.where((m) => !m.isSelf).toList();
    // Hoist toLowerCase() outside iteration to avoid per-item allocation.
    final lowerQuery = searchQuery.toLowerCase();
    final filtered = searchQuery.isEmpty
        ? nonSelfMembers
        : nonSelfMembers
            .where(
              (m) => m.displayName.toLowerCase().contains(lowerQuery),
            )
            .toList();

    return _MemberList(
      members: filtered,
      openingId: openingId,
      onSelect: onSelect,
    );
  }
}

class _AgentsTab extends ConsumerWidget {
  const _AgentsTab({
    required this.searchQuery,
    required this.openingId,
    required this.onSelect,
  });

  final String searchQuery;
  final String? openingId;
  final void Function(AgentItem) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // INV-NEW-DM-AGENTS-SELECT-1: Only rebuild for fields consumed by
    // the agent list — status, items, failure. Mutations to machines,
    // activityLogs, isRefreshing, isCreating do not trigger rebuilds.
    final (:status, :items, :failure) = ref.watch(
      agentsStoreProvider.select(
        (s) => (status: s.status, items: s.items, failure: s.failure),
      ),
    );

    return switch (status) {
      AgentsStatus.initial ||
      AgentsStatus.loading =>
        const AppLoadingIndicator(),
      AgentsStatus.failure => _ErrorContent(
          message: failure?.message ?? 'Failed to load agents.',
          onRetry: () async => ref.read(agentsStoreProvider.notifier).retry(),
        ),
      AgentsStatus.success => _buildFilteredList(items),
    };
  }

  Widget _buildFilteredList(List<AgentItem> items) {
    // Hoist toLowerCase() outside iteration to avoid per-item allocation.
    final lowerQuery = searchQuery.toLowerCase();
    final filtered = searchQuery.isEmpty
        ? items
        : items
            .where(
              (a) =>
                  a.label.toLowerCase().contains(lowerQuery) ||
                  a.name.toLowerCase().contains(lowerQuery),
            )
            .toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No agents found.'));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final agent = filtered[index];
        final isOpening = openingId == agent.id;
        return ListTile(
          key: ValueKey('dm-agent-${agent.id}'),
          leading: CircleAvatar(
            backgroundImage: agent.avatarUrl != null
                ? CachedNetworkImageProvider(
                    agent.avatarUrl!,
                    maxWidth: 200,
                    maxHeight: 200,
                  )
                : null,
            child: agent.avatarUrl == null
                ? const Icon(Icons.smart_toy_outlined)
                : null,
          ),
          title: Text(agent.label),
          subtitle: Text(agent.model),
          trailing: isOpening
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          enabled: openingId == null,
          onTap: () => onSelect(agent),
        );
      },
    );
  }
}

class _MemberList extends StatelessWidget {
  const _MemberList({
    required this.members,
    required this.openingId,
    required this.onSelect,
  });

  final List<MemberProfile> members;
  final String? openingId;
  final void Function(MemberProfile) onSelect;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const Center(child: Text('No members found.'));
    }
    final colors = Theme.of(context).extension<AppColors>();
    return ListView.builder(
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        final isOpening = openingId == member.id;
        return ListTile(
          key: ValueKey('dm-member-${member.id}'),
          leading: CircleAvatar(
            backgroundImage: member.avatarUrl != null
                ? CachedNetworkImageProvider(
                    member.avatarUrl!,
                    maxWidth: 200,
                    maxHeight: 200,
                  )
                : null,
            child: member.avatarUrl == null
                ? Text(
                    member.displayName.characters.first.toUpperCase(),
                    style: AppTypography.label.copyWith(
                      color: colors?.text,
                    ),
                  )
                : null,
          ),
          title: Text(member.displayName),
          trailing: isOpening
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          enabled: openingId == null,
          onTap: () => onSelect(member),
        );
      },
    );
  }
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
