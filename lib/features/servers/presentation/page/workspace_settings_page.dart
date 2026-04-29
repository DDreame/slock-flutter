import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/errors/app_failure.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/presentation/widgets/server_management_dialogs.dart';

class WorkspaceSettingsPage extends ConsumerWidget {
  const WorkspaceSettingsPage({required this.serverId, super.key});

  final String serverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverListState = ref.watch(serverListStoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Workspace Settings')),
      body: switch (serverListState.status) {
        ServerListStatus.initial ||
        ServerListStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        ServerListStatus.failure => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    serverListState.failure?.message ??
                        'Unable to load workspace.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: ref.read(serverListStoreProvider.notifier).retry,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ServerListStatus.success =>
          _buildSuccess(context, ref, serverListState),
      },
    );
  }

  Widget _buildSuccess(
    BuildContext context,
    WidgetRef ref,
    ServerListState state,
  ) {
    final server = _findServer(state, serverId);
    if (server == null) {
      return const Center(child: Text('Workspace not found.'));
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        _InfoSection(server: server),
        const Divider(),
        _NavigationSection(serverId: serverId),
        const Divider(),
        _ActionsSection(server: server),
      ],
    );
  }

  ServerSummary? _findServer(
    ServerListState state,
    String serverId,
  ) {
    if (state.status != ServerListStatus.success) return null;
    for (final server in state.servers) {
      if (server.id == serverId) return server;
    }
    return null;
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.server});

  final ServerSummary server;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            server.name,
            style: theme.textTheme.headlineSmall,
          ),
          if (server.slug.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              server.slug,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Role',
            value: server.role.isNotEmpty
                ? server.role[0].toUpperCase() + server.role.substring(1)
                : 'Unknown',
          ),
          if (server.createdAt != null)
            _InfoRow(
              label: 'Created',
              value: _formatDate(server.createdAt!),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}'
        '-${date.day.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _NavigationSection extends StatelessWidget {
  const _NavigationSection({required this.serverId});

  final String serverId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Manage',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ListTile(
          key: const ValueKey('workspace-settings-members'),
          leading: const Icon(Icons.people_outline),
          title: const Text('Members'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/servers/$serverId/members'),
        ),
        ListTile(
          key: const ValueKey('workspace-settings-billing'),
          leading: const Icon(Icons.payment_outlined),
          title: const Text('Billing'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/billing'),
        ),
      ],
    );
  }
}

class _ActionsSection extends ConsumerWidget {
  const _ActionsSection({required this.server});

  final ServerSummary server;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Actions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (server.isAdmin)
          ListTile(
            key: const ValueKey('workspace-settings-rename'),
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Rename workspace'),
            onTap: () => _renameServer(context, ref),
          ),
        if (server.isOwner)
          ListTile(
            key: const ValueKey('workspace-settings-delete'),
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Delete workspace',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _deleteServer(context, ref),
          ),
        if (!server.isOwner)
          ListTile(
            key: const ValueKey('workspace-settings-leave'),
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Leave workspace',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _leaveServer(context, ref),
          ),
      ],
    );
  }

  Future<void> _renameServer(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => RenameServerDialog(currentName: server.name),
    );
    if (name == null || !context.mounted) return;

    try {
      await ref
          .read(serverListStoreProvider.notifier)
          .renameServer(server.id, name);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workspace renamed.')),
      );
    } on AppFailure catch (failure) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message ?? 'Failed to rename workspace.'),
        ),
      );
    }
  }

  Future<void> _deleteServer(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => ConfirmServerActionDialog(
            title: 'Delete workspace?',
            message:
                'Delete ${server.name}? This permanently removes the workspace '
                'and all its data.',
            confirmLabel: 'Delete',
            confirmKey: const ValueKey('workspace-settings-delete-confirm'),
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(serverListStoreProvider.notifier).deleteServer(server.id);
      if (!context.mounted) return;
      context.go('/home');
    } on AppFailure catch (failure) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message ?? 'Failed to delete workspace.'),
        ),
      );
    }
  }

  Future<void> _leaveServer(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => ConfirmServerActionDialog(
            title: 'Leave workspace?',
            message:
                'Leave ${server.name}? You can rejoin later with a new invite.',
            confirmLabel: 'Leave',
            confirmKey: const ValueKey('workspace-settings-leave-confirm'),
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(serverListStoreProvider.notifier).leaveServer(server.id);
      if (!context.mounted) return;
      context.go('/home');
    } on AppFailure catch (failure) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message ?? 'Failed to leave workspace.'),
        ),
      );
    }
  }
}
