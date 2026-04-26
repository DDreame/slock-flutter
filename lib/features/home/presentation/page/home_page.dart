import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/channels/application/channel_management_state.dart';
import 'package:slock_app/features/channels/application/channel_management_store.dart';
import 'package:slock_app/features/channels/presentation/widgets/channel_management_dialogs.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_admin_realtime_binding.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/presentation/widgets/home_channel_row.dart';
import 'package:slock_app/features/home/presentation/widgets/home_direct_message_row.dart';
import 'package:slock_app/features/home/presentation/widgets/new_dm_dialog.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/presentation/widgets/server_switcher_sheet.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    ref.watch(homeAdminRealtimeBindingProvider);
    final state = ref.watch(homeListStoreProvider);
    final homeStore = ref.read(homeListStoreProvider.notifier);
    final unreadState = ref.watch(channelUnreadStoreProvider);
    final unreadStore = ref.read(channelUnreadStoreProvider.notifier);
    final managementState = ref.watch(channelManagementStoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: _HomeAppBarTitle(onTap: () => showServerSwitcherSheet(context)),
        actions: [
          IconButton(
            key: const ValueKey('home-members'),
            icon: const Icon(Icons.people_outline),
            onPressed: () {
              final serverId = ref.read(activeServerScopeIdProvider);
              if (serverId != null) {
                context.push('/servers/${serverId.value}/members');
              }
            },
          ),
          IconButton(
            key: const ValueKey('home-search'),
            icon: const Icon(Icons.search),
            onPressed: () {
              final serverId = ref.read(activeServerScopeIdProvider);
              if (serverId != null) {
                context.push('/servers/${serverId.value}/search');
              }
            },
          ),
        ],
      ),
      body: switch (state.status) {
        HomeListStatus.noActiveServer => _HomeNoServerState(
            onSelectServer: () => showServerSwitcherSheet(context),
          ),
        HomeListStatus.initial || HomeListStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
        HomeListStatus.failure => _HomeErrorState(
            message: state.failure?.message ?? 'Unable to load conversations.',
            onRetry: homeStore.retry,
          ),
        HomeListStatus.success => ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              ListTile(
                key: const ValueKey('home-saved-messages'),
                leading: const Icon(Icons.bookmark_outline),
                title: const Text('Saved Messages'),
                onTap: () {
                  final serverId = ref.read(activeServerScopeIdProvider);
                  if (serverId != null) {
                    context.push('/servers/${serverId.value}/saved-messages');
                  }
                },
              ),
              ListTile(
                key: const ValueKey('home-tasks'),
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Tasks'),
                onTap: () {
                  final serverId = ref.read(activeServerScopeIdProvider);
                  if (serverId != null) {
                    context.go('/servers/${serverId.value}/tasks');
                  }
                },
              ),
              ListTile(
                key: const ValueKey('home-machines'),
                leading: const Icon(Icons.memory_outlined),
                title: const Text('Machines'),
                onTap: () {
                  final serverId = ref.read(activeServerScopeIdProvider);
                  if (serverId != null) {
                    context.go('/servers/${serverId.value}/machines');
                  }
                },
              ),
              if (state.pinnedChannels.isNotEmpty) ...[
                const _HomeSectionHeader(title: 'Pinned'),
                for (final channel in state.pinnedChannels)
                  HomeChannelRow(
                    key: ValueKey('pinned-${channel.scopeId.routeParam}'),
                    channel: channel,
                    unreadCount:
                        unreadState.channelUnreadCount(channel.scopeId),
                    isMutating: managementState.isBusy,
                    isPinned: true,
                    onTap: () {
                      unreadStore.markChannelRead(channel.scopeId);
                      context.go(homeStore.channelRoutePath(channel.scopeId));
                    },
                    onEdit: () => _showEditChannelDialog(channel),
                    onDelete: () => _showDeleteChannelDialog(channel),
                    onLeave: () => _showLeaveChannelDialog(channel),
                    onTogglePin: () => homeStore.unpinChannel(channel.scopeId),
                  ),
              ],
              _HomeSectionHeader(
                title: 'Channels',
                onAdd: _showCreateChannelDialog,
                addButtonKey: const ValueKey('channel-create-button'),
                addTooltip: 'Create channel',
              ),
              for (final channel in state.channels)
                HomeChannelRow(
                  key: ValueKey('channel-${channel.scopeId.routeParam}'),
                  channel: channel,
                  unreadCount: unreadState.channelUnreadCount(channel.scopeId),
                  isMutating: managementState.isBusy,
                  onTap: () {
                    unreadStore.markChannelRead(channel.scopeId);
                    context.go(homeStore.channelRoutePath(channel.scopeId));
                  },
                  onEdit: () => _showEditChannelDialog(channel),
                  onDelete: () => _showDeleteChannelDialog(channel),
                  onLeave: () => _showLeaveChannelDialog(channel),
                  onTogglePin: () => homeStore.pinChannel(channel.scopeId),
                ),
              _HomeSectionHeader(
                title: 'Direct Messages',
                onAdd: _showNewDmDialog,
                addButtonKey: const ValueKey('dm-create-button'),
                addTooltip: 'New message',
              ),
              for (final directMessage in state.directMessages)
                HomeDirectMessageRow(
                  key: ValueKey('dm-${directMessage.scopeId.routeParam}'),
                  directMessage: directMessage,
                  unreadCount: unreadState.dmUnreadCount(directMessage.scopeId),
                  onTap: () {
                    unreadStore.markDmRead(directMessage.scopeId);
                    context.go(
                      homeStore.directMessageRoutePath(directMessage.scopeId),
                    );
                  },
                  onHide: () => homeStore.hideDm(directMessage.scopeId),
                ),
              if (state.hiddenDirectMessages.isNotEmpty)
                ListTile(
                  key: const ValueKey('home-hidden-dms'),
                  leading: const Icon(Icons.visibility_off_outlined),
                  title: Text(
                    'Hidden conversations (${state.hiddenDirectMessages.length})',
                  ),
                  onTap: () => _showHiddenDmsSheet(homeStore, unreadStore),
                ),
              if (state.pinnedAgents.isNotEmpty) ...[
                const _HomeSectionHeader(title: 'Pinned Agents'),
                for (final agent in state.pinnedAgents)
                  _HomeAgentRow(
                    key: ValueKey('pinned-agent-${agent.id}'),
                    agent: agent,
                    isPinned: true,
                    onTap: () => context.go('/agents/${agent.id}'),
                    onTogglePin: () => homeStore.unpinAgent(agent.id),
                  ),
              ],
              if (state.agents.isNotEmpty || state.pinnedAgents.isNotEmpty) ...[
                const _HomeSectionHeader(title: 'Agents'),
                for (final agent in state.agents)
                  _HomeAgentRow(
                    key: ValueKey('agent-${agent.id}'),
                    agent: agent,
                    isPinned: false,
                    onTap: () => context.go('/agents/${agent.id}'),
                    onTogglePin: () => homeStore.pinAgent(agent.id),
                  ),
              ],
            ],
          ),
      },
    );
  }

  Future<void> _showCreateChannelDialog() async {
    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) {
      return;
    }
    final pageContext = context;

    await showDialog<void>(
      context: pageContext,
      builder: (dialogContext) {
        return Consumer(
          builder: (_, ref, __) {
            final state = ref.watch(channelManagementStoreProvider);
            final store = ref.read(channelManagementStoreProvider.notifier);
            return CreateChannelDialog(
              isSubmitting: state.isRunning(ChannelManagementAction.create),
              onCancel: () => Navigator.of(dialogContext).pop(),
              onCreate: (name) async {
                try {
                  final channelId = await store.createChannel(name);
                  if (!mounted || !pageContext.mounted) {
                    return;
                  }
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  _showSnackBar('Channel created.');
                  if (channelId != null) {
                    pageContext.go(
                      '/servers/${serverId.routeParam}/channels/$channelId',
                    );
                  }
                } on AppFailure catch (failure) {
                  if (!mounted) {
                    return;
                  }
                  _showSnackBar(failure.message ?? 'Failed to create channel.');
                }
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showNewDmDialog() async {
    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) {
      return;
    }
    final pageContext = context;

    final channelId = await showDialog<String>(
      context: pageContext,
      builder: (_) => NewDmDialog(serverId: serverId),
    );

    if (channelId != null && mounted && pageContext.mounted) {
      pageContext.go('/servers/${serverId.value}/dms/$channelId');
    }
  }

  Future<void> _showEditChannelDialog(HomeChannelSummary channel) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(channelManagementStoreProvider);
            final store = ref.read(channelManagementStoreProvider.notifier);
            return EditChannelDialog(
              currentName: channel.name,
              isSubmitting: state.isRunning(
                ChannelManagementAction.edit,
                channelId: channel.scopeId.value,
              ),
              onCancel: () => Navigator.of(dialogContext).pop(),
              onSave: (name) async {
                try {
                  await store.renameChannel(channel.scopeId, name: name);
                  if (!mounted) {
                    return;
                  }
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  _showSnackBar('Channel updated.');
                } on AppFailure catch (failure) {
                  if (!mounted) {
                    return;
                  }
                  _showSnackBar(failure.message ?? 'Failed to update channel.');
                }
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteChannelDialog(HomeChannelSummary channel) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(channelManagementStoreProvider);
            final store = ref.read(channelManagementStoreProvider.notifier);
            return ConfirmChannelActionDialog(
              dialogKey: const ValueKey('delete-channel-dialog'),
              title: 'Delete channel',
              message: 'Delete ${channel.name}? This cannot be undone.',
              confirmLabel: 'Delete',
              isSubmitting: state.isRunning(
                ChannelManagementAction.delete,
                channelId: channel.scopeId.value,
              ),
              onCancel: () => Navigator.of(dialogContext).pop(),
              onConfirm: () async {
                try {
                  await store.deleteChannel(channel.scopeId);
                  if (!mounted) {
                    return;
                  }
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  _showSnackBar('Channel deleted.');
                } on AppFailure catch (failure) {
                  if (!mounted) {
                    return;
                  }
                  _showSnackBar(failure.message ?? 'Failed to delete channel.');
                }
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showLeaveChannelDialog(HomeChannelSummary channel) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(channelManagementStoreProvider);
            final store = ref.read(channelManagementStoreProvider.notifier);
            return ConfirmChannelActionDialog(
              dialogKey: const ValueKey('leave-channel-dialog'),
              title: 'Leave channel',
              message: 'Leave ${channel.name}?',
              confirmLabel: 'Leave',
              isSubmitting: state.isRunning(
                ChannelManagementAction.leave,
                channelId: channel.scopeId.value,
              ),
              onCancel: () => Navigator.of(dialogContext).pop(),
              onConfirm: () async {
                try {
                  await store.leaveChannel(channel.scopeId);
                  if (!mounted) {
                    return;
                  }
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  _showSnackBar('Left channel.');
                } on AppFailure catch (failure) {
                  if (!mounted) {
                    return;
                  }
                  _showSnackBar(failure.message ?? 'Failed to leave channel.');
                }
              },
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showHiddenDmsSheet(
    HomeListStore homeStore,
    ChannelUnreadStore unreadStore,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return Consumer(
          builder: (_, ref, __) {
            final hiddenDms =
                ref.watch(homeListStoreProvider).hiddenDirectMessages;
            if (hiddenDms.isEmpty) {
              Navigator.of(sheetContext).pop();
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
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Hidden conversations',
                        style: TextStyle(
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
                                child: const Text('Unhide'),
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
}

class _HomeAgentRow extends StatelessWidget {
  const _HomeAgentRow({
    super.key,
    required this.agent,
    required this.isPinned,
    required this.onTap,
    required this.onTogglePin,
  });

  final AgentItem agent;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.smart_toy_outlined),
      title: Text(agent.label),
      subtitle: Text(agent.activity),
      trailing: PopupMenuButton<String>(
        key: ValueKey('agent-menu-${agent.id}'),
        onSelected: (value) {
          if (value == 'toggle_pin') onTogglePin();
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'toggle_pin',
            child: Text(isPinned ? 'Unpin' : 'Pin'),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _HomeSectionHeader extends StatelessWidget {
  const _HomeSectionHeader({
    required this.title,
    this.onAdd,
    this.addButtonKey,
    this.addTooltip,
  });

  final String title;
  final VoidCallback? onAdd;
  final Key? addButtonKey;
  final String? addTooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (onAdd != null)
            IconButton(
              key: addButtonKey,
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              tooltip: addTooltip,
            ),
        ],
      ),
    );
  }
}

class _HomeNoServerState extends StatelessWidget {
  const _HomeNoServerState({required this.onSelectServer});

  final VoidCallback onSelectServer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select a server to get started.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onSelectServer,
              child: const Text('Select workspace'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeErrorState extends StatelessWidget {
  const _HomeErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _HomeAppBarTitle extends ConsumerWidget {
  const _HomeAppBarTitle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeServer = ref.watch(activeServerScopeIdProvider);
    final serverListState = ref.watch(serverListStoreProvider);

    String title = 'Slock';
    if (activeServer != null &&
        serverListState.status == ServerListStatus.success) {
      for (final server in serverListState.servers) {
        if (server.id == activeServer.value) {
          title = server.name;
          break;
        }
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}
