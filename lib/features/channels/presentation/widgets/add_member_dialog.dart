import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/widgets/app_loading_indicator.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/application/channel_member_store.dart';
import 'package:slock_app/features/members/application/member_list_state.dart';
import 'package:slock_app/features/members/application/member_list_store.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/l10n/l10n.dart';

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
      ref.read(agentsStoreProvider.notifier).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AlertDialog(
        title: Text(context.l10n.channelsAddMemberTitle),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              TabBar(
                tabs: [
                  Tab(text: context.l10n.channelsAddMemberTabHumans),
                  Tab(text: context.l10n.channelsAddMemberTabAgents),
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
            child: Text(context.l10n.channelsAddMemberClose),
          ),
        ],
      ),
    );
  }

  Widget _buildHumansList() {
    // INV-SELECT-809: Only rebuild when status, failure, or members change.
    // isInvitingByEmail, updatingRoleMemberIds, etc. do not affect this list.
    final (:status, :failure, :members) = ref.watch(
      memberListStoreProvider.select(
        (s) => (status: s.status, failure: s.failure, members: s.members),
      ),
    );
    if (status == MemberListStatus.initial ||
        status == MemberListStatus.loading) {
      return const AppLoadingIndicator();
    }
    if (status == MemberListStatus.failure) {
      return Center(
        child: Text(
          failure?.userMessage(context.l10n) ?? context.l10n.errorUnknown,
        ),
      );
    }
    final candidates =
        members.where((m) => !_existingUserIds.contains(m.id)).toList();
    if (candidates.isEmpty) {
      return Center(child: Text(context.l10n.channelsAddMemberNoHumans));
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
    // INV-SELECT-809: Only rebuild when status, failure, or items change.
    // machines, activityLogs, isRefreshing, isCreating do not affect this list.
    final (:status, :failure, :items) = ref.watch(
      agentsStoreProvider.select(
        (s) => (status: s.status, failure: s.failure, items: s.items),
      ),
    );
    if (status == AgentsStatus.initial || status == AgentsStatus.loading) {
      return const AppLoadingIndicator();
    }
    if (status == AgentsStatus.failure) {
      return Center(
        child: Text(
          failure?.userMessage(context.l10n) ?? context.l10n.errorUnknown,
        ),
      );
    }
    final candidates =
        items.where((a) => !_existingAgentIds.contains(a.id)).toList();
    if (candidates.isEmpty) {
      return Center(child: Text(context.l10n.channelsAddMemberNoAgents));
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
      await ref.read(channelMemberStoreProvider.notifier).addHumanMember(
            human.id,
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
          SnackBar(content: Text(failure.userMessage(context.l10n))),
        );
    }
  }

  Future<void> _addAgent(AgentItem agent) async {
    setState(() => _addingIds.add(agent.id));
    try {
      await ref.read(channelMemberStoreProvider.notifier).addAgentMember(
            agent.id,
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
          SnackBar(content: Text(failure.userMessage(context.l10n))),
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
        backgroundImage: member.avatarUrl != null
            ? CachedNetworkImageProvider(
                member.avatarUrl!,
                maxWidth: 200,
                maxHeight: 200,
              )
            : null,
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
        backgroundImage: agent.avatarUrl != null
            ? CachedNetworkImageProvider(
                agent.avatarUrl!,
                maxWidth: 200,
                maxHeight: 200,
              )
            : null,
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
