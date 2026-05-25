import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_status_tokens.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/machines/application/workspaces_state.dart';
import 'package:slock_app/features/machines/application/workspaces_store.dart';
import 'package:slock_app/features/machines/data/machines_repository_provider.dart';
import 'package:slock_app/features/machines/data/workspace_item.dart';
import 'package:slock_app/l10n/l10n.dart';

class WorkspacesPage extends StatelessWidget {
  WorkspacesPage({
    super.key,
    required String serverId,
    required this.machineId,
    required this.machineName,
  }) : _serverId = ServerScopeId(serverId);

  final ServerScopeId _serverId;
  final String machineId;
  final String machineName;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        currentMachinesServerIdProvider.overrideWithValue(_serverId),
        currentWorkspacesMachineIdProvider.overrideWithValue(machineId),
      ],
      child: _WorkspacesScreen(machineName: machineName),
    );
  }
}

class _WorkspacesScreen extends ConsumerStatefulWidget {
  const _WorkspacesScreen({required this.machineName});

  final String machineName;

  @override
  ConsumerState<_WorkspacesScreen> createState() => _WorkspacesScreenState();
}

class _WorkspacesScreenState extends ConsumerState<_WorkspacesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(workspacesStoreProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workspacesStoreProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.workspacesPageTitle)),
      body: switch (state.status) {
        WorkspacesStatus.initial || WorkspacesStatus.loading => const Center(
            key: ValueKey('workspaces-loading'),
            child: CircularProgressIndicator(),
          ),
        WorkspacesStatus.failure => _WorkspacesFailureView(
            message: state.failure?.userMessage(context.l10n) ??
                context.l10n.workspacesLoadFailed,
            onRetry: ref.read(workspacesStoreProvider.notifier).load,
          ),
        WorkspacesStatus.success => _WorkspacesSuccessView(
            items: state.items,
            machineName: widget.machineName,
            onRefresh: ref.read(workspacesStoreProvider.notifier).load,
            onDelete: _deleteWorkspace,
          ),
      },
    );
  }

  Future<void> _deleteWorkspace(WorkspaceItem workspace) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(l10n.workspacesDeleteTitle),
              content: Text(l10n.workspacesDeleteMessage(workspace.name)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.workspacesDeleteCancel),
                ),
                FilledButton(
                  key: const ValueKey('workspaces-confirm-delete'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.workspacesDeleteConfirm),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) {
      return;
    }

    try {
      await ref
          .read(workspacesStoreProvider.notifier)
          .deleteWorkspace(workspace.id);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.workspacesDeletedSnackbar)),
      );
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(failure.userMessage(l10n)),
        ),
      );
    }
  }
}

class _WorkspacesFailureView extends StatelessWidget {
  const _WorkspacesFailureView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('workspaces-error'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.l10n.workspacesRetryButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspacesSuccessView extends StatelessWidget {
  const _WorkspacesSuccessView({
    required this.items,
    required this.machineName,
    required this.onRefresh,
    required this.onDelete,
  });

  final List<WorkspaceItem> items;
  final String machineName;
  final Future<void> Function() onRefresh;
  final Future<void> Function(WorkspaceItem workspace) onDelete;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        key: const ValueKey('workspaces-empty'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_open_outlined, size: 40),
              const SizedBox(height: 12),
              Text(
                context.l10n.workspacesEmpty,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        key: const ValueKey('workspaces-list'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final workspace = items[index];
          return _WorkspaceCard(
            workspace: workspace,
            onDelete: () => onDelete(workspace),
          );
        },
      ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    required this.workspace,
    required this.onDelete,
  });

  final WorkspaceItem workspace;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Card(
      key: ValueKey('workspace-${workspace.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workspace.name,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _WorkspaceStatusChip(status: workspace.status),
                          if (workspace.agentName != null)
                            Chip(
                              avatar: const Icon(Icons.smart_toy, size: 16),
                              label: Text(workspace.agentName!),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey('workspace-delete-${workspace.id}'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                  tooltip: l10n.workspacesDeleteConfirm,
                ),
              ],
            ),
            if (workspace.path != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '${l10n.workspacesMetaPath}: ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      workspace.path!,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkspaceStatusChip extends StatelessWidget {
  const _WorkspaceStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      'active' => AppStatusTone.success,
      _ => AppStatusTone.neutral,
    };
    final colors = appStatusColors(Theme.of(context).colorScheme, tone);
    final l10n = context.l10n;

    return Chip(
      label: Text(
        status == 'active'
            ? l10n.workspacesStatusActive
            : l10n.workspacesStatusInactive,
      ),
      backgroundColor: colors.container,
      labelStyle: TextStyle(color: colors.onContainer),
    );
  }
}
