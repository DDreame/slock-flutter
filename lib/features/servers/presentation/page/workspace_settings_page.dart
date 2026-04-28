import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';

class WorkspaceSettingsPage extends ConsumerWidget {
  const WorkspaceSettingsPage({required this.serverId, super.key});

  final String serverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverListState = ref.watch(serverListStoreProvider);
    final server = _findServer(serverListState, serverId);

    return Scaffold(
      appBar: AppBar(title: const Text('Workspace Settings')),
      body: server == null
          ? const Center(child: Text('Workspace not found.'))
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _InfoSection(server: server),
                const Divider(),
                _NavigationSection(serverId: serverId),
              ],
            ),
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
