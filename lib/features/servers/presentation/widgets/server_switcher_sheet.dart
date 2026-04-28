import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';

Future<void> showServerSwitcherSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => const ServerSwitcherSheet(),
  );
}

class ServerSwitcherSheet extends ConsumerWidget {
  const ServerSwitcherSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  onSelect: (server) {
                    ref
                        .read(serverSelectionStoreProvider.notifier)
                        .selectServer(server.id);
                    Navigator.of(context).pop();
                  },
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
}

class _ServerList extends StatelessWidget {
  const _ServerList({
    required this.servers,
    required this.selectedServerId,
    required this.onSelect,
  });

  final List<ServerSummary> servers;
  final String? selectedServerId;
  final ValueChanged<ServerSummary> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: servers.length,
      itemBuilder: (context, index) {
        final server = servers[index];
        final isSelected = server.id == selectedServerId;
        return ListTile(
          key: ValueKey('server-${server.id}'),
          title: Text(server.name),
          trailing: isSelected ? const Icon(Icons.check) : null,
          selected: isSelected,
          onTap: () => onSelect(server),
        );
      },
    );
  }
}

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
          FilledButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
