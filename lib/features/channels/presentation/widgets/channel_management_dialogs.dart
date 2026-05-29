import 'package:flutter/material.dart';
import 'package:slock_app/l10n/l10n.dart';

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
      title: Text(context.l10n.channelsDialogCreateTitle),
      content: TextField(
        key: const ValueKey('create-channel-name'),
        controller: _controller,
        enabled: !widget.isSubmitting,
        autofocus: true,
        decoration: InputDecoration(
            labelText: context.l10n.channelsDialogCreateNameLabel),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: widget.isSubmitting ? null : widget.onCancel,
          child: Text(context.l10n.channelsDialogCreateCancel),
        ),
        FilledButton(
          onPressed: widget.isSubmitting || name.isEmpty
              ? null
              : () => widget.onCreate(name),
          child: Text(widget.isSubmitting
              ? context.l10n.channelsDialogCreateSubmitting
              : context.l10n.channelsDialogCreateSubmit),
        ),
      ],
    );
  }
}

/// Result returned by [EditChannelDialog] when the user saves.
class EditChannelResult {
  const EditChannelResult({
    required this.name,
    required this.description,
    required this.isPrivate,
  });

  final String name;

  /// The description text. Empty string means "clear description".
  final String description;

  final bool isPrivate;
}

class EditChannelDialog extends StatefulWidget {
  const EditChannelDialog({
    super.key,
    required this.currentName,
    required this.onSave,
    required this.onCancel,
    this.currentDescription,
    this.currentIsPrivate = false,
    this.isSubmitting = false,
  });

  final String currentName;
  final String? currentDescription;
  final bool currentIsPrivate;
  final ValueChanged<EditChannelResult> onSave;
  final VoidCallback onCancel;
  final bool isSubmitting;

  @override
  State<EditChannelDialog> createState() => _EditChannelDialogState();
}

class _EditChannelDialogState extends State<EditChannelDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late bool _isPrivate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _descriptionController =
        TextEditingController(text: widget.currentDescription ?? '');
    _isPrivate = widget.currentIsPrivate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    if (name != widget.currentName) return true;
    if (description != (widget.currentDescription ?? '')) return true;
    if (_isPrivate != widget.currentIsPrivate) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final name = _nameController.text.trim();
    final canSave = name.isNotEmpty && _hasChanges;
    return AlertDialog(
      key: const ValueKey('edit-channel-dialog'),
      title: Text(context.l10n.channelsDialogEditTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('edit-channel-name'),
              controller: _nameController,
              enabled: !widget.isSubmitting,
              autofocus: true,
              decoration: InputDecoration(
                  labelText: context.l10n.channelsDialogEditNameLabel),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('edit-channel-description'),
              controller: _descriptionController,
              enabled: !widget.isSubmitting,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.l10n.channelsDialogEditDescriptionLabel,
                hintText: context.l10n.channelsDialogEditDescriptionHint,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              key: const ValueKey('edit-channel-private-switch'),
              title: Text(context.l10n.channelsDialogEditPrivateLabel),
              subtitle: Text(context.l10n.channelsDialogEditPrivateDescription),
              value: _isPrivate,
              contentPadding: EdgeInsets.zero,
              onChanged: widget.isSubmitting
                  ? null
                  : (value) => setState(() => _isPrivate = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.isSubmitting ? null : widget.onCancel,
          child: Text(context.l10n.channelsDialogEditCancel),
        ),
        FilledButton(
          onPressed: widget.isSubmitting || !canSave
              ? null
              : () => widget.onSave(EditChannelResult(
                    name: name,
                    description: _descriptionController.text.trim(),
                    isPrivate: _isPrivate,
                  )),
          child: Text(widget.isSubmitting
              ? context.l10n.channelsDialogEditSubmitting
              : context.l10n.channelsDialogEditSubmit),
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
          child: Text(context.l10n.channelsDialogConfirmCancel),
        ),
        FilledButton(
          onPressed: isSubmitting ? null : onConfirm,
          child: Text(isSubmitting
              ? context.l10n.channelsDialogConfirmWorking
              : confirmLabel),
        ),
      ],
    );
  }
}
