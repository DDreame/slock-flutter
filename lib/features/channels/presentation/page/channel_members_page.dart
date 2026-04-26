import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_realtime_binding.dart';
import 'package:slock_app/features/channels/application/channel_member_state.dart';
import 'package:slock_app/features/channels/application/channel_member_store.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/presentation/widget/add_member_dialog.dart';

class ChannelMembersPage extends ConsumerStatefulWidget {
  final String serverId;
  final String channelId;

  const ChannelMembersPage({
    super.key,
    required this.serverId,
    required this.channelId,
  });

  @override
  ConsumerState<ChannelMembersPage> createState() => _ChannelMembersPageState();
}

class _ChannelMembersPageState extends ConsumerState<ChannelMembersPage> {
  @override
  Widget build(BuildContext context) {
    final serverId = ServerScopeId(widget.serverId);
    return ProviderScope(
      overrides: [
        currentChannelMemberServerIdProvider.overrideWithValue(serverId),
        currentChannelMemberChannelIdProvider
            .overrideWithValue(widget.channelId),
      ],
      child: _ChannelMembersBody(
        serverId: widget.serverId,
        channelId: widget.channelId,
      ),
    );
  }
}

class _ChannelMembersBody extends ConsumerStatefulWidget {
  final String serverId;
  final String channelId;

  const _ChannelMembersBody({
    required this.serverId,
    required this.channelId,
  });

  @override
  ConsumerState<_ChannelMembersBody> createState() =>
      _ChannelMembersBodyState();
}

class _ChannelMembersBodyState extends ConsumerState<_ChannelMembersBody> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(channelMemberStoreProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(channelMembersRealtimeBindingProvider);
    final state = ref.watch(channelMemberStoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Channel Members'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showAddMemberDialog(context),
          ),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(ChannelMemberState state) {
    switch (state.status) {
      case ChannelMemberStatus.initial:
      case ChannelMemberStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case ChannelMemberStatus.failure:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.failure?.message ?? 'Failed to load members.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(channelMemberStoreProvider.notifier).retry(),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      case ChannelMemberStatus.success:
        if (state.items.isEmpty) {
          return const Center(child: Text('No members in this channel.'));
        }
        return ListView.builder(
          itemCount: state.items.length,
          itemBuilder: (context, index) {
            final member = state.items[index];
            return _MemberTile(
              member: member,
              onRemove: () => _removeMember(member),
            );
          },
        );
    }
  }

  Future<void> _showAddMemberDialog(BuildContext context) async {
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AddMemberDialog(
        serverId: widget.serverId,
        channelId: widget.channelId,
        existingMembers: ref.read(channelMemberStoreProvider).items,
      ),
    );
    if (added == true) {
      ref.read(channelMemberStoreProvider.notifier).load();
    }
  }

  Future<void> _removeMember(ChannelMember member) async {
    try {
      if (member.isHuman) {
        await ref
            .read(channelMemberStoreProvider.notifier)
            .removeHumanMember(member.userId!);
      } else if (member.isAgent) {
        await ref
            .read(channelMemberStoreProvider.notifier)
            .removeAgentMember(member.agentId!);
      }
    } on AppFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(failure.message ?? 'Failed to remove member.'),
          ),
        );
    }
  }
}

class _MemberTile extends StatelessWidget {
  final ChannelMember member;
  final VoidCallback onRemove;

  const _MemberTile({required this.member, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
        child: member.avatarUrl == null
            ? Icon(member.isAgent ? Icons.smart_toy : Icons.person)
            : null,
      ),
      title: Text(member.displayName),
      subtitle: Text(member.isAgent ? 'Agent' : 'Human'),
      trailing: IconButton(
        icon: const Icon(Icons.remove_circle_outline),
        onPressed: onRemove,
      ),
    );
  }
}
