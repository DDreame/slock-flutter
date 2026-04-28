import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/presentation/widgets/server_management_dialogs.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';

Future<void> showServerSwitcherSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const ServerSwitcherSheet(),
  );
}

class ServerSwitcherSheet extends ConsumerStatefulWidget {
  const ServerSwitcherSheet({super.key});

  @override
  ConsumerState<ServerSwitcherSheet> createState() =>
      _ServerSwitcherSheetState();
}

class _ServerSwitcherSheetState extends ConsumerState<ServerSwitcherSheet> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serverListStoreProvider);
    final activeServer = ref.watch(activeServerScopeIdProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Switch workspace',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('server-switcher-create'),
                  onPressed: state.isCreating ? null : _showCreateServerDialog,
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(
                    state.isCreating ? 'Creating...' : 'Create workspace',
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('server-switcher-join'),
                  onPressed:
                      state.isJoiningInvite ? null : _showJoinServerDialog,
                  icon: const Icon(Icons.group_add_outlined),
                  label: Text(
                    state.isJoiningInvite ? 'Joining...' : 'Join workspace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          switch (state.status) {
            ServerListStatus.initial ||
            ServerListStatus.loading =>
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ServerListStatus.failure => _ServerListError(
                message: state.failure?.message ?? 'Unable to load workspaces.',
                onRetry: ref.read(serverListStoreProvider.notifier).retry,
              ),
            ServerListStatus.success when state.servers.isEmpty =>
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No workspaces available.')),
              ),
            ServerListStatus.success => Flexible(
                child: _ServerList(
                  servers: state.servers,
                  selectedServerId: activeServer?.value,
                  state: state,
                  onSelect: _selectServer,
                  onRename: _renameServer,
                  onDelete: _deleteServer,
                  onLeave: _leaveServer,
                ),
              ),
          },
          if (activeServer != null &&
              state.status == ServerListStatus.success) ...[
            const Divider(height: 1),
            ListTile(
              key: const ValueKey('server-switcher-settings'),
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Workspace Settings'),
              onTap: () {
                Navigator.of(context).pop();
                context.push(
                  '/servers/${activeServer.value}/settings',
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _selectServer(ServerSummary server) async {
    await ref
        .read(serverSelectionStoreProvider.notifier)
        .selectServer(server.id);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _showCreateServerDialog() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const CreateServerDialog(),
    );
    if (name == null) {
      return;
    }

    try {
      await ref.read(serverListStoreProvider.notifier).createServer(name);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Workspace created.')));
      Navigator.of(context).pop();
    } on AppFailure catch (failure) {
      _showFailureSnackBar(failure.message ?? 'Failed to create workspace.');
    }
  }

  Future<void> _showJoinServerDialog() async {
    final inviteCode = await showDialog<String>(
      context: context,
      builder: (_) => const JoinServerDialog(),
    );
    if (inviteCode == null) {
      return;
    }

    try {
      await ref.read(serverListStoreProvider.notifier).acceptInvite(inviteCode);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Workspace joined.')));
      Navigator.of(context).pop();
    } on AppFailure catch (failure) {
      _showFailureSnackBar(failure.message ?? 'Failed to join workspace.');
    }
  }

  Future<void> _renameServer(ServerSummary server) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => RenameServerDialog(currentName: server.name),
    );
    if (name == null) {
      return;
    }

    try {
      await ref
          .read(serverListStoreProvider.notifier)
          .renameServer(server.id, name);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Workspace renamed.')));
    } on AppFailure catch (failure) {
      _showFailureSnackBar(failure.message ?? 'Failed to rename workspace.');
    }
  }

  Future<void> _deleteServer(ServerSummary server) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => ConfirmServerActionDialog(
            title: 'Delete workspace?',
            message:
                'Delete ${server.name}? This permanently removes the workspace.',
            confirmLabel: 'Delete',
            confirmKey: const ValueKey('delete-server-confirm'),
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }

    try {
      await ref.read(serverListStoreProvider.notifier).deleteServer(server.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Workspace deleted.')));
      Navigator.of(context).pop();
    } on AppFailure catch (failure) {
      _showFailureSnackBar(failure.message ?? 'Failed to delete workspace.');
    }
  }

  Future<void> _leaveServer(ServerSummary server) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => ConfirmServerActionDialog(
            title: 'Leave workspace?',
            message:
                'Leave ${server.name}? You can rejoin later with a new invite.',
            confirmLabel: 'Leave',
            confirmKey: const ValueKey('leave-server-confirm'),
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }

    try {
      await ref.read(serverListStoreProvider.notifier).leaveServer(server.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Workspace left.')));
      Navigator.of(context).pop();
    } on AppFailure catch (failure) {
      _showFailureSnackBar(failure.message ?? 'Failed to leave workspace.');
    }
  }

  void _showFailureSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ServerList extends StatelessWidget {
  const _ServerList({
    required this.servers,
    required this.selectedServerId,
    required this.state,
    required this.onSelect,
    required this.onRename,
    required this.onDelete,
    required this.onLeave,
  });

  final List<ServerSummary> servers;
  final String? selectedServerId;
  final ServerListState state;
  final Future<void> Function(ServerSummary server) onSelect;
  final Future<void> Function(ServerSummary server) onRename;
  final Future<void> Function(ServerSummary server) onDelete;
  final Future<void> Function(ServerSummary server) onLeave;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: servers.length,
      itemBuilder: (context, index) {
        final server = servers[index];
        final isSelected = server.id == selectedServerId;
        final isBusy = state.isBusy(server.id);
        return ListTile(
          key: ValueKey('server-${server.id}'),
          title: Text(server.name),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBusy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              if (isSelected) ...[
                if (isBusy) const SizedBox(width: 8),
                const Icon(Icons.check),
              ],
              if (!isBusy)
                PopupMenuButton<_ServerRowAction>(
                  key: ValueKey('server-actions-${server.id}'),
                  onSelected: (action) {
                    switch (action) {
                      case _ServerRowAction.rename:
                        unawaited(onRename(server));
                        return;
                      case _ServerRowAction.delete:
                        unawaited(onDelete(server));
                        return;
                      case _ServerRowAction.leave:
                        unawaited(onLeave(server));
                        return;
                    }
                  },
                  itemBuilder: (context) {
                    return [
                      const PopupMenuItem<_ServerRowAction>(
                        value: _ServerRowAction.rename,
                        child: Text('Rename'),
                      ),
                      PopupMenuItem<_ServerRowAction>(
                        value: server.isOwner
                            ? _ServerRowAction.delete
                            : _ServerRowAction.leave,
                        child: Text(
                          server.isOwner
                              ? 'Delete workspace'
                              : 'Leave workspace',
                        ),
                      ),
                    ];
                  },
                ),
            ],
          ),
          selected: isSelected,
          onTap: () => onSelect(server),
        );
      },
    );
  }
}

enum _ServerRowAction { rename, delete, leave }

class _ServerListError extends StatelessWidget {
  const _ServerListError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
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
