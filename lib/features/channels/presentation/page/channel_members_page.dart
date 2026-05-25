import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/widgets/app_loading_indicator.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_member_state.dart';
import 'package:slock_app/features/channels/application/channel_member_store.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/presentation/widgets/add_member_dialog.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/presence/presentation/widgets/presence_avatar.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/l10n/l10n.dart';

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
      () => ref.read(channelMemberStoreProvider.notifier).ensureLoaded(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to channel members update signals relayed by the root event
    // router. Replaces the old channelMembersRealtimeBindingProvider.
    ref.listen(routedChannelMembersSignalProvider, (prev, next) {
      if (next == null) return;
      final serverId = ref.read(currentChannelMemberServerIdProvider);
      final channelId = ref.read(currentChannelMemberChannelIdProvider);
      if (next.serverId != null && next.serverId != serverId.value) return;
      if (next.channelId != null && next.channelId != channelId) return;
      if (ref.read(channelMemberStoreProvider).status ==
          ChannelMemberStatus.loading) {
        return;
      }
      unawaited(ref.read(channelMemberStoreProvider.notifier).load());
    });

    final state = ref.watch(channelMemberStoreProvider);
    final canManageMembers = _canManageMembers();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.channelsMembersTitle),
        actions: canManageMembers
            ? [
                IconButton(
                  key: const ValueKey('channel-members-add-button'),
                  icon: const Icon(Icons.person_add),
                  onPressed: () => _showAddMemberDialog(context),
                ),
              ]
            : null,
      ),
      body: _buildBody(state, canManageMembers: canManageMembers),
    );
  }

  Widget _buildBody(
    ChannelMemberState state, {
    required bool canManageMembers,
  }) {
    switch (state.status) {
      case ChannelMemberStatus.initial:
      case ChannelMemberStatus.loading:
        return const AppLoadingIndicator();
      case ChannelMemberStatus.failure:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.failure?.userMessage(context.l10n) ??
                  context.l10n.errorUnknown),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(channelMemberStoreProvider.notifier).retry(),
                child: Text(context.l10n.channelsMembersRetry),
              ),
            ],
          ),
        );
      case ChannelMemberStatus.success:
        if (state.items.isEmpty) {
          return Center(child: Text(context.l10n.channelsMembersEmpty));
        }
        final currentUserId =
            ref.watch(sessionStoreProvider.select((s) => s.userId));
        return ListView.builder(
          itemCount: state.items.length,
          itemBuilder: (context, index) {
            final member = state.items[index];
            final isSelf = member.isHuman && member.userId == currentUserId;
            return _MemberTile(
              member: member,
              canManageMembers: canManageMembers,
              showMessageAction: member.isHuman && !isSelf,
              onRemove: () => _removeMember(member),
              onMessage: () => _openDirectMessage(member),
            );
          },
        );
    }
  }

  bool _canManageMembers() {
    final servers = ref.watch(serverListStoreProvider.select((s) => s.servers));
    for (final server in servers) {
      if (server.id == widget.serverId) {
        return server.isAdmin;
      }
    }
    return false;
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
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(context.l10n.channelsMembersRemoveTitle),
              content: Text(
                context.l10n.channelsMembersRemoveMessage(member.displayName),
              ),
              actions: [
                TextButton(
                  key: const ValueKey('channel-member-remove-cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(context.l10n.channelsMembersRemoveCancel),
                ),
                FilledButton(
                  key: const ValueKey('channel-member-remove-confirm'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(context.l10n.channelsMembersRemoveConfirm),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed || !mounted) return;
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
            content: Text(failure.userMessage(context.l10n)),
          ),
        );
    }
  }

  Future<void> _openDirectMessage(ChannelMember member) async {
    if (member.userId == null) return;
    try {
      final channelId =
          await ref.read(memberRepositoryProvider).openDirectMessage(
                ServerScopeId(widget.serverId),
                userId: member.userId!,
              );
      if (!mounted) return;
      context.push('/servers/${widget.serverId}/dms/$channelId');
    } on AppFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(failure.userMessage(context.l10n)),
          ),
        );
    }
  }
}

class _MemberTile extends StatelessWidget {
  final ChannelMember member;
  final bool canManageMembers;
  final bool showMessageAction;
  final VoidCallback onRemove;
  final VoidCallback onMessage;

  const _MemberTile({
    required this.member,
    required this.canManageMembers,
    required this.showMessageAction,
    required this.onRemove,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      backgroundImage: member.avatarUrl != null
          ? CachedNetworkImageProvider(
              member.avatarUrl!,
              maxWidth: 200,
              maxHeight: 200,
            )
          : null,
      child: member.avatarUrl == null
          ? Icon(member.isAgent ? Icons.smart_toy : Icons.person)
          : null,
    );

    return ListTile(
      leading: member.isHuman && member.userId != null
          ? PresenceAvatar(
              userId: member.userId!,
              child: avatar,
            )
          : avatar,
      title: Text(member.displayName),
      subtitle: Text(member.isAgent
          ? context.l10n.channelsMembersTypeAgent
          : context.l10n.channelsMembersTypeHuman),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showMessageAction)
            IconButton(
              key: ValueKey('channel-member-message-${member.id}'),
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: context.l10n.channelsMembersMessageTooltip,
              onPressed: onMessage,
            ),
          if (canManageMembers)
            IconButton(
              key: ValueKey('channel-member-remove-${member.id}'),
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
