import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/haptic/haptic_service.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_status_tokens.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/message_bubble.dart';
import 'package:slock_app/app/widgets/relative_time_text.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/presentation/utils/sender_label_l10n.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_attachment_renderers.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_reactions.dart';
import 'package:slock_app/features/conversation/presentation/widgets/markdown_message_body.dart';
import 'package:slock_app/features/conversation/presentation/widgets/inline_ref_syntax.dart';
import 'package:slock_app/features/conversation/presentation/widgets/message_content_widget.dart';
import 'package:slock_app/features/conversation/presentation/widgets/message_context_menu.dart';
import 'package:slock_app/features/conversation/presentation/widgets/message_gesture_wrapper.dart';
import 'package:slock_app/features/channels/data/channel_member_repository_provider.dart';
import 'package:slock_app/features/conversation/presentation/utils/mention_profile_resolver.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/profile/data/profile_repository_provider.dart';
import 'package:slock_app/features/share/presentation/page/share_target_picker_page.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/application/thread_replies_store.dart';
import 'package:slock_app/features/conversation/presentation/utils/message_permalink_builder.dart';
import 'package:slock_app/features/translation/application/translation_cache_store.dart';
import 'package:slock_app/features/translation/application/translation_settings_store.dart';
import 'package:slock_app/features/translation/data/translation_settings.dart';
import 'package:slock_app/features/translation/presentation/widgets/translated_content_overlay.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:slock_app/l10n/l10n.dart';

AppLocalizations _conversationL10n(BuildContext context) =>
    AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('en'));

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

class ConversationMessageCard extends ConsumerStatefulWidget {
  const ConversationMessageCard({
    super.key,
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

  // ---------------------------------------------------------------------------
  // #655: Exposed base style constants for test identity assertions.
  //
  // Tests use `identical(ConversationMessageCard.senderNameBaseStyle,
  //   AppTypography.labelBold)` to prove the precomputed constant is used,
  // not a fresh copyWith allocation.
  // ---------------------------------------------------------------------------

  /// Base TextStyle for sender name labels — precomputed with w600.
  @visibleForTesting
  static const senderNameBaseStyle = AppTypography.labelBold;

  /// Base TextStyle for AI badge labels — precomputed with w600.
  @visibleForTesting
  static const aiBadgeBaseStyle = AppTypography.captionBold;

  /// Hoisted BorderRadius for system-variant messages — avoids per-build
  /// allocation (#853).
  @visibleForTesting
  static final systemBorderRadius =
      BorderRadius.circular(BubbleTokens.radiusLarge);

  /// Hoisted BorderRadius for linked task badges — pill shape (#853).
  @visibleForTesting
  static final taskBadgeBorderRadius = BorderRadius.circular(999);

  /// Hoisted BorderRadius for agent AI badge (Scan #45).
  static final _agentBadgeBorderRadius =
      BorderRadius.circular(AppSpacing.radiusSm);

  @override
  ConsumerState<ConversationMessageCard> createState() =>
      ConversationMessageCardState();
}

class ConversationMessageCardState
    extends ConsumerState<ConversationMessageCard> {
  bool _showPreciseTimestamp = false;
  Timer? _timestampTimer;
  bool _isLoadingTask = false;

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

  /// Opens the member profile sheet for the sender of a message. (#535, #656)
  ///
  /// Shows a loading indicator immediately, then transitions to full profile
  /// content once the network fetch completes.
  Future<void> _openSenderProfile(
    BuildContext context,
    ConversationMessageSummary message,
    ConversationDetailTarget target,
  ) async {
    final senderId = message.senderId;
    if (senderId == null || senderId.isEmpty) return;
    final isAgent = message.senderType == 'agent';

    // #656: Show loading sheet immediately for visual feedback.
    final profileFuture = ref
        .read(profileRepositoryProvider)
        .loadProfile(target.serverId, userId: senderId);

    // Prevent unhandled-future-error: the bottom-sheet route transition spans
    // multiple frames, so _ProfileLoadingSheet.initState may not attach its
    // .catchError() handler before this future completes with an error.
    profileFuture.ignore();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ProfileLoadingSheet(
        key: const ValueKey('profile-loading-sheet'),
        profileFuture: profileFuture,
        onMessageTap: (profile) {
          Navigator.of(sheetContext).pop();
          _openDirectMessage(target.serverId, senderId, isAgent: isAgent);
        },
        onError: (e, st) {
          ref.read(diagnosticsCollectorProvider).error(
            'ConversationDetail',
            'profile load failed: $e',
            metadata: {'stackTrace': st.toString()},
          );
        },
      ),
    );
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
    } catch (e, st) {
      ref.read(diagnosticsCollectorProvider).error(
        'ConversationDetail',
        'direct message open failed: $e',
        metadata: {'stackTrace': st.toString()},
      );
      // Fail-soft: if DM open fails, do nothing.
    }
  }

  /// Handles tapping an @mention in message content. Resolves the mention
  /// handle to a member entity ID, then navigates to their profile page.
  ///
  /// Degrades gracefully when the mention cannot be resolved (e.g. member
  /// left the channel).
  Future<void> _onMentionTap(String mentionName) async {
    final target = widget.target;
    try {
      final route = await resolveMentionProfileRoute(
        memberRepo: ref.read(channelMemberRepositoryProvider),
        serverId: target.serverId,
        channelId: target.conversationId,
        mentionName: mentionName,
      );
      if (route == null || !mounted) return;

      context.push(route);
    } catch (e, st) {
      ref.read(diagnosticsCollectorProvider).error(
        'ConversationDetail',
        'mention tap profile navigation failed: $e',
        metadata: {'stackTrace': st.toString()},
      );
    }
  }

  /// Handles tapping a #channel reference in message content.
  /// Resolves the channel name to a channel ID via the home list store,
  /// then navigates to the channel conversation page.
  ///
  /// Degrades gracefully when the channel cannot be resolved.
  void _onChannelRefTap(String channelName) {
    final target = widget.target;
    try {
      final state = ref.read(homeListStoreProvider);
      final nameLower = channelName.toLowerCase();
      final match = state.channels
          .where((c) => c.name.toLowerCase() == nameLower)
          .firstOrNull;
      if (match == null) {
        // Try pinned channels as well.
        final pinnedMatch = state.pinnedChannels
            .where((c) => c.name.toLowerCase() == nameLower)
            .firstOrNull;
        if (pinnedMatch == null) return;
        context.push(
          '/servers/${target.serverId.value}/channels/${pinnedMatch.scopeId.value}',
        );
        return;
      }
      context.push(
        '/servers/${target.serverId.value}/channels/${match.scopeId.value}',
      );
    } catch (e, st) {
      ref.read(diagnosticsCollectorProvider).error(
        'ConversationDetail',
        'channel ref tap navigation failed: $e',
        metadata: {'stackTrace': st.toString()},
      );
    }
  }

  /// Handles tapping a `task #N` reference in message content.
  /// Resolves the task via API and navigates to the message or tasks tab.
  Future<void> _onTaskRefTap(String taskNumber) async {
    if (_isLoadingTask) return; // PERF-1: re-entry guard for rapid taps.

    final target = widget.target;
    final number = int.tryParse(taskNumber);
    if (number == null || number <= 0) return;

    _isLoadingTask = true;

    // Capture messenger before async gap so we can dismiss the snackbar
    // even if the widget is unmounted (P2-A: stale snackbar fix).
    final messenger = ScaffoldMessenger.of(context);

    // Show brief loading indicator.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text('task #$taskNumber'),
            ],
          ),
          duration: const Duration(seconds: 10),
        ),
      );

    try {
      final repo = ref.read(tasksRepositoryProvider);
      final task = await repo.getTaskByNumber(
        target.serverId,
        channelId: target.conversationId,
        taskNumber: number,
      );

      // P2-A: Always dismiss loading snackbar, even if navigated away.
      messenger.hideCurrentSnackBar();
      if (!mounted) return;

      if (task.isLegacy || task.messageId == null) {
        context.push('/servers/${target.serverId.value}/tasks');
      } else {
        context.push(
          '/servers/${target.serverId.value}/channels/${task.channelId}'
          '?messageId=${task.messageId}',
        );
      }
    } on NotFoundFailure {
      // P2-B: Specific API error — task does not exist.
      messenger.hideCurrentSnackBar();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.taskRefNotFound)),
      );
    } catch (_) {
      // P2-B: Generic failure (network, etc.) — distinct from navigation errors.
      messenger.hideCurrentSnackBar();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.taskRefLoadFailed)),
      );
    } finally {
      _isLoadingTask = false;
    }
  }

  /// Handles tapping a thread reference (`#channel:hexid` or `dm:@name:hexid`).
  /// Resolves the channel/DM name to a scope ID via the home list store,
  /// then navigates to the thread replies page.
  ///
  /// Degrades gracefully when the target channel/DM cannot be resolved.
  void _onThreadRefTap(ThreadRefData data) {
    final target = widget.target;
    try {
      final state = ref.read(homeListStoreProvider);
      final nameLower = data.targetName.toLowerCase();
      String? parentChannelId;

      if (data.isDm) {
        // Resolve DM peer name → DM scope ID.
        final dmMatch = state.directMessages
            .where((d) => d.title.toLowerCase() == nameLower)
            .firstOrNull;
        if (dmMatch == null) {
          // Try pinned DMs as well.
          final pinnedDmMatch = state.pinnedDirectMessages
              .where((d) => d.title.toLowerCase() == nameLower)
              .firstOrNull;
          if (pinnedDmMatch == null) return;
          parentChannelId = pinnedDmMatch.scopeId.value;
        } else {
          parentChannelId = dmMatch.scopeId.value;
        }
      } else {
        // Resolve channel name → channel scope ID.
        final channelMatch = state.channels
            .where((c) => c.name.toLowerCase() == nameLower)
            .firstOrNull;
        if (channelMatch == null) {
          final pinnedMatch = state.pinnedChannels
              .where((c) => c.name.toLowerCase() == nameLower)
              .firstOrNull;
          if (pinnedMatch == null) return;
          parentChannelId = pinnedMatch.scopeId.value;
        } else {
          parentChannelId = channelMatch.scopeId.value;
        }
      }

      final threadTarget = ThreadRouteTarget(
        serverId: target.serverId.value,
        parentChannelId: parentChannelId,
        parentMessageId: data.messageShortId,
      );
      context.push(threadTarget.toLocation());
    } catch (e, st) {
      ref.read(diagnosticsCollectorProvider).error(
        'ConversationDetail',
        'thread ref tap navigation failed: $e',
        metadata: {'stackTrace': st.toString()},
      );
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
            _conversationL10n(context).conversationMessageDeletedPlaceholder,
            style: AppTypography.body.copyWith(
              color: colors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final isSaved = ref.watch(
      conversationDetailStoreProvider.select(
        (s) => s.savedMessageIds.contains(message.id),
      ),
    );
    // INV-SEL-815: Single consolidated .select() for session data — avoids
    // 4 separate subscriptions that each independently compare state.
    final (:currentUserId, :currentUserName) = ref.watch(
      sessionStoreProvider.select(
        (s) => (currentUserId: s.userId, currentUserName: s.displayName),
      ),
    );
    final visualKind =
        _resolveConversationMessageVisualKind(message, currentUserId);
    final senderLabel = switch (visualKind) {
      _ConversationMessageVisualKind.self => context.l10n.messageSenderYou,
      _ => message.localizedSenderLabel(context.l10n),
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
        ConversationMessageCard.systemBorderRadius,
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

    // #655: Use pre-computed labelBold to avoid per-build weight allocation.
    final senderStyle = ConversationMessageCard.senderNameBaseStyle.copyWith(
      color: visualKind == _ConversationMessageVisualKind.agent
          ? colors.agentAccent
          : colors.textSecondary,
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
          : BoxDecoration(borderRadius: borderRadius),
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
                    child: Text(context.l10n.messageSenderYou,
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
                  RelativeTimeText(
                      time: message.createdAt, style: timestampStyle),
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
                  RelativeTimeText(
                      time: message.createdAt, style: timestampStyle),
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
            AttachmentSection(attachments: message.attachments!),
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
                  borderRadius: ConversationMessageCard._agentBadgeBorderRadius,
                ),
                child: Text(
                  context.l10n.conversationMessageAiBadge,
                  // #655: Use pre-computed captionBold.
                  style: ConversationMessageCard.aiBadgeBaseStyle.copyWith(
                    color: colors.primaryForeground,
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
      final threadLabel = message.replyCount != null && message.replyCount! > 0
          ? context.l10n.conversationMessageReplyCount(message.replyCount!)
          : context.l10n.conversationMessageInThread;
      threadIndicator = Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Semantics(
          button: true,
          label: threadLabel,
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
                  threadLabel,
                  key: const ValueKey('message-thread-indicator'),
                  style: AppTypography.label.copyWith(
                    color: colors.primary,
                  ),
                ),
              ],
            ),
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
            ReactionRow(
              reactions: message.reactions,
              messageId: message.id,
              currentUserId: currentUserId,
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
              ReactionRow(
                reactions: message.reactions,
                messageId: message.id,
                currentUserId: currentUserId,
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
          borderRadius: ConversationMessageCard.systemBorderRadius,
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
          borderRadius: ConversationMessageCard.systemBorderRadius,
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

    // Read selection state from the store — narrowed to 2 fields so that
    // mutations to draft, uploadProgress, messages, etc. do NOT rebuild cards.
    final (:isSelectionMode, :isSelected) = ref.watch(
      conversationDetailStoreProvider.select(
        (s) => (
          isSelectionMode: s.isSelectionMode,
          isSelected: s.selectedMessageIds.contains(message.id),
        ),
      ),
    );

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
        return Semantics(
          button: true,
          label: context.l10n.messageSelectionToggleSemantics,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ref
                .read(conversationDetailStoreProvider.notifier)
                .toggleMessageSelection(message.id),
            child: shellWithSelection,
          ),
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
        onDoubleTapHaptic: () => ref.read(hapticServiceProvider).lightImpact(),
        enableSwipeReply: !message.content.contains('```'),
        onSwipeReply: () => ref
            .read(conversationDetailStoreProvider.notifier)
            .setReplyTo(message),
        onSwipeThresholdHaptic: () =>
            ref.read(hapticServiceProvider).mediumImpact(),
        onLongPress: () => _showContextMenu(context, ref, isSaved, visualKind),
        onLongPressHaptic: () => ref.read(hapticServiceProvider).mediumImpact(),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            _lastPointerDownGlobalPos = event.position;
          },
          child: shellWithSelection,
        ),
      );
    }

    return Semantics(
      button: true,
      label: context.l10n.messageContextMenuSemantics,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => _showContextMenu(context, ref, isSaved, visualKind),
        child: shellWithSelection,
      ),
    );
  }

  /// Quick-react to a message with the first curated emoji.
  Future<void> _quickReact(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(conversationDetailStoreProvider.notifier)
          .addReaction(widget.message.id, '👍');
      // #656: Haptic feedback on successful reaction.
      ref.read(hapticServiceProvider).mediumImpact();
    } on AppFailure catch (failure) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(failure.userMessage(context.l10n)),
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
      onMentionTap: _onMentionTap,
      onChannelRefTap: _onChannelRefTap,
      onTaskRefTap: _onTaskRefTap,
      onThreadRefTap: _onThreadRefTap,
    );

    // If translation is cached for this message, wrap with overlay.
    final entry = ref.watch(
      translationCacheStoreProvider.select((s) => s.translations[message.id]),
    );
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
        Clipboard.setData(
            ClipboardData(text: stripMarkdown(widget.message.content)));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              content: Text(context.l10n.conversationCopiedToClipboard)));
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
                      SnackBar(
                          content:
                              Text(context.l10n.conversationMessageForwarded)),
                    );
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(context.l10n.conversationSendFailed),
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
                content: Text(failure.userMessage(context.l10n)),
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
      onCopyMarkdown: () {
        Clipboard.setData(ClipboardData(text: widget.message.content));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              content: Text(context.l10n.conversationCopiedToClipboard)));
      },
      onCopyLink: () {
        final threadContext = ref.read(currentThreadContextProvider);
        final permalink = buildMessagePermalink(
          target: widget.target,
          messageId: widget.message.id,
          threadContext: threadContext,
        );
        Clipboard.setData(ClipboardData(text: permalink));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(context.l10n.conversationLinkCopied)),
          );
      },
    );
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (_) => EditMessageDialog(
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
      builder: (_) => const EmojiPickerSheet(),
    );
    if (emoji == null || !context.mounted) return;

    try {
      await ref
          .read(conversationDetailStoreProvider.notifier)
          .addReaction(widget.message.id, emoji);
      // #656: Haptic feedback on successful reaction.
      ref.read(hapticServiceProvider).mediumImpact();
    } on AppFailure catch (failure) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(failure.userMessage(context.l10n)),
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
            title:
                Text(_conversationL10n(context).conversationDeleteDialogTitle),
            content: Text(
                _conversationL10n(context).conversationDeleteDialogContent),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                    _conversationL10n(context).conversationDeleteDialogCancel),
              ),
              TextButton(
                key: const ValueKey('delete-message-confirm'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                    _conversationL10n(context).conversationDeleteDialogConfirm),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    ref.read(hapticServiceProvider).mediumImpact();

    try {
      await ref
          .read(conversationDetailStoreProvider.notifier)
          .deleteMessage(widget.message.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content:
                Text(_conversationL10n(context).conversationDeleteSuccess)));
    } on AppFailure catch (failure) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(failure.userMessage(context.l10n)),
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
          SnackBar(content: Text(context.l10n.conversationTaskCreated)),
        );
    } on AppFailure catch (failure) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(failure.userMessage(context.l10n)),
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
    return Semantics(
      button: true,
      label: context.l10n.linkedTaskBadgeSemantics,
      child: GestureDetector(
        onTap: () => context.push('/servers/$serverId/tasks'),
        behavior: HitTestBehavior.opaque,
        child: Container(
          key: ValueKey('message-linked-task-${task.id}'),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: colors.container,
            border: Border.all(color: colors.foreground),
            borderRadius: ConversationMessageCard.taskBadgeBorderRadius,
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
      title: Text(_conversationL10n(context).conversationOpenLinkTitle),
      content: Text(
        _conversationL10n(context).conversationOpenLinkContent(href),
        style: TextStyle(color: colors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(_conversationL10n(context).conversationOpenLinkCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(_conversationL10n(context).conversationOpenLinkConfirm),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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

    return Semantics(
      button: onTap != null,
      label: onTap != null ? context.l10n.quotedMessageTapSemantics : null,
      child: GestureDetector(
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
            borderRadius: ConversationMessageCard._agentBadgeBorderRadius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                replyTo.localizedSenderLabel(context.l10n),
                // #655: Use pre-computed labelBold.
                style: ConversationMessageCard.senderNameBaseStyle.copyWith(
                  color: labelColor,
                ),
              ),
              Text(
                replyTo.content.isEmpty
                    ? context.l10n.conversationQuoteFallback
                    : replyTo.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: bodyColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// #656: Profile loading sheet — shows a loading indicator immediately,
// then transitions to the full profile content once data arrives.
// ---------------------------------------------------------------------------

class _ProfileLoadingSheet extends StatefulWidget {
  const _ProfileLoadingSheet({
    super.key,
    required this.profileFuture,
    this.onMessageTap,
    this.onError,
  });

  final Future<MemberProfile> profileFuture;
  final void Function(MemberProfile)? onMessageTap;
  final void Function(Object, StackTrace)? onError;

  @override
  State<_ProfileLoadingSheet> createState() => _ProfileLoadingSheetState();
}

class _ProfileLoadingSheetState extends State<_ProfileLoadingSheet> {
  MemberProfile? _profile;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await widget.profileFuture;
      if (!mounted) return;
      setState(() => _profile = profile);
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _hasError = true);
      widget.onError?.call(e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    if (_hasError) {
      // Close the sheet on error (fail-soft).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    if (_profile == null) {
      // Loading state — show spinner with drag handle.
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: colors.textTertiary,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const CircularProgressIndicator(
                key: ValueKey('profile-loading-indicator'),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      );
    }

    // Profile loaded — delegate to the existing member profile sheet widget.
    final member = _profile!;
    return _MemberProfileSheetContent(
      member: member,
      onMessageTap: widget.onMessageTap != null
          ? () => widget.onMessageTap!(member)
          : null,
    );
  }
}

/// Renders the member profile content (same layout as _MemberProfileSheet
/// in member_profile_sheet.dart but inlined here to avoid double-sheet nesting).
class _MemberProfileSheetContent extends StatelessWidget {
  const _MemberProfileSheetContent({
    required this.member,
    this.onMessageTap,
  });

  final MemberProfile member;
  final VoidCallback? onMessageTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              key: const ValueKey('profile-sheet-handle'),
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.textTertiary,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),

            // Display name
            Text(
              member.displayName,
              key: const ValueKey('profile-sheet-name'),
              style: AppTypography.headline.copyWith(color: colors.text),
              textAlign: TextAlign.center,
            ),

            // Username
            if (member.username != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '@${member.username}',
                key: const ValueKey('profile-sheet-username'),
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),

            // Role badge
            if (member.role != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Container(
                key: const ValueKey('profile-sheet-role'),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  _capitalizeProfilePresence(member.role!),
                  style: AppTypography.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],

            // Presence
            if (member.presence != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    key: const ValueKey('profile-sheet-presence-dot'),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _profilePresenceColor(colors, member.presence),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _capitalizeProfilePresence(member.presence!),
                    key: const ValueKey('profile-sheet-presence'),
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            // Message / DM button
            if (onMessageTap != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const ValueKey('member-profile-dm-action'),
                  onPressed: onMessageTap,
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text(context.l10n.conversationProfileMessage),
                ),
              ),
            if (onMessageTap != null) const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

Color _profilePresenceColor(AppColors colors, String? presence) {
  return switch (presence) {
    'online' => colors.success,
    'thinking' => colors.warning,
    'working' => colors.primary,
    'error' => colors.error,
    _ => colors.textTertiary,
  };
}

String _capitalizeProfilePresence(String presence) {
  if (presence.isEmpty) return presence;
  return presence[0].toUpperCase() + presence.substring(1);
}
