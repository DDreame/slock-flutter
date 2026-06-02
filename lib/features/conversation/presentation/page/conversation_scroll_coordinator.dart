import 'dart:async';

import 'package:flutter/material.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/page/quote_jump_overlay.dart';

/// Encapsulates scroll-related state and logic for the conversation detail page.
///
/// Handles:
/// - Scroll-to-bottom FAB visibility
/// - Throttled viewport offset persistence
/// - Load-older pagination trigger
/// - Quote-jump scroll + highlight flash
/// - Message GlobalKey management
///
/// Extracted from `_ConversationDetailScreenState` to reduce god-widget LOC.
class ConversationScrollCoordinator {
  ConversationScrollCoordinator({
    required this.scrollController,
    required this.readState,
    required this.loadOlder,
    required this.updateViewportOffset,
  });

  final ScrollController scrollController;

  /// Reads the current conversation state (avoids passing WidgetRef).
  final ConversationDetailState Function() readState;

  /// Triggers loadOlder pagination in the store.
  final VoidCallback loadOlder;

  /// Persists the viewport scroll offset to the store.
  final void Function(double offset) updateViewportOffset;

  // -- Public state (read by the page's build method) --

  bool showScrollToBottom = false;
  String? highlightedMessageId;
  QuoteJumpState quoteJumpState = QuoteJumpState.idle;

  // -- Internal state --

  bool didApplyInitialLanding = false;
  Timer? _scrollThrottleTimer;
  double? _olderLoadAnchorOffset;
  double? _olderLoadAnchorMaxExtent;
  Timer? _highlightTimer;
  Timer? _quoteJumpNotFoundTimer;
  final Map<String, GlobalKey> _messageGlobalKeys = {};
  int lastRegisteredMessageCount = 0;

  /// Returns the number of tracked GlobalKeys (test hook).
  int get messageGlobalKeyCount => _messageGlobalKeys.length;

  /// Clears the GlobalKey map (called on dispose for test observability).
  void clearMessageGlobalKeys() => _messageGlobalKeys.clear();

  GlobalKey getMessageKey(String messageId) {
    return _messageGlobalKeys.putIfAbsent(messageId, () => GlobalKey());
  }

  /// Evicts GlobalKeys for messages no longer in the loaded window.
  /// Prevents unbounded growth during long pagination sessions.
  void evictStaleKeys(List<ConversationMessageSummary> messages) {
    if (_messageGlobalKeys.length > messages.length + 20) {
      final activeIds = <String>{for (final m in messages) m.id};
      _messageGlobalKeys.removeWhere((id, _) => !activeIds.contains(id));
    }
  }

  // ---------------------------------------------------------------------------
  // Scroll handling
  // ---------------------------------------------------------------------------

  /// Called by the ScrollController listener. Returns `true` if
  /// [showScrollToBottom] changed (caller should setState).
  bool handleScroll() {
    if (!scrollController.hasClients) return false;

    // Show/hide scroll-to-bottom FAB based on scroll offset.
    final shouldShow = scrollController.offset > 300;
    final changed = shouldShow != showScrollToBottom;
    if (changed) {
      showScrollToBottom = shouldShow;
    }

    // Throttle updateViewportOffset writes.
    if (_scrollThrottleTimer == null || !_scrollThrottleTimer!.isActive) {
      _scrollThrottleTimer = Timer(const Duration(milliseconds: 100), () {
        if (scrollController.hasClients) {
          updateViewportOffset(scrollController.offset);
        }
      });
    }

    // Load older messages when near the top (oldest end).
    final maxExtent = scrollController.position.maxScrollExtent;
    if (scrollController.offset >= maxExtent - 80) {
      final state = readState();
      if (state.status == ConversationDetailStatus.success &&
          !state.isLoadingOlder &&
          state.hasOlder) {
        _olderLoadAnchorOffset = scrollController.offset;
        _olderLoadAnchorMaxExtent = maxExtent;
        loadOlder();
      }
    }

    return changed;
  }

  // ---------------------------------------------------------------------------
  // Scroll state synchronization (after store state changes)
  // ---------------------------------------------------------------------------

  /// Synchronizes scroll position after a state change.
  /// Returns `true` if called successfully (caller may need setState for
  /// landing-related state changes).
  ///
  /// [onScrollToMessage] is called when an initial landing scroll is needed.
  void syncScrollState(
    ConversationDetailState? previous,
    ConversationDetailState next, {
    required bool restoredFromSession,
    required String? highlightMessageId,
    required int Function() unreadCountForTarget,
    required void Function(
            String messageId, List<ConversationMessageSummary> messages)
        scrollToMessageId,
  }) {
    if (!scrollController.hasClients) return;

    if (!didApplyInitialLanding &&
        next.status == ConversationDetailStatus.success &&
        next.messages.isNotEmpty) {
      final targetMsgId = highlightMessageId;
      if (targetMsgId != null || !restoredFromSession) {
        didApplyInitialLanding = true;
        final unreadCount = unreadCountForTarget();
        final firstUnreadMsgId =
            unreadCount > 0 && unreadCount <= next.messages.length
                ? next.messages[next.messages.length - unreadCount].id
                : null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!scrollController.hasClients) return;
          if (targetMsgId != null) {
            scrollToMessageId(targetMsgId, next.messages);
          } else if (firstUnreadMsgId != null) {
            scrollToMessageId(firstUnreadMsgId, next.messages);
          } else {
            scrollController.jumpTo(0);
          }
        });
      }
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
        if (!scrollController.hasClients) return;
        final maxExtentDelta =
            scrollController.position.maxScrollExtent - previousMaxExtent;
        scrollController.jumpTo(anchorOffset + maxExtentDelta);
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Quote-jump: scroll to message + highlight
  // ---------------------------------------------------------------------------

  /// Scrolls to a specific message by ID and shows a highlight flash.
  /// If the message is not in the loaded list, calls [onMissing].
  void scrollToMessageId(
    String messageId,
    List<ConversationMessageSummary> messages, {
    required Future<void> Function(String messageId) onMissing,
  }) {
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx < 0) {
      onMissing(messageId);
      return;
    }
    scrollToAndHighlight(messageId);
  }

  /// Scrolls to a message using GlobalKey-based ensureVisible and applies
  /// a highlight flash that auto-dismisses after 1.5 seconds.
  ///
  /// Returns `true` (state changed — caller should setState).
  bool scrollToAndHighlight(String messageId) {
    _highlightTimer?.cancel();
    _quoteJumpNotFoundTimer?.cancel();

    highlightedMessageId = messageId;
    quoteJumpState = QuoteJumpState.idle;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = getMessageKey(messageId);
      if (key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 300),
          alignment: 0.3,
          curve: Curves.easeInOut,
        );
      } else {
        // GlobalKey not yet in viewport — fall back to proportional estimate.
        final state = readState();
        final idx = state.messages.indexWhere((m) => m.id == messageId);
        if (idx >= 0 && scrollController.hasClients) {
          final maxExtent = scrollController.position.maxScrollExtent;
          final estimatedOffset = state.messages.isEmpty
              ? 0.0
              : (state.messages.length - idx) /
                  (state.messages.length + 1) *
                  maxExtent;
          scrollController.jumpTo(estimatedOffset.clamp(0.0, maxExtent));
        }
      }
    });

    // Auto-dismiss highlight after 1.5 seconds.
    _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
      highlightedMessageId = null;
      // Caller must poll or use a callback for this.
    });

    return true;
  }

  /// Sets quote-jump state to loading. Returns `true` (state changed).
  bool setQuoteJumpLoading() {
    _quoteJumpNotFoundTimer?.cancel();
    quoteJumpState = QuoteJumpState.loading;
    return true;
  }

  /// Sets quote-jump state to not-found with auto-dismiss timer.
  /// Returns `true` (state changed).
  bool setQuoteJumpNotFound() {
    quoteJumpState = QuoteJumpState.notFound;
    _scheduleNotFoundDismiss();
    return true;
  }

  /// Dismiss the not-found overlay. Returns `true` if state changed.
  bool dismissQuoteJumpNotFound() {
    if (quoteJumpState != QuoteJumpState.notFound) return false;
    _quoteJumpNotFoundTimer?.cancel();
    quoteJumpState = QuoteJumpState.idle;
    return true;
  }

  void _scheduleNotFoundDismiss() {
    _quoteJumpNotFoundTimer?.cancel();
    _quoteJumpNotFoundTimer = Timer(const Duration(seconds: 4), () {
      if (quoteJumpState != QuoteJumpState.notFound) return;
      quoteJumpState = QuoteJumpState.idle;
      // Caller must poll or use a callback for this.
    });
  }

  void dispose() {
    _scrollThrottleTimer?.cancel();
    _highlightTimer?.cancel();
    _quoteJumpNotFoundTimer?.cancel();
    _messageGlobalKeys.clear();
  }
}
