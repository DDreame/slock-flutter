import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/l10n/l10n.dart';

// ---------------------------------------------------------------------------
// Create task dialog extracted from tasks_page.dart.
// ---------------------------------------------------------------------------

class CreateTaskDialog extends StatefulWidget {
  const CreateTaskDialog({
    super.key,
    required this.channels,
    required this.onCreate,
  });

  final List<HomeChannelSummary> channels;
  final Future<void> Function(String channelId, String title) onCreate;

  @override
  State<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<CreateTaskDialog> {
  final _titleController = TextEditingController();
  late String _selectedChannelId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedChannelId = widget.channels.first.scopeId.value;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      key: const ValueKey('create-task-dialog'),
      title: Text(l10n.tasksCreateTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            key: const ValueKey('task-channel-dropdown'),
            initialValue: _selectedChannelId,
            decoration:
                InputDecoration(labelText: l10n.tasksCreateChannelLabel),
            items: [
              for (final channel in widget.channels)
                DropdownMenuItem(
                  value: channel.scopeId.value,
                  child: Text(channel.name),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _selectedChannelId = value);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('task-title-field'),
            controller: _titleController,
            decoration: InputDecoration(labelText: l10n.tasksCreateTitleLabel),
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.tasksCreateCancel),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.tasksCreateConfirm),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _isSubmitting = true);
    await widget.onCreate(_selectedChannelId, title);
    if (mounted) setState(() => _isSubmitting = false);
  }
}
