import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/features/conversation/presentation/widgets/markdown_message_body.dart';
import 'package:slock_app/features/conversation/presentation/widgets/message_content_widget.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_status_tokens.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/message_bubble.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/l10n/l10n.dart';
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.titleOverride ?? state.resolvedTitle),
            if (state.memberCount != null)
              Text(
                '${state.memberCount} '
                '${state.memberCount == 1 ? 'member' : 'members'}',
                key: const ValueKey('conversation-member-count'),
                style: AppTypography.caption.copyWith(
                  color:
                      Theme.of(context).extension<AppColors>()!.textSecondary,
                ),
              ),
          ],
        ),
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
          if (state.status == ConversationDetailStatus.success)
            IconButton(
              key: const ValueKey('conversation-members-toggle'),
              icon: const Icon(Icons.people_outline),
              onPressed: () {},
            ),
          ...?widget.appBarActionsBuilder?.call(context, ref, state),
        ],
      ),
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
          if (state.status == ConversationDetailStatus.success)
            _ConversationComposer(
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
      _composerController.clear();
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
    final colors = Theme.of(context).extension<AppColors>()!;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.sendFailure != null) ...[
              Text(
                state.sendFailure?.message ?? 'Failed to send message.',
                key: const ValueKey('composer-send-error'),
                style: TextStyle(
                  color: colors.error,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (state.pendingAttachments.isNotEmpty) ...[
              Wrap(
                key: const ValueKey('composer-pending-attachments'),
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
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
              const SizedBox(height: AppSpacing.sm),
            ],
            Row(
              children: [
                Container(
                  key: const ValueKey('composer-attach'),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.surfaceAlt,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.attach_file, size: 20),
                    padding: EdgeInsets.zero,
                    onPressed:
                        state.isSending ? null : () => _pickFile(context),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    key: const ValueKey('composer-input'),
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    onSubmitted: (_) => state.canSend ? onSend() : null,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Write a message',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull),
                        borderSide:
                            BorderSide(color: colors.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  key: const ValueKey('composer-send'),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: state.canSend ? colors.primary : colors.surfaceAlt,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      state.isSending ? Icons.hourglass_top : Icons.send,
                      size: 20,
                      color: state.canSend
                          ? colors.primaryForeground
                          : colors.textTertiary,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: state.canSend ? onSend : null,
                  ),
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

/// Maximum bubble width as a fraction of available space.
const _bubbleMaxWidthFraction = 0.78;

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
    final colors = theme.extension<AppColors>()!;
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

    // Z3 color tokens
    final bubbleColor = switch (visualKind) {
      _ConversationMessageVisualKind.self => colors.primary,
      _ConversationMessageVisualKind.agent => colors.agentLight,
      _ConversationMessageVisualKind.other => colors.surfaceAlt,
      _ConversationMessageVisualKind.system => null,
    };
    final foregroundColor = switch (visualKind) {
      _ConversationMessageVisualKind.self => colors.primaryForeground,
      _ConversationMessageVisualKind.system => colors.textSecondary,
      _ => colors.text,
    };

    // Z3 asymmetric border radii
    final borderRadius = switch (visualKind) {
      _ConversationMessageVisualKind.self => const BorderRadius.only(
          topLeft: Radius.circular(BubbleTokens.radiusLarge),
          topRight: Radius.circular(BubbleTokens.radiusSmall),
          bottomLeft: Radius.circular(BubbleTokens.radiusLarge),
          bottomRight: Radius.circular(BubbleTokens.radiusLarge),
        ),
      _ConversationMessageVisualKind.system =>
        BorderRadius.circular(BubbleTokens.radiusLarge),
      _ => const BorderRadius.only(
          topLeft: Radius.circular(BubbleTokens.radiusSmall),
          topRight: Radius.circular(BubbleTokens.radiusLarge),
          bottomLeft: Radius.circular(BubbleTokens.radiusLarge),
          bottomRight: Radius.circular(BubbleTokens.radiusLarge),
        ),
    };

    // Sender name label style
    final showSenderLabel =
        visualKind == _ConversationMessageVisualKind.other ||
            visualKind == _ConversationMessageVisualKind.agent;

    final senderStyle = AppTypography.label.copyWith(
      color: visualKind == _ConversationMessageVisualKind.agent
          ? colors.agentAccent
          : colors.textSecondary,
      fontWeight: FontWeight.w600,
    );
    final timestampStyle = AppTypography.caption.copyWith(
      color: foregroundColor.withValues(alpha: 0.78),
    );
    final bodyStyle = AppTypography.body.copyWith(
      color: foregroundColor,
      fontStyle: visualKind == _ConversationMessageVisualKind.system
          ? FontStyle.italic
          : null,
    );

    final bubble = Container(
      key: ValueKey('message-${message.id}'),
      padding: visualKind == _ConversationMessageVisualKind.system
          ? const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            )
          : const EdgeInsets.all(AppSpacing.md),
      decoration: bubbleColor != null
          ? BoxDecoration(
              color: bubbleColor,
              borderRadius: borderRadius,
            )
          : const BoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (visualKind == _ConversationMessageVisualKind.self)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text('You',
                        style: senderStyle.copyWith(
                          color: foregroundColor,
                        )),
                  ),
                  if (message.isPinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.push_pin,
                        size: 14,
                        color: colors.primaryForeground.withValues(
                          alpha: 0.78,
                        ),
                      ),
                    ),
                  if (isSaved)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.bookmark,
                        size: 14,
                        color: colors.primaryForeground.withValues(
                          alpha: 0.78,
                        ),
                      ),
                    ),
                  Text(timestamp, style: timestampStyle),
                  if (message.linkedTask != null &&
                      target.surface == ConversationSurface.channel) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: _MessageLinkedTaskBadge(
                        task: message.linkedTask!,
                        serverId: target.serverId.value,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (visualKind != _ConversationMessageVisualKind.self)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  if (!showSenderLabel)
                    Expanded(
                      child: Text(senderLabel,
                          style: senderStyle.copyWith(
                            color: foregroundColor,
                          )),
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
                        color: colors.primary,
                      ),
                    ),
                  Text(timestamp, style: timestampStyle),
                  if (message.linkedTask != null &&
                      target.surface == ConversationSurface.channel) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: _MessageLinkedTaskBadge(
                        task: message.linkedTask!,
                        serverId: target.serverId.value,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          MessageContentWidget(
            message: message,
            isSystem: visualKind == _ConversationMessageVisualKind.system,
            kind: switch (visualKind) {
              _ConversationMessageVisualKind.self => MessageBubbleKind.self,
              _ConversationMessageVisualKind.agent => MessageBubbleKind.agent,
              _ => MessageBubbleKind.other,
            },
            highlightQuery: highlightQuery,
            baseStyle: bodyStyle,
            highlightColor: colors.primaryLight,
            onLinkTap: (text, href, title) =>
                _confirmAndLaunchUrl(context, href),
          ),
          if (message.attachments != null && message.attachments!.isNotEmpty)
            _AttachmentSection(attachments: message.attachments!),
        ],
      ),
    );

    // Sender label is placed ABOVE the bubble for other/agent messages.
    Widget senderLabelWidget = const SizedBox.shrink();
    if (showSenderLabel) {
      senderLabelWidget = Padding(
        key: const ValueKey('sender-label-row'),
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (visualKind == _ConversationMessageVisualKind.agent) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: colors.agentAccent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  'AI',
                  style: AppTypography.caption.copyWith(
                    color: colors.primaryForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(senderLabel, style: senderStyle),
          ],
        ),
      );
    }

    // Thread indicator is placed BELOW the bubble, not inside it.
    Widget threadIndicator = const SizedBox.shrink();
    if (message.threadId != null) {
      threadIndicator = Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
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
                color: colors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                message.replyCount != null && message.replyCount! > 0
                    ? '${message.replyCount} ${message.replyCount == 1 ? 'reply' : 'replies'}'
                    : 'In thread',
                key: const ValueKey('message-thread-indicator'),
                style: AppTypography.label.copyWith(
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Message tap → thread navigation for channel surface only,
    // and only when the message already has a thread.
    final enableTapToThread = target.surface == ConversationSurface.channel &&
        visualKind != _ConversationMessageVisualKind.system &&
        message.threadId != null;

    return _TapFeedbackWrapper(
      enableFeedback: enableTapToThread,
      onTap: enableTapToThread ? () => _navigateToThread(context) : null,
      onLongPress: () => _showMessageActions(context, ref, isSaved),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxBubbleWidth = constraints.maxWidth * _bubbleMaxWidthFraction;
          return Align(
            key: ValueKey('message-shell-${message.id}'),
            alignment: shellAlignment,
            child: switch (visualKind) {
              _ConversationMessageVisualKind.system => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: double.infinity, child: bubble),
                    threadIndicator,
                  ],
                ),
              _ => ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                        visualKind == _ConversationMessageVisualKind.self
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                    children: [
                      senderLabelWidget,
                      bubble,
                      threadIndicator,
                    ],
                  ),
                ),
            },
          );
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

  void _navigateToThread(BuildContext context) {
    context.push(
      ThreadRouteTarget(
        serverId: target.serverId.value,
        parentChannelId: target.conversationId,
        parentMessageId: message.id,
        threadChannelId: message.threadId,
      ).toLocation(),
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

/// Duration of the press-state opacity transition.
const _kPressFeedbackDuration = Duration(milliseconds: 150);

/// Opacity applied to the bubble while the user holds a tap.
const _kPressFeedbackOpacity = 0.7;

/// Wraps a child in a [GestureDetector] with optional animated opacity
/// feedback on tap-down. When [enableFeedback] is `false` the opacity
/// animation is skipped and the child is rendered at full opacity.
class _TapFeedbackWrapper extends StatefulWidget {
  const _TapFeedbackWrapper({
    required this.enableFeedback,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  final bool enableFeedback;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  @override
  State<_TapFeedbackWrapper> createState() => _TapFeedbackWrapperState();
}

class _TapFeedbackWrapperState extends State<_TapFeedbackWrapper> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (!widget.enableFeedback) return;
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (!widget.enableFeedback) return;
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (!widget.enableFeedback) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedOpacity(
        key: const ValueKey('message-tap-feedback'),
        opacity: _isPressed ? _kPressFeedbackOpacity : 1.0,
        duration: _kPressFeedbackDuration,
        child: widget.child,
      ),
    );
  }
}

class _MessageLinkedTaskBadge extends StatelessWidget {
  const _MessageLinkedTaskBadge({
    required this.task,
    required this.serverId,
  });

  final ConversationLinkedTaskSummary task;
  final String serverId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, tone) = switch (task.status) {
      'todo' => (Icons.radio_button_unchecked, AppStatusTone.neutral),
      'in_progress' => (Icons.timelapse, AppStatusTone.info),
      'in_review' => (Icons.rate_review, AppStatusTone.warning),
      'done' => (Icons.check_circle, AppStatusTone.success),
      _ => (Icons.circle_outlined, AppStatusTone.neutral),
    };
    final colors = appStatusColors(theme.colorScheme, tone);
    final label = StringBuffer('#${task.taskNumber}');
    if (task.claimedByName != null && task.claimedByName!.isNotEmpty) {
      label.write(' @${task.claimedByName}');
    }

    // Absorb taps and navigate to the tasks page so they don't
    // bubble up to the message card's thread-navigation
    // GestureDetector.
    return GestureDetector(
      onTap: () => context.push('/servers/$serverId/tasks'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        key: ValueKey('message-linked-task-${task.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colors.container,
          border: Border.all(color: colors.foreground),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: colors.onContainer),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label.toString(),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows a confirmation dialog before launching an external URL.
Future<void> _confirmAndLaunchUrl(BuildContext context, String? href) async {
  if (href == null || href.isEmpty) return;
  final uri = Uri.tryParse(href);
  if (uri == null) return;

  final colors = Theme.of(context).extension<AppColors>()!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Open Link'),
      content: Text(
        'Open $href?',
        style: TextStyle(color: colors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Open'),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
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

  static const _imageTypes = {
    'image/png',
    'image/jpeg',
    'image/jpg',
    'image/gif',
    'image/webp',
  };

  static const _htmlTypes = {
    'text/html',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        key: const ValueKey('message-attachments'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final attachment in attachments)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _buildAttachmentWidget(context, attachment),
            ),
        ],
      ),
    );
  }

  Widget _buildAttachmentWidget(
    BuildContext context,
    MessageAttachment attachment,
  ) {
    final mimeType = attachment.type.toLowerCase();

    if (_imageTypes.contains(mimeType) && attachment.url != null) {
      return _ImageAttachmentPreview(attachment: attachment);
    }

    if (_htmlTypes.contains(mimeType)) {
      return _HtmlAttachmentRow(attachment: attachment);
    }

    return _GenericFileAttachmentRow(attachment: attachment);
  }
}

class _ImageAttachmentPreview extends StatelessWidget {
  const _ImageAttachmentPreview({required this.attachment});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      key: ValueKey('image-preview-${attachment.id ?? attachment.name}'),
      onTap: () => _openFullScreen(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 200,
                maxWidth: 280,
              ),
              child: Image.network(
                attachment.url!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return SizedBox(
                    height: 120,
                    width: 200,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stack) {
                  return Container(
                    height: 80,
                    width: 200,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          attachment.name,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            attachment.name,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _FullScreenImageViewer(attachment: attachment),
      ),
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  const _FullScreenImageViewer({required this.attachment});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          attachment.name,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          if (attachment.url != null)
            IconButton(
              key: const ValueKey('image-viewer-open-external'),
              icon: const Icon(Icons.open_in_new),
              onPressed: () => launchUrl(
                Uri.parse(attachment.url!),
                mode: LaunchMode.externalApplication,
              ),
              tooltip: context.l10n.attachmentOpenInBrowser,
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          key: const ValueKey('image-viewer-interactive'),
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            attachment.url!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.attachmentUnableToLoadImage,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white54),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HtmlAttachmentRow extends StatelessWidget {
  const _HtmlAttachmentRow({required this.attachment});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: ValueKey('html-attachment-${attachment.id ?? attachment.name}'),
      onTap: attachment.url != null
          ? () => launchUrl(
                Uri.parse(attachment.url!),
                mode: LaunchMode.externalApplication,
              )
          : null,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.language,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
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
                  Text(
                    [
                      context.l10n.attachmentHtmlOpensInBrowser,
                      if (attachment.formattedSize != null)
                        attachment.formattedSize!,
                    ].join(' · '),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (attachment.url != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.open_in_new,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GenericFileAttachmentRow extends StatelessWidget {
  const _GenericFileAttachmentRow({required this.attachment});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: ValueKey('file-attachment-${attachment.id ?? attachment.name}'),
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
                color:
                    attachment.url != null ? theme.colorScheme.primary : null,
                decoration:
                    attachment.url != null ? TextDecoration.underline : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            [
              attachment.type,
              if (attachment.formattedSize != null) attachment.formattedSize!,
            ].join(' · '),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
