import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_status_tokens.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/machines/application/machines_realtime_binding.dart';
import 'package:slock_app/features/machines/application/machines_state.dart';
import 'package:slock_app/features/machines/application/machines_store.dart';
import 'package:slock_app/features/machines/data/machine_item.dart';
import 'package:slock_app/features/machines/data/machines_repository_provider.dart';
import 'package:slock_app/features/machines/presentation/page/workspaces_page.dart';
import 'package:slock_app/l10n/l10n.dart';

class MachinesPage extends StatelessWidget {
  MachinesPage({super.key, required String serverId})
      : _serverId = ServerScopeId(serverId);

  final ServerScopeId _serverId;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [currentMachinesServerIdProvider.overrideWithValue(_serverId)],
      child: const _MachinesScreen(),
    );
  }
}

class _MachinesScreen extends ConsumerStatefulWidget {
  const _MachinesScreen();

  @override
  ConsumerState<_MachinesScreen> createState() => _MachinesScreenState();
}

class _MachinesScreenState extends ConsumerState<_MachinesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(machinesStoreProvider.notifier).ensureLoaded(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(machinesRealtimeBindingProvider);
    final state = ref.watch(machinesStoreProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.machinesPageTitle)),
      floatingActionButton: state.status == MachinesStatus.success
          ? FloatingActionButton.extended(
              key: const ValueKey('machines-create-fab'),
              onPressed: state.isCreating ? null : _createMachine,
              icon: state.isCreating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(context.l10n.machinesAddButton),
            )
          : null,
      body: switch (state.status) {
        MachinesStatus.initial || MachinesStatus.loading => const Center(
            key: ValueKey('machines-loading'),
            child: CircularProgressIndicator(),
          ),
        MachinesStatus.failure => _MachinesFailureView(
            message: state.failure?.userMessage(context.l10n) ??
                context.l10n.machinesLoadFailed,
            onRetry: ref.read(machinesStoreProvider.notifier).load,
          ),
        MachinesStatus.success => _MachinesSuccessView(
            state: state,
            serverId: ref.read(currentMachinesServerIdProvider),
            onRefresh: ref.read(machinesStoreProvider.notifier).load,
            onCreate: _createMachine,
            onRename: _renameMachine,
            onRotateApiKey: _rotateApiKey,
            onDelete: _deleteMachine,
          ),
      },
    );
  }

  Future<void> _createMachine() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final name = await _showMachineNameDialog(
      title: l10n.machinesRegisterTitle,
      actionLabel: l10n.machinesRegisterAction,
      initialValue: '',
      helperText: l10n.machinesRegisterHelper,
    );
    if (name == null) {
      return;
    }

    try {
      final result = await ref
          .read(machinesStoreProvider.notifier)
          .registerMachine(name: name);
      if (!mounted) {
        return;
      }
      await _showApiKeyDialog(
        machineName: result.machine.name,
        apiKey: result.apiKey,
        title: l10n.machinesRegisteredTitle,
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

  Future<void> _renameMachine(MachineItem machine) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final name = await _showMachineNameDialog(
      title: l10n.machinesRenameTitle,
      actionLabel: l10n.machinesRenameSaveAction,
      initialValue: machine.name,
      helperText: l10n.machinesRenameHelper,
    );
    if (name == null || name == machine.name) {
      return;
    }

    try {
      await ref
          .read(machinesStoreProvider.notifier)
          .renameMachine(machine.id, name: name);
      if (!mounted) {
        return;
      }
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.machinesRenamedSnackbar)));
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(failure.userMessage(l10n))),
      );
    }
  }

  Future<void> _rotateApiKey(MachineItem machine) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final apiKey = await ref
          .read(machinesStoreProvider.notifier)
          .rotateMachineApiKey(machine.id);
      if (!mounted) {
        return;
      }
      await _showApiKeyDialog(
        machineName: machine.name,
        apiKey: apiKey,
        title: l10n.machinesRotatedApiKeyTitle,
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

  Future<void> _deleteMachine(MachineItem machine) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(l10n.machinesDeleteTitle),
              content: Text(
                l10n.machinesDeleteMessage(machine.name),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.machinesDeleteCancel),
                ),
                FilledButton(
                  key: const ValueKey('machines-confirm-delete'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.machinesDeleteConfirm),
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
      await ref.read(machinesStoreProvider.notifier).deleteMachine(machine.id);
      if (!mounted) {
        return;
      }
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.machinesDeletedSnackbar)));
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(failure.userMessage(l10n))),
      );
    }
  }

  Future<String?> _showMachineNameDialog({
    required String title,
    required String actionLabel,
    required String initialValue,
    required String helperText,
  }) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return _MachineNameDialog(
          title: title,
          actionLabel: actionLabel,
          initialValue: initialValue,
          helperText: helperText,
        );
      },
    );
  }

  Future<void> _showApiKeyDialog({
    required String machineName,
    required String apiKey,
    required String title,
  }) async {
    if (apiKey.isEmpty) {
      return;
    }

    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.machinesCopyApiKeyMessage(machineName)),
              const SizedBox(height: 12),
              Text(l10n.machinesApiKeyRevealedNote),
              const SizedBox(height: 16),
              SelectableText(
                apiKey,
                key: const ValueKey('machine-api-key-value'),
              ),
            ],
          ),
          actions: [
            TextButton(
              key: const ValueKey('machines-copy-api-key'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: apiKey));
                if (!context.mounted) {
                  return;
                }
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.machinesApiKeyCopied)),
                );
              },
              child: Text(l10n.machinesCopyButton),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.machinesDoneButton),
            ),
          ],
        );
      },
    );
  }
}

class _MachinesFailureView extends StatelessWidget {
  const _MachinesFailureView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('machines-error'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.l10n.machinesRetryButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _MachinesSuccessView extends StatelessWidget {
  const _MachinesSuccessView({
    required this.state,
    required this.serverId,
    required this.onRefresh,
    required this.onCreate,
    required this.onRename,
    required this.onRotateApiKey,
    required this.onDelete,
  });

  final MachinesState state;
  final ServerScopeId serverId;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onCreate;
  final Future<void> Function(MachineItem machine) onRename;
  final Future<void> Function(MachineItem machine) onRotateApiKey;
  final Future<void> Function(MachineItem machine) onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final connectedCount = state.items.where((item) => item.isOnline).length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: ValueKey(state.items.isEmpty ? 'machines-empty' : 'machines-list'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Card(
            key: const ValueKey('machines-summary-card'),
            child: ListTile(
              title: Text(l10n.machinesSummaryCount(state.items.length)),
              subtitle: Text(l10n.machinesSummaryOnline(connectedCount)),
              trailing: state.latestDaemonVersion == null
                  ? null
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(l10n.machinesLatestDaemon),
                        Text(state.latestDaemonVersion!),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          if (state.items.isEmpty)
            _MachinesEmptyCard(isCreating: state.isCreating, onCreate: onCreate)
          else
            for (final machine in state.items) ...[
              _MachineCard(
                machine: machine,
                isBusy: state.isBusy(machine.id),
                serverId: serverId,
                onRename: () => onRename(machine),
                onRotateApiKey: () => onRotateApiKey(machine),
                onDelete: () => onDelete(machine),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _MachinesEmptyCard extends StatelessWidget {
  const _MachinesEmptyCard({required this.isCreating, required this.onCreate});

  final bool isCreating;
  final Future<void> Function() onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.memory_outlined, size: 40),
            const SizedBox(height: 12),
            Text(
              l10n.machinesEmptyTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.machinesEmptyDescription,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('machines-create-empty'),
              onPressed: isCreating ? null : onCreate,
              icon: const Icon(Icons.add),
              label: Text(l10n.machinesRegisterButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _MachineCard extends StatelessWidget {
  const _MachineCard({
    required this.machine,
    required this.isBusy,
    required this.serverId,
    required this.onRename,
    required this.onRotateApiKey,
    required this.onDelete,
  });

  final MachineItem machine;
  final bool isBusy;
  final ServerScopeId serverId;
  final Future<void> Function() onRename;
  final Future<void> Function() onRotateApiKey;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: ValueKey('machine-${machine.id}'),
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
                      Text(machine.name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatusChip(status: machine.status),
                          if (machine.apiKeyPrefix != null)
                            Chip(
                              label: Text(
                                context.l10n.machinesApiKeyPrefix(
                                    machine.apiKeyPrefix!),
                              ),
                            ),
                          ...machine.runtimes.map(
                            (runtime) => Chip(label: Text(runtime)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isBusy)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  PopupMenuButton<_MachineAction>(
                    key: ValueKey('machine-actions-${machine.id}'),
                    onSelected: (action) {
                      switch (action) {
                        case _MachineAction.workspaces:
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => WorkspacesPage(
                                serverId: serverId.value,
                                machineId: machine.id,
                                machineName: machine.name,
                              ),
                            ),
                          );
                        case _MachineAction.rename:
                          onRename();
                        case _MachineAction.rotateApiKey:
                          onRotateApiKey();
                        case _MachineAction.delete:
                          onDelete();
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: _MachineAction.workspaces,
                        child: Text(ctx.l10n.machinesMenuWorkspaces),
                      ),
                      PopupMenuItem(
                        value: _MachineAction.rename,
                        child: Text(ctx.l10n.machinesMenuRename),
                      ),
                      PopupMenuItem(
                        value: _MachineAction.rotateApiKey,
                        child: Text(ctx.l10n.machinesMenuRotateApiKey),
                      ),
                      PopupMenuItem(
                        value: _MachineAction.delete,
                        child: Text(ctx.l10n.machinesMenuDelete),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (machine.hostname != null)
                  _MachineMeta(
                    label: context.l10n.machinesMetaHost,
                    value: machine.hostname!,
                  ),
                if (machine.os != null)
                  _MachineMeta(
                    label: context.l10n.machinesMetaOs,
                    value: machine.os!,
                  ),
                if (machine.daemonVersion != null)
                  _MachineMeta(
                    label: context.l10n.machinesMetaDaemon,
                    value: machine.daemonVersion!,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MachineMeta extends StatelessWidget {
  const _MachineMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyMedium,
        children: [
          TextSpan(
            text: '$label: ',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      'online' => AppStatusTone.success,
      'offline' => AppStatusTone.neutral,
      'error' => AppStatusTone.error,
      _ => AppStatusTone.info,
    };
    final colors = appStatusColors(Theme.of(context).colorScheme, tone);

    return Chip(
      label: Text(_statusLabel(status, context)),
      backgroundColor: colors.container,
      labelStyle: TextStyle(color: colors.onContainer),
    );
  }

  String _statusLabel(String raw, BuildContext context) {
    final l10n = context.l10n;
    return switch (raw) {
      'online' => l10n.machinesStatusOnline,
      'offline' => l10n.machinesStatusOffline,
      'error' => l10n.machinesStatusError,
      _ => raw,
    };
  }
}

class _MachineNameDialog extends StatefulWidget {
  const _MachineNameDialog({
    required this.title,
    required this.actionLabel,
    required this.initialValue,
    required this.helperText,
  });

  final String title;
  final String actionLabel;
  final String initialValue;
  final String helperText;

  @override
  State<_MachineNameDialog> createState() => _MachineNameDialogState();
}

class _MachineNameDialogState extends State<_MachineNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.helperText),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('machines-name-field'),
            controller: _controller,
            autofocus: true,
            decoration:
                InputDecoration(labelText: context.l10n.machinesNameLabel),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.machinesNameDialogCancel),
        ),
        FilledButton(
          key: const ValueKey('machines-name-submit'),
          onPressed: _submit,
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      return;
    }
    Navigator.of(context).pop(value);
  }
}

enum _MachineAction { workspaces, rename, rotateApiKey, delete }
