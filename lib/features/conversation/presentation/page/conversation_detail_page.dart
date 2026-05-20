import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/connection_status_banner.dart';
import 'package:slock_app/app/widgets/skeleton_list_item.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/data/channel_member_repository_provider.dart';
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_session_store.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/application/download_priority_scheduler.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/data/typing_realtime_binding.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_info_page.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_composer.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_message_list.dart';
export 'package:slock_app/features/conversation/presentation/widgets/conversation_message_list.dart'
    show dateSeparatorToLocal;
import 'package:slock_app/features/conversation/presentation/widgets/conversation_search_overlay.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_selection_bar.dart';
import 'package:slock_app/features/conversation/presentation/widgets/typing_indicator_widget.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/presence/application/presence_store.dart';
import 'package:slock_app/features/screenshot/application/screenshot_store.dart';
import 'package:slock_app/features/screenshot/data/screenshot_capture_service.dart';
import 'package:slock_app/features/translation/application/translation_cache_store.dart';
import 'package:slock_app/features/translation/application/translation_settings_store.dart';
import 'package:slock_app/features/translation/data/translation_settings.dart';
import 'package:slock_app/features/unread/application/mark_read_use_case.dart';
import 'package:slock_app/features/unread/application/unread_source_projection.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';
import 'package:slock_app/features/voice/application/voice_message_store.dart';
import 'package:slock_app/features/voice/data/voice_recorder_service.dart';
import 'package:slock_app/stores/composer/composer_settings_store.dart';

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

  /// When set, the page will scroll to (and optionally highlight) this message
  /// once the message list is loaded.
  final String? highlightMessageId;

  /// Test-only hook: returns the current number of cached message GlobalKeys
  /// in the most-recently-mounted [_ConversationDetailScreenState]. Null when
  /// no instance is mounted. Used by Phase A invariant tests to observe
  /// explicit map clearing on dispose.
  @visibleForTesting
  static int Function()? debugMessageGlobalKeyCount;

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
        highlightMessageId: highlightMessageId,
      ),
    );
  }
}

class _ConversationDetailScreen extends ConsumerStatefulWidget {
  const _ConversationDetailScreen({
    this.titleOverride,
    this.appBarActionsBuilder,
    required this.registerOpenTarget,
    this.highlightMessageId,
  });

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
  ProviderSubscription<ConversationDetailState>? _stateSubscription;
  ProviderSubscription<TranslationSettingsState>? _translationSettingsSub;
  ProviderSubscription<UnreadSourceProjectionState>? _deferredMarkReadSub;
  bool _didApplyInitialLanding = false;
  double? _olderLoadAnchorOffset;
  double? _olderLoadAnchorMaxExtent;
  final GlobalKey _screenshotBoundaryKey = GlobalKey();
  bool _isFormattingToolbarVisible = false;
  bool _isEmojiPickerVisible = false;
  bool _showScrollToBottom = false;
  Timer? _scrollThrottleTimer;

  // Quote-jump highlight state.
  String? _highlightedMessageId;
  Timer? _highlightTimer;
  bool _isQuoteJumpLoading = false;
  final Map<String, GlobalKey> _messageGlobalKeys = {};

  GlobalKey _getMessageKey(String messageId) {
    return _messageGlobalKeys.putIfAbsent(messageId, () => GlobalKey());
  }

  // Mention autocomplete state.
  bool _showMentionOverlay = false;
  String _mentionQuery = '';
  int _mentionTriggerOffset = -1;
  List<ChannelMember> _mentionMembers = [];
  bool _mentionMembersLoaded = false;

  // Voice recording.
  VoiceRecorderService? _voiceRecorder;
  StreamSubscription<VoiceRecorderState>? _voiceStateSub;
  StreamSubscription<double>? _voiceAmplitudeSub;
  StreamSubscription<Duration>? _voiceElapsedSub;

  @override
  void initState() {
    super.initState();
    // Register test hook for observing GlobalKey map size.
    ConversationDetailPage.debugMessageGlobalKeyCount =
        () => _messageGlobalKeys.length;
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
    // Load translation settings so auto-translate and context menu work
    // without requiring a prior visit to the settings page.
    _translationSettingsSub = ref.listenManual<TranslationSettingsState>(
      translationSettingsStoreProvider,
      _handleTranslationSettingsLoaded,
    );
    Future.microtask(
      () => ref.read(translationSettingsStoreProvider.notifier).ensureLoaded(),
    );
  }

  @override
  void dispose() {
    // Clear the key map so the test hook observes count == 0 after dispose.
    // Phase B adds this line; the hook stays alive for test observation.
    _messageGlobalKeys.clear();
    _voiceStateSub?.cancel();
    _voiceAmplitudeSub?.cancel();
    _voiceElapsedSub?.cancel();
    _voiceRecorder?.dispose();
    _stateSubscription?.close();
    _translationSettingsSub?.close();
    _deferredMarkReadSub?.close();
    _scrollThrottleTimer?.cancel();
    _highlightTimer?.cancel();
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
    // INV-SCAFFOLD-SELECT-1: Watch only scaffold-relevant fields so that
    // messages/pendingMessages mutations (the hottest path) do NOT trigger
    // a full scaffold rebuild. The message list has its own subscription via
    // _ConversationMessageList.
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
          isSelectionMode: s.isSelectionMode,
          sendFailure: s.sendFailure,
          pendingAttachments: s.pendingAttachments,
          replyToMessage: s.replyToMessage,
          uploadProgress: s.uploadProgress,
          isSending: s.isSending,
          canSend: s.canSend,
        )));
    final state = ref.read(conversationDetailStoreProvider);
    // INV-NET-DEGRADE-2: surface refresh failure via snackbar only when a
    // refresh completes with failure — not on pagination or mutation errors.
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
    final voiceRecordingState = ref.watch(
      voiceMessageStoreProvider.select((s) => s.recordingState),
    );
    final isRecording = voiceRecordingState == VoiceRecorderState.recording;

    // Initialize typing realtime binding — auto-binds/disposes via provider.
    final target = ref.read(currentConversationDetailTargetProvider);
    final typingScopeKey =
        'server:${target.serverId.value}/${target.surface == ConversationSurface.channel ? 'channel' : 'dm'}:${target.conversationId}';
    ref.watch(typingRealtimeBindingProvider(typingScopeKey));

    if (_composerController.text != state.draft) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _composerController.text != state.draft) {
          _composerController.value = TextEditingValue(
            text: state.draft,
            selection: TextSelection.collapsed(offset: state.draft.length),
          );
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.titleOverride ?? state.resolvedTitle),
            if (target.surface == ConversationSurface.directMessage)
              _DmPresenceSubtitle(
                conversationId: target.conversationId,
              )
            else if (state.description != null && state.description!.isNotEmpty)
              Text(
                state.description!,
                key: const ValueKey('channel-description-text'),
                style: AppTypography.caption.copyWith(
                  color:
                      Theme.of(context).extension<AppColors>()!.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            else if (state.memberCount != null)
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
              tooltip: state.isSearchActive ? 'Close search' : 'Search',
              onPressed: ref
                  .read(conversationDetailStoreProvider.notifier)
                  .toggleSearch,
            ),
          if (state.status == ConversationDetailStatus.success)
            IconButton(
              key: const ValueKey('conversation-members-shortcut'),
              icon: const Icon(Icons.info_outline),
              tooltip: 'Conversation info',
              onPressed: () {
                final target =
                    ref.read(currentConversationDetailTargetProvider);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ConversationInfoPage(
                      target: target,
                      title: state.resolvedTitle,
                      description: state.description,
                      initialSection: ConversationInfoSection.members,
                    ),
                  ),
                );
              },
            ),
          if (state.status == ConversationDetailStatus.success)
            IconButton(
              key: const ValueKey('conversation-screenshot'),
              icon: const Icon(Icons.screenshot_outlined),
              onPressed: () => _captureAndAnnotate(),
              tooltip: 'Screenshot',
            ),
          ...?widget.appBarActionsBuilder?.call(context, ref, state),
        ],
      ),
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
          const ConnectionStatusBanner(),
          const _OfflineBanner(),
          Expanded(
            child: switch (state.status) {
              ConversationDetailStatus.initial ||
              ConversationDetailStatus.loading =>
                ListView(
                  key: const ValueKey('conversation-skeleton'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageHorizontal,
                    vertical: AppSpacing.sm,
                  ),
                  children: const [
                    SkeletonListItem(
                      key: ValueKey('conversation-skeleton-item-0'),
                    ),
                    SkeletonListItem(
                      key: ValueKey('conversation-skeleton-item-1'),
                    ),
                    SkeletonListItem(
                      key: ValueKey('conversation-skeleton-item-2'),
                    ),
                    SkeletonListItem(
                      key: ValueKey('conversation-skeleton-item-3'),
                    ),
                    SkeletonListItem(
                      key: ValueKey('conversation-skeleton-item-4'),
                    ),
                  ],
                ),
              ConversationDetailStatus.failure => _ConversationFailureView(
                  state: state,
                  onRetry: () => ref
                      .read(conversationDetailStoreProvider.notifier)
                      .retry(),
                ),
              ConversationDetailStatus.success when state.isEmpty =>
                _ConversationEmptyView(title: state.resolvedTitle),
              ConversationDetailStatus.success => Column(
                  children: [
                    if (state.isRefreshing)
                      const LinearProgressIndicator(
                        key: ValueKey('conversation-refreshing'),
                        minHeight: 2,
                      ),
                    Expanded(
                      child: Stack(
                        children: [
                          RepaintBoundary(
                            key: _screenshotBoundaryKey,
                            child: ConversationMessageList(
                              controller: _scrollController,
                              onScrollToMessage: _scrollToMessageId,
                              highlightedMessageId: _highlightedMessageId,
                              messageKeyBuilder: _getMessageKey,
                            ),
                          ),
                          if (_isQuoteJumpLoading)
                            const Positioned.fill(
                              child: Align(
                                alignment: Alignment.center,
                                child: Card(
                                  key: ValueKey('quote-jump-loading'),
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.info_outline, size: 16),
                                        SizedBox(width: 12),
                                        Text('Message not available'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (_showScrollToBottom)
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: FloatingActionButton.small(
                                key: const ValueKey('scroll-to-bottom-fab'),
                                onPressed: () {
                                  _scrollController.animateTo(
                                    0,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                  );
                                },
                                child: const Icon(
                                  Icons.keyboard_double_arrow_down,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
            },
          ),
          if (state.status == ConversationDetailStatus.success)
            const TypingIndicatorWidget(),
          if (state.status == ConversationDetailStatus.success &&
              _showMentionOverlay &&
              _filteredMentionMembers.isNotEmpty)
            _MentionSuggestionOverlay(
              key: const ValueKey('mention-suggestion-overlay'),
              members: _filteredMentionMembers,
              onSelect: _insertMention,
            ),
          if (state.status == ConversationDetailStatus.success &&
              state.isSelectionMode)
            const SelectionActionBar()
          else if (state.status == ConversationDetailStatus.success)
            ConversationComposer(
              controller: _composerController,
              focusNode: _composerFocusNode,
              state: state,
              isRecording: isRecording,
              enterToSend: ref.watch(
                composerSettingsStoreProvider.select((s) => s.enterToSend),
              ),
              isFormattingToolbarVisible: _isFormattingToolbarVisible,
              isEmojiPickerVisible: _isEmojiPickerVisible,
              onToggleFormattingToolbar: () {
                setState(() {
                  _isFormattingToolbarVisible = !_isFormattingToolbarVisible;
                });
              },
              onToggleEmojiPicker: () {
                setState(() {
                  _isEmojiPickerVisible = !_isEmojiPickerVisible;
                });
              },
              onChanged: (value) {
                ref
                    .read(conversationDetailStoreProvider.notifier)
                    .updateDraft(value);
                if (value.trim().isNotEmpty) {
                  _emitTyping();
                }
                _detectMentionTrigger(value);
              },
              onSend: _handleSend,
              onPickAttachment: ref
                  .read(conversationDetailStoreProvider.notifier)
                  .addPendingAttachment,
              onRemoveAttachment: ref
                  .read(conversationDetailStoreProvider.notifier)
                  .removePendingAttachment,
              onCancelUpload: ref
                  .read(conversationDetailStoreProvider.notifier)
                  .cancelUpload,
              onClearReply: ref
                  .read(conversationDetailStoreProvider.notifier)
                  .clearReplyTo,
              onMicTap: _startRecording,
              onSendRecording: _stopRecordingAndSend,
              onCancelRecording: _cancelRecording,
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

  void _emitTyping() {
    final target = ref.read(currentConversationDetailTargetProvider);
    final typingScopeKey =
        'server:${target.serverId.value}/${target.surface == ConversationSurface.channel ? 'channel' : 'dm'}:${target.conversationId}';
    ref.read(typingRealtimeBindingProvider(typingScopeKey)).emitTyping();
  }

  // ---------------------------------------------------------------------------
  // Mention autocomplete
  // ---------------------------------------------------------------------------

  void _detectMentionTrigger(String text) {
    final cursorOffset = _composerController.selection.baseOffset;
    if (cursorOffset < 0) {
      _closeMentionOverlay();
      return;
    }

    // Walk backwards from cursor to find '@' trigger.
    final textBeforeCursor = text.substring(0, cursorOffset);
    final atIndex = textBeforeCursor.lastIndexOf('@');
    if (atIndex < 0) {
      _closeMentionOverlay();
      return;
    }

    // '@' must be at start of text or preceded by a whitespace character.
    if (atIndex > 0 && textBeforeCursor[atIndex - 1] != ' ') {
      _closeMentionOverlay();
      return;
    }

    // Extract query after '@' (up to cursor).
    final query = textBeforeCursor.substring(atIndex + 1);

    // Query must not contain spaces (would mean user moved past the mention).
    if (query.contains(' ')) {
      _closeMentionOverlay();
      return;
    }

    setState(() {
      _showMentionOverlay = true;
      _mentionQuery = query;
      _mentionTriggerOffset = atIndex;
    });

    if (!_mentionMembersLoaded) {
      _loadMentionMembers();
    }
  }

  void _closeMentionOverlay() {
    if (_showMentionOverlay) {
      setState(() {
        _showMentionOverlay = false;
        _mentionQuery = '';
        _mentionTriggerOffset = -1;
      });
    }
  }

  Future<void> _loadMentionMembers() async {
    try {
      final target = ref.read(currentConversationDetailTargetProvider);
      final repo = ref.read(channelMemberRepositoryProvider);
      final members = await repo.listMembers(
        target.serverId,
        channelId: target.conversationId,
      );
      if (mounted) {
        setState(() {
          _mentionMembers = members;
          _mentionMembersLoaded = true;
        });
      }
    } on Exception catch (e) {
      ref.read(diagnosticsCollectorProvider).error(
            'ConversationDetail',
            'Mention member load failed: $e',
          );
    }
  }

  List<ChannelMember> get _filteredMentionMembers {
    if (_mentionQuery.isEmpty) return _mentionMembers;
    final queryLower = _mentionQuery.toLowerCase();
    return _mentionMembers
        .where((m) => m.displayName.toLowerCase().contains(queryLower))
        .toList();
  }

  void _insertMention(ChannelMember member) {
    final text = _composerController.text;
    final mention = '@${member.mentionHandle} ';
    final before = text.substring(0, _mentionTriggerOffset);
    final cursorOffset = _composerController.selection.baseOffset;
    final after = text.substring(cursorOffset);
    final newText = '$before$mention$after';
    _composerController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: before.length + mention.length,
      ),
    );
    // Notify the store about draft change.
    ref.read(conversationDetailStoreProvider.notifier).updateDraft(newText);
    _closeMentionOverlay();
  }

  Future<void> _captureAndAnnotate() async {
    const captureService = ScreenshotCaptureService();
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final path = await captureService.capture(
      _screenshotBoundaryKey,
      pixelRatio: pixelRatio,
    );
    if (path == null || !mounted) return;

    ref.read(screenshotStoreProvider.notifier).setCapturedImage(path);
    context.push('/screenshot-annotate');
  }

  Future<void> _startRecording() async {
    final recorder = _voiceRecorder ??= VoiceRecorderService();
    final store = ref.read(voiceMessageStoreProvider.notifier);

    // Check / request microphone permission.
    try {
      final granted = await recorder.hasPermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            key: ValueKey('mic-permission-denied'),
            content: Text(
              'Microphone permission denied. '
              'Please enable it in Settings.',
            ),
          ),
        );
        return;
      }
    } on Exception catch (e) {
      ref.read(diagnosticsCollectorProvider).error(
            'ConversationDetail',
            'Mic permission check failed: $e',
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: ValueKey('mic-permission-error'),
          content: Text('Could not check microphone permission.'),
        ),
      );
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_voice.m4a';

      _voiceStateSub?.cancel();
      _voiceAmplitudeSub?.cancel();
      _voiceElapsedSub?.cancel();

      _voiceStateSub = recorder.stateStream.listen((s) {
        store.setRecordingState(s);
      });
      _voiceAmplitudeSub = recorder.amplitudeStream.listen((a) {
        store.addAmplitude(a);
      });
      _voiceElapsedSub = recorder.elapsedStream.listen((d) {
        store.setElapsed(d);
      });

      await recorder.start(outputPath: outputPath);
      store.setRecordingState(VoiceRecorderState.recording);
    } on Exception catch (e) {
      // Clean up any partial subscriptions.
      _voiceStateSub?.cancel();
      _voiceAmplitudeSub?.cancel();
      _voiceElapsedSub?.cancel();
      store.reset();

      ref
          .read(diagnosticsCollectorProvider)
          .error('VoiceRecording', 'Recording start failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: ValueKey('recording-start-error'),
          content: Text(
            'Could not start recording. '
            'Please check microphone availability.',
          ),
        ),
      );
    }
  }

  Future<void> _stopRecordingAndSend() async {
    final recorder = _voiceRecorder;
    if (recorder == null) return;

    // Capture recorded amplitudes before resetting the store.
    final amplitudes = List<double>.unmodifiable(
        ref.read(voiceMessageStoreProvider).amplitudes);

    final path = await recorder.stop();
    final store = ref.read(voiceMessageStoreProvider.notifier);
    store.reset();

    _voiceStateSub?.cancel();
    _voiceAmplitudeSub?.cancel();
    _voiceElapsedSub?.cancel();

    if (path == null || !mounted) return;

    final name = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    // Cache the recorded waveform so the inline player can use it.
    if (amplitudes.isNotEmpty) {
      ref.read(voiceWaveformCacheProvider.notifier).put(name, amplitudes);
    }

    ref.read(conversationDetailStoreProvider.notifier).addPendingAttachment(
          PendingAttachment(
            path: path,
            name: name,
            mimeType: 'audio/mp4',
          ),
        );
    // Auto-send the voice message immediately.
    await _handleSend();
  }

  Future<void> _cancelRecording() async {
    final recorder = _voiceRecorder;
    if (recorder == null) return;

    await recorder.cancel();
    ref.read(voiceMessageStoreProvider.notifier).reset();

    _voiceStateSub?.cancel();
    _voiceAmplitudeSub?.cancel();
    _voiceElapsedSub?.cancel();
  }

  /// INV-TRANSLATE-3: auto-translate visible messages when mode is auto.
  /// Called on first successful load and after loadOlder/loadNewer.
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

  /// #566: Eagerly register all image attachments with the download scheduler.
  /// This ensures offscreen items are tracked (deferred) from page load.
  /// VisibilityDetector later promotes visible items to the priority queue.
  void _registerAttachmentDownloads(
    List<ConversationMessageSummary> messages,
  ) {
    final scheduler = ref.read(downloadSchedulerProvider.notifier);
    for (final message in messages) {
      final attachments = message.attachments;
      if (attachments == null) continue;
      for (final attachment in attachments) {
        if (attachment.id == null) continue;
        final mimeType = attachment.type.toLowerCase();
        if (!mimeType.startsWith('image/')) continue;
        if (attachment.thumbnailUrl == null && attachment.url == null) continue;
        scheduler.enqueue(
          attachment.id!,
          () async {/* Pre-fetch signed URL — actual fetch added later. */},
        );
      }
    }
  }

  /// Handles the race where conversation data arrives before translation
  /// settings. When settings transition to success and conversation is
  /// already loaded, re-trigger auto-translate.
  void _handleTranslationSettingsLoaded(
    TranslationSettingsState? previous,
    TranslationSettingsState next,
  ) {
    if (previous?.status != TranslationSettingsStatus.success &&
        next.status == TranslationSettingsStatus.success) {
      final convState = ref.read(conversationDetailStoreProvider);
      if (convState.status == ConversationDetailStatus.success) {
        _autoTranslateIfNeeded(convState.messages);
      }
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    // Show/hide scroll-to-bottom FAB based on scroll offset.
    // With reverse:true, offset 0 = bottom (newest), offset > 300 = scrolled up.
    final shouldShow = _scrollController.offset > 300;
    if (shouldShow != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = shouldShow;
      });
    }

    // Throttle updateViewportOffset writes to avoid 60+ state writes/sec
    // during rapid scrolling. Timer-based: at most one write per 100ms.
    if (_scrollThrottleTimer == null || !_scrollThrottleTimer!.isActive) {
      _scrollThrottleTimer = Timer(const Duration(milliseconds: 100), () {
        if (mounted && _scrollController.hasClients) {
          ref
              .read(conversationDetailStoreProvider.notifier)
              .updateViewportOffset(_scrollController.offset);
        }
      });
    }

    // With reverse:true, offset 0 = bottom (newest), maxScrollExtent = top
    // (oldest). Load older messages when near the top (oldest end).
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (_scrollController.offset < maxExtent - 80) {
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
    // Fire markRead exactly once on first successful load,
    // only when there are actually unread messages (INV-READ-4).
    // If the inbox projection is not yet loaded (race condition: user opened
    // conversation before inbox finished loading), set up a one-shot deferred
    // listener that fires markRead when the projection becomes available
    // (INV-RACE-1). The deferred listener fires at most once (INV-RACE-2).
    if (previous?.status != ConversationDetailStatus.success &&
        next.status == ConversationDetailStatus.success) {
      final t = ref.read(currentConversationDetailTargetProvider);
      final projection = ref.read(unreadSourceProjectionProvider);

      if (projection.isLoaded) {
        _fireMarkReadIfUnread(t, projection);
      } else {
        // Inbox not loaded yet — defer markRead until projection is available.
        // Use addPostFrameCallback so the loaded projection state is
        // observable before markRead's optimistic zeroing takes effect.
        _deferredMarkReadSub?.close();
        _deferredMarkReadSub = ref.listenManual<UnreadSourceProjectionState>(
          unreadSourceProjectionProvider,
          (previous, next) {
            if (next.isLoaded) {
              // One-shot: close subscription immediately.
              _deferredMarkReadSub?.close();
              _deferredMarkReadSub = null;
              // Defer markRead to next frame so the loaded state is
              // observable before optimistic zeroing (INV-RACE-1).
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _fireMarkReadIfUnread(t, next);
                }
              });
            }
          },
        );
      }

      // INV-TRANSLATE-3: auto-translate visible messages on first load
      // when translation mode is auto.
      _autoTranslateIfNeeded(next.messages);
    }

    // #566: Register attachment downloads on every state change (not just
    // first load). After loadOlder() appends messages, the new attachments
    // must also be enqueued. The scheduler's enqueue() deduplicates, so
    // calling with all messages on every change is safe.
    if (next.status == ConversationDetailStatus.success) {
      _registerAttachmentDownloads(next.messages);
    }

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

  /// Fires markRead for the current conversation if the projection
  /// reports unread messages. Called both on immediate success and
  /// from the deferred listener (INV-RACE-1).
  void _fireMarkReadIfUnread(
    ConversationDetailTarget t,
    UnreadSourceProjectionState projection,
  ) {
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
      final targetMsgId = widget.highlightMessageId;
      // Compute the first unread message ID for auto-scroll.
      final unreadCount = unreadCountForTarget(ref, next.target);
      final firstUnreadMsgId =
          unreadCount > 0 && unreadCount <= next.messages.length
              ? next.messages[next.messages.length - unreadCount].id
              : null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) {
          return;
        }
        if (targetMsgId != null) {
          _scrollToMessageId(targetMsgId, next.messages);
        } else if (firstUnreadMsgId != null) {
          // Auto-scroll to the first unread message (unread divider area).
          _scrollToMessageId(firstUnreadMsgId, next.messages);
        } else {
          _scrollController.jumpTo(0);
        }
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

  /// Scroll to a specific message by ID and show a highlight flash.
  ///
  /// When the target message is in the loaded list, scrolls to it using
  /// GlobalKey-based [Scrollable.ensureVisible] and shows a brief highlight.
  /// When the target is not loaded, attempts to load older messages via API;
  /// if still not found, shows a [quote-jump-loading] feedback widget.
  void _scrollToMessageId(
    String messageId,
    List<ConversationMessageSummary> messages,
  ) {
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx < 0) {
      // Message not in loaded window — attempt async load.
      _handleQuoteJumpMissing(messageId);
      return;
    }
    _scrollToAndHighlight(messageId);
  }

  /// Scrolls to a message using GlobalKey-based ensureVisible and applies
  /// a highlight flash that auto-dismisses after 1.5 seconds.
  void _scrollToAndHighlight(String messageId) {
    // Clear any existing highlight first.
    _highlightTimer?.cancel();

    // Set the highlight immediately so the widget tree rebuilds with it.
    setState(() {
      _highlightedMessageId = messageId;
      _isQuoteJumpLoading = false;
    });

    // Use post-frame callback to ensure the widget is built before scrolling.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _getMessageKey(messageId);
      if (key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 300),
          alignment: 0.3,
          curve: Curves.easeInOut,
        );
      } else {
        // GlobalKey not yet in viewport — fall back to proportional estimate.
        final state = ref.read(conversationDetailStoreProvider);
        final idx = state.messages.indexWhere((m) => m.id == messageId);
        if (idx >= 0 && _scrollController.hasClients) {
          final maxExtent = _scrollController.position.maxScrollExtent;
          final estimatedOffset = state.messages.isEmpty
              ? 0.0
              : (state.messages.length - idx) /
                  (state.messages.length + 1) *
                  maxExtent;
          _scrollController.jumpTo(estimatedOffset.clamp(0.0, maxExtent));
        }
      }
    });

    // Auto-dismiss highlight after 1.5 seconds.
    _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _highlightedMessageId = null);
    });
  }

  /// Handles quote-jump when the target message is not in the loaded window.
  /// Attempts to load older messages; if the target is still not found,
  /// shows a persistent feedback widget keyed [quote-jump-loading].
  Future<void> _handleQuoteJumpMissing(String messageId) async {
    setState(() => _isQuoteJumpLoading = true);

    final notifier = ref.read(conversationDetailStoreProvider.notifier);
    final state = ref.read(conversationDetailStoreProvider);

    if (state.hasOlder) {
      await notifier.loadOlder();
      if (!mounted) return;

      // Re-check after loading.
      final updatedState = ref.read(conversationDetailStoreProvider);
      final idx = updatedState.messages.indexWhere((m) => m.id == messageId);
      if (idx >= 0) {
        _scrollToAndHighlight(messageId);
        return;
      }
    }

    // Still not found — show persistent feedback.
    if (mounted) {
      setState(() => _isQuoteJumpLoading = true);
    }
  }

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

// ---------------------------------------------------------------------------
// Mention suggestion overlay — shows channel members matching '@query'
// ---------------------------------------------------------------------------

class _MentionSuggestionOverlay extends StatelessWidget {
  const _MentionSuggestionOverlay({
    super.key,
    required this.members,
    required this.onSelect,
  });

  final List<ChannelMember> members;
  final ValueChanged<ChannelMember> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.border, width: 0.5),
        ),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        itemCount: members.length,
        itemBuilder: (context, index) {
          final member = members[index];
          return InkWell(
            key: ValueKey('mention-suggestion-$index'),
            onTap: () => onSelect(member),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: colors.surfaceAlt,
                    child: Text(
                      member.displayName.isNotEmpty
                          ? member.displayName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    member.displayName,
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.text,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DM presence subtitle — shown in the app bar for direct messages.
// ---------------------------------------------------------------------------

class _DmPresenceSubtitle extends ConsumerWidget {
  const _DmPresenceSubtitle({required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peerId = ref.watch(
      homeListStoreProvider.select((state) {
        for (final dm in state.pinnedDirectMessages) {
          if (dm.scopeId.value == conversationId) return dm.peerId;
        }
        for (final dm in state.directMessages) {
          if (dm.scopeId.value == conversationId) return dm.peerId;
        }
        for (final dm in state.hiddenDirectMessages) {
          if (dm.scopeId.value == conversationId) return dm.peerId;
        }
        return null;
      }),
    );
    if (peerId == null) return const SizedBox.shrink();

    final status = ref.watch(
      presenceStoreProvider.select((s) => s.statusOf(peerId)),
    );
    final colors = Theme.of(context).extension<AppColors>()!;

    final dotColor = switch (status) {
      UserPresenceStatus.online => colors.success,
      UserPresenceStatus.idle => colors.warning,
      UserPresenceStatus.offline => colors.textTertiary,
    };
    final statusText = switch (status) {
      UserPresenceStatus.online => 'Online',
      UserPresenceStatus.idle => 'Idle',
      UserPresenceStatus.offline => 'Offline',
    };

    return Row(
      key: const ValueKey('conversation-dm-presence'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          statusText,
          style: AppTypography.caption.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Banner shown at the top of the conversation when the device is offline.
///
/// Watches the [ConnectivityService] status stream and only renders when
/// the device is currently offline. Collapses to zero height when online.
class _OfflineBanner extends ConsumerWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityServiceProvider);
    return StreamBuilder<ConnectivityStatus>(
      stream: connectivity.statusStream,
      initialData: connectivity.status,
      builder: (context, snapshot) {
        final isOnline = (snapshot.data ?? ConnectivityStatus.online) ==
            ConnectivityStatus.online;
        if (isOnline) return const SizedBox.shrink();

        final colors = Theme.of(context).extension<AppColors>()!;
        return Container(
          key: const ValueKey('offline-banner'),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          color: colors.warning.withValues(alpha: 0.15),
          child: Row(
            children: [
              Icon(Icons.cloud_off, size: 16, color: colors.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'You are offline. Messages will be sent when you reconnect.',
                  style: AppTypography.caption.copyWith(color: colors.warning),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Bottom action bar shown during multi-select mode. (#537)
///
/// Displays Cancel, Delete, and Save buttons for batch operations
/// on the currently selected messages.
