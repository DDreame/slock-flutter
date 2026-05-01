import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
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
import 'package:slock_app/features/home/presentation/widgets/home_console_grid.dart';
import 'package:slock_app/features/home/presentation/widgets/home_direct_message_row.dart';
import 'package:slock_app/features/home/presentation/widgets/new_dm_dialog.dart';
import 'package:slock_app/l10n/l10n.dart';
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
    final l10n = context.l10n;

    // Build a lookup of online agent display names for DM status dots.
    // Human presence is not yet available in the home model.
    // TODO: wire human presence when available.
    final onlineAgentNames = <String>{
      for (final agent in state.agents)
        if (agent.isActive) agent.label,
      for (final agent in state.pinnedAgents)
        if (agent.isActive) agent.label,
    };

    final pinnedConversationRows = _buildPinnedConversationRows(
      state: state,
      homeStore: homeStore,
      channelUnreadCount: unreadState.channelUnreadCount,
      dmUnreadCount: unreadState.dmUnreadCount,
      unreadStore: unreadStore,
      isMutating: managementState.isBusy,
      onlineAgentNames: onlineAgentNames,
    );

    return Scaffold(
      appBar: AppBar(
        title: _HomeAppBarTitle(onTap: () => showServerSwitcherSheet(context)),
      ),
      body: switch (state.status) {
        HomeListStatus.noActiveServer => _HomeNoServerState(
            onSelectServer: () => showServerSwitcherSheet(context),
          ),
        HomeListStatus.initial || HomeListStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
        HomeListStatus.failure => _HomeErrorState(
            message: state.failure?.message ?? l10n.homeLoadFailedFallback,
            onRetry: homeStore.retry,
          ),
        HomeListStatus.success => RefreshIndicator(
            key: const ValueKey('home-refresh-indicator'),
            onRefresh: homeStore.load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HomeConsoleGrid(
                    key: const ValueKey('home-console-grid'),
                    items: [
                      HomeConsoleGridItem(
                        tileKey: const ValueKey('home-agents'),
                        icon: Icons.smart_toy_outlined,
                        label: l10n.homeConsoleAgentControl,
                        value:
                            '${state.agents.length + state.pinnedAgents.length}',
                        onTap: () => _pushServerRoute('agents'),
                      ),
                      HomeConsoleGridItem(
                        tileKey: const ValueKey('home-tasks'),
                        icon: Icons.check_circle_outline,
                        label: l10n.homeConsoleTasks,
                        value: '${state.taskCount}',
                        onTap: () => _pushServerRoute('tasks'),
                      ),
                      HomeConsoleGridItem(
                        tileKey: const ValueKey('home-machines'),
                        icon: Icons.memory_outlined,
                        label: l10n.homeConsoleMachines,
                        value: '${state.machineCount}',
                        onTap: () => _pushServerRoute('machines'),
                      ),
                      HomeConsoleGridItem(
                        tileKey: const ValueKey('home-threads'),
                        icon: Icons.forum_outlined,
                        label: l10n.homeConsoleThreads,
                        value: '${state.threadCount}',
                        onTap: () => _pushServerRoute('threads'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (pinnedConversationRows.isNotEmpty) ...[
                    _HomeSectionHeader(title: l10n.homeSectionPinned),
                    ...pinnedConversationRows,
                  ],
                  _HomeSectionHeader(
                    title: l10n.homeSectionChannels,
                    onAdd: _showCreateChannelDialog,
                    addButtonKey: const ValueKey('channel-create-button'),
                    addTooltip: l10n.homeCreateChannelTooltip,
                  ),
                  if (state.channels.isEmpty)
                    Padding(
                      key: const ValueKey('home-channels-empty'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text(l10n.homeChannelsEmpty),
                    ),
                  for (final entry in state.channels.asMap().entries)
                    HomeChannelRow(
                      key: ValueKey(
                        'channel-${entry.value.scopeId.routeParam}',
                      ),
                      channel: entry.value,
                      unreadCount:
                          unreadState.channelUnreadCount(entry.value.scopeId),
                      isMutating: managementState.isBusy,
                      onTap: () {
                        unreadStore.markChannelRead(entry.value.scopeId);
                        context.push(
                          homeStore.channelRoutePath(entry.value.scopeId),
                        );
                      },
                      onEdit: () => _showEditChannelDialog(entry.value),
                      onDelete: () => _showDeleteChannelDialog(entry.value),
                      onLeave: () => _showLeaveChannelDialog(entry.value),
                      onTogglePin: () =>
                          homeStore.pinChannel(entry.value.scopeId),
                      onMoveUp: entry.key > 0
                          ? () => homeStore.moveChannel(
                                entry.value.scopeId,
                                moveUp: true,
                              )
                          : null,
                      onMoveDown: entry.key < state.channels.length - 1
                          ? () => homeStore.moveChannel(
                                entry.value.scopeId,
                                moveUp: false,
                              )
                          : null,
                    ),
                  _HomeSectionHeader(
                    title: l10n.homeSectionDirectMessages,
                    onAdd: _showNewDmDialog,
                    addButtonKey: const ValueKey('dm-create-button'),
                    addTooltip: l10n.homeNewMessageTooltip,
                  ),
                  if (state.directMessages.isEmpty)
                    Padding(
                      key: const ValueKey('home-dms-empty'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text(l10n.homeDirectMessagesEmpty),
                    ),
                  for (final entry in state.directMessages.asMap().entries)
                    HomeDirectMessageRow(
                      key: ValueKey('dm-${entry.value.scopeId.routeParam}'),
                      directMessage: entry.value,
                      unreadCount:
                          unreadState.dmUnreadCount(entry.value.scopeId),
                      isOnline: onlineAgentNames.contains(entry.value.title),
                      onTap: () {
                        unreadStore.markDmRead(entry.value.scopeId);
                        context.push(
                          homeStore.directMessageRoutePath(entry.value.scopeId),
                        );
                      },
                      onTogglePin: () => homeStore.pinDirectMessage(
                        entry.value.scopeId,
                      ),
                      onHide: () => homeStore.hideDm(entry.value.scopeId),
                      onMoveUp: entry.key > 0
                          ? () => homeStore.moveDirectMessage(
                                entry.value.scopeId,
                                moveUp: true,
                              )
                          : null,
                      onMoveDown: entry.key < state.directMessages.length - 1
                          ? () => homeStore.moveDirectMessage(
                                entry.value.scopeId,
                                moveUp: false,
                              )
                          : null,
                    ),
                  if (state.hiddenDirectMessages.isNotEmpty)
                    ListTile(
                      key: const ValueKey('home-hidden-dms'),
                      leading: const Icon(Icons.visibility_off_outlined),
                      title: Text(
                        l10n.homeHiddenConversationsCount(
                            state.hiddenDirectMessages.length),
                      ),
                      onTap: () => _showHiddenDmsSheet(homeStore, unreadStore),
                    ),
                  if (state.pinnedAgents.isNotEmpty) ...[
                    _HomeSectionHeader(title: l10n.homeSectionPinnedAgents),
                    for (final agent in state.pinnedAgents)
                      _HomeAgentRow(
                        key: ValueKey('pinned-agent-${agent.id}'),
                        agent: agent,
                        isPinned: true,
                        onTap: () => _openAgentDetail(agent.id),
                        onTogglePin: () => homeStore.unpinAgent(agent.id),
                      ),
                  ],
                  if (state.agents.isNotEmpty ||
                      state.pinnedAgents.isNotEmpty) ...[
                    _HomeSectionHeader(title: l10n.homeSectionAgents),
                    for (final agent in state.agents)
                      _HomeAgentRow(
                        key: ValueKey('agent-${agent.id}'),
                        agent: agent,
                        isPinned: false,
                        onTap: () => _openAgentDetail(agent.id),
                        onTogglePin: () => homeStore.pinAgent(agent.id),
                      ),
                  ],
                ],
              ),
            ),
          ),
      },
    );
  }

  void _openAgentDetail(String agentId) {
    final serverId = ref.read(activeServerScopeIdProvider)?.value;
    if (serverId != null) {
      context.go('/servers/$serverId/agents/$agentId');
      return;
    }
    context.go('/agents/$agentId');
  }

  Future<void> _showCreateChannelDialog() async {
    final l10n = context.l10n;
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
                  _showSnackBar(l10n.homeChannelCreated);
                  if (channelId != null) {
                    pageContext.go(
                      '/servers/${serverId.routeParam}/channels/$channelId',
                    );
                  }
                } on AppFailure catch (failure) {
                  if (!mounted) {
                    return;
                  }
                  _showSnackBar(
                      failure.message ?? l10n.homeChannelCreateFailed);
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
    final l10n = context.l10n;
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
                  _showSnackBar(l10n.homeChannelUpdated);
                } on AppFailure catch (failure) {
                  if (!mounted) {
                    return;
                  }
                  _showSnackBar(
                      failure.message ?? l10n.homeChannelUpdateFailed);
                }
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteChannelDialog(HomeChannelSummary channel) async {
    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(channelManagementStoreProvider);
            final store = ref.read(channelManagementStoreProvider.notifier);
            return ConfirmChannelActionDialog(
              dialogKey: const ValueKey('delete-channel-dialog'),
              title: l10n.homeDeleteChannelTitle,
              message: l10n.homeDeleteChannelMessage(channel.name),
              confirmLabel: l10n.homeDeleteChannelConfirm,
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
                  _showSnackBar(l10n.homeChannelDeleted);
                } on AppFailure catch (failure) {
                  if (!mounted) {
                    return;
                  }
                  _showSnackBar(
                      failure.message ?? l10n.homeChannelDeleteFailed);
                }
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showLeaveChannelDialog(HomeChannelSummary channel) async {
    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(channelManagementStoreProvider);
            final store = ref.read(channelManagementStoreProvider.notifier);
            return ConfirmChannelActionDialog(
              dialogKey: const ValueKey('leave-channel-dialog'),
              title: l10n.homeLeaveChannelTitle,
              message: l10n.homeLeaveChannelMessage(channel.name),
              confirmLabel: l10n.homeLeaveChannelConfirm,
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
                  _showSnackBar(l10n.homeChannelLeft);
                } on AppFailure catch (failure) {
                  if (!mounted) {
                    return;
                  }
                  _showSnackBar(failure.message ?? l10n.homeChannelLeaveFailed);
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

  void _pushServerRoute(String routeSuffix) {
    final serverId = ref.read(activeServerScopeIdProvider)?.value;
    if (serverId == null) {
      return;
    }
    context.push('/servers/$serverId/$routeSuffix');
  }

  List<Widget> _buildPinnedConversationRows({
    required HomeListState state,
    required HomeListStore homeStore,
    required int Function(ChannelScopeId) channelUnreadCount,
    required int Function(DirectMessageScopeId) dmUnreadCount,
    required ChannelUnreadStore unreadStore,
    required bool isMutating,
    required Set<String> onlineAgentNames,
  }) {
    final pinnedChannels = {
      for (final channel in state.pinnedChannels)
        channel.scopeId.value: channel,
    };
    final pinnedDms = {
      for (final dm in state.pinnedDirectMessages) dm.scopeId.value: dm,
    };
    final rows = <Widget>[];
    final pinnedIds = state.pinnedConversationOrder;

    for (final entry in pinnedIds.asMap().entries) {
      final pinnedId = entry.value;
      final canMoveUp = entry.key > 0;
      final canMoveDown = entry.key < pinnedIds.length - 1;

      final channel = pinnedChannels[pinnedId];
      if (channel != null) {
        rows.add(
          HomeChannelRow(
            key: ValueKey('pinned-${channel.scopeId.routeParam}'),
            channel: channel,
            unreadCount: channelUnreadCount(channel.scopeId),
            isMutating: isMutating,
            isPinned: true,
            onTap: () {
              unreadStore.markChannelRead(channel.scopeId);
              context.push(homeStore.channelRoutePath(channel.scopeId));
            },
            onEdit: () => _showEditChannelDialog(channel),
            onDelete: () => _showDeleteChannelDialog(channel),
            onLeave: () => _showLeaveChannelDialog(channel),
            onTogglePin: () => homeStore.unpinChannel(channel.scopeId),
            onMoveUp: canMoveUp
                ? () => homeStore.movePinnedConversation(
                      channel.scopeId.serverId,
                      channel.scopeId.value,
                      moveUp: true,
                    )
                : null,
            onMoveDown: canMoveDown
                ? () => homeStore.movePinnedConversation(
                      channel.scopeId.serverId,
                      channel.scopeId.value,
                      moveUp: false,
                    )
                : null,
          ),
        );
        continue;
      }

      final directMessage = pinnedDms[pinnedId];
      if (directMessage != null) {
        rows.add(
          HomeDirectMessageRow(
            key: ValueKey('pinned-dm-${directMessage.scopeId.routeParam}'),
            directMessage: directMessage,
            unreadCount: dmUnreadCount(directMessage.scopeId),
            isPinned: true,
            isOnline: onlineAgentNames.contains(directMessage.title),
            onTap: () {
              unreadStore.markDmRead(directMessage.scopeId);
              context.push(
                homeStore.directMessageRoutePath(directMessage.scopeId),
              );
            },
            onTogglePin: () => homeStore.unpinDirectMessage(
              directMessage.scopeId,
            ),
            onHide: () => homeStore.hideDm(directMessage.scopeId),
            onMoveUp: canMoveUp
                ? () => homeStore.movePinnedConversation(
                      directMessage.scopeId.serverId,
                      directMessage.scopeId.value,
                      moveUp: true,
                    )
                : null,
            onMoveDown: canMoveDown
                ? () => homeStore.movePinnedConversation(
                      directMessage.scopeId.serverId,
                      directMessage.scopeId.value,
                      moveUp: false,
                    )
                : null,
          ),
        );
      }
    }

    return rows;
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
            child:
                Text(isPinned ? context.l10n.homeUnpin : context.l10n.homePin),
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
    final colors = Theme.of(context).extension<AppColors>()!;

    return Column(
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: colors.border,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.md,
            AppSpacing.pageHorizontal,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.title.copyWith(
                    color: colors.text,
                  ),
                ),
              ),
              if (onAdd != null)
                IconButton(
                  key: addButtonKey,
                  onPressed: onAdd,
                  icon: Icon(
                    Icons.add,
                    color: colors.textSecondary,
                  ),
                  tooltip: addTooltip,
                ),
            ],
          ),
        ),
      ],
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
            Text(
              context.l10n.homeNoServerMessage,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onSelectServer,
              child: Text(context.l10n.homeSelectWorkspace),
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
            FilledButton(
                onPressed: onRetry, child: Text(context.l10n.homeRetry)),
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
