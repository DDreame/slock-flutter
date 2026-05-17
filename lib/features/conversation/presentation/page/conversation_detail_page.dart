import 'dart:async';
import 'dart:math' as math;

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_info_page.dart';
import 'package:slock_app/features/conversation/presentation/widgets/csv_preview_widget.dart';
import 'package:slock_app/features/conversation/presentation/widgets/markdown_message_body.dart';
import 'package:slock_app/features/conversation/presentation/widgets/message_content_widget.dart';
import 'package:slock_app/features/conversation/presentation/widgets/svg_preview_widget.dart';
import 'package:slock_app/features/conversation/presentation/widgets/text_preview_widget.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_status_tokens.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/message_bubble.dart';
import 'package:slock_app/app/widgets/skeleton_list_item.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/data/channel_member_repository_provider.dart';
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_session_store.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/application/message_send_status.dart';
import 'package:slock_app/features/conversation/data/attachment_repository_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/share/presentation/page/share_target_picker_page.dart';
import 'package:slock_app/features/unread/application/mark_read_use_case.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';
import 'package:slock_app/features/conversation/presentation/widgets/message_context_menu.dart';
import 'package:slock_app/features/conversation/presentation/widgets/message_gesture_wrapper.dart';
import 'package:slock_app/features/screenshot/application/screenshot_store.dart';
import 'package:slock_app/features/screenshot/data/screenshot_capture_service.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/voice/application/voice_message_store.dart';
import 'package:slock_app/features/voice/data/audio_player_service.dart';
import 'package:slock_app/features/voice/data/voice_recorder_service.dart';
import 'package:slock_app/features/voice/presentation/widgets/voice_message_bubble.dart';
import 'package:slock_app/features/voice/presentation/widgets/voice_recorder_widget.dart';
import 'package:slock_app/features/translation/application/translation_cache_store.dart';
import 'package:slock_app/features/translation/application/translation_settings_store.dart';
import 'package:slock_app/features/translation/data/translation_settings.dart';
import 'package:slock_app/features/translation/presentation/widget/translated_content_overlay.dart';
import 'package:slock_app/features/conversation/data/typing_realtime_binding.dart';
import 'package:slock_app/features/conversation/presentation/widgets/formatting_toolbar.dart';
import 'package:slock_app/features/conversation/presentation/widgets/typing_indicator_widget.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/members/presentation/widgets/member_profile_sheet.dart';
import 'package:slock_app/features/presence/application/presence_store.dart';
import 'package:slock_app/features/profile/data/profile_repository_provider.dart';
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
    this.highlightMessageId,
  }) : _target = target;

  final ConversationDetailTarget _target;
  final String? titleOverride;
  final ConversationAppBarActionsBuilder? appBarActionsBuilder;
  final bool registerOpenTarget;

  /// When set, the page will scroll to (and optionally highlight) this message
  /// once the message list is loaded.
  final String? highlightMessageId;

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
    _voiceStateSub?.cancel();
    _voiceAmplitudeSub?.cancel();
    _voiceElapsedSub?.cancel();
    _voiceRecorder?.dispose();
    _stateSubscription?.close();
    _translationSettingsSub?.close();
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
    final state = ref.watch(conversationDetailStoreProvider);
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
    final voiceState = ref.watch(voiceMessageStoreProvider);
    final isRecording =
        voiceState.recordingState == VoiceRecorderState.recording;

    // Initialize typing realtime binding — auto-binds/disposes via provider.
    final target = ref.read(currentConversationDetailTargetProvider);
    final typingScopeKey =
        'server:${target.serverId.value}/${target.surface == ConversationSurface.channel ? 'channel' : 'dm'}:${target.conversationId}';
    ref.watch(typingRealtimeBindingProvider(typingScopeKey));

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
            if (target.surface == ConversationSurface.directMessage)
              _DmPresenceSubtitle(
                conversationId: target.conversationId,
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
              onPressed: ref
                  .read(conversationDetailStoreProvider.notifier)
                  .toggleSearch,
            ),
          if (state.status == ConversationDetailStatus.success &&
              ref.read(currentConversationDetailTargetProvider).surface ==
                  ConversationSurface.channel)
            IconButton(
              key: const ValueKey('conversation-pinned-messages'),
              icon: const Icon(Icons.push_pin_outlined),
              onPressed: () async {
                final target =
                    ref.read(currentConversationDetailTargetProvider);
                // Use GoRouter push instead of Navigator.push so the page
                // is visible to GoRouter's navigation stack.
                final messageId = await context.push<String>(
                  '/servers/${target.serverId.value}/channels/${target.conversationId}/pinned',
                  extra: target,
                );
                if (messageId != null && mounted) {
                  final currentState =
                      ref.read(conversationDetailStoreProvider);
                  if (currentState.status == ConversationDetailStatus.success) {
                    _scrollToMessageId(messageId, currentState.messages);
                  }
                }
              },
            ),
          if (state.status == ConversationDetailStatus.success)
            IconButton(
              key: const ValueKey('conversation-members-toggle'),
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                final target =
                    ref.read(currentConversationDetailTargetProvider);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ConversationInfoPage(
                      target: target,
                      title: state.resolvedTitle,
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
                            child: _ConversationMessageList(
                              controller: _scrollController,
                              state: state,
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
            const _SelectionActionBar()
          else if (state.status == ConversationDetailStatus.success)
            _ConversationComposer(
              controller: _composerController,
              focusNode: _composerFocusNode,
              state: state,
              isRecording: isRecording,
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
    } catch (_) {
      // Silently fail — mention suggestions are optional.
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
    } catch (_) {
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
    } catch (e) {
      // Clean up any partial subscriptions.
      _voiceStateSub?.cancel();
      _voiceAmplitudeSub?.cancel();
      _voiceElapsedSub?.cancel();
      store.reset();

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
      ref.read(voiceWaveformCacheProvider.notifier).update(
            (cache) => {...cache, name: amplitudes},
          );
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
    if (previous?.status != ConversationDetailStatus.success &&
        next.status == ConversationDetailStatus.success) {
      final t = ref.read(currentConversationDetailTargetProvider);
      final projection = ref.read(unreadSourceProjectionProvider);
      switch (t.surface) {
        case ConversationSurface.channel:
          final scopeId =
              ChannelScopeId(serverId: t.serverId, value: t.conversationId);
          if (projection.channelUnreadCount(scopeId) > 0) {
            ref.read(markChannelReadUseCaseProvider)(scopeId);
          }
        case ConversationSurface.directMessage:
          final scopeId = DirectMessageScopeId(
              serverId: t.serverId, value: t.conversationId);
          if (projection.dmUnreadCount(scopeId) > 0) {
            ref.read(markDmReadUseCaseProvider)(scopeId);
          }
      }

      // INV-TRANSLATE-3: auto-translate visible messages on first load
      // when translation mode is auto.
      _autoTranslateIfNeeded(next.messages);
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
      final unreadCount = _unreadCountForTarget(ref, next.target);
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

class _ConversationMessageList extends ConsumerWidget {
  const _ConversationMessageList({
    required this.controller,
    required this.state,
    this.onScrollToMessage,
    this.highlightedMessageId,
    this.messageKeyBuilder,
  });

  final ScrollController controller;
  final ConversationDetailState state;
  final void Function(
          String messageId, List<ConversationMessageSummary> messages)?
      onScrollToMessage;

  /// The message ID currently highlighted from a quote-jump.
  final String? highlightedMessageId;

  /// Returns a [GlobalKey] for a given message ID, used for
  /// [Scrollable.ensureVisible]-based scroll targeting.
  final GlobalKey Function(String messageId)? messageKeyBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCount = state.pendingMessages.length;
    final totalCount = state.messages.length + pendingCount + 1;
    // Compute maxBubbleWidth once at the list level instead of per-message
    // LayoutBuilder to avoid unnecessary layout passes.
    // Subtract horizontal list padding (16 each side) to match the inner
    // width that LayoutBuilder previously provided.
    final maxBubbleWidth =
        (MediaQuery.of(context).size.width - 32) * _bubbleMaxWidthFraction;

    // Compute unread divider position from the production unread projection.
    // The divider separator index is pendingCount + unreadCount - 1, i.e.
    // between the last unread message (item[pendingCount + unreadCount - 1])
    // and the first read message (item[pendingCount + unreadCount]).
    final unreadCount = _unreadCountForTarget(ref, state.target);
    final unreadSepIndex =
        unreadCount > 0 && unreadCount <= state.messages.length
            ? pendingCount + unreadCount - 1
            : -1;

    return ListView.separated(
      key: const ValueKey('conversation-success'),
      controller: controller,
      reverse: true,
      cacheExtent: 500,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(16),
      itemCount: totalCount,
      separatorBuilder: (context, index) {
        // Resolve timestamps for the items on both sides of this separator.
        // With reverse:true, item[index] is newer (below), item[index+1] is
        // older (above). Show a date chip when they fall on different days.
        final newerDate = _dateForItemAt(index, pendingCount, state);
        final olderDate = _dateForItemAt(index + 1, pendingCount, state);

        // Check if this separator is the unread boundary.
        final isUnreadBoundary = index == unreadSepIndex;

        // Date separator takes priority — wrap with unread divider if needed.
        if (newerDate != null &&
            olderDate != null &&
            !_isSameDay(newerDate, olderDate)) {
          if (isUnreadBoundary) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _UnreadDivider(),
                _DateSeparatorWidget(
                  key: const ValueKey('date-separator'),
                  date: newerDate,
                ),
              ],
            );
          }
          return _DateSeparatorWidget(
            key: const ValueKey('date-separator'),
            date: newerDate,
          );
        }

        // Unread divider at this separator position.
        if (isUnreadBoundary) {
          return const _UnreadDivider();
        }

        // Grouped messages (same sender, <5min, same day) get a tighter gap.
        final newerMsg = _messageForItemAt(index, pendingCount, state);
        final olderMsg = _messageForItemAt(index + 1, pendingCount, state);
        if (newerMsg != null &&
            olderMsg != null &&
            _shouldGroupWith(newerMsg, olderMsg)) {
          return const SizedBox(height: 3);
        }
        return const SizedBox(height: 12);
      },
      itemBuilder: (context, index) {
        // With reverse:true, index 0 = bottom of screen.
        // Order: pending (newest first) → messages (newest first) → header.
        if (index < pendingCount) {
          final pending = state.pendingMessages[pendingCount - 1 - index];
          return _PendingMessageCard(
            key: ValueKey('pending-${pending.localId}'),
            pending: pending,
            maxBubbleWidth: maxBubbleWidth,
          );
        }
        final adjustedIndex = index - pendingCount;
        if (adjustedIndex < state.messages.length) {
          final message =
              state.messages[state.messages.length - 1 - adjustedIndex];
          // Determine if this message should show its header by checking
          // the chronologically-previous message (index+1 in reversed list).
          final olderMsg = _messageForItemAt(index + 1, pendingCount, state);
          final showHeader =
              olderMsg == null || !_shouldGroupWith(message, olderMsg);
          final isCurrentSearchMatch = state.searchMatchIds.isNotEmpty &&
              state.currentSearchMatchIndex < state.searchMatchIds.length &&
              state.searchMatchIds[state.currentSearchMatchIndex] == message.id;
          final isQuoteJumpHighlighted = highlightedMessageId == message.id;
          final messageKey = messageKeyBuilder?.call(message.id);
          return RepaintBoundary(
            key: ValueKey('repaint-boundary-${message.id}'),
            child: KeyedSubtree(
              key: messageKey,
              child: _ConversationMessageCard(
                target: state.target,
                message: message,
                maxBubbleWidth: maxBubbleWidth,
                showHeader: showHeader,
                highlightQuery: state.searchQuery,
                isCurrentSearchMatch: isCurrentSearchMatch,
                isQuoteJumpHighlighted: isQuoteJumpHighlighted,
                onScrollToMessage: onScrollToMessage != null
                    ? (messageId) =>
                        onScrollToMessage!(messageId, state.messages)
                    : null,
              ),
            ),
          );
        }
        // Last item (top of screen) = history header.
        return _ConversationHistoryHeader(state: state);
      },
    );
  }
}

/// Returns the unread message count for [target] from the projection store.
int _unreadCountForTarget(WidgetRef ref, ConversationDetailTarget target) {
  final projection = ref.watch(unreadSourceProjectionProvider);
  switch (target.surface) {
    case ConversationSurface.channel:
      final scopeId = ChannelScopeId(
          serverId: target.serverId, value: target.conversationId);
      return projection.channelUnreadCount(scopeId);
    case ConversationSurface.directMessage:
      final scopeId = DirectMessageScopeId(
          serverId: target.serverId, value: target.conversationId);
      return projection.dmUnreadCount(scopeId);
  }
}

/// "New messages" divider inserted at the boundary between read and unread
/// messages in the conversation list.
class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      key: const ValueKey('unread-divider'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: colors.primary,
              thickness: 1,
              height: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'New messages',
              style: AppTypography.caption.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: colors.primary,
              thickness: 1,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Precise timestamp label shown below a message bubble when tapped.
/// Displays the full date and time in HH:mm:ss format.
class _PreciseTimestampLabel extends StatelessWidget {
  const _PreciseTimestampLabel({required this.createdAt});

  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final local = createdAt.toLocal();
    final formatted = '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';
    return Padding(
      key: const ValueKey('precise-timestamp'),
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        formatted,
        style: AppTypography.caption.copyWith(
          color: colors.textSecondary,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// Normalizes a [DateTime] to the user's local timezone for day-boundary
/// comparison. Override in tests to simulate non-UTC timezones.
@visibleForTesting
DateTime Function(DateTime) dateSeparatorToLocal = (dt) => dt.toLocal();

/// Resolve the [ConversationMessageSummary] at [index], or null for pending/header.
ConversationMessageSummary? _messageForItemAt(
  int index,
  int pendingCount,
  ConversationDetailState state,
) {
  if (index < pendingCount) return null; // pending message
  final adjustedIndex = index - pendingCount;
  if (adjustedIndex < state.messages.length) {
    return state.messages[state.messages.length - 1 - adjustedIndex];
  }
  return null; // header
}

/// Whether [newer] should be grouped with [older] (same sender, <5min, same
/// day, neither is a system message).
bool _shouldGroupWith(
  ConversationMessageSummary newer,
  ConversationMessageSummary older,
) {
  if (newer.isSystem || older.isSystem) return false;
  if (newer.senderId == null || newer.senderId != older.senderId) return false;
  final diff = newer.createdAt.difference(older.createdAt).abs();
  if (diff > const Duration(minutes: 5)) return false;
  if (!_isSameDay(newer.createdAt, older.createdAt)) return false;
  return true;
}

/// Resolve the [DateTime] for the list item at [index], or null for the header.
DateTime? _dateForItemAt(
  int index,
  int pendingCount,
  ConversationDetailState state,
) {
  if (index < pendingCount) {
    return state.pendingMessages[pendingCount - 1 - index].createdAt;
  }
  final adjustedIndex = index - pendingCount;
  if (adjustedIndex < state.messages.length) {
    return state.messages[state.messages.length - 1 - adjustedIndex].createdAt;
  }
  // Header item — no date.
  return null;
}

/// True when [a] and [b] fall on the same local calendar day.
bool _isSameDay(DateTime a, DateTime b) {
  final la = dateSeparatorToLocal(a);
  final lb = dateSeparatorToLocal(b);
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

class _DateSeparatorWidget extends StatelessWidget {
  const _DateSeparatorWidget({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDateLabel(date),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDateLabel(DateTime date) {
    final local = dateSeparatorToLocal(date);
    final now = DateTime.now();
    if (_isSameDay(local, now)) return 'Today';
    final yesterday = now.subtract(const Duration(days: 1));
    if (_isSameDay(local, yesterday)) return 'Yesterday';
    return DateFormat.MMMEd().format(local);
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
      return const SizedBox.shrink(
        key: ValueKey('conversation-has-older'),
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

class _PendingMessageCard extends ConsumerWidget {
  const _PendingMessageCard({
    super.key,
    required this.pending,
    required this.maxBubbleWidth,
  });

  final PendingMessage pending;
  final double maxBubbleWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isFailed = pending.status == MessageSendStatus.failed;
    final isSending = pending.status == MessageSendStatus.sending;
    final isQueued = pending.status == MessageSendStatus.queued;
    final isSent = pending.status == MessageSendStatus.sent;

    final bodyStyle = AppTypography.body.copyWith(
      color: colors.primaryForeground,
    );
    const borderRadius = BorderRadius.only(
      topLeft: Radius.circular(BubbleTokens.radiusLarge),
      topRight: Radius.circular(BubbleTokens.radiusSmall),
      bottomLeft: Radius.circular(BubbleTokens.radiusLarge),
      bottomRight: Radius.circular(BubbleTokens.radiusLarge),
    );

    final bubble = Container(
      key: ValueKey('pending-bubble-${pending.localId}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color:
            isFailed ? colors.primary.withValues(alpha: 0.6) : colors.primary,
        borderRadius: borderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pending.content, style: bodyStyle),
        ],
      ),
    );

    final statusRow = Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSending) ...[
            SizedBox(
              key: const ValueKey('pending-sending-indicator'),
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Sending...',
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
          if (isQueued) ...[
            Icon(
              Icons.schedule,
              key: const ValueKey('pending-queued-icon'),
              size: 14,
              color: colors.warning,
            ),
            const SizedBox(width: 4),
            Text(
              'Queued — waiting for connection',
              key: const ValueKey('pending-queued-label'),
              style: AppTypography.caption.copyWith(
                color: colors.warning,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              key: const ValueKey('pending-queued-dismiss-button'),
              onTap: () => ref
                  .read(conversationDetailStoreProvider.notifier)
                  .dismissPendingMessage(pending.localId),
              child: Text(
                'Dismiss',
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ),
          ],
          if (isSent) ...[
            Icon(
              Icons.check_circle_outline,
              key: const ValueKey('pending-sent-icon'),
              size: 14,
              color: colors.success,
            ),
            const SizedBox(width: 4),
            Text(
              'Sent',
              key: const ValueKey('pending-sent-label'),
              style: AppTypography.caption.copyWith(
                color: colors.success,
              ),
            ),
          ],
          if (isFailed) ...[
            Icon(
              Icons.error_outline,
              key: const ValueKey('pending-failed-icon'),
              size: 14,
              color: colors.error,
            ),
            const SizedBox(width: 4),
            Text(
              'Failed to send',
              key: const ValueKey('pending-failed-label'),
              style: AppTypography.caption.copyWith(
                color: colors.error,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              key: const ValueKey('pending-retry-button'),
              onTap: () => ref
                  .read(conversationDetailStoreProvider.notifier)
                  .retrySend(pending.localId),
              child: Text(
                'Retry',
                style: AppTypography.caption.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              key: const ValueKey('pending-dismiss-button'),
              onTap: () => ref
                  .read(conversationDetailStoreProvider.notifier)
                  .dismissPendingMessage(pending.localId),
              child: Text(
                'Dismiss',
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            bubble,
            statusRow,
          ],
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

class _ConversationComposer extends StatelessWidget {
  const _ConversationComposer({
    required this.controller,
    required this.focusNode,
    required this.state,
    required this.isRecording,
    required this.isFormattingToolbarVisible,
    required this.isEmojiPickerVisible,
    required this.onToggleFormattingToolbar,
    required this.onToggleEmojiPicker,
    required this.onChanged,
    required this.onSend,
    required this.onPickAttachment,
    required this.onRemoveAttachment,
    required this.onCancelUpload,
    required this.onClearReply,
    required this.onMicTap,
    required this.onSendRecording,
    required this.onCancelRecording,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ConversationDetailState state;
  final bool isRecording;
  final bool isFormattingToolbarVisible;
  final bool isEmojiPickerVisible;
  final VoidCallback onToggleFormattingToolbar;
  final VoidCallback onToggleEmojiPicker;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onSend;
  final ValueChanged<PendingAttachment> onPickAttachment;
  final ValueChanged<int> onRemoveAttachment;
  final ValueChanged<int> onCancelUpload;
  final VoidCallback onClearReply;
  final VoidCallback onMicTap;
  final VoidCallback onSendRecording;
  final VoidCallback onCancelRecording;

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
            if (state.replyToMessage != null) ...[
              _ReplyPreviewBanner(
                key: const ValueKey('composer-reply-preview'),
                message: state.replyToMessage!,
                onDismiss: onClearReply,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
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
                    _AttachmentChip(
                      key: ValueKey('pending-attachment-$i'),
                      name: state.pendingAttachments[i].name,
                      progress: state.uploadProgress[i],
                      onDelete: state.uploadProgress.containsKey(i)
                          ? null
                          : () => onRemoveAttachment(i),
                      onCancel: state.uploadProgress.containsKey(i)
                          ? () => onCancelUpload(i)
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (isRecording)
              VoiceRecorderWidget(
                key: const ValueKey('composer-voice-recorder'),
                onSend: onSendRecording,
                onCancel: onCancelRecording,
              )
            else ...[
              FormattingToolbar(
                controller: controller,
                visible: isFormattingToolbarVisible,
                focusNode: focusNode,
                onChanged: onChanged,
              ),
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
                      onPressed: state.isSending
                          ? null
                          : () => _showAttachOptions(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    key: const ValueKey('composer-format-toggle'),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isFormattingToolbarVisible
                          ? colors.primaryLight
                          : colors.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.text_format,
                        size: 20,
                        color:
                            isFormattingToolbarVisible ? colors.primary : null,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: onToggleFormattingToolbar,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    key: const ValueKey('composer-emoji'),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isEmojiPickerVisible
                          ? colors.primaryLight
                          : colors.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.emoji_emotions_outlined,
                        size: 20,
                        color: isEmojiPickerVisible ? colors.primary : null,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: onToggleEmojiPicker,
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
                  if (state.canSend)
                    Container(
                      key: const ValueKey('composer-send'),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          state.isSending ? Icons.hourglass_top : Icons.send,
                          size: 20,
                          color: colors.primaryForeground,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: onSend,
                      ),
                    )
                  else
                    Container(
                      key: const ValueKey('composer-mic'),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.surfaceAlt,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.mic,
                          size: 20,
                          color: colors.textTertiary,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: state.isSending ? null : onMicTap,
                      ),
                    ),
                ],
              ),
            ],
            if (isEmojiPickerVisible)
              SizedBox(
                key: const ValueKey('composer-emoji-picker'),
                height: 256,
                child: EmojiPicker(
                  textEditingController: controller,
                  onEmojiSelected: (_, __) {
                    // Sync controller text to store draft so send() sees
                    // emoji insertions made by the package.
                    onChanged(controller.text);
                  },
                  config: Config(
                    height: 256,
                    checkPlatformCompatibility: false,
                    emojiViewConfig: EmojiViewConfig(
                      emojiSizeMax: 28,
                      backgroundColor: colors.surface,
                    ),
                    categoryViewConfig: CategoryViewConfig(
                      backgroundColor: colors.surface,
                      indicatorColor: colors.primary,
                      iconColorSelected: colors.primary,
                      recentTabBehavior: RecentTabBehavior.NONE,
                    ),
                    bottomActionBarConfig: const BottomActionBarConfig(
                      showBackspaceButton: false,
                      showSearchViewButton: true,
                    ),
                    searchViewConfig: SearchViewConfig(
                      backgroundColor: colors.surface,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAttachOptions(BuildContext context) async {
    final colors = Theme.of(context).extension<AppColors>()!;
    final option = await showModalBottomSheet<_AttachOption>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: colors.text),
              title: const Text('Photo & Video'),
              onTap: () => Navigator.pop(ctx, _AttachOption.gallery),
            ),
            ListTile(
              key: const ValueKey('attach-camera'),
              leading: Icon(Icons.camera_alt, color: colors.text),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, _AttachOption.camera),
            ),
            ListTile(
              leading: Icon(Icons.insert_drive_file, color: colors.text),
              title: const Text('File'),
              onTap: () => Navigator.pop(ctx, _AttachOption.file),
            ),
          ],
        ),
      ),
    );
    if (option == null || !context.mounted) return;
    switch (option) {
      case _AttachOption.gallery:
        await _pickGallery();
      case _AttachOption.camera:
        await _pickCamera(context);
      case _AttachOption.file:
        await _pickFile();
    }
  }

  Future<void> _pickGallery() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.media);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    final extension = file.extension ?? '';
    final mimeType = _mimeFromExtension(extension);
    onPickAttachment(PendingAttachment(
      path: file.path!,
      name: file.name,
      mimeType: mimeType,
    ));
  }

  Future<void> _pickCamera(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera);
      if (photo == null) return;
      final name = photo.name;
      final ext = name.split('.').last;
      final mimeType = _mimeFromExtension(ext);
      onPickAttachment(PendingAttachment(
        path: photo.path,
        name: name,
        mimeType: mimeType,
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: ValueKey('camera-error-snackbar'),
          content: Text('Camera unavailable. Please check permissions.'),
        ),
      );
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
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
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      _ => 'application/octet-stream',
    };
  }
}

enum _AttachOption { gallery, camera, file }

/// A chip that shows the attachment filename. When an upload is in progress,
/// overlays a progress indicator and replaces the delete button with cancel.
class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({
    super.key,
    required this.name,
    this.progress,
    this.onDelete,
    this.onCancel,
  });

  final String name;

  /// Null when not uploading; 0.0-1.0 during upload.
  final double? progress;
  final VoidCallback? onDelete;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isUploading = progress != null;
    final percent = isUploading ? (progress! * 100).round() : 0;

    return Chip(
      avatar: isUploading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                key: const ValueKey('attachment-upload-indicator'),
                value: progress,
                strokeWidth: 2,
                color: colors.primary,
              ),
            )
          : const Icon(Icons.attach_file, size: 16),
      label: Text(
        isUploading ? '$name · $percent%' : name,
        overflow: TextOverflow.ellipsis,
      ),
      deleteIcon: Icon(
        isUploading ? Icons.close : Icons.cancel,
        size: 16,
      ),
      onDeleted: isUploading ? onCancel : onDelete,
    );
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

class _ConversationMessageCard extends ConsumerStatefulWidget {
  const _ConversationMessageCard({
    required this.target,
    required this.message,
    required this.maxBubbleWidth,
    this.showHeader = true,
    this.highlightQuery = '',
    this.isCurrentSearchMatch = false,
    this.isQuoteJumpHighlighted = false,
    this.onScrollToMessage,
  });

  final ConversationDetailTarget target;
  final ConversationMessageSummary message;
  final double maxBubbleWidth;
  final bool showHeader;
  final String highlightQuery;
  final bool isCurrentSearchMatch;
  final bool isQuoteJumpHighlighted;
  final ValueChanged<String>? onScrollToMessage;

  @override
  ConsumerState<_ConversationMessageCard> createState() =>
      _ConversationMessageCardState();
}

class _ConversationMessageCardState
    extends ConsumerState<_ConversationMessageCard> {
  bool _showPreciseTimestamp = false;
  Timer? _timestampTimer;

  // Sender-name hit-test state for profile popup. (#535)
  // We track the pointer-down position via a Listener (which does NOT
  // participate in the gesture arena) and compare it against the sender
  // name's render box in the MessageGestureWrapper's single-tap callback.
  // This avoids adding a child GestureDetector that would win the arena
  // and break double-tap quick-react detection.
  final GlobalKey _senderNameKey = GlobalKey();
  Offset? _lastPointerDownGlobalPos;

  @override
  void dispose() {
    _timestampTimer?.cancel();
    super.dispose();
  }

  void _togglePreciseTimestamp() {
    setState(() {
      _showPreciseTimestamp = !_showPreciseTimestamp;
    });
    _timestampTimer?.cancel();
    if (_showPreciseTimestamp) {
      _timestampTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showPreciseTimestamp = false);
      });
    }
  }

  /// Opens the member profile sheet for the sender of a message. (#535)
  Future<void> _openSenderProfile(
    BuildContext context,
    ConversationMessageSummary message,
    ConversationDetailTarget target,
  ) async {
    final senderId = message.senderId;
    if (senderId == null || senderId.isEmpty) return;
    final isAgent = message.senderType == 'agent';

    try {
      final profile = await ref
          .read(profileRepositoryProvider)
          .loadProfile(target.serverId, userId: senderId);
      if (!context.mounted) return;

      await showMemberProfileSheet(
        context: context,
        member: profile,
        onMessageTap: () {
          // Close the sheet first.
          Navigator.of(context).pop();
          // Open DM with the member (agent-aware branch).
          _openDirectMessage(target.serverId, senderId, isAgent: isAgent);
        },
      );
    } catch (_) {
      // Fail-soft: if profile fetch fails, do nothing.
    }
  }

  /// Opens a direct message with the given user or agent. (#535)
  Future<void> _openDirectMessage(
    ServerScopeId serverId,
    String senderId, {
    bool isAgent = false,
  }) async {
    try {
      final repo = ref.read(memberRepositoryProvider);
      final channelId = isAgent
          ? await repo.openAgentDirectMessage(serverId, agentId: senderId)
          : await repo.openDirectMessage(serverId, userId: senderId);
      if (!mounted) return;
      context.push('/servers/${serverId.value}/dms/$channelId');
    } catch (_) {
      // Fail-soft: if DM open fails, do nothing.
    }
  }

  /// Returns `true` when the last pointer-down landed inside the sender
  /// name widget's render box.
  bool _isTapOnSenderName() {
    final box = _senderNameKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || _lastPointerDownGlobalPos == null) return false;
    final local = box.globalToLocal(_lastPointerDownGlobalPos!);
    return box.paintBounds.contains(local);
  }

  /// Unified tap handler for messages that routes sender-name taps to the
  /// profile popup while preserving thread navigation / precise timestamp
  /// behavior for taps elsewhere on the bubble. This fires AFTER the
  /// [MessageGestureWrapper]'s 300 ms double-tap window, so double-tap
  /// quick-react is unaffected.
  void _handleMessageTap(
    BuildContext context,
    ConversationMessageSummary message,
    ConversationDetailTarget target, {
    required bool enableTapToThread,
  }) {
    if (_isTapOnSenderName()) {
      _openSenderProfile(context, message, target);
      return;
    }
    if (enableTapToThread) {
      _navigateToThread(context);
    } else {
      _togglePreciseTimestamp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final target = widget.target;
    final maxBubbleWidth = widget.maxBubbleWidth;
    final showHeader = widget.showHeader;
    final highlightQuery = widget.highlightQuery;
    final isCurrentSearchMatch = widget.isCurrentSearchMatch;
    final onScrollToMessage = widget.onScrollToMessage;
    final timestamp = formatRelativeTime(message.createdAt);
    final theme = Theme.of(context);
    final colors = theme.extension<AppColors>()!;

    // Deleted messages render as a greyed placeholder with no interactions.
    if (message.isDeleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Align(
          alignment: Alignment.center,
          child: Text(
            '[Message deleted]',
            style: AppTypography.body.copyWith(
              color: colors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final savedIds = ref.watch(
      conversationDetailStoreProvider.select((s) => s.savedMessageIds),
    );
    final currentUserId =
        ref.watch(sessionStoreProvider.select((session) => session.userId));
    final currentUserName = ref
        .watch(sessionStoreProvider.select((session) => session.displayName));
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
          if (message.replyTo != null)
            _QuotedMessageBlock(
              key: ValueKey('quoted-${message.id}'),
              replyTo: message.replyTo!,
              isSelf: visualKind == _ConversationMessageVisualKind.self,
              onTap: onScrollToMessage != null
                  ? () => onScrollToMessage(message.replyTo!.id)
                  : null,
            ),
          if (showHeader && visualKind == _ConversationMessageVisualKind.self)
            Padding(
              key: ValueKey('message-header-${message.id}'),
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
          if (showHeader && visualKind != _ConversationMessageVisualKind.self)
            Padding(
              key: ValueKey('message-header-${message.id}'),
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
          _buildMessageContent(
            ref: ref,
            message: message,
            visualKind: visualKind,
            highlightQuery: highlightQuery,
            bodyStyle: bodyStyle,
            colors: colors,
            currentUserName: currentUserName,
            onLinkTap: (text, href, title) =>
                _confirmAndLaunchUrl(context, href),
          ),
          if (message.attachments != null && message.attachments!.isNotEmpty)
            _AttachmentSection(attachments: message.attachments!),
        ],
      ),
    );

    // Sender label is placed ABOVE the bubble for other/agent messages.
    // Hidden when message is grouped (showHeader == false).
    Widget senderLabelWidget = const SizedBox.shrink();
    if (showSenderLabel && showHeader) {
      senderLabelWidget = Padding(
        key: _senderNameKey,
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

    final isNonSystem = visualKind != _ConversationMessageVisualKind.system;

    // Build the message layout (Align → Column with sender label, bubble,
    // reactions, and thread indicator).
    Widget shellContent = switch (visualKind) {
      _ConversationMessageVisualKind.system => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: double.infinity, child: bubble),
            _ReactionRow(
              reactions: message.reactions,
              messageId: message.id,
              currentUserId: ref.watch(sessionStoreProvider).userId,
            ),
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
              _ReactionRow(
                reactions: message.reactions,
                messageId: message.id,
                currentUserId: ref.watch(sessionStoreProvider).userId,
              ),
              threadIndicator,
              if (_showPreciseTimestamp)
                _PreciseTimestampLabel(createdAt: message.createdAt),
            ],
          ),
        ),
    };

    // Wrap with current-search-match highlight decoration when this message
    // is the actively focused search result.
    if (isCurrentSearchMatch) {
      shellContent = Container(
        key: const ValueKey('search-current-match-highlight'),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(BubbleTokens.radiusLarge),
        ),
        padding: const EdgeInsets.all(4),
        child: shellContent,
      );
    }

    // Wrap with quote-jump highlight when this message was just scrolled to
    // via a quoted-message tap.
    if (widget.isQuoteJumpHighlighted) {
      shellContent = Container(
        key: const ValueKey('quote-jump-highlight'),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(BubbleTokens.radiusLarge),
        ),
        padding: const EdgeInsets.all(4),
        child: shellContent,
      );
    }

    final shell = Align(
      key: ValueKey('message-shell-${message.id}'),
      alignment: shellAlignment,
      child: shellContent,
    );

    // Read selection state from the store.
    final detailState = ref.watch(conversationDetailStoreProvider);
    final isSelectionMode = detailState.isSelectionMode;
    final isSelected = detailState.selectedMessageIds.contains(message.id);

    // In selection mode, show a checkmark overlay on selected messages.
    Widget shellWithSelection = shell;
    if (isSelectionMode && isSelected) {
      shellWithSelection = Stack(
        children: [
          shell,
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              key: ValueKey('selection-check-${message.id}'),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                color: colors.primaryForeground,
                size: 16,
              ),
            ),
          ),
        ],
      );
    }

    // Wrap the entire message shell in a gesture wrapper for double-tap
    // react, swipe-to-reply, and long-press context menu. The wrapper
    // covers the full shell area so that long-press can trigger on empty
    // space around the bubble (avoiding SelectableText gesture arena
    // conflicts in MarkdownBody). Child widget taps (reaction chips,
    // thread indicator, task badges, links) still work because their
    // gesture recognizers are deeper in the tree and win the arena.
    //
    // In selection mode, taps toggle selection and long-press/swipe/
    // double-tap are disabled.
    if (isNonSystem) {
      if (isSelectionMode) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => ref
              .read(conversationDetailStoreProvider.notifier)
              .toggleMessageSelection(message.id),
          child: shellWithSelection,
        );
      }
      return MessageGestureWrapper(
        enablePressFeedback: enableTapToThread,
        onTap: () => _handleMessageTap(
          context,
          message,
          target,
          enableTapToThread: enableTapToThread,
        ),
        onDoubleTap: () => _quickReact(context, ref),
        enableSwipeReply: !message.content.contains('```'),
        onSwipeReply: () => ref
            .read(conversationDetailStoreProvider.notifier)
            .setReplyTo(message),
        onLongPress: () => _showContextMenu(context, ref, isSaved, visualKind),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            _lastPointerDownGlobalPos = event.position;
          },
          child: shellWithSelection,
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _showContextMenu(context, ref, isSaved, visualKind),
      child: shellWithSelection,
    );
  }

  /// Quick-react to a message with 👍 (the first curated emoji).
  Future<void> _quickReact(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(conversationDetailStoreProvider.notifier)
          .addReaction(widget.message.id, '👍');
    } on AppFailure catch (failure) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(failure.message ?? 'Failed to add reaction.'),
          ),
        );
    }
  }

  /// Builds message content, wrapping with [TranslatedContentOverlay]
  /// when a translation entry exists in the cache for this message.
  Widget _buildMessageContent({
    required WidgetRef ref,
    required ConversationMessageSummary message,
    required _ConversationMessageVisualKind visualKind,
    required String highlightQuery,
    required TextStyle bodyStyle,
    required AppColors colors,
    required String? currentUserName,
    required void Function(String, String?, String) onLinkTap,
  }) {
    final contentWidget = MessageContentWidget(
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
      onLinkTap: onLinkTap,
      currentUserName: currentUserName,
    );

    // If translation is cached for this message, wrap with overlay.
    final cacheState = ref.watch(translationCacheStoreProvider);
    final entry = cacheState.translations[message.id];
    if (entry == null) return contentWidget;

    return TranslatedContentOverlay(
      messageId: message.id,
      originalChild: contentWidget,
      translatedContent: entry.translatedContent,
      entry: entry,
    );
  }

  void _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    bool isSaved,
    _ConversationMessageVisualKind visualKind,
  ) {
    final isOwn = visualKind == _ConversationMessageVisualKind.self;
    final notifier = ref.read(conversationDetailStoreProvider.notifier);
    final isChannel = widget.target.surface == ConversationSurface.channel;

    // Show translate action when translation mode is not off.
    final translationMode =
        ref.read(translationSettingsStoreProvider).settings.mode;
    final canTranslate = translationMode != TranslationMode.off;

    showMessageContextMenu(
      context: context,
      message: widget.message,
      isOwn: isOwn,
      isSaved: isSaved,
      isChannel: isChannel,
      onReply: () => notifier.setReplyTo(widget.message),
      onReact: () => _showEmojiPicker(context, ref),
      onCopy: () {
        Clipboard.setData(ClipboardData(text: widget.message.content));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Copied to clipboard.')));
      },
      onForward: () {
        final messageContent = widget.message.content;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ShareTargetPickerPage(
              onTargetSelected: (target) async {
                final forwardTarget = target.isChannel
                    ? ConversationDetailTarget.channel(
                        ChannelScopeId(
                          serverId: target.serverId,
                          value: target.scopeId,
                        ),
                      )
                    : ConversationDetailTarget.directMessage(
                        DirectMessageScopeId(
                          serverId: target.serverId,
                          value: target.scopeId,
                        ),
                      );
                try {
                  await ref
                      .read(conversationRepositoryProvider)
                      .sendMessage(forwardTarget, messageContent);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(content: Text('Message forwarded')),
                    );
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('Failed to send. Please try again.'),
                      ),
                    );
                }
              },
              onCancel: () => Navigator.of(context).pop(),
            ),
          ),
        );
      },
      onSave: () => notifier.toggleSaveMessage(widget.message.id),
      onPin: () async {
        try {
          if (widget.message.isPinned) {
            await notifier.unpinMessage(widget.message.id);
          } else {
            await notifier.pinMessage(widget.message.id);
          }
        } on AppFailure catch (failure) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(failure.message ??
                    'Failed to ${widget.message.isPinned ? 'unpin' : 'pin'} message.'),
              ),
            );
        }
      },
      onEdit: isOwn ? () => _showEditDialog(context, ref) : null,
      onDelete: isOwn ? () => _confirmAndDeleteMessage(context, ref) : null,
      onReplyInThread: isChannel
          ? () {
              context.push(
                ThreadRouteTarget(
                  serverId: widget.target.serverId.value,
                  parentChannelId: widget.target.conversationId,
                  parentMessageId: widget.message.id,
                  threadChannelId: widget.message.threadId,
                ).toLocation(),
              );
            }
          : null,
      onCreateTask:
          isChannel ? () => _convertMessageToTask(context, ref) : null,
      onTranslate: canTranslate
          ? () => ref
              .read(translationCacheStoreProvider.notifier)
              .translateMessage(widget.message.id)
          : null,
      onSelect: () => ref
          .read(conversationDetailStoreProvider.notifier)
          .enterSelectionMode(widget.message.id),
    );
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _EditMessageDialog(
        initialContent: widget.message.content,
        onSave: (newContent) async {
          await ref
              .read(conversationDetailStoreProvider.notifier)
              .editMessage(widget.message.id, newContent);
        },
      ),
    );
  }

  Future<void> _showEmojiPicker(BuildContext context, WidgetRef ref) async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => const _EmojiPickerSheet(),
    );
    if (emoji == null || !context.mounted) return;

    try {
      await ref
          .read(conversationDetailStoreProvider.notifier)
          .addReaction(widget.message.id, emoji);
    } on AppFailure catch (failure) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(failure.message ?? 'Failed to add reaction.'),
          ),
        );
    }
  }

  void _navigateToThread(BuildContext context) {
    context.push(
      ThreadRouteTarget(
        serverId: widget.target.serverId.value,
        parentChannelId: widget.target.conversationId,
        parentMessageId: widget.message.id,
        threadChannelId: widget.message.threadId,
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
    HapticFeedback.mediumImpact();

    try {
      await ref
          .read(conversationDetailStoreProvider.notifier)
          .deleteMessage(widget.message.id);
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
        widget.target.serverId,
        messageId: widget.message.id,
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

/// Launches an external URL. For http/https links, launches directly without
/// confirmation dialog. Non-http schemes show a confirmation dialog first.
Future<void> _confirmAndLaunchUrl(BuildContext context, String? href) async {
  if (href == null || href.isEmpty) return;
  final uri = Uri.tryParse(href);
  if (uri == null) return;

  // http/https links launch directly — no confirmation needed.
  if (uri.scheme == 'http' || uri.scheme == 'https') {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }

  // Non-http schemes (mailto:, tel:, custom://) show confirmation.
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

  static const _csvTypes = {
    'text/csv',
    'application/csv',
  };

  static const _svgTypes = {
    'image/svg+xml',
  };

  static const _markdownTypes = {
    'text/markdown',
    'text/x-markdown',
  };

  static const _textTypes = {
    'text/plain',
  };

  /// Size limit for inline previews (1 MB). Larger files fall back to the
  /// generic attachment row (INV-ATTACH-3).
  static const _inlinePreviewSizeLimit = 1048576;

  static bool _isAudioType(String mimeType) => mimeType.startsWith('audio/');

  static bool _isMarkdownByExtension(String name) =>
      name.endsWith('.md') || name.endsWith('.markdown');

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

    if (_imageTypes.contains(mimeType) &&
        (attachment.thumbnailUrl != null || attachment.url != null)) {
      return _ImageAttachmentPreview(attachment: attachment);
    }

    if (_htmlTypes.contains(mimeType)) {
      return _HtmlAttachmentRow(attachment: attachment);
    }

    if (_isAudioType(mimeType) && attachment.url != null) {
      return _AudioAttachmentRow(attachment: attachment);
    }

    // Size gate (INV-ATTACH-3): skip inline preview for large files.
    if (attachment.sizeBytes != null &&
        attachment.sizeBytes! > _inlinePreviewSizeLimit) {
      return _GenericFileAttachmentRow(attachment: attachment);
    }

    final genericFallback = _GenericFileAttachmentRow(attachment: attachment);

    if (_csvTypes.contains(mimeType)) {
      return CsvPreviewWidget(
        attachment: attachment,
        fallback: genericFallback,
      );
    }

    if (_svgTypes.contains(mimeType)) {
      return SvgPreviewWidget(
        attachment: attachment,
        fallback: genericFallback,
      );
    }

    if (_markdownTypes.contains(mimeType) ||
        _isMarkdownByExtension(attachment.name)) {
      return TextPreviewWidget(
        attachment: attachment,
        isMarkdown: true,
        fallback: genericFallback,
      );
    }

    if (_textTypes.contains(mimeType)) {
      return TextPreviewWidget(
        attachment: attachment,
        isMarkdown: false,
        fallback: genericFallback,
      );
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
                attachment.thumbnailUrl ?? attachment.url!,
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
    // Use GoRouter push instead of Navigator.push so the page
    // is visible to GoRouter's navigation stack.
    context.push('/file-preview', extra: attachment);
  }
}

class _FullScreenImageViewer extends ConsumerStatefulWidget {
  const _FullScreenImageViewer({required this.attachment});

  final MessageAttachment attachment;

  @override
  ConsumerState<_FullScreenImageViewer> createState() =>
      _FullScreenImageViewerState();
}

class _FullScreenImageViewerState
    extends ConsumerState<_FullScreenImageViewer> {
  String? _signedUrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSignedUrl();
  }

  Future<void> _loadSignedUrl() async {
    final att = widget.attachment;
    final diagnostics = ref.read(diagnosticsCollectorProvider);
    // If no id, fall back to direct url (legacy attachment).
    if (att.id == null || att.id!.isEmpty) {
      diagnostics.info(
        'attachment-preview',
        'source=signedUrl, attachmentId=missing, '
            'mimeType=${att.type}, fallback=directUrl',
      );
      setState(() => _signedUrl = att.url);
      return;
    }
    setState(() => _loading = true);
    try {
      final repo = ref.read(attachmentRepositoryProvider);
      final serverId = _extractServerIdFromContext();
      final url = await repo.getSignedUrl(
        serverId,
        attachmentId: att.id!,
      );
      if (mounted) {
        setState(() {
          _signedUrl = url;
          _loading = false;
        });
      }
    } on AppFailure catch (e) {
      diagnostics.error(
        'attachment-preview',
        'source=signedUrl, attachmentId=${att.id}, '
            'mimeType=${att.type}, failureType=${e.runtimeType}',
      );
      if (mounted) {
        setState(() {
          _signedUrl = att.url;
          _loading = false;
        });
      }
    }
  }

  ServerScopeId _extractServerIdFromContext() {
    // Best-effort extraction from open conversation target.
    final target = ref.read(currentOpenConversationTargetProvider);
    if (target != null) return target.serverId;
    // Fallback: use a default — signed URLs require server scope.
    return const ServerScopeId('');
  }

  @override
  Widget build(BuildContext context) {
    final displayUrl = _signedUrl ?? widget.attachment.url;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.attachment.name,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          if (displayUrl != null)
            IconButton(
              key: const ValueKey('image-viewer-open-external'),
              icon: const Icon(Icons.open_in_new),
              onPressed: () => launchUrl(
                Uri.parse(displayUrl),
                mode: LaunchMode.externalApplication,
              ),
              tooltip: context.l10n.attachmentOpenInBrowser,
            ),
        ],
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator(color: Colors.white70)
            : displayUrl != null
                ? InteractiveViewer(
                    key: const ValueKey('image-viewer-interactive'),
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      displayUrl,
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
                  )
                : Column(
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
                  ),
      ),
    );
  }
}

class _HtmlAttachmentRow extends ConsumerWidget {
  const _HtmlAttachmentRow({required this.attachment});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return InkWell(
      key: ValueKey('html-attachment-${attachment.id ?? attachment.name}'),
      onTap: () => _openHtmlPreview(context, ref),
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
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
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

  Future<void> _openHtmlPreview(BuildContext context, WidgetRef ref) async {
    final diagnostics = ref.read(diagnosticsCollectorProvider);
    // If we have an attachment id, use the html-preview-url endpoint.
    if (attachment.id != null && attachment.id!.isNotEmpty) {
      try {
        final target = ref.read(currentOpenConversationTargetProvider);
        if (target == null) return;
        final repo = ref.read(attachmentRepositoryProvider);
        final previewUrl = await repo.getHtmlPreviewUrl(
          target.serverId,
          attachmentId: attachment.id!,
        );
        await launchUrl(
          Uri.parse(previewUrl),
          mode: LaunchMode.externalApplication,
        );
        return;
      } on AppFailure catch (e) {
        diagnostics.error(
          'attachment-preview',
          'source=htmlPreview, attachmentId=${attachment.id}, '
              'mimeType=${attachment.type}, failureType=${e.runtimeType}',
        );
        // Fall through to direct URL if available.
      }
    } else {
      diagnostics.info(
        'attachment-preview',
        'source=htmlPreview, attachmentId=missing, '
            'mimeType=${attachment.type}, fallback=directUrl',
      );
    }
    // Fallback: use direct url if present.
    if (attachment.url != null) {
      await launchUrl(
        Uri.parse(attachment.url!),
        mode: LaunchMode.externalApplication,
      );
    }
  }
}

class _GenericFileAttachmentRow extends ConsumerWidget {
  const _GenericFileAttachmentRow({required this.attachment});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasTapTarget = attachment.url != null || attachment.id != null;
    return InkWell(
      key: ValueKey('file-attachment-${attachment.id ?? attachment.name}'),
      onTap: hasTapTarget ? () => _openFile(context, ref) : null,
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
                color: hasTapTarget ? theme.colorScheme.primary : null,
                decoration: hasTapTarget ? TextDecoration.underline : null,
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

  Future<void> _openFile(BuildContext context, WidgetRef ref) async {
    // Use GoRouter push instead of Navigator.push so the page
    // is visible to GoRouter's navigation stack.
    context.push('/file-preview', extra: attachment);
  }
}

/// Inline audio player for voice/audio attachments in chat messages.
class _AudioAttachmentRow extends ConsumerStatefulWidget {
  const _AudioAttachmentRow({required this.attachment});

  final MessageAttachment attachment;

  @override
  ConsumerState<_AudioAttachmentRow> createState() =>
      _AudioAttachmentRowState();
}

class _AudioAttachmentRowState extends ConsumerState<_AudioAttachmentRow> {
  late final AudioPlayerService _player;
  AudioPlaybackState _playbackState = AudioPlaybackState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<AudioPlaybackState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  bool _initialized = false;
  List<double> _waveform = const [];

  @override
  void initState() {
    super.initState();
    _player = AudioPlayerService();
    _resolveWaveform();
  }

  /// Resolve waveform data: use cached amplitudes for own recordings,
  /// or load audio eagerly to derive duration-based waveform for received audio.
  void _resolveWaveform() {
    // Check cache for own recordings (real amplitudes from recording session).
    final cache = ref.read(voiceWaveformCacheProvider);
    final cached = cache[widget.attachment.name];
    if (cached != null && cached.isNotEmpty) {
      _waveform = cached;
      return;
    }
    // For received audio, load the audio to get its duration.
    _loadAudioForWaveform();
  }

  Future<void> _loadAudioForWaveform() async {
    final url = widget.attachment.url;
    if (url == null) return;
    try {
      _ensureSubscriptions();
      final duration = await _player.load(url);
      if (duration != null && mounted) {
        setState(() {
          _duration = duration;
          _waveform = _waveformFromDuration(duration);
        });
      }
    } catch (_) {
      // If loading fails, leave waveform empty — will show a minimal bar.
    }
  }

  /// Generate a duration-proportional waveform approximation.
  ///
  /// Produces ~1 bar per 0.75s of audio (capped at 50 bars, minimum 8).
  /// Bar heights vary in a smooth sine-based pattern to give a natural
  /// audio-like appearance while being deterministic per duration.
  static List<double> _waveformFromDuration(Duration duration) {
    final seconds = duration.inMilliseconds / 1000.0;
    final barCount = (seconds / 0.75).round().clamp(8, 50);
    return List.generate(barCount, (i) {
      // Smooth varying pattern based on index position.
      final t = i / barCount;
      final base = 0.3 + 0.4 * math.sin(t * math.pi * 3.7);
      final detail = 0.15 * math.sin(t * math.pi * 11.3 + 0.7);
      return (base + detail).clamp(0.15, 0.95);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _ensureSubscriptions() {
    if (_initialized) return;
    _initialized = true;
    _stateSub = _player.stateStream.listen((s) {
      if (mounted) setState(() => _playbackState = s);
    });
    _positionSub = _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durationSub = _player.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
  }

  Future<void> _handlePlayPause() async {
    _ensureSubscriptions();
    final url = widget.attachment.url;
    if (url == null) return;
    switch (_playbackState) {
      case AudioPlaybackState.stopped:
        await _player.play(url);
      case AudioPlaybackState.playing:
        await _player.pause();
      case AudioPlaybackState.paused:
        await _player.resume();
    }
  }

  Future<void> _handleSeek(double fraction) async {
    if (_duration.inMilliseconds <= 0) return;
    final target = Duration(
      milliseconds: (_duration.inMilliseconds * fraction).round(),
    );
    await _player.seek(target);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: VoiceMessageBubble(
        duration: _duration,
        position: _position,
        isPlaying: _playbackState == AudioPlaybackState.playing,
        waveform: _waveform,
        onPlayPause: _handlePlayPause,
        onSeek: _handleSeek,
      ),
    );
  }
}

class _EditMessageDialog extends StatefulWidget {
  const _EditMessageDialog({
    required this.initialContent,
    required this.onSave,
  });

  final String initialContent;
  final Future<void> Function(String newContent) onSave;

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  late final TextEditingController _controller;
  bool _hasChanged = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final changed = _controller.text.trim() != widget.initialContent &&
        _controller.text.trim().isNotEmpty;
    if (changed != _hasChanged) {
      setState(() => _hasChanged = changed);
    }
  }

  Future<void> _onSave() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(_controller.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Message edited.')));
    } on AppFailure catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Failed to edit message.'),
          ),
        );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('edit-message-dialog'),
      title: const Text('Edit message'),
      content: TextField(
        key: const ValueKey('edit-message-field'),
        controller: _controller,
        autofocus: true,
        maxLines: null,
        textInputAction: TextInputAction.newline,
        enabled: !_saving,
      ),
      actions: [
        TextButton(
          key: const ValueKey('edit-message-cancel'),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey('edit-message-save'),
          onPressed: _hasChanged && !_saving ? _onSave : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Curated set of common reaction emojis.
const _reactionEmojis = [
  '👍',
  '❤️',
  '😂',
  '😮',
  '😢',
  '🎉',
  '🔥',
  '👀',
  '🙏',
  '💯',
  '✅',
  '❌',
  '👏',
  '🤔',
  '😍',
  '🚀',
  '💪',
  '⭐',
  '🤝',
  '💡',
];

class _EmojiPickerSheet extends StatelessWidget {
  const _EmojiPickerSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'React with emoji',
                style: AppTypography.title,
              ),
            ),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: _reactionEmojis.map((emoji) {
                return InkWell(
                  key: ValueKey('emoji-$emoji'),
                  onTap: () => Navigator.of(context).pop(emoji),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionRow extends ConsumerWidget {
  const _ReactionRow({
    required this.reactions,
    required this.messageId,
    required this.currentUserId,
  });

  final List<MessageReaction> reactions;
  final String messageId;
  final String? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: reactions.map((reaction) {
          final isOwn =
              currentUserId != null && reaction.reactedByUser(currentUserId!);
          return _ReactionChip(
            key: ValueKey('reaction-${reaction.emoji}'),
            emoji: reaction.emoji,
            count: reaction.count,
            isOwn: isOwn,
            colors: colors,
            onTap: () async {
              try {
                await ref
                    .read(conversationDetailStoreProvider.notifier)
                    .toggleReaction(messageId, reaction.emoji);
              } on AppFailure catch (failure) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content:
                          Text(failure.message ?? 'Failed to update reaction.'),
                    ),
                  );
              }
            },
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    super.key,
    required this.emoji,
    required this.count,
    required this.isOwn,
    required this.colors,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool isOwn;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isOwn
              ? colors.primary.withValues(alpha: 0.15)
              : colors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: isOwn ? colors.primary : colors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: AppTypography.caption.copyWith(
                color: isOwn ? colors.primary : colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner shown above the composer when replying to a message.
class _ReplyPreviewBanner extends StatelessWidget {
  const _ReplyPreviewBanner({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  final ConversationMessageSummary message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: colors.primary, width: 3),
        ),
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.senderLabel,
                  style: AppTypography.label.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            key: const ValueKey('reply-preview-dismiss'),
            onTap: onDismiss,
            child: Icon(
              Icons.close,
              size: 20,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quoted message block rendered inside a message bubble.
class _QuotedMessageBlock extends StatelessWidget {
  const _QuotedMessageBlock({
    super.key,
    required this.replyTo,
    required this.isSelf,
    this.onTap,
  });

  final ReplyToSummary replyTo;
  final bool isSelf;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final accentColor = isSelf
        ? colors.primaryForeground.withValues(alpha: 0.7)
        : colors.primary;
    final bgColor = isSelf
        ? colors.primaryForeground.withValues(alpha: 0.12)
        : colors.primary.withValues(alpha: 0.08);
    final labelColor = accentColor;
    final bodyColor = isSelf
        ? colors.primaryForeground.withValues(alpha: 0.85)
        : colors.textSecondary;

    return GestureDetector(
      key: const ValueKey('quoted-message-tap'),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: accentColor, width: 3),
          ),
          color: bgColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              replyTo.senderLabel,
              style: AppTypography.label.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              replyTo.content.isEmpty ? '[Message]' : replyTo.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: bodyColor,
              ),
            ),
          ],
        ),
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
class _SelectionActionBar extends ConsumerWidget {
  const _SelectionActionBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final state = ref.watch(conversationDetailStoreProvider);
    final selectedCount = state.selectedMessageIds.length;

    return Container(
      key: const ValueKey('selection-action-bar'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('selection-action-cancel'),
              icon: const Icon(Icons.close),
              tooltip: 'Cancel',
              onPressed: () => ref
                  .read(conversationDetailStoreProvider.notifier)
                  .exitSelectionMode(),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '$selectedCount selected',
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            IconButton(
              key: const ValueKey('selection-action-save'),
              icon: const Icon(Icons.bookmark_outline),
              tooltip: 'Save',
              onPressed: selectedCount > 0
                  ? () async {
                      final ids = Set<String>.of(state.selectedMessageIds);
                      final result = await ref
                          .read(conversationDetailStoreProvider.notifier)
                          .batchSaveMessages(ids);
                      if (!context.mounted) return;
                      _showBatchResultSnackbar(
                        context,
                        action: 'saved',
                        succeeded: result.succeeded,
                        failed: result.failed,
                      );
                    }
                  : null,
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              key: const ValueKey('selection-action-delete'),
              icon: Icon(Icons.delete_outline, color: colors.error),
              tooltip: 'Delete',
              onPressed: selectedCount > 0
                  ? () async {
                      final ids = Set<String>.of(state.selectedMessageIds);
                      final result = await ref
                          .read(conversationDetailStoreProvider.notifier)
                          .batchDeleteMessages(ids);
                      if (!context.mounted) return;
                      _showBatchResultSnackbar(
                        context,
                        action: 'deleted',
                        succeeded: result.succeeded,
                        failed: result.failed,
                      );
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _showBatchResultSnackbar(
    BuildContext context, {
    required String action,
    required int succeeded,
    required int failed,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final String message;
    if (failed == 0) {
      message = '$succeeded message${succeeded == 1 ? '' : 's'} $action.';
    } else if (succeeded == 0) {
      message = 'Failed to ${action == 'deleted' ? 'delete' : 'save'} '
          '$failed message${failed == 1 ? '' : 's'}.';
    } else {
      message = '$succeeded $action, $failed failed.';
    }

    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
