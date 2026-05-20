import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/widgets/app_loading_indicator.dart';
import 'package:slock_app/app/widgets/friendly_error_state.dart';
import 'package:slock_app/core/errors/app_failure.dart';
import 'package:slock_app/core/telemetry/diagnostic_share_sheet.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/presentation/widgets/server_management_dialogs.dart';
import 'package:slock_app/l10n/l10n.dart';

class WorkspaceSettingsPage extends ConsumerWidget {
  const WorkspaceSettingsPage({required this.serverId, super.key});

  final String serverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverListState = ref.watch(serverListStoreProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeConsoleWorkspaceSettings)),
      body: switch (serverListState.status) {
        ServerListStatus.initial ||
        ServerListStatus.loading =>
          const AppLoadingIndicator(),
        ServerListStatus.failure => FriendlyErrorState(
            key: const ValueKey('workspace-settings-error'),
            title: l10n.workspaceSettingsUnavailableTitle,
            message: l10n.workspaceSettingsUnavailableMessage,
            onRetry: ref.read(serverListStoreProvider.notifier).retry,
            onShareDiagnostics: () => DiagnosticShareSheet.show(context),
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
    final l10n = context.l10n;
    final server = _findServer(state, serverId);
    if (server == null) {
      return Center(child: Text(l10n.workspaceSettingsNotFound));
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
    final l10n = context.l10n;
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
            label: l10n.workspaceSettingsRoleLabel,
            value: server.role.isNotEmpty
                ? server.role[0].toUpperCase() + server.role.substring(1)
                : l10n.workspaceSettingsRoleUnknown,
          ),
          if (server.createdAt != null)
            _InfoRow(
              label: l10n.workspaceSettingsCreatedLabel,
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
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            l10n.workspaceSettingsManageSection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ListTile(
          key: const ValueKey('workspace-settings-members'),
          leading: const Icon(Icons.people_outline),
          title: Text(l10n.homeConsoleMembers),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/servers/$serverId/members'),
        ),
        ListTile(
          key: const ValueKey('workspace-settings-billing'),
          leading: const Icon(Icons.payment_outlined),
          title: Text(l10n.homeConsoleBilling),
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
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            l10n.workspaceSettingsActionsSection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (server.isAdmin)
          ListTile(
            key: const ValueKey('workspace-settings-rename'),
            leading: const Icon(Icons.edit_outlined),
            title: Text(l10n.workspaceSettingsRenameAction),
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
              l10n.workspaceSettingsDeleteAction,
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
              l10n.workspaceSettingsLeaveAction,
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

    final l10n = context.l10n;
    try {
      await ref
          .read(serverListStoreProvider.notifier)
          .renameServer(server.id, name);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.workspaceSettingsRenamedSnackbar)),
      );
    } on AppFailure catch (failure) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failure.message ?? l10n.workspaceSettingsRenameFailed,
          ),
        ),
      );
    }
  }

  Future<void> _deleteServer(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => ConfirmServerActionDialog(
            title: l10n.workspaceSettingsDeleteDialogTitle,
            message: l10n.workspaceSettingsDeleteDialogMessage(server.name),
            confirmLabel: l10n.workspaceSettingsDeleteConfirmLabel,
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
          content: Text(
            failure.message ?? l10n.workspaceSettingsDeleteFailed,
          ),
        ),
      );
    }
  }

  Future<void> _leaveServer(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => ConfirmServerActionDialog(
            title: l10n.workspaceSettingsLeaveDialogTitle,
            message: l10n.workspaceSettingsLeaveDialogMessage(server.name),
            confirmLabel: l10n.workspaceSettingsLeaveConfirmLabel,
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
          content: Text(
            failure.message ?? l10n.workspaceSettingsLeaveFailed,
          ),
        ),
      );
    }
  }
}
