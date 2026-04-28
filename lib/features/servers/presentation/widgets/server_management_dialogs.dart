import 'package:flutter/material.dart';

class CreateServerDialog extends StatefulWidget {
  const CreateServerDialog({super.key});

  @override
  State<CreateServerDialog> createState() => _CreateServerDialogState();
}

class _CreateServerDialogState extends State<CreateServerDialog> {
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
      key: const ValueKey('create-server-dialog'),
      title: const Text('Create workspace'),
      content: TextField(
        key: const ValueKey('create-server-name'),
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Workspace name'),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('create-server-submit'),
          onPressed: name.isEmpty
              ? null
              : () => Navigator.of(context).pop(name),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class RenameServerDialog extends StatefulWidget {
  const RenameServerDialog({super.key, required this.currentName});

  final String currentName;

  @override
  State<RenameServerDialog> createState() => _RenameServerDialogState();
}

class _RenameServerDialogState extends State<RenameServerDialog> {
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
      key: const ValueKey('rename-server-dialog'),
      title: const Text('Rename workspace'),
      content: TextField(
        key: const ValueKey('rename-server-name'),
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Workspace name'),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('rename-server-submit'),
          onPressed: canSave ? () => Navigator.of(context).pop(name) : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class JoinServerDialog extends StatefulWidget {
  const JoinServerDialog({super.key});

  @override
  State<JoinServerDialog> createState() => _JoinServerDialogState();
}

class _JoinServerDialogState extends State<JoinServerDialog> {
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
    final token = _controller.text.trim();
    return AlertDialog(
      key: const ValueKey('join-server-dialog'),
      title: const Text('Join workspace'),
      content: TextField(
        key: const ValueKey('join-server-token'),
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Invite code or link',
          hintText: 'https://slock.ai/invite/token-123',
        ),
        minLines: 1,
        maxLines: 2,
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('join-server-submit'),
          onPressed: token.isEmpty
              ? null
              : () => Navigator.of(context).pop(token),
          child: const Text('Join'),
        ),
      ],
    );
  }
}

class ConfirmServerActionDialog extends StatelessWidget {
  const ConfirmServerActionDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmKey,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Key confirmKey;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: confirmKey,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
