import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

class ConversationDetailPage extends StatelessWidget {
  const ConversationDetailPage({
    super.key,
    required ConversationDetailTarget target,
  }) : _target = target;

  final ConversationDetailTarget _target;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(_target),
      ],
      child: const _ConversationDetailScreen(),
    );
  }
}

class _ConversationDetailScreen extends ConsumerStatefulWidget {
  const _ConversationDetailScreen();

  @override
  ConsumerState<_ConversationDetailScreen> createState() =>
      _ConversationDetailScreenState();
}

class _ConversationDetailScreenState
    extends ConsumerState<_ConversationDetailScreen> {
  late final TextEditingController _composerController;
  late final FocusNode _composerFocusNode;

  @override
  void initState() {
    super.initState();
    _composerController = TextEditingController();
    _composerFocusNode = FocusNode();
    Future.microtask(
      () => ref.read(conversationDetailStoreProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    _composerController.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationDetailStoreProvider);
    if (_composerController.text != state.draft) {
      _composerController.value = TextEditingValue(
        text: state.draft,
        selection: TextSelection.collapsed(offset: state.draft.length),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(state.resolvedTitle)),
      bottomNavigationBar: state.status == ConversationDetailStatus.success
          ? _ConversationComposer(
              controller: _composerController,
              focusNode: _composerFocusNode,
              state: state,
              onChanged: ref
                  .read(conversationDetailStoreProvider.notifier)
                  .updateDraft,
              onSend: _handleSend,
            )
          : null,
      body: switch (state.status) {
        ConversationDetailStatus.initial ||
        ConversationDetailStatus.loading =>
          const Center(
            key: ValueKey('conversation-loading'),
            child: CircularProgressIndicator(),
          ),
        ConversationDetailStatus.failure => _ConversationFailureView(
            state: state,
            onRetry: () =>
                ref.read(conversationDetailStoreProvider.notifier).retry(),
          ),
        ConversationDetailStatus.success when state.isEmpty =>
          _ConversationEmptyView(title: state.resolvedTitle),
        ConversationDetailStatus.success =>
          _ConversationMessageList(state: state),
      },
    );
  }

  Future<void> _handleSend() async {
    await ref.read(conversationDetailStoreProvider.notifier).send();
    final state = ref.read(conversationDetailStoreProvider);
    if (state.sendFailure == null && state.draft.isEmpty) {
      _composerFocusNode.unfocus();
    }
  }
}

class _ConversationFailureView extends StatelessWidget {
  const _ConversationFailureView({required this.state, required this.onRetry});

  final ConversationDetailState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('conversation-error'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Could not load ${state.resolvedTitle}.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              state.failure?.message ?? 'Please try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _ConversationEmptyView extends StatelessWidget {
  const _ConversationEmptyView({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('conversation-empty'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No messages in $title yet.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ConversationMessageList extends StatelessWidget {
  const _ConversationMessageList({required this.state});

  final ConversationDetailState state;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const ValueKey('conversation-success'),
      padding: const EdgeInsets.all(16),
      itemCount: state.messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final message = state.messages[index];
        return _ConversationMessageCard(message: message);
      },
    );
  }
}

class _ConversationComposer extends StatelessWidget {
  const _ConversationComposer({
    required this.controller,
    required this.focusNode,
    required this.state,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ConversationDetailState state;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.sendFailure != null) ...[
              Text(
                state.sendFailure?.message ?? 'Failed to send message.',
                key: const ValueKey('composer-send-error'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('composer-input'),
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    onSubmitted: (_) => state.canSend ? onSend() : null,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Write a message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  key: const ValueKey('composer-send'),
                  onPressed: state.canSend ? onSend : null,
                  child: Text(state.isSending ? 'Sending...' : 'Send'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationMessageCard extends StatelessWidget {
  const _ConversationMessageCard({required this.message});

  final ConversationMessageSummary message;

  @override
  Widget build(BuildContext context) {
    final timestamp = _formatTimestamp(message.createdAt);

    return Container(
      key: ValueKey('message-${message.id}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  message.senderLabel,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              Text(timestamp, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message.content,
            style: message.isSystem
                ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    )
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

String _formatTimestamp(DateTime value) {
  final utcValue = value.toUtc();
  final month = switch (utcValue.month) {
    1 => 'Jan',
    2 => 'Feb',
    3 => 'Mar',
    4 => 'Apr',
    5 => 'May',
    6 => 'Jun',
    7 => 'Jul',
    8 => 'Aug',
    9 => 'Sep',
    10 => 'Oct',
    11 => 'Nov',
    _ => 'Dec',
  };
  final hour = utcValue.hour.toString().padLeft(2, '0');
  final minute = utcValue.minute.toString().padLeft(2, '0');
  return '$month ${utcValue.day}, $hour:$minute UTC';
}
