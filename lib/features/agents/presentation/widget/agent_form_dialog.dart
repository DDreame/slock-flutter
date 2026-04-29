import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/machines/data/machine_item.dart';
import 'package:slock_app/features/machines/data/machines_repository.dart';

const _serverHeaderName = 'X-Server-Id';

const _runtimeLabels = <String, String>{
  'claude': 'Claude Code',
  'codex': 'Codex CLI',
  'kimi': 'Kimi CLI',
  'copilot': 'Copilot CLI',
  'cursor': 'Cursor CLI',
  'gemini': 'Gemini CLI',
};

const _fallbackModelsByRuntime = <String, List<_AgentModelOption>>{
  'claude': [
    _AgentModelOption(id: 'sonnet', label: 'Sonnet'),
    _AgentModelOption(id: 'opus', label: 'Opus'),
    _AgentModelOption(id: 'haiku', label: 'Haiku'),
  ],
  'codex': [
    _AgentModelOption(id: 'gpt-5.5', label: 'GPT-5.5'),
    _AgentModelOption(id: 'gpt-5.4', label: 'GPT-5.4'),
    _AgentModelOption(id: 'gpt-5.3-codex', label: 'GPT-5.3 Codex'),
    _AgentModelOption(id: 'gpt-5.2-codex', label: 'GPT-5.2 Codex'),
    _AgentModelOption(id: 'gpt-5.2', label: 'GPT-5.2'),
    _AgentModelOption(id: 'gpt-5', label: 'GPT-5'),
  ],
  'copilot': [
    _AgentModelOption(id: 'gpt-5.4', label: 'GPT-5.4'),
    _AgentModelOption(id: 'gpt-5.2', label: 'GPT-5.2'),
    _AgentModelOption(id: 'claude-4-sonnet', label: 'Claude 4 Sonnet'),
    _AgentModelOption(id: 'claude-4.5-sonnet', label: 'Claude 4.5 Sonnet'),
  ],
  'cursor': [
    _AgentModelOption(id: 'composer-2-fast', label: 'Composer 2 Fast'),
    _AgentModelOption(id: 'composer-2', label: 'Composer 2'),
    _AgentModelOption(id: 'auto', label: 'Auto'),
  ],
  'gemini': [
    _AgentModelOption(
      id: 'gemini-3.1-pro-preview',
      label: 'Gemini 3.1 Pro (Preview)',
    ),
    _AgentModelOption(
      id: 'gemini-3-flash-preview',
      label: 'Gemini 3 Flash (Preview)',
    ),
    _AgentModelOption(id: 'gemini-2.5-pro', label: 'Gemini 2.5 Pro'),
    _AgentModelOption(id: 'gemini-2.5-flash', label: 'Gemini 2.5 Flash'),
  ],
  'kimi': [_AgentModelOption(id: 'default', label: 'Configured Default')],
};

const _reasoningEffortOptions = <_AgentModelOption>[
  _AgentModelOption(id: 'low', label: 'Low'),
  _AgentModelOption(id: 'medium', label: 'Medium'),
  _AgentModelOption(id: 'high', label: 'High'),
  _AgentModelOption(id: 'xhigh', label: 'Extra High'),
];

const _reasoningRuntimes = {'codex', 'copilot'};

class AgentFormDialog extends ConsumerStatefulWidget {
  const AgentFormDialog({super.key, required this.serverId, this.initialAgent});

  final String serverId;
  final AgentItem? initialAgent;

  bool get isEditing => initialAgent != null;

  @override
  ConsumerState<AgentFormDialog> createState() => _AgentFormDialogState();
}

class _AgentFormDialogState extends ConsumerState<AgentFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _modelController;

  List<MachineItem> _machines = const [];
  List<_AgentModelOption> _modelSuggestions = const [];
  bool _isLoadingMachines = true;
  bool _isLoadingModels = false;
  String? _machinesError;
  String? _formError;
  String? _selectedMachineId;
  String? _selectedRuntime;
  String _reasoningEffort = 'medium';

  @override
  void initState() {
    super.initState();
    final agent = widget.initialAgent;
    _nameController = TextEditingController(text: agent?.name ?? '');
    _descriptionController = TextEditingController(
      text: agent?.description ?? '',
    );
    _modelController = TextEditingController(text: agent?.model ?? '');
    _selectedMachineId = agent?.machineId;
    _selectedRuntime = agent?.runtime;
    _reasoningEffort = agent?.reasoningEffort ?? _reasoningEffort;
    _loadMachines();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  MachineItem? get _selectedMachine {
    final machineId = _selectedMachineId;
    if (machineId == null) {
      return null;
    }
    for (final machine in _machines) {
      if (machine.id == machineId) {
        return machine;
      }
    }
    return null;
  }

  Options get _serverOptions =>
      Options(headers: {_serverHeaderName: widget.serverId});

  Future<void> _loadMachines() async {
    setState(() {
      _isLoadingMachines = true;
      _machinesError = null;
    });

    try {
      final response = await ref.read(appDioClientProvider).get<Object?>(
            '/servers/${widget.serverId}/machines',
            options: _serverOptions,
          );
      final snapshot = parseMachinesSnapshot(response.data);
      if (!mounted) {
        return;
      }

      setState(() {
        _machines = snapshot.items;
        _isLoadingMachines = false;

        final selectedMachineId = _selectedMachineId;
        if (selectedMachineId == null ||
            !_machines.any((machine) => machine.id == selectedMachineId)) {
          _selectedMachineId = _machines.isEmpty ? null : _machines.first.id;
        }

        _syncRuntimeForSelectedMachine();
        if (_modelController.text.trim().isEmpty) {
          _seedDefaultModel(overwrite: true);
        }
      });

      await _loadRuntimeModels();
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingMachines = false;
        _machinesError = failure.message ?? 'Failed to load machines.';
      });
    }
  }

  void _syncRuntimeForSelectedMachine() {
    final machine = _selectedMachine;
    final runtimes = machine?.runtimes ?? const <String>[];
    if (runtimes.isEmpty) {
      _selectedRuntime = null;
      return;
    }
    final currentRuntime = _selectedRuntime;
    if (currentRuntime != null && runtimes.contains(currentRuntime)) {
      return;
    }
    String? supportedRuntime;
    for (final runtime in runtimes) {
      if (_runtimeLabels.containsKey(runtime)) {
        supportedRuntime = runtime;
        break;
      }
    }
    _selectedRuntime = supportedRuntime ?? runtimes.first;
  }

  Future<void> _loadRuntimeModels() async {
    final machineId = _selectedMachineId;
    final runtime = _selectedRuntime;
    if (machineId == null || runtime == null) {
      setState(() {
        _modelSuggestions = const [];
        _isLoadingModels = false;
      });
      return;
    }

    final fallback = _fallbackModelsForRuntime(runtime);

    setState(() {
      _isLoadingModels = true;
      _modelSuggestions = fallback;
    });

    try {
      final response = await ref.read(appDioClientProvider).get<Object?>(
            '/servers/${widget.serverId}/machines/$machineId/runtime-models/$runtime',
            options: _serverOptions,
          );
      final payload = _RuntimeModelPayload.fromObject(response.data);
      final suggestions = payload.models.isEmpty ? fallback : payload.models;
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingModels = false;
        _modelSuggestions = suggestions;
        final defaultModel =
            payload.defaultModelId ?? _defaultModelForRuntime(runtime);
        final currentModel = _modelController.text.trim();
        if (currentModel.isEmpty ||
            currentModel == _defaultModelForRuntime(runtime)) {
          _modelController.text = defaultModel;
        }
      });
    } on AppFailure {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingModels = false;
        _modelSuggestions = fallback;
      });
    }
  }

  List<_AgentModelOption> _fallbackModelsForRuntime(String runtime) {
    return _fallbackModelsByRuntime[runtime] ?? const [];
  }

  String _defaultModelForRuntime(String runtime) {
    final fallback = _fallbackModelsForRuntime(runtime);
    if (fallback.isNotEmpty) {
      return fallback.first.id;
    }
    return 'default';
  }

  void _seedDefaultModel({required bool overwrite}) {
    final runtime = _selectedRuntime;
    if (runtime == null) {
      if (overwrite) {
        _modelController.clear();
      }
      return;
    }
    if (overwrite || _modelController.text.trim().isEmpty) {
      _modelController.text = _defaultModelForRuntime(runtime);
    }
  }

  void _selectMachine(String? machineId) {
    if (machineId == null) {
      return;
    }
    setState(() {
      _selectedMachineId = machineId;
      _syncRuntimeForSelectedMachine();
      _seedDefaultModel(overwrite: true);
      _formError = null;
    });
    _loadRuntimeModels();
  }

  void _selectRuntime(String? runtime) {
    if (runtime == null) {
      return;
    }
    setState(() {
      _selectedRuntime = runtime;
      _seedDefaultModel(overwrite: true);
      if (!_reasoningRuntimes.contains(runtime)) {
        _reasoningEffort = 'medium';
      }
      _formError = null;
    });
    _loadRuntimeModels();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final machineId = _selectedMachineId;
    final runtime = _selectedRuntime;
    final model = _modelController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _formError = 'Name is required.';
      });
      return;
    }
    if (machineId == null) {
      setState(() {
        _formError = 'Machine is required.';
      });
      return;
    }
    if (runtime == null || runtime.isEmpty) {
      setState(() {
        _formError = 'Runtime is required.';
      });
      return;
    }
    if (model.isEmpty) {
      setState(() {
        _formError = 'Model is required.';
      });
      return;
    }

    Navigator.of(context).pop(
      AgentMutationInput(
        name: name,
        description: _descriptionController.text.trim(),
        model: model,
        runtime: runtime,
        reasoningEffort:
            _reasoningRuntimes.contains(runtime) ? _reasoningEffort : null,
        machineId: machineId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final runtimeOptions = _selectedMachine?.runtimes ?? const <String>[];
    final showReasoning = _selectedRuntime != null &&
        _reasoningRuntimes.contains(_selectedRuntime);

    return AlertDialog(
      title: Text(widget.isEditing ? 'Edit Agent' : 'Create Agent'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: _isLoadingMachines
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : _machinesError != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_machinesError!),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _loadMachines,
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_formError != null) ...[
                          Text(
                            _formError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_machines.isEmpty) ...[
                          const Text('No machines available for this server.'),
                        ] else ...[
                          DropdownButtonFormField<String>(
                            key: const ValueKey('agent-form-machine'),
                            initialValue: _selectedMachineId,
                            decoration:
                                const InputDecoration(labelText: 'Machine'),
                            items: _machines
                                .map(
                                  (machine) => DropdownMenuItem<String>(
                                    value: machine.id,
                                    child: Text(
                                      machine.hostname == null
                                          ? machine.name
                                          : '${machine.name} (${machine.hostname})',
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: _selectMachine,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const ValueKey('agent-form-name'),
                            controller: _nameController,
                            decoration:
                                const InputDecoration(labelText: 'Name'),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const ValueKey('agent-form-description'),
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                            ),
                            minLines: 2,
                            maxLines: 4,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            key: const ValueKey('agent-form-runtime'),
                            initialValue: _selectedRuntime,
                            decoration:
                                const InputDecoration(labelText: 'Runtime'),
                            items: runtimeOptions
                                .map(
                                  (runtime) => DropdownMenuItem<String>(
                                    value: runtime,
                                    child: Text(
                                        _runtimeLabels[runtime] ?? runtime),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged:
                                runtimeOptions.isEmpty ? null : _selectRuntime,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const ValueKey('agent-form-model'),
                            controller: _modelController,
                            decoration: InputDecoration(
                              labelText: 'Model',
                              suffixIcon: _isLoadingModels
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            textInputAction: showReasoning
                                ? TextInputAction.next
                                : TextInputAction.done,
                          ),
                          if (_modelSuggestions.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _modelSuggestions
                                  .map(
                                    (option) => ActionChip(
                                      key: ValueKey('agent-model-${option.id}'),
                                      label: Text(option.label),
                                      onPressed: () {
                                        _modelController.text = option.id;
                                      },
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ],
                          if (showReasoning) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: const ValueKey('agent-form-reasoning'),
                              initialValue: _reasoningEffort,
                              decoration: const InputDecoration(
                                labelText: 'Reasoning Effort',
                              ),
                              items: _reasoningEffortOptions
                                  .map(
                                    (option) => DropdownMenuItem<String>(
                                      value: option.id,
                                      child: Text(option.label),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  _reasoningEffort = value;
                                });
                              },
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('agent-form-submit'),
          onPressed: _machines.isEmpty || _isLoadingMachines ? null : _submit,
          child: Text(widget.isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

class _RuntimeModelPayload {
  const _RuntimeModelPayload({this.models = const [], this.defaultModelId});

  final List<_AgentModelOption> models;
  final String? defaultModelId;

  factory _RuntimeModelPayload.fromObject(Object? payload) {
    final map = switch (payload) {
      final Map<String, dynamic> value => value,
      final Map value => Map<String, dynamic>.from(value),
      _ => const <String, dynamic>{},
    };

    final models = switch (map['models']) {
      final List raw => raw
          .whereType<Object>()
          .map(_AgentModelOption.fromObject)
          .whereType<_AgentModelOption>()
          .toList(growable: false),
      _ => const <_AgentModelOption>[],
    };

    return _RuntimeModelPayload(
      models: models,
      defaultModelId: _optionalString(map['default']),
    );
  }
}

class _AgentModelOption {
  const _AgentModelOption({required this.id, required this.label});

  final String id;
  final String label;

  static _AgentModelOption? fromObject(Object? payload) {
    final map = switch (payload) {
      final Map<String, dynamic> value => value,
      final Map value => Map<String, dynamic>.from(value),
      _ => null,
    };
    if (map == null) {
      return null;
    }

    final id = _optionalString(map['id']);
    if (id == null) {
      return null;
    }
    return _AgentModelOption(
      id: id,
      label: _optionalString(map['label']) ?? id,
    );
  }
}

String? _optionalString(Object? value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}
