import 'package:flutter/material.dart';

class CreateChannelDialog extends StatefulWidget {
  const CreateChannelDialog({
    super.key,
    required this.onCreate,
    required this.onCancel,
    this.isSubmitting = false,
  });

  final ValueChanged<String> onCreate;
  final VoidCallback onCancel;
  final bool isSubmitting;

  @override
  State<CreateChannelDialog> createState() => _CreateChannelDialogState();
}

class _CreateChannelDialogState extends State<CreateChannelDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = _controller.text.trim();
    return AlertDialog(
      key: const ValueKey('create-channel-dialog'),
      title: const Text('Create channel'),
      content: TextField(
        key: const ValueKey('create-channel-name'),
        controller: _controller,
        enabled: !widget.isSubmitting,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Channel name'),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: widget.isSubmitting ? null : widget.onCancel,
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: widget.isSubmitting || name.isEmpty
              ? null
              : () => widget.onCreate(name),
          child: Text(widget.isSubmitting ? 'Creating...' : 'Create'),
        ),
      ],
    );
  }
}

class EditChannelDialog extends StatefulWidget {
  const EditChannelDialog({
    super.key,
    required this.currentName,
    required this.onSave,
    required this.onCancel,
    this.isSubmitting = false,
  });

  final String currentName;
  final ValueChanged<String> onSave;
  final VoidCallback onCancel;
  final bool isSubmitting;

  @override
  State<EditChannelDialog> createState() => _EditChannelDialogState();
}

class _EditChannelDialogState extends State<EditChannelDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = _controller.text.trim();
    final canSave = name.isNotEmpty && name != widget.currentName;
    return AlertDialog(
      key: const ValueKey('edit-channel-dialog'),
      title: const Text('Edit channel'),
      content: TextField(
        key: const ValueKey('edit-channel-name'),
        controller: _controller,
        enabled: !widget.isSubmitting,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Channel name'),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: widget.isSubmitting ? null : widget.onCancel,
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: widget.isSubmitting || !canSave
              ? null
              : () => widget.onSave(name),
          child: Text(widget.isSubmitting ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}

class ConfirmChannelActionDialog extends StatelessWidget {
  const ConfirmChannelActionDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.dialogKey,
    required this.onConfirm,
    required this.onCancel,
    this.isSubmitting = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Key dialogKey;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: dialogKey,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: isSubmitting ? null : onCancel,
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: isSubmitting ? null : onConfirm,
          child: Text(isSubmitting ? 'Working...' : confirmLabel),
        ),
      ],
    );
  }
}
