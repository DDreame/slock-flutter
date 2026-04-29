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
      appBar: AppBar(title: const Text('Machines')),
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
              label: const Text('Add Machine'),
            )
          : null,
      body: switch (state.status) {
        MachinesStatus.initial || MachinesStatus.loading => const Center(
            key: ValueKey('machines-loading'),
            child: CircularProgressIndicator(),
          ),
        MachinesStatus.failure => _MachinesFailureView(
            message: state.failure?.message ?? 'Failed to load machines.',
            onRetry: ref.read(machinesStoreProvider.notifier).load,
          ),
        MachinesStatus.success => _MachinesSuccessView(
            state: state,
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
    final messenger = ScaffoldMessenger.of(context);
    final name = await _showMachineNameDialog(
      title: 'Register Machine',
      actionLabel: 'Register',
      initialValue: '',
      helperText: 'Create a machine and reveal its API key once.',
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
        title: 'Machine Registered',
      );
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(failure.message ?? 'Failed to register machine.'),
        ),
      );
    }
  }

  Future<void> _renameMachine(MachineItem machine) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = await _showMachineNameDialog(
      title: 'Rename Machine',
      actionLabel: 'Save',
      initialValue: machine.name,
      helperText: 'Update the machine label shown across the workspace.',
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
      messenger.showSnackBar(const SnackBar(content: Text('Machine renamed.')));
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(failure.message ?? 'Failed to rename machine.')),
      );
    }
  }

  Future<void> _rotateApiKey(MachineItem machine) async {
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
        title: 'Rotated API Key',
      );
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(failure.message ?? 'Failed to rotate machine API key.'),
        ),
      );
    }
  }

  Future<void> _deleteMachine(MachineItem machine) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete Machine?'),
              content: Text(
                'Delete ${machine.name}? This removes the machine from the server list.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const ValueKey('machines-confirm-delete'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Delete'),
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
      messenger.showSnackBar(const SnackBar(content: Text('Machine deleted.')));
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(failure.message ?? 'Failed to delete machine.')),
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
              Text('Copy the API key for $machineName now.'),
              const SizedBox(height: 12),
              const Text(
                'This key is only revealed at creation or rotation time.',
              ),
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
                  const SnackBar(content: Text('API key copied.')),
                );
              },
              child: const Text('Copy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
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
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _MachinesSuccessView extends StatelessWidget {
  const _MachinesSuccessView({
    required this.state,
    required this.onRefresh,
    required this.onCreate,
    required this.onRename,
    required this.onRotateApiKey,
    required this.onDelete,
  });

  final MachinesState state;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onCreate;
  final Future<void> Function(MachineItem machine) onRename;
  final Future<void> Function(MachineItem machine) onRotateApiKey;
  final Future<void> Function(MachineItem machine) onDelete;

  @override
  Widget build(BuildContext context) {
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
              title: Text('${state.items.length} machine(s)'),
              subtitle: Text('$connectedCount online'),
              trailing: state.latestDaemonVersion == null
                  ? null
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Latest daemon'),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.memory_outlined, size: 40),
            const SizedBox(height: 12),
            const Text(
              'No machines registered yet.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Register a machine to attach runtimes and admin operations to this server.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('machines-create-empty'),
              onPressed: isCreating ? null : onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Register Machine'),
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
    required this.onRename,
    required this.onRotateApiKey,
    required this.onDelete,
  });

  final MachineItem machine;
  final bool isBusy;
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
                            Chip(label: Text('Key ${machine.apiKeyPrefix}...')),
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
                        case _MachineAction.rename:
                          onRename();
                        case _MachineAction.rotateApiKey:
                          onRotateApiKey();
                        case _MachineAction.delete:
                          onDelete();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _MachineAction.rename,
                        child: Text('Rename'),
                      ),
                      PopupMenuItem(
                        value: _MachineAction.rotateApiKey,
                        child: Text('Rotate API Key'),
                      ),
                      PopupMenuItem(
                        value: _MachineAction.delete,
                        child: Text('Delete'),
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
                  _MachineMeta(label: 'Host', value: machine.hostname!),
                if (machine.os != null)
                  _MachineMeta(label: 'OS', value: machine.os!),
                if (machine.daemonVersion != null)
                  _MachineMeta(label: 'Daemon', value: machine.daemonVersion!),
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
      label: Text(_statusLabel(status)),
      backgroundColor: colors.container,
      labelStyle: TextStyle(color: colors.onContainer),
    );
  }

  String _statusLabel(String raw) {
    return switch (raw) {
      'online' => 'Online',
      'offline' => 'Offline',
      'error' => 'Error',
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
            decoration: const InputDecoration(labelText: 'Machine name'),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
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

enum _MachineAction { rename, rotateApiKey, delete }
