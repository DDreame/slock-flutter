import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/data/channel_member_repository_provider.dart';
import 'package:slock_app/features/members/application/member_list_state.dart';
import 'package:slock_app/features/members/application/member_list_store.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';

class AddMemberDialog extends StatelessWidget {
  final String serverId;
  final String channelId;
  final List<ChannelMember> existingMembers;

  const AddMemberDialog({
    super.key,
    required this.serverId,
    required this.channelId,
    required this.existingMembers,
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        currentMembersServerIdProvider
            .overrideWithValue(ServerScopeId(serverId)),
      ],
      child: _AddMemberDialogBody(
        serverId: serverId,
        channelId: channelId,
        existingMembers: existingMembers,
      ),
    );
  }
}

class _AddMemberDialogBody extends ConsumerStatefulWidget {
  final String serverId;
  final String channelId;
  final List<ChannelMember> existingMembers;

  const _AddMemberDialogBody({
    required this.serverId,
    required this.channelId,
    required this.existingMembers,
  });

  @override
  ConsumerState<_AddMemberDialogBody> createState() =>
      _AddMemberDialogBodyState();
}

class _AddMemberDialogBodyState extends ConsumerState<_AddMemberDialogBody> {
  bool _added = false;
  final Set<String> _addingIds = {};
  late final Set<String> _existingUserIds;
  late final Set<String> _existingAgentIds;

  @override
  void initState() {
    super.initState();
    _existingUserIds = widget.existingMembers
        .where((m) => m.isHuman)
        .map((m) => m.userId!)
        .toSet();
    _existingAgentIds = widget.existingMembers
        .where((m) => m.isAgent)
        .map((m) => m.agentId!)
        .toSet();
    Future.microtask(() {
      ref.read(memberListStoreProvider.notifier).ensureLoaded();
      ref.read(agentsStoreProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AlertDialog(
        title: const Text('Add Member'),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Humans'),
                  Tab(text: 'Agents'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildHumansList(),
                    _buildAgentsList(),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_added),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHumansList() {
    final memberState = ref.watch(memberListStoreProvider);
    if (memberState.status == MemberListStatus.initial ||
        memberState.status == MemberListStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (memberState.status == MemberListStatus.failure) {
      return Center(
        child: Text(
          memberState.failure?.message ?? 'Failed to load members.',
        ),
      );
    }
    final candidates = memberState.members
        .where((m) => !_existingUserIds.contains(m.id))
        .toList();
    if (candidates.isEmpty) {
      return const Center(child: Text('No more humans to add.'));
    }
    return ListView.builder(
      itemCount: candidates.length,
      itemBuilder: (context, index) {
        final human = candidates[index];
        return _HumanCandidateTile(
          member: human,
          isAdding: _addingIds.contains(human.id),
          onAdd: () => _addHuman(human),
        );
      },
    );
  }

  Widget _buildAgentsList() {
    final agentsState = ref.watch(agentsStoreProvider);
    if (agentsState.status == AgentsStatus.initial ||
        agentsState.status == AgentsStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (agentsState.status == AgentsStatus.failure) {
      return Center(
        child: Text(
          agentsState.failure?.message ?? 'Failed to load agents.',
        ),
      );
    }
    final candidates = agentsState.items
        .where((a) => !_existingAgentIds.contains(a.id))
        .toList();
    if (candidates.isEmpty) {
      return const Center(child: Text('No more agents to add.'));
    }
    return ListView.builder(
      itemCount: candidates.length,
      itemBuilder: (context, index) {
        final agent = candidates[index];
        return _AgentCandidateTile(
          agent: agent,
          isAdding: _addingIds.contains(agent.id),
          onAdd: () => _addAgent(agent),
        );
      },
    );
  }

  Future<void> _addHuman(MemberProfile human) async {
    setState(() => _addingIds.add(human.id));
    try {
      final repo = ref.read(channelMemberRepositoryProvider);
      await repo.addHumanMember(
        ServerScopeId(widget.serverId),
        channelId: widget.channelId,
        userId: human.id,
      );
      _added = true;
      if (mounted) {
        setState(() {
          _addingIds.remove(human.id);
          _existingUserIds.add(human.id);
        });
      }
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _addingIds.remove(human.id));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(failure.message ?? 'Failed to add member.')),
        );
    }
  }

  Future<void> _addAgent(AgentItem agent) async {
    setState(() => _addingIds.add(agent.id));
    try {
      final repo = ref.read(channelMemberRepositoryProvider);
      await repo.addAgentMember(
        ServerScopeId(widget.serverId),
        channelId: widget.channelId,
        agentId: agent.id,
      );
      _added = true;
      if (mounted) {
        setState(() {
          _addingIds.remove(agent.id);
          _existingAgentIds.add(agent.id);
        });
      }
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _addingIds.remove(agent.id));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(failure.message ?? 'Failed to add agent.')),
        );
    }
  }
}

class _HumanCandidateTile extends StatelessWidget {
  final MemberProfile member;
  final bool isAdding;
  final VoidCallback onAdd;

  const _HumanCandidateTile({
    required this.member,
    required this.isAdding,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
        child: member.avatarUrl == null ? const Icon(Icons.person) : null,
      ),
      title: Text(member.displayName),
      trailing: isAdding
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: onAdd,
            ),
    );
  }
}

class _AgentCandidateTile extends StatelessWidget {
  final AgentItem agent;
  final bool isAdding;
  final VoidCallback onAdd;

  const _AgentCandidateTile({
    required this.agent,
    required this.isAdding,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            agent.avatarUrl != null ? NetworkImage(agent.avatarUrl!) : null,
        child: agent.avatarUrl == null ? const Icon(Icons.smart_toy) : null,
      ),
      title: Text(agent.label),
      trailing: isAdding
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: onAdd,
            ),
    );
  }
}
