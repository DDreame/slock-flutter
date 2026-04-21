import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_session_store.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';

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
  late final ScrollController _scrollController;
  late final bool _restoredFromSession;
  ProviderSubscription<ConversationDetailState>? _stateSubscription;
  bool _didApplyInitialLanding = false;
  double? _olderLoadAnchorOffset;
  double? _olderLoadAnchorMaxExtent;

  @override
  void initState() {
    super.initState();
    final target = ref.read(currentConversationDetailTargetProvider);
    final cachedSession =
        ref.read(conversationDetailSessionStoreProvider)[target];
    _composerController = TextEditingController();
    _composerFocusNode = FocusNode();
    _restoredFromSession = cachedSession != null;
    _scrollController = ScrollController(
      initialScrollOffset: cachedSession?.scrollOffset ?? 0,
    )..addListener(_handleScroll);
    _stateSubscription = ref.listenManual<ConversationDetailState>(
      conversationDetailStoreProvider,
      _handleStateChange,
      fireImmediately: true,
    );
    Future.microtask(
      () => ref.read(conversationDetailStoreProvider.notifier).ensureLoaded(),
    );
  }

  @override
  void dispose() {
    _stateSubscription?.close();
    if (_scrollController.hasClients) {
      ref
          .read(conversationDetailStoreProvider.notifier)
          .updateViewportOffset(_scrollController.offset);
    }
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _composerController.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(
      currentOpenConversationRegistrationProvider(
        ref.read(currentConversationDetailTargetProvider),
      ),
    );
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
              onPickAttachment: ref
                  .read(conversationDetailStoreProvider.notifier)
                  .addPendingAttachment,
              onRemoveAttachment: ref
                  .read(conversationDetailStoreProvider.notifier)
                  .removePendingAttachment,
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
        ConversationDetailStatus.success => _ConversationMessageList(
            controller: _scrollController,
            state: state,
          ),
      },
    );
  }

  Future<void> _handleSend() async {
    await ref.read(conversationDetailStoreProvider.notifier).send();
    final state = ref.read(conversationDetailStoreProvider);
    if (state.sendFailure == null &&
        state.draft.isEmpty &&
        state.pendingAttachments.isEmpty) {
      _composerFocusNode.unfocus();
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    ref
        .read(conversationDetailStoreProvider.notifier)
        .updateViewportOffset(_scrollController.offset);

    if (_scrollController.offset > 80) {
      return;
    }

    final state = ref.read(conversationDetailStoreProvider);
    if (state.status != ConversationDetailStatus.success ||
        state.isLoadingOlder ||
        !state.hasOlder) {
      return;
    }

    _olderLoadAnchorOffset = _scrollController.offset;
    _olderLoadAnchorMaxExtent = _scrollController.position.maxScrollExtent;
    ref.read(conversationDetailStoreProvider.notifier).loadOlder();
  }

  void _handleStateChange(
    ConversationDetailState? previous,
    ConversationDetailState next,
  ) {
    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _syncScrollState(previous, next);
      });
      return;
    }
    _syncScrollState(previous, next);
  }

  void _syncScrollState(
    ConversationDetailState? previous,
    ConversationDetailState next,
  ) {
    if (!_scrollController.hasClients) {
      return;
    }

    if (!_didApplyInitialLanding &&
        !_restoredFromSession &&
        next.status == ConversationDetailStatus.success &&
        next.messages.isNotEmpty) {
      _didApplyInitialLanding = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) {
          return;
        }
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    }

    if (previous?.isLoadingOlder == true &&
        next.status == ConversationDetailStatus.success &&
        !next.isLoadingOlder &&
        next.messages.length > (previous?.messages.length ?? 0) &&
        _olderLoadAnchorOffset != null &&
        _olderLoadAnchorMaxExtent != null) {
      final anchorOffset = _olderLoadAnchorOffset!;
      final previousMaxExtent = _olderLoadAnchorMaxExtent!;
      _olderLoadAnchorOffset = null;
      _olderLoadAnchorMaxExtent = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) {
          return;
        }
        final maxExtentDelta =
            _scrollController.position.maxScrollExtent - previousMaxExtent;
        _scrollController.jumpTo(anchorOffset + maxExtentDelta);
      });
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
  const _ConversationMessageList({
    required this.controller,
    required this.state,
  });

  final ScrollController controller;
  final ConversationDetailState state;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const ValueKey('conversation-success'),
      controller: controller,
      padding: const EdgeInsets.all(16),
      itemCount: state.messages.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _ConversationHistoryHeader(state: state);
        }
        final message = state.messages[index - 1];
        return _ConversationMessageCard(message: message);
      },
    );
  }
}

class _ConversationHistoryHeader extends StatelessWidget {
  const _ConversationHistoryHeader({required this.state});

  final ConversationDetailState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingOlder) {
      return const Center(
        key: ValueKey('conversation-loading-older'),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (state.hasOlder) {
      return const Center(
        key: ValueKey('conversation-has-older'),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text('Pull up to load older messages'),
        ),
      );
    }

    if (state.historyLimited) {
      return const Center(
        key: ValueKey('conversation-history-limited'),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text('Earlier history is limited.'),
        ),
      );
    }

    return const SizedBox.shrink(
        key: ValueKey('conversation-history-complete'));
  }
}

class _ConversationComposer extends StatelessWidget {
  const _ConversationComposer({
    required this.controller,
    required this.focusNode,
    required this.state,
    required this.onChanged,
    required this.onSend,
    required this.onPickAttachment,
    required this.onRemoveAttachment,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ConversationDetailState state;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onSend;
  final ValueChanged<PendingAttachment> onPickAttachment;
  final ValueChanged<int> onRemoveAttachment;

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
            if (state.pendingAttachments.isNotEmpty) ...[
              Wrap(
                key: const ValueKey('composer-pending-attachments'),
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < state.pendingAttachments.length; i++)
                    Chip(
                      key: ValueKey('pending-attachment-$i'),
                      avatar: const Icon(Icons.attach_file, size: 16),
                      label: Text(
                        state.pendingAttachments[i].name,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onDeleted: () => onRemoveAttachment(i),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                IconButton(
                  key: const ValueKey('composer-attach'),
                  icon: const Icon(Icons.attach_file),
                  onPressed: state.isSending ? null : () => _pickFile(context),
                ),
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

  Future<void> _pickFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) {
      return;
    }
    final file = result.files.first;
    if (file.path == null) {
      return;
    }
    final extension = file.extension ?? '';
    final mimeType = _mimeFromExtension(extension);
    onPickAttachment(PendingAttachment(
      path: file.path!,
      name: file.name,
      mimeType: mimeType,
    ));
  }

  static String _mimeFromExtension(String ext) {
    return switch (ext.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'txt' => 'text/plain',
      'mp4' => 'video/mp4',
      'mp3' => 'audio/mpeg',
      _ => 'application/octet-stream',
    };
  }
}

class _ConversationMessageCard extends StatelessWidget {
  const _ConversationMessageCard({required this.message});

  final ConversationMessageSummary message;

  @override
  Widget build(BuildContext context) {
    final timestamp = _formatTimestamp(message.createdAt);
    final theme = Theme.of(context);

    return Container(
      key: ValueKey('message-${message.id}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.threadId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'In thread',
                key: const ValueKey('message-thread-indicator'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  message.senderLabel,
                  style: theme.textTheme.labelMedium,
                ),
              ),
              Text(timestamp, style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          _MessageContentBody(message: message),
          if (message.attachments != null && message.attachments!.isNotEmpty)
            _AttachmentSection(attachments: message.attachments!),
        ],
      ),
    );
  }
}

class _MessageContentBody extends StatelessWidget {
  const _MessageContentBody({required this.message});

  final ConversationMessageSummary message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = message.isSystem
        ? theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)
        : theme.textTheme.bodyMedium;

    final spans = _buildLinkifiedSpans(message.content, baseStyle, theme);
    if (spans.length == 1 && spans.first is! WidgetSpan) {
      return Text.rich(spans.first, key: const ValueKey('message-content'));
    }
    return Text.rich(
      TextSpan(children: spans),
      key: const ValueKey('message-content'),
    );
  }
}

final _urlPattern = RegExp(
  r'https?://[^\s<>\[\]()]+',
  caseSensitive: false,
);

List<InlineSpan> _buildLinkifiedSpans(
  String text,
  TextStyle? baseStyle,
  ThemeData theme,
) {
  final matches = _urlPattern.allMatches(text).toList();
  if (matches.isEmpty) {
    return [TextSpan(text: text, style: baseStyle)];
  }

  final linkStyle = (baseStyle ?? const TextStyle()).copyWith(
    color: theme.colorScheme.primary,
    decoration: TextDecoration.underline,
  );

  final spans = <InlineSpan>[];
  var lastEnd = 0;
  for (final match in matches) {
    if (match.start > lastEnd) {
      spans.add(TextSpan(
          text: text.substring(lastEnd, match.start), style: baseStyle));
    }
    spans.add(TextSpan(text: match.group(0), style: linkStyle));
    lastEnd = match.end;
  }
  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
  }
  return spans;
}

class _AttachmentSection extends StatelessWidget {
  const _AttachmentSection({required this.attachments});

  final List<MessageAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        key: const ValueKey('message-attachments'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final attachment in attachments)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.attach_file,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      attachment.name,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    attachment.type,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
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
