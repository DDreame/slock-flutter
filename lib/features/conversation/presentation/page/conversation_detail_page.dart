import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/skeleton_list_item.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/core/haptic/haptic_service.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/features/channels/application/load_mention_members_use_case.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_session_store.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/application/download_priority_scheduler.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/application/typing_realtime_binding_provider.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_helpers.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_info_page.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_scroll_coordinator.dart';
import 'package:slock_app/features/conversation/presentation/page/mention_autocomplete_controller.dart';
import 'package:slock_app/features/conversation/presentation/page/mention_suggestion_overlay.dart';
import 'package:slock_app/features/conversation/presentation/page/quote_jump_overlay.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_composer.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_message_list.dart';
export 'package:slock_app/features/conversation/presentation/widgets/conversation_message_list.dart'
    show dateSeparatorToLocalProvider;
import 'package:slock_app/features/conversation/presentation/widgets/conversation_search_overlay.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_selection_bar.dart';
import 'package:slock_app/features/conversation/presentation/widgets/typing_indicator_widget.dart';
import 'package:slock_app/features/translation/application/translation_cache_store.dart';
import 'package:slock_app/features/translation/application/translation_settings_store.dart';
import 'package:slock_app/features/translation/data/translation_settings.dart';
import 'package:slock_app/features/unread/application/mark_read_use_case.dart';
import 'package:slock_app/features/unread/application/read_cursor_service.dart';
import 'package:slock_app/features/unread/application/unread_source_projection.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';
import 'package:slock_app/features/voice/application/voice_message_store.dart';
import 'package:slock_app/features/voice/application/voice_recording_controller.dart';
import 'package:slock_app/features/voice/data/voice_recorder_service.dart';
import 'package:slock_app/features/voice/presentation/widgets/voice_recording_lifecycle_binding.dart';
import 'package:slock_app/stores/composer/composer_settings_store.dart';

// Re-export extracted types so existing test imports don't break.
export 'package:slock_app/features/conversation/presentation/page/quote_jump_overlay.dart'
    show QuoteJumpState, QuoteJumpOverlay, QuoteJumpDismissibleOverlay;
export 'package:slock_app/features/conversation/presentation/page/mention_suggestion_overlay.dart'
    show buildMentionSuggestionOverlay;

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
    this.highlightMessageId,
  }) : _target = target;

  final ConversationDetailTarget _target;
  final String? titleOverride;
  final ConversationAppBarActionsBuilder? appBarActionsBuilder;
  final bool registerOpenTarget;
  final String? highlightMessageId;

  @visibleForTesting
  static int Function()? debugMessageGlobalKeyCount;

  @visibleForTesting
  static int debugAttachmentRegistrationCount = 0;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(_target),
      ],
      child: _ConversationDetailScreen(
        target: _target,
        titleOverride: titleOverride,
        appBarActionsBuilder: appBarActionsBuilder,
        registerOpenTarget: registerOpenTarget,
        highlightMessageId: highlightMessageId,
      ),
    );
  }
}

class _ConversationDetailScreen extends ConsumerStatefulWidget {
  const _ConversationDetailScreen({
    required this.target,
    this.titleOverride,
    this.appBarActionsBuilder,
    required this.registerOpenTarget,
    this.highlightMessageId,
  });

  final ConversationDetailTarget target;
  final String? titleOverride;
  final ConversationAppBarActionsBuilder? appBarActionsBuilder;
  final bool registerOpenTarget;
  final String? highlightMessageId;

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
  late final ConversationScrollCoordinator _scrollCoordinator;
  late final MentionAutocompleteController _mentionController;
  ProviderSubscription<ConversationDetailState>? _stateSubscription;
  ProviderSubscription<TranslationSettingsState>? _translationSettingsSub;
  ProviderSubscription<UnreadSourceProjectionState>? _deferredMarkReadSub;
  Timer? _highlightExpiryTimer;
  Timer? _quoteJumpExpiryTimer;
  bool _pendingDraftCallback = false;
  final GlobalKey _screenshotBoundaryKey = GlobalKey();
  bool _isFormattingToolbarVisible = false;
  bool _isEmojiPickerVisible = false;
  bool _asTask = false;

  /// Message IDs that should play a send animation (slide-up + fade-in).
  /// Populated when the user sends a message and a new own-message appears.
  final Set<String> _newlySentIds = {};

  /// Tracks whether a send was just triggered, so we can attribute the next
  /// new own-message to a user send action (vs. realtime incoming).
  bool _pendingSendAnimation = false;

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
    _scrollCoordinator = ConversationScrollCoordinator(
      scrollController: _scrollController,
      readState: () => ref.read(conversationDetailStoreProvider),
      loadOlder: () =>
          ref.read(conversationDetailStoreProvider.notifier).loadOlder(),
      updateViewportOffset: (offset) => ref
          .read(conversationDetailStoreProvider.notifier)
          .updateViewportOffset(offset),
    );
    ConversationDetailPage.debugMessageGlobalKeyCount =
        () => _scrollCoordinator.messageGlobalKeyCount;
    _mentionController = MentionAutocompleteController(
      loadMembers: _loadMentionMembers,
    );
    _stateSubscription = ref.listenManual<ConversationDetailState>(
      conversationDetailStoreProvider,
      _handleStateChange,
      fireImmediately: true,
    );
    Future.microtask(
      () => ref.read(conversationDetailStoreProvider.notifier).ensureLoaded(),
    );
    _translationSettingsSub = ref.listenManual<TranslationSettingsState>(
      translationSettingsStoreProvider,
      _handleTranslationSettingsLoaded,
    );
    Future.microtask(
      () => ref.read(translationSettingsStoreProvider.notifier).ensureLoaded(),
    );
  }

  @override
  void didUpdateWidget(covariant _ConversationDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _mentionController.reset();
      setState(() {});
      Future.microtask(
        () => ref.read(conversationDetailStoreProvider.notifier).ensureLoaded(),
      );
    }
  }

  @override
  void dispose() {
    _highlightExpiryTimer?.cancel();
    _quoteJumpExpiryTimer?.cancel();
    _scrollCoordinator.dispose();
    _mentionController.dispose();
    _stateSubscription?.close();
    _translationSettingsSub?.close();
    _deferredMarkReadSub?.close();
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
      ref.watch(currentOpenConversationRegistrationProvider(
        ref.read(currentConversationDetailTargetProvider),
      ));
    }
    ref.watch(downloadSchedulerProvider);

    // INV-SCAFFOLD-SELECT-1: Watch only scaffold-relevant fields.
    // Selection mode is watched separately via Consumer boundary below
    // to prevent full scaffold rebuild on selection toggle.
    ref.watch(conversationDetailStoreProvider.select((s) => (
          status: s.status,
          failure: s.failure,
          draft: s.draft,
          resolvedTitle: s.resolvedTitle,
          description: s.description,
          memberCount: s.memberCount,
          isSearchActive: s.isSearchActive,
          isEmpty: s.isEmpty,
          isRefreshing: s.isRefreshing,
          sendFailure: s.sendFailure,
          pendingAttachments: s.pendingAttachments,
          replyToMessage: s.replyToMessage,
          uploadProgress: s.uploadProgress,
          isSending: s.isSending,
          canSend: s.canSend,
        )));
    final state = ref.read(conversationDetailStoreProvider);

    ref.listen(
      conversationDetailStoreProvider.select((s) => s.isRefreshing),
      (prev, next) {
        if (prev == true && next == false) {
          final s = ref.read(conversationDetailStoreProvider);
          if (s.failure != null &&
              s.status == ConversationDetailStatus.success) {
            _showRefreshFailedSnackBar();
          }
        }
      },
    );

    // Scroll to current search match when index changes (prev/next navigation).
    ref.listen(
      conversationDetailStoreProvider.select((s) => (
            matchIndex: s.currentSearchMatchIndex,
            matchIds: s.searchMatchIds,
          )),
      (prev, next) {
        if (next.matchIndex >= 0 && next.matchIndex < next.matchIds.length) {
          final messageId = next.matchIds[next.matchIndex];
          final messages = ref.read(conversationDetailStoreProvider).messages;
          _scrollToMessageId(messageId, messages);
        }
      },
    );

    final voiceRecordingState = ref.watch(
      voiceMessageStoreProvider.select((s) => s.recordingState),
    );
    final isRecording = voiceRecordingState == VoiceRecorderState.recording;

    final target = ref.read(currentConversationDetailTargetProvider);
    final typingScopeKey =
        'server:${target.serverId.value}/${target.surface == ConversationSurface.channel ? 'channel' : 'dm'}:${target.conversationId}';
    ref.watch(typingRealtimeBindingProvider(typingScopeKey));

    if (_composerController.text != state.draft && !_pendingDraftCallback) {
      _pendingDraftCallback = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pendingDraftCallback = false;
        if (mounted && _composerController.text != state.draft) {
          _composerController.value = TextEditingValue(
            text: state.draft,
            selection: TextSelection.collapsed(offset: state.draft.length),
          );
        }
      });
    }

    return VoiceRecordingLifecycleBinding(
      child: Scaffold(
        appBar: _buildAppBar(context, state, target),
        body: Column(
          children: [
            if (state.isSearchActive)
              ConversationSearchBar(
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
            const OfflineBanner(),
            Expanded(child: _buildBody(context, state)),
            if (state.status == ConversationDetailStatus.success)
              const TypingIndicatorWidget(),
            if (state.status == ConversationDetailStatus.success)
              const OutboxFailedBanner(),
            if (state.status == ConversationDetailStatus.success &&
                _mentionController.showOverlay &&
                _mentionController.filteredMembers.isNotEmpty)
              MentionSuggestionOverlay(
                key: const ValueKey('mention-suggestion-overlay'),
                members: _mentionController.filteredMembers,
                onSelect: _insertMention,
              ),
            // INV-PERF-SELECT-1: Consumer boundary isolates selection mode
            // rebuild from the scaffold. Only the bottom area rebuilds when
            // selection mode toggles.
            Consumer(builder: (context, bottomRef, _) {
              final isSelectionMode =
                  bottomRef.watch(isSelectionModeActiveProvider);
              return _buildBottomArea(state, isRecording, isSelectionMode);
            }),
          ],
        ),
      ),
    );
  }

  // -- Build helpers --

  AppBar _buildAppBar(BuildContext context, ConversationDetailState state,
      ConversationDetailTarget target) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final heroTag = 'conversation-avatar-${target.conversationId}';
    final (bgColor, icon) = switch (target.surface) {
      ConversationSurface.channel => (
          colors.success.withValues(alpha: 0.12),
          Icons.tag,
        ),
      ConversationSurface.directMessage => (
          colors.warning.withValues(alpha: 0.12),
          Icons.chat_bubble_outline,
        ),
    };

    return AppBar(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BackButton(),
          Hero(
            tag: heroTag,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: colors.textSecondary),
            ),
          ),
        ],
      ),
      leadingWidth: 80,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.titleOverride ?? state.resolvedTitle),
          if (target.surface == ConversationSurface.directMessage)
            DmPresenceSubtitle(conversationId: target.conversationId)
          else if (state.description != null && state.description!.isNotEmpty)
            Text(
              state.description!,
              key: const ValueKey('channel-description-text'),
              style: AppTypography.caption.copyWith(
                color: Theme.of(context).extension<AppColors>()!.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          else if (state.memberCount != null)
            Text(
              context.l10n.conversationMemberCount(state.memberCount!),
              key: const ValueKey('conversation-member-count'),
              style: AppTypography.caption.copyWith(
                color: Theme.of(context).extension<AppColors>()!.textSecondary,
              ),
            ),
        ],
      ),
      actions: [
        if (state.status == ConversationDetailStatus.success)
          IconButton(
            key: const ValueKey('conversation-search-toggle'),
            icon: Icon(state.isSearchActive ? Icons.search_off : Icons.search),
            tooltip: state.isSearchActive
                ? context.l10n.conversationCloseSearch
                : context.l10n.conversationSearchTooltip,
            onPressed:
                ref.read(conversationDetailStoreProvider.notifier).toggleSearch,
          ),
        if (state.status == ConversationDetailStatus.success)
          IconButton(
            key: const ValueKey('conversation-members-shortcut'),
            icon: const Icon(Icons.info_outline),
            tooltip: context.l10n.conversationInfoTooltip,
            onPressed: () {
              final t = ref.read(currentConversationDetailTargetProvider);
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ConversationInfoPage(
                  target: t,
                  title: state.resolvedTitle,
                  description: state.description,
                  initialSection: ConversationInfoSection.members,
                ),
              ));
            },
          ),
        if (state.status == ConversationDetailStatus.success)
          IconButton(
            key: const ValueKey('conversation-screenshot'),
            icon: const Icon(Icons.screenshot_outlined),
            onPressed: () => ref
                .read(conversationDetailStoreProvider.notifier)
                .enterSelectionModeEmpty(),
            tooltip: context.l10n.conversationScreenshotTooltip,
          ),
        ...?widget.appBarActionsBuilder?.call(context, ref, state),
      ],
    );
  }

  Widget _buildBody(BuildContext context, ConversationDetailState state) {
    return switch (state.status) {
      ConversationDetailStatus.initial ||
      ConversationDetailStatus.loading =>
        ListView(
          key: const ValueKey('conversation-skeleton'),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal,
            vertical: AppSpacing.sm,
          ),
          children: const [
            SkeletonListItem(key: ValueKey('conversation-skeleton-item-0')),
            SkeletonListItem(key: ValueKey('conversation-skeleton-item-1')),
            SkeletonListItem(key: ValueKey('conversation-skeleton-item-2')),
            SkeletonListItem(key: ValueKey('conversation-skeleton-item-3')),
            SkeletonListItem(key: ValueKey('conversation-skeleton-item-4')),
          ],
        ),
      ConversationDetailStatus.failure => ConversationFailureView(
          state: state,
          onRetry: () =>
              ref.read(conversationDetailStoreProvider.notifier).retry(),
        ),
      ConversationDetailStatus.success when state.isEmpty =>
        ConversationEmptyView(title: state.resolvedTitle),
      ConversationDetailStatus.success => Column(
          children: [
            if (state.isRefreshing)
              const LinearProgressIndicator(
                key: ValueKey('conversation-refreshing'),
                minHeight: 2,
              ),
            Expanded(
              child: Stack(children: [
                RepaintBoundary(
                  key: _screenshotBoundaryKey,
                  child: ConversationMessageList(
                    controller: _scrollController,
                    onScrollToMessage: _scrollToMessageId,
                    highlightedMessageId:
                        _scrollCoordinator.highlightedMessageId,
                    messageKeyBuilder: _scrollCoordinator.getMessageKey,
                    newlySentIds: _newlySentIds,
                  ),
                ),
                if (_scrollCoordinator.quoteJumpState != QuoteJumpState.idle)
                  Positioned.fill(
                    child: QuoteJumpDismissibleOverlay(
                      state: _scrollCoordinator.quoteJumpState,
                      onDismiss: _dismissQuoteJumpNotFound,
                    ),
                  ),
                if (_scrollCoordinator.showScrollToBottom)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: _ScrollToBottomFab(
                      key: const ValueKey('scroll-to-bottom-fab'),
                      unreadCount: _scrollCoordinator.unreadSinceScrolled,
                      onPressed: () {
                        _scrollCoordinator.unreadSinceScrolled = 0;
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      },
                    ),
                  ),
              ]),
            ),
          ],
        ),
    };
  }

  Widget _buildBottomArea(
      ConversationDetailState state, bool isRecording, bool isSelectionMode) {
    if (state.status != ConversationDetailStatus.success) {
      return const SizedBox.shrink();
    }
    if (isSelectionMode) return const SelectionActionBar();
    if (state.isArchived) return const ArchivedChannelBanner();
    return ConversationComposer(
      controller: _composerController,
      focusNode: _composerFocusNode,
      state: state,
      isRecording: isRecording,
      enterToSend: ref.watch(
        composerSettingsStoreProvider.select((s) => s.enterToSend),
      ),
      isFormattingToolbarVisible: _isFormattingToolbarVisible,
      isEmojiPickerVisible: _isEmojiPickerVisible,
      onToggleFormattingToolbar: () => setState(
          () => _isFormattingToolbarVisible = !_isFormattingToolbarVisible),
      onToggleEmojiPicker: () =>
          setState(() => _isEmojiPickerVisible = !_isEmojiPickerVisible),
      onChanged: (value) {
        ref.read(conversationDetailStoreProvider.notifier).updateDraft(value);
        if (value.trim().isNotEmpty) _emitTyping();
        _detectMentionTrigger(value);
      },
      onSend: _handleSend,
      onPickAttachment: ref
          .read(conversationDetailStoreProvider.notifier)
          .addPendingAttachment,
      onRemoveAttachment: ref
          .read(conversationDetailStoreProvider.notifier)
          .removePendingAttachment,
      onCancelUpload:
          ref.read(conversationDetailStoreProvider.notifier).cancelUpload,
      onClearReply:
          ref.read(conversationDetailStoreProvider.notifier).clearReplyTo,
      onMicTap: _startRecording,
      onSendRecording: _stopRecordingAndSend,
      onCancelRecording: _cancelRecording,
      asTask: _asTask,
      onToggleAsTask: () => setState(() => _asTask = !_asTask),
    );
  }

  // -- Scroll handling --

  void _handleScroll() {
    if (_scrollCoordinator.handleScroll()) setState(() {});
  }

  // -- State change handling --

  void _handleStateChange(
    ConversationDetailState? previous,
    ConversationDetailState next,
  ) {
    if (previous?.status != ConversationDetailStatus.success &&
        next.status == ConversationDetailStatus.success) {
      final t = ref.read(currentConversationDetailTargetProvider);
      final projection = ref.read(unreadSourceProjectionProvider);
      if (projection.isLoaded) {
        _fireMarkReadIfUnread(t, projection);
      } else {
        _deferredMarkReadSub?.close();
        _deferredMarkReadSub = ref.listenManual<UnreadSourceProjectionState>(
          unreadSourceProjectionProvider,
          (previous, next) {
            if (next.isLoaded) {
              _deferredMarkReadSub?.close();
              _deferredMarkReadSub = null;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _fireMarkReadIfUnread(t, next);
              });
            }
          },
        );
      }
      _autoTranslateIfNeeded(next.messages);
      _updateReadCursor(next.messages);
    }

    if (next.status == ConversationDetailStatus.success &&
        next.messages.length != _scrollCoordinator.lastRegisteredMessageCount) {
      // Track new messages arriving while user is scrolled up (FAB badge).
      final oldCount = _scrollCoordinator.lastRegisteredMessageCount;
      if (_scrollCoordinator.showScrollToBottom &&
          oldCount > 0 &&
          next.messages.length > oldCount) {
        _scrollCoordinator.unreadSinceScrolled +=
            next.messages.length - oldCount;
      }
      // Track newly-sent own messages for send animation.
      if (_pendingSendAnimation &&
          next.messages.isNotEmpty &&
          next.messages.length > oldCount) {
        _pendingSendAnimation = false;
        // The newest message (last in list, first chronologically) is the
        // just-sent message.
        _newlySentIds.add(next.messages.last.id);
      }
      _scrollCoordinator.lastRegisteredMessageCount = next.messages.length;
      _registerAttachmentDownloads(next.messages);
      _updateReadCursor(next.messages);
      // INV-P0-UNREAD: Re-fire mark-read when new messages arrive while the
      // conversation is already open. Without this, `_fireMarkReadIfUnread`
      // only fires on the initial transition to success, leaving new messages
      // unread in the inbox projection (requires exit/re-enter to clear).
      final t = ref.read(currentConversationDetailTargetProvider);
      final projection = ref.read(unreadSourceProjectionProvider);
      if (projection.isLoaded) {
        _fireMarkReadIfUnread(t, projection);
      } else {
        // Deferred fallback: projection not yet loaded when new messages
        // arrive (e.g. rapid reconnect). Wait for it, then mark read (#858).
        _deferredMarkReadSub?.close();
        _deferredMarkReadSub = ref.listenManual<UnreadSourceProjectionState>(
          unreadSourceProjectionProvider,
          (previous, next) {
            if (next.isLoaded) {
              _deferredMarkReadSub?.close();
              _deferredMarkReadSub = null;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _fireMarkReadIfUnread(t, next);
              });
            }
          },
        );
      }
    }

    if (next.status == ConversationDetailStatus.success) {
      _scrollCoordinator.evictStaleKeys(next.messages);
    }

    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncScrollState(previous, next);
      });
      return;
    }
    _syncScrollState(previous, next);
  }

  void _syncScrollState(
      ConversationDetailState? previous, ConversationDetailState next) {
    _scrollCoordinator.syncScrollState(
      previous,
      next,
      restoredFromSession: _restoredFromSession,
      highlightMessageId: widget.highlightMessageId,
      unreadCountForTarget: () => unreadCountForTarget(ref, next.target),
      scrollToMessageId: _scrollToMessageId,
    );
  }

  void _scrollToMessageId(
      String messageId, List<ConversationMessageSummary> messages) {
    _scrollCoordinator.scrollToMessageId(
      messageId,
      messages,
      onMissing: _handleQuoteJumpMissing,
    );
    setState(() {});
  }

  Future<void> _handleQuoteJumpMissing(String messageId) async {
    if (_scrollCoordinator.setQuoteJumpLoading()) setState(() {});

    await ref
        .read(conversationDetailStoreProvider.notifier)
        .loadContext(messageId);
    if (!mounted) return;

    final updatedState = ref.read(conversationDetailStoreProvider);
    final idx = updatedState.messages.indexWhere((m) => m.id == messageId);
    if (idx >= 0) {
      if (_scrollCoordinator.scrollToAndHighlight(messageId)) setState(() {});
      _scheduleHighlightExpiry();
      return;
    }

    if (mounted) {
      if (_scrollCoordinator.setQuoteJumpNotFound()) setState(() {});
      _scheduleQuoteJumpNotFoundExpiry();
    }
  }

  void _dismissQuoteJumpNotFound() {
    if (_scrollCoordinator.dismissQuoteJumpNotFound()) setState(() {});
  }

  void _scheduleHighlightExpiry() {
    _highlightExpiryTimer?.cancel();
    _highlightExpiryTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) {
        _scrollCoordinator.highlightedMessageId = null;
        setState(() {});
      }
    });
  }

  void _scheduleQuoteJumpNotFoundExpiry() {
    _quoteJumpExpiryTimer?.cancel();
    _quoteJumpExpiryTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _scrollCoordinator.dismissQuoteJumpNotFound();
        setState(() {});
      }
    });
  }

  // -- Mark read --

  void _fireMarkReadIfUnread(
      ConversationDetailTarget t, UnreadSourceProjectionState projection) {
    switch (t.surface) {
      case ConversationSurface.channel:
        final scopeId =
            ChannelScopeId(serverId: t.serverId, value: t.conversationId);
        if (projection.channelUnreadCount(scopeId) > 0) {
          ref.read(markChannelReadUseCaseProvider)(scopeId);
        }
      case ConversationSurface.directMessage:
        final scopeId =
            DirectMessageScopeId(serverId: t.serverId, value: t.conversationId);
        if (projection.dmUnreadCount(scopeId) > 0) {
          ref.read(markDmReadUseCaseProvider)(scopeId);
        }
    }
  }

  void _updateReadCursor(List<ConversationMessageSummary> messages) {
    if (messages.isEmpty) return;
    final t = ref.read(currentConversationDetailTargetProvider);
    int? highestSeq;
    for (final m in messages) {
      final seq = m.seq;
      if (seq != null && (highestSeq == null || seq > highestSeq)) {
        highestSeq = seq;
      }
    }
    if (highestSeq == null || highestSeq <= 0) return;
    ref.read(readCursorServiceProvider)?.markSeen(t.conversationId, highestSeq);
  }

  // -- Mention autocomplete --

  void _detectMentionTrigger(String text) {
    final cursorOffset = _composerController.selection.baseOffset;
    if (_mentionController.detectTrigger(text, cursorOffset)) setState(() {});
  }

  Future<List<ChannelMember>> _loadMentionMembers() async {
    final target = ref.read(currentConversationDetailTargetProvider);
    try {
      final load = ref.read(loadMentionMembersUseCaseProvider);
      final members = await load(
          serverId: target.serverId, channelId: target.conversationId);
      if (mounted &&
          ref.read(currentConversationDetailTargetProvider) == target) {
        setState(() {});
      }
      return members;
    } on Exception catch (e) {
      ref
          .read(diagnosticsCollectorProvider)
          .error('ConversationDetail', 'Mention member load failed: $e');
      rethrow;
    }
  }

  void _insertMention(ChannelMember member) {
    final text = _composerController.text;
    final cursorOffset = _composerController.selection.baseOffset;
    final result = _mentionController.insertMention(member, text, cursorOffset);
    _composerController.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.cursorOffset),
    );
    ref.read(conversationDetailStoreProvider.notifier).updateDraft(result.text);
    setState(() {});
    ref.read(hapticServiceProvider).mediumImpact();
  }

  // -- Sending --

  Future<void> _handleSend() async {
    final sendAsTask = _asTask;
    await ref
        .read(conversationDetailStoreProvider.notifier)
        .send(asTask: sendAsTask);
    final state = ref.read(conversationDetailStoreProvider);

    if (state.sendFailure?.causeType == 'offlineAttachment' && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        key: const ValueKey('offline-attachment-snackbar'),
        content: Text(context.l10n.conversationOfflineAttachmentSnackbar),
      ));
      return;
    }

    if (state.sendFailure == null &&
        state.draft.isEmpty &&
        state.pendingAttachments.isEmpty) {
      _pendingSendAnimation = true;
      ref.read(hapticServiceProvider).lightImpact();
      _composerController.clear();
      _composerFocusNode.unfocus();
      if (sendAsTask) setState(() => _asTask = false);
    }
  }

  // -- Typing --

  void _emitTyping() {
    final target = ref.read(currentConversationDetailTargetProvider);
    final typingScopeKey =
        'server:${target.serverId.value}/${target.surface == ConversationSurface.channel ? 'channel' : 'dm'}:${target.conversationId}';
    ref.read(typingRealtimeBindingProvider(typingScopeKey)).emitTyping();
  }

  // -- Voice recording --

  Future<void> _startRecording() async {
    final controller = ref.read(voiceRecordingControllerProvider.notifier);
    final result = await controller.startRecording();
    if (!mounted) return;
    switch (result) {
      case StartRecordingResult.success:
      case StartRecordingResult.alreadyStarting:
        break;
      case StartRecordingResult.permissionDenied:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          key: const ValueKey('mic-permission-denied'),
          content: Text(context.l10n.conversationMicDenied),
        ));
      case StartRecordingResult.error:
        ref
            .read(diagnosticsCollectorProvider)
            .error('VoiceRecording', 'Recording start failed');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          key: const ValueKey('recording-start-error'),
          content: Text(context.l10n.conversationMicUnavailable),
        ));
    }
  }

  Future<void> _stopRecordingAndSend() async {
    final controller = ref.read(voiceRecordingControllerProvider.notifier);
    final amplitudes = List<double>.unmodifiable(
        ref.read(voiceMessageStoreProvider.notifier).amplitudes);
    final path = await controller.stopRecording();
    if (path == null || !mounted) return;
    final name = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    if (amplitudes.isNotEmpty) {
      ref.read(voiceWaveformCacheProvider.notifier).put(name, amplitudes);
    }
    ref.read(conversationDetailStoreProvider.notifier).addPendingAttachment(
          PendingAttachment(path: path, name: name, mimeType: 'audio/mp4'),
        );
    await _handleSend();
  }

  Future<void> _cancelRecording() async {
    await ref.read(voiceRecordingControllerProvider.notifier).cancelRecording();
  }

  // -- Translation --

  void _autoTranslateIfNeeded(List<ConversationMessageSummary> messages) {
    final settingsState = ref.read(translationSettingsStoreProvider);
    if (settingsState.settings.mode != TranslationMode.auto) return;
    if (messages.isEmpty) return;
    final messageIds = messages
        .where((m) => !m.isDeleted && m.messageType != 'system')
        .map((m) => m.id)
        .toList();
    if (messageIds.isEmpty) return;
    ref
        .read(translationCacheStoreProvider.notifier)
        .translateMessages(messageIds);
  }

  void _handleTranslationSettingsLoaded(
      TranslationSettingsState? previous, TranslationSettingsState next) {
    if (previous?.status != TranslationSettingsStatus.success &&
        next.status == TranslationSettingsStatus.success) {
      final convState = ref.read(conversationDetailStoreProvider);
      if (convState.status == ConversationDetailStatus.success) {
        _autoTranslateIfNeeded(convState.messages);
      }
    }
  }

  // -- Attachment downloads --

  void _registerAttachmentDownloads(List<ConversationMessageSummary> messages) {
    ConversationDetailPage.debugAttachmentRegistrationCount++;
    final scheduler = ref.read(downloadSchedulerProvider.notifier);
    for (final message in messages) {
      final attachments = message.attachments;
      if (attachments == null) continue;
      for (final attachment in attachments) {
        if (attachment.id == null) continue;
        final mimeType = attachment.type.toLowerCase();
        if (!mimeType.startsWith('image/')) continue;
        if (attachment.thumbnailUrl == null && attachment.url == null) continue;
        scheduler.enqueue(attachment.id!, () async {});
      }
    }
  }

  // -- Snackbar --

  void _showRefreshFailedSnackBar() {
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l10n.refreshFailedSnackbar),
        action: SnackBarAction(
          label: l10n.refreshFailedRetry,
          onPressed: () =>
              ref.read(conversationDetailStoreProvider.notifier).refresh(),
        ),
      ));
  }
}

/// Scroll-to-bottom FAB with an optional unread count badge.
class _ScrollToBottomFab extends StatelessWidget {
  const _ScrollToBottomFab({
    super.key,
    required this.unreadCount,
    required this.onPressed,
  });

  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton.small(
          tooltip: context.l10n.scrollToBottomFabTooltip,
          onPressed: onPressed,
          child: const Icon(Icons.keyboard_double_arrow_down),
        ),
        if (unreadCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              key: const ValueKey('fab-unread-badge'),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onError,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
