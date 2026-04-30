import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_session_store.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/stores/session/session_store.dart';

typedef ConversationAppBarActionsBuilder = List<Widget> Function(
  BuildContext context,
  WidgetRef ref,
  ConversationDetailState state,
);

class ConversationDetailPage extends StatelessWidget {
  const ConversationDetailPage({
    super.key,
    required ConversationDetailTarget target,
    this.titleOverride,
    this.appBarActionsBuilder,
    this.registerOpenTarget = true,
  }) : _target = target;

  final ConversationDetailTarget _target;
  final String? titleOverride;
  final ConversationAppBarActionsBuilder? appBarActionsBuilder;
  final bool registerOpenTarget;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(_target),
      ],
      child: _ConversationDetailScreen(
        titleOverride: titleOverride,
        appBarActionsBuilder: appBarActionsBuilder,
        registerOpenTarget: registerOpenTarget,
      ),
    );
  }
}

class _ConversationDetailScreen extends ConsumerStatefulWidget {
  const _ConversationDetailScreen({
    this.titleOverride,
    this.appBarActionsBuilder,
    required this.registerOpenTarget,
  });

  final String? titleOverride;
  final ConversationAppBarActionsBuilder? appBarActionsBuilder;
  final bool registerOpenTarget;

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
    if (widget.registerOpenTarget) {
      ref.watch(
        currentOpenConversationRegistrationProvider(
          ref.read(currentConversationDetailTargetProvider),
        ),
      );
    }
    final state = ref.watch(conversationDetailStoreProvider);
    if (_composerController.text != state.draft) {
      _composerController.value = TextEditingValue(
        text: state.draft,
        selection: TextSelection.collapsed(offset: state.draft.length),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titleOverride ?? state.resolvedTitle),
        actions: [
          if (state.status == ConversationDetailStatus.success)
            IconButton(
              key: const ValueKey('conversation-search-toggle'),
              icon: Icon(
                state.isSearchActive ? Icons.search_off : Icons.search,
              ),
              onPressed: ref
                  .read(conversationDetailStoreProvider.notifier)
                  .toggleSearch,
            ),
          ...?widget.appBarActionsBuilder?.call(context, ref, state),
        ],
      ),
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
      body: Column(
        children: [
          if (state.isSearchActive)
            _ConversationSearchBar(
              state: state,
              onChanged: ref
                  .read(conversationDetailStoreProvider.notifier)
                  .updateSearchQuery,
              onNext: ref
                  .read(conversationDetailStoreProvider.notifier)
                  .nextSearchResult,
              onPrevious: ref
                  .read(conversationDetailStoreProvider.notifier)
                  .previousSearchResult,
              onClose: ref
                  .read(conversationDetailStoreProvider.notifier)
                  .toggleSearch,
            ),
          Expanded(
            child: switch (state.status) {
              ConversationDetailStatus.initial ||
              ConversationDetailStatus.loading =>
                const Center(
                  key: ValueKey('conversation-loading'),
                  child: CircularProgressIndicator(),
                ),
              ConversationDetailStatus.failure => _ConversationFailureView(
                  state: state,
                  onRetry: () => ref
                      .read(conversationDetailStoreProvider.notifier)
                      .retry(),
                ),
              ConversationDetailStatus.success when state.isEmpty =>
                _ConversationEmptyView(title: state.resolvedTitle),
              ConversationDetailStatus.success => _ConversationMessageList(
                  controller: _scrollController,
                  state: state,
                ),
            },
          ),
        ],
      ),
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
        return _ConversationMessageCard(
          target: state.target,
          message: message,
          highlightQuery: state.searchQuery,
        );
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

enum _ConversationMessageVisualKind { self, other, system, agent }

_ConversationMessageVisualKind _resolveConversationMessageVisualKind(
  ConversationMessageSummary message,
  String? currentUserId,
) {
  if (message.isSystem) {
    return _ConversationMessageVisualKind.system;
  }
  if (message.senderType == 'agent') {
    return _ConversationMessageVisualKind.agent;
  }
  if (currentUserId != null && message.senderId == currentUserId) {
    return _ConversationMessageVisualKind.self;
  }
  return _ConversationMessageVisualKind.other;
}

class _ConversationMessageCard extends ConsumerWidget {
  const _ConversationMessageCard({
    required this.target,
    required this.message,
    this.highlightQuery = '',
  });

  final ConversationDetailTarget target;
  final ConversationMessageSummary message;
  final String highlightQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timestamp = formatRelativeTime(message.createdAt);
    final theme = Theme.of(context);
    final savedIds = ref.watch(
      conversationDetailStoreProvider.select((s) => s.savedMessageIds),
    );
    final currentUserId =
        ref.watch(sessionStoreProvider.select((session) => session.userId));
    final isSaved = savedIds.contains(message.id);
    final visualKind =
        _resolveConversationMessageVisualKind(message, currentUserId);
    final senderLabel = switch (visualKind) {
      _ConversationMessageVisualKind.self => 'You',
      _ => message.senderLabel,
    };
    final shellAlignment = switch (visualKind) {
      _ConversationMessageVisualKind.self => Alignment.centerRight,
      _ConversationMessageVisualKind.system => Alignment.center,
      _ => Alignment.centerLeft,
    };
    final surfaceColor = switch (visualKind) {
      _ConversationMessageVisualKind.self => theme.colorScheme.primaryContainer,
      _ConversationMessageVisualKind.agent =>
        theme.colorScheme.tertiaryContainer,
      _ConversationMessageVisualKind.system =>
        theme.colorScheme.surfaceContainerHigh,
      _ConversationMessageVisualKind.other =>
        theme.colorScheme.surfaceContainerHighest,
    };
    final borderColor = switch (visualKind) {
      _ConversationMessageVisualKind.self => theme.colorScheme.primary,
      _ConversationMessageVisualKind.agent => theme.colorScheme.tertiary,
      _ConversationMessageVisualKind.system => theme.colorScheme.outline,
      _ConversationMessageVisualKind.other => theme.colorScheme.outlineVariant,
    };
    final foregroundColor = switch (visualKind) {
      _ConversationMessageVisualKind.self =>
        theme.colorScheme.onPrimaryContainer,
      _ConversationMessageVisualKind.agent =>
        theme.colorScheme.onTertiaryContainer,
      _ConversationMessageVisualKind.system =>
        theme.colorScheme.onSurfaceVariant,
      _ConversationMessageVisualKind.other => theme.colorScheme.onSurface,
    };
    final senderIcon = switch (visualKind) {
      _ConversationMessageVisualKind.agent => Icons.smart_toy_outlined,
      _ConversationMessageVisualKind.system => Icons.info_outline,
      _ => null,
    };
    final senderStyle = theme.textTheme.labelMedium?.copyWith(
      color: foregroundColor,
      fontWeight: FontWeight.w600,
    );
    final timestampStyle = theme.textTheme.bodySmall?.copyWith(
      color: foregroundColor.withValues(alpha: 0.78),
    );
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: foregroundColor,
      fontStyle: visualKind == _ConversationMessageVisualKind.system
          ? FontStyle.italic
          : null,
    );
    final bubble = Container(
      key: ValueKey('message-${message.id}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.threadId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InkWell(
                key: const ValueKey('message-thread-entry'),
                onTap: () {
                  context.push(
                    ThreadRouteTarget(
                      serverId: target.serverId.value,
                      parentChannelId: target.conversationId,
                      parentMessageId: message.id,
                      threadChannelId: message.threadId,
                    ).toLocation(),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.forum_outlined,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      message.replyCount != null && message.replyCount! > 0
                          ? '${message.replyCount} ${message.replyCount == 1 ? 'reply' : 'replies'}'
                          : 'In thread',
                      key: const ValueKey('message-thread-indicator'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            children: [
              if (senderIcon != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    senderIcon,
                    size: 14,
                    color: foregroundColor,
                  ),
                ),
              Expanded(
                child: Text(
                  senderLabel,
                  style: senderStyle,
                ),
              ),
              if (message.isPinned)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.push_pin,
                    size: 14,
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              if (isSaved)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.bookmark,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                ),
              Text(timestamp, style: timestampStyle),
            ],
          ),
          const SizedBox(height: 8),
          _MessageContentBody(
            message: message,
            highlightQuery: highlightQuery,
            baseStyle: bodyStyle,
            highlightColor: theme.colorScheme.secondaryContainer,
          ),
          if (message.attachments != null && message.attachments!.isNotEmpty)
            _AttachmentSection(attachments: message.attachments!),
        ],
      ),
    );

    return GestureDetector(
      onLongPress: () => _showMessageActions(context, ref, isSaved),
      child: Align(
        key: ValueKey('message-shell-${message.id}'),
        alignment: shellAlignment,
        child: switch (visualKind) {
          _ConversationMessageVisualKind.system =>
            SizedBox(width: double.infinity, child: bubble),
          _ => ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: bubble,
            ),
        },
      ),
    );
  }

  void _showMessageActions(
    BuildContext context,
    WidgetRef ref,
    bool isSaved,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('message-action-save'),
              leading:
                  Icon(isSaved ? Icons.bookmark_remove : Icons.bookmark_add),
              title: Text(isSaved ? 'Unsave message' : 'Save message'),
              onTap: () {
                Navigator.of(context).pop();
                ref
                    .read(conversationDetailStoreProvider.notifier)
                    .toggleSaveMessage(message.id);
              },
            ),
            ListTile(
              key: const ValueKey('message-action-pin'),
              leading: Icon(
                  message.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(message.isPinned ? 'Unpin message' : 'Pin message'),
              onTap: () {
                Navigator.of(context).pop();
                final notifier =
                    ref.read(conversationDetailStoreProvider.notifier);
                if (message.isPinned) {
                  notifier.unpinMessage(message.id);
                } else {
                  notifier.pinMessage(message.id);
                }
              },
            ),
            if (target.surface == ConversationSurface.channel)
              ListTile(
                key: const ValueKey('message-action-reply-thread'),
                leading: const Icon(Icons.forum_outlined),
                title: const Text('Reply in thread'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(
                    ThreadRouteTarget(
                      serverId: target.serverId.value,
                      parentChannelId: target.conversationId,
                      parentMessageId: message.id,
                      threadChannelId: message.threadId,
                    ).toLocation(),
                  );
                },
              ),
            if (target.surface == ConversationSurface.channel)
              ListTile(
                key: const ValueKey('message-action-create-task'),
                leading: const Icon(Icons.task_alt),
                title: const Text('Create task'),
                onTap: () {
                  Navigator.of(context).pop();
                  _convertMessageToTask(context, ref);
                },
              ),
            ListTile(
              key: const ValueKey('message-action-delete'),
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete message'),
              onTap: () {
                Navigator.of(context).pop();
                _confirmAndDeleteMessage(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndDeleteMessage(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete message?'),
            content: const Text('This message will be permanently deleted.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                key: const ValueKey('delete-message-confirm'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    try {
      await ref
          .read(conversationDetailStoreProvider.notifier)
          .deleteMessage(message.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Message deleted.')));
    } on AppFailure catch (failure) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(failure.message ?? 'Failed to delete message.'),
          ),
        );
    }
  }

  Future<void> _convertMessageToTask(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final repo = ref.read(tasksRepositoryProvider);
      await repo.convertMessageToTask(
        target.serverId,
        messageId: message.id,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Task created.')),
        );
    } on AppFailure catch (failure) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(failure.message ?? 'Failed to create task.'),
          ),
        );
    }
  }
}

class _MessageContentBody extends StatelessWidget {
  const _MessageContentBody({
    required this.message,
    this.highlightQuery = '',
    this.baseStyle,
    this.highlightColor,
  });

  final ConversationMessageSummary message;
  final String highlightQuery;
  final TextStyle? baseStyle;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBaseStyle = baseStyle ??
        (message.isSystem
            ? theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)
            : theme.textTheme.bodyMedium);

    if (highlightQuery.isNotEmpty) {
      return Text.rich(
        _buildHighlightedSpan(
          message.content,
          highlightQuery,
          effectiveBaseStyle,
          highlightColor ?? theme.colorScheme.primaryContainer,
        ),
        key: const ValueKey('message-content'),
      );
    }

    final spans = _buildLinkifiedSpans(
      message.content,
      effectiveBaseStyle,
      theme,
    );
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

TextSpan _buildHighlightedSpan(
  String text,
  String query,
  TextStyle? baseStyle,
  Color highlightColor,
) {
  if (query.isEmpty) {
    return TextSpan(text: text, style: baseStyle);
  }

  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final spans = <InlineSpan>[];
  var lastEnd = 0;

  var index = lowerText.indexOf(lowerQuery);
  while (index != -1) {
    if (index > lastEnd) {
      spans.add(
          TextSpan(text: text.substring(lastEnd, index), style: baseStyle));
    }
    spans.add(TextSpan(
      text: text.substring(index, index + query.length),
      style: (baseStyle ?? const TextStyle()).copyWith(
        backgroundColor: highlightColor,
        fontWeight: FontWeight.bold,
      ),
    ));
    lastEnd = index + query.length;
    index = lowerText.indexOf(lowerQuery, lastEnd);
  }

  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
  }

  if (spans.isEmpty) {
    return TextSpan(text: text, style: baseStyle);
  }
  return TextSpan(children: spans);
}

class _ConversationSearchBar extends StatefulWidget {
  const _ConversationSearchBar({
    required this.state,
    required this.onChanged,
    required this.onNext,
    required this.onPrevious,
    required this.onClose,
  });

  final ConversationDetailState state;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onClose;

  @override
  State<_ConversationSearchBar> createState() => _ConversationSearchBarState();
}

class _ConversationSearchBarState extends State<_ConversationSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.state.searchQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matchCount = widget.state.searchMatchIds.length;
    final currentMatch = widget.state.currentSearchMatchIndex;

    return Container(
      key: const ValueKey('conversation-search-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('conversation-search-input'),
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search in conversation...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: widget.onChanged,
            ),
          ),
          if (matchCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${currentMatch + 1}/$matchCount',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (matchCount > 1) ...[
            IconButton(
              key: const ValueKey('search-previous'),
              icon: const Icon(Icons.keyboard_arrow_up, size: 20),
              onPressed: widget.onPrevious,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              key: const ValueKey('search-next'),
              icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              onPressed: widget.onNext,
              visualDensity: VisualDensity.compact,
            ),
          ],
          IconButton(
            key: const ValueKey('search-close'),
            icon: const Icon(Icons.close, size: 20),
            onPressed: widget.onClose,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
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
              child: InkWell(
                key: ValueKey('attachment-tap-${attachment.name}'),
                onTap: attachment.url != null
                    ? () => launchUrl(
                          Uri.parse(attachment.url!),
                          mode: LaunchMode.externalApplication,
                        )
                    : null,
                borderRadius: BorderRadius.circular(4),
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
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: attachment.url != null
                              ? theme.colorScheme.primary
                              : null,
                          decoration: attachment.url != null
                              ? TextDecoration.underline
                              : null,
                        ),
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
            ),
        ],
      ),
    );
  }
}
