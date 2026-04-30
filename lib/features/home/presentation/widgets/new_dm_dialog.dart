import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/members/application/member_list_state.dart';
import 'package:slock_app/features/members/application/member_list_store.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';

class NewDmDialog extends StatelessWidget {
  const NewDmDialog({super.key, required this.serverId});

  final ServerScopeId serverId;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        currentMembersServerIdProvider.overrideWithValue(serverId),
      ],
      child: _NewDmDialogContent(serverId: serverId),
    );
  }
}

class _NewDmDialogContent extends ConsumerStatefulWidget {
  const _NewDmDialogContent({required this.serverId});

  final ServerScopeId serverId;

  @override
  ConsumerState<_NewDmDialogContent> createState() =>
      _NewDmDialogContentState();
}

class _NewDmDialogContentState extends ConsumerState<_NewDmDialogContent> {
  String? _openingId;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(memberListStoreProvider.notifier).ensureLoaded();
      ref.read(agentsStoreProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AlertDialog(
        key: const ValueKey('new-dm-dialog'),
        title: const Text('New message'),
        content: SizedBox(
          width: double.maxFinite,
          height: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TabBar(
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
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('new-dm-search'),
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim()),
              ),
              const SizedBox(height: 8),
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
        actions: [
          TextButton(
            onPressed:
                _openingId != null ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
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
        const Center(child: CircularProgressIndicator()),
      MemberListStatus.failure => _ErrorContent(
          message: state.failure?.message ?? 'Failed to load members.',
          onRetry: ref.read(memberListStoreProvider.notifier).load,
        ),
      MemberListStatus.success => _buildFilteredList(state),
    };
  }

  Widget _buildFilteredList(MemberListState state) {
    final nonSelfMembers = state.members.where((m) => !m.isSelf).toList();
    final filtered = searchQuery.isEmpty
        ? nonSelfMembers
        : nonSelfMembers
            .where(
              (m) => m.displayName
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase()),
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
    final state = ref.watch(agentsStoreProvider);

    return switch (state.status) {
      AgentsStatus.initial ||
      AgentsStatus.loading =>
        const Center(child: CircularProgressIndicator()),
      AgentsStatus.failure => _ErrorContent(
          message: state.failure?.message ?? 'Failed to load agents.',
          onRetry: ref.read(agentsStoreProvider.notifier).retry,
        ),
      AgentsStatus.success => _buildFilteredList(state),
    };
  }

  Widget _buildFilteredList(AgentsState state) {
    final filtered = searchQuery.isEmpty
        ? state.items
        : state.items
            .where(
              (a) =>
                  a.label.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  a.name.toLowerCase().contains(searchQuery.toLowerCase()),
            )
            .toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No agents found.'));
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final agent = filtered[index];
        final isOpening = openingId == agent.id;
        return ListTile(
          key: ValueKey('dm-agent-${agent.id}'),
          leading: CircleAvatar(
            backgroundImage:
                agent.avatarUrl != null ? NetworkImage(agent.avatarUrl!) : null,
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
    return ListView.builder(
      shrinkWrap: true,
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        final isOpening = openingId == member.id;
        return ListTile(
          key: ValueKey('dm-member-${member.id}'),
          leading: CircleAvatar(
            backgroundImage: member.avatarUrl != null
                ? NetworkImage(member.avatarUrl!)
                : null,
            child: member.avatarUrl == null
                ? Text(member.displayName.characters.first.toUpperCase())
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
