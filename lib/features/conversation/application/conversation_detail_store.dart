import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_session_store.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/image_compressor.dart';
import 'package:slock_app/features/conversation/application/message_send_status.dart';
import 'package:slock_app/features/conversation/application/outbox_store.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/application/pinned_messages_store.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/inbox/application/message_preview_resolver.dart';
import 'package:slock_app/l10n/app_localizations_provider.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';
import 'package:slock_app/stores/session/session_store.dart';

part 'conversation_detail_store_send.dart';
part 'conversation_detail_store_search.dart';
part 'conversation_detail_store_reactions.dart';
part 'conversation_detail_store_selection.dart';

final currentConversationDetailTargetProvider =
    Provider<ConversationDetailTarget>((ref) {
  throw UnimplementedError(
    'currentConversationDetailTargetProvider must be overridden.',
  );
});

final conversationDetailStoreProvider = NotifierProvider.autoDispose<
    ConversationDetailStore, ConversationDetailState>(
  ConversationDetailStore.new,
  dependencies: [currentConversationDetailTargetProvider],
);

const _realtimeMessageCreatedEventType = 'message:new';
const _realtimeMessageUpdatedEventType = 'message:updated';
const _realtimeMessageDeletedEventType = 'message:deleted';
const _realtimeMessagePinnedEventType = 'message:pinned';
const _realtimeMessageUnpinnedEventType = 'message:unpinned';
const _realtimeReactionAddedEventType = 'message:reaction_added';
const _realtimeReactionRemovedEventType = 'message:reaction_removed';

// ---------------------------------------------------------------------------
// Shared utility mixin — provides helpers used by Send, Reactions, and
// Selection mixins that need access to session persistence and message
// deduplication logic.
// ---------------------------------------------------------------------------

mixin _ConversationDetailCoreMixin
    on AutoDisposeNotifier<ConversationDetailState> {
  void _persistSession() {
    ref.read(conversationDetailSessionStoreProvider.notifier).saveSuccessState(
          state,
          scrollOffset: ref
                  .read(conversationDetailSessionStoreProvider)[state.target]
                  ?.scrollOffset ??
              0,
        );
  }

  List<ConversationMessageSummary> _appendDedupedMessage(
    List<ConversationMessageSummary> existing,
    ConversationMessageSummary next,
  ) {
    // INV-DEDUP-663-1: O(1) lookup via lazily-cached message ID Set.
    final store = this as ConversationDetailStore;
    if (store._messageIdSet.contains(next.id)) {
      return existing;
    }
    return [...existing, next];
  }

  List<ConversationMessageSummary> _prependDedupedMessages(
    List<ConversationMessageSummary> existing,
    List<ConversationMessageSummary> olderMessages,
  ) {
    // INV-DEDUP-668: Reuse lazily-cached _messageIdSet for O(1) lookup.
    final store = this as ConversationDetailStore;
    final existingIds = store._messageIdSet;
    final dedupedOlder = olderMessages
        .where((message) => !existingIds.contains(message.id))
        .toList(growable: false);
    if (dedupedOlder.isEmpty) {
      return existing;
    }
    return [...dedupedOlder, ...existing];
  }

  List<ConversationMessageSummary> _appendDedupedMessages(
    List<ConversationMessageSummary> existing,
    List<ConversationMessageSummary> newerMessages,
  ) {
    // INV-DEDUP-668: Reuse lazily-cached _messageIdSet for O(1) lookup.
    final store = this as ConversationDetailStore;
    final existingIds = store._messageIdSet;
    final dedupedNewer = newerMessages
        .where((message) => !existingIds.contains(message.id))
        .toList(growable: false);
    if (dedupedNewer.isEmpty) {
      return existing;
    }
    return [...existing, ...dedupedNewer];
  }

  int? _maxSeq(List<ConversationMessageSummary> messages) {
    return messages
        .map((message) => message.seq)
        .whereType<int>()
        .fold<int?>(null, (current, next) {
      if (current == null || next > current) {
        return next;
      }
      return current;
    });
  }

  bool _isCurrentRequest(
    int requestEpoch,
    ConversationDetailTarget target,
  ) {
    return requestEpoch == (this as ConversationDetailStore)._requestEpoch &&
        ref.read(currentConversationDetailTargetProvider) == target;
  }
}

// ---------------------------------------------------------------------------
// Main store class
// ---------------------------------------------------------------------------

class ConversationDetailStore
    extends AutoDisposeNotifier<ConversationDetailState>
    with
        _ConversationDetailCoreMixin,
        _ConversationDetailSendMixin,
        _ConversationDetailSearchMixin,
        _ConversationDetailReactionsMixin,
        _ConversationDetailSelectionMixin {
  int _requestEpoch = 0;
  final RequestCoordinator _coordinator = RequestCoordinator();

  /// INV-DEDUP-663-1: Cached Set of message IDs for O(1) dedup lookup.
  /// Invalidated (rebuilt lazily) whenever state.messages list changes.
  List<ConversationMessageSummary>? _cachedMessageList;
  Set<String> _cachedMessageIdSet = const {};

  /// Returns the current message ID set, rebuilding lazily when the
  /// messages list identity changes. O(1) amortized per dedup check.
  Set<String> get _messageIdSet {
    final currentMessages = state.messages;
    if (!identical(currentMessages, _cachedMessageList)) {
      _cachedMessageIdSet = {for (final m in currentMessages) m.id};
      _cachedMessageList = currentMessages;
    }
    return _cachedMessageIdSet;
  }

  /// INV-DEDUP-663-1: Exposes [_messageIdSet] for test verification of
  /// Set-based dedup invalidation.
  @visibleForTesting
  Set<String> get messageIdSetForTesting => _messageIdSet;

  /// INV-DEDUP-663-1: Returns true when the cached Set was built from the
  /// current [state.messages] list. Used to verify that [_appendDedupedMessage]
  /// actually consults [_messageIdSet] on the hot path.
  @visibleForTesting
  bool get isMessageIdSetCacheWarm =>
      identical(_cachedMessageList, state.messages);

  /// INV-DEDUP-663-1: Exposes [_appendDedupedMessage] for direct hot-path
  /// verification in tests.
  @visibleForTesting
  List<ConversationMessageSummary> appendDedupedMessageForTesting(
    List<ConversationMessageSummary> existing,
    ConversationMessageSummary next,
  ) =>
      _appendDedupedMessage(existing, next);

  /// INV-DEDUP-668: Exposes [_prependDedupedMessages] for batch-path testing.
  @visibleForTesting
  List<ConversationMessageSummary> prependDedupedMessagesForTesting(
    List<ConversationMessageSummary> existing,
    List<ConversationMessageSummary> olderMessages,
  ) =>
      _prependDedupedMessages(existing, olderMessages);

  /// INV-DEDUP-668: Exposes [_appendDedupedMessages] for batch-path testing.
  @visibleForTesting
  List<ConversationMessageSummary> appendDedupedMessagesForTesting(
    List<ConversationMessageSummary> existing,
    List<ConversationMessageSummary> newerMessages,
  ) =>
      _appendDedupedMessages(existing, newerMessages);

  /// Maximum duration a message can stay in [MessageSendStatus.sending]
  /// before being auto-transitioned to queued via the outbox.
  static const sendTimeoutDuration = Duration(seconds: 30);

  /// Duration the "sent" indicator remains visible before removal.
  static const sentIndicatorDuration = Duration(seconds: 2);

  @override
  ConversationDetailState build() {
    final target = ref.watch(currentConversationDetailTargetProvider);
    final ingress = ref.watch(realtimeReductionIngressProvider);
    final cachedSession =
        ref.read(conversationDetailSessionStoreProvider)[target];

    final subscription = ingress.acceptedEvents.listen((event) {
      if (event.payload == null) {
        return;
      }

      if (event.eventType == _realtimeMessageCreatedEventType) {
        _handleMessageCreated(
          event.payload!,
          target,
          gapDetected: event.gapDetected,
        );
      } else if (event.eventType == _realtimeMessageUpdatedEventType) {
        _handleMessageUpdated(event.payload!, target);
      } else if (event.eventType == _realtimeMessageDeletedEventType) {
        _handleMessageDeleted(event.payload!, target);
      } else if (event.eventType == _realtimeMessagePinnedEventType) {
        _handleMessagePinToggled(event.payload!, target, isPinned: true);
      } else if (event.eventType == _realtimeMessageUnpinnedEventType) {
        _handleMessagePinToggled(event.payload!, target, isPinned: false);
      } else if (event.eventType == _realtimeReactionAddedEventType) {
        _handleReactionAdded(event.payload!, target);
      } else if (event.eventType == _realtimeReactionRemovedEventType) {
        _handleReactionRemoved(event.payload!, target);
      }
    });

    // Register outbox drain callback so drain results reconcile pending
    // messages back into the conversation state.
    // Capture the notifier reference now — reading providers inside
    // ref.onDispose is unsafe (container may already be disposed).
    final outbox = ref.read(outboxStoreProvider.notifier);
    final targetKey = outboxTargetKey(target);
    outbox.registerDrainCallback(targetKey, _onOutboxDrain);

    ref.onDispose(() {
      unawaited(subscription.cancel());
      _coordinator.dispose();
      for (final timer in _sentRemovalTimers) {
        timer.cancel();
      }
      _sentRemovalTimers.clear();
      for (final timer in _sendTimeoutTimers.values) {
        timer.cancel();
      }
      _sendTimeoutTimers.clear();
      for (final token in _sendCancelTokens.values) {
        if (!token.isCancelled) token.cancel('Disposed');
      }
      _sendCancelTokens.clear();
      for (final token in _uploadCancelTokens.values) {
        if (!token.isCancelled) token.cancel('Disposed');
      }
      _uploadCancelTokens.clear();
      // Unregister outbox drain callback using captured reference.
      outbox.unregisterDrainCallback(targetKey);
    });

    var initialState = cachedSession?.toState(target) ??
        ConversationDetailState(target: target);

    // Hydrate pending messages from the durable outbox.
    // The outbox is the single source of truth for queued messages across
    // page reopens and app restarts. Merge any outbox items for this target
    // into the pending list, deduplicating by localId.
    final outboxState = ref.read(outboxStoreProvider);
    final outboxItems = outboxState.items[targetKey]?.where(
          (m) => m.status == OutboxMessageStatus.pending,
        ) ??
        const [];
    if (outboxItems.isNotEmpty) {
      final existingLocalIds =
          initialState.pendingMessages.map((m) => m.localId).toSet();
      final hydrated = <PendingMessage>[
        ...initialState.pendingMessages,
        for (final item in outboxItems)
          if (!existingLocalIds.contains(item.localId))
            PendingMessage(
              localId: item.localId,
              content: item.content,
              createdAt: item.createdAt,
              replyToId: item.replyToId,
              status: MessageSendStatus.queued,
            ),
      ];
      if (hydrated.length != initialState.pendingMessages.length) {
        initialState = initialState.copyWith(pendingMessages: hydrated);
      }
    }

    // Remove stale session-persisted queued messages that the outbox already
    // drained while this page was closed.
    if (initialState.pendingMessages.isNotEmpty) {
      final outboxLocalIds = outboxItems.map((m) => m.localId).toSet();
      final pruned = initialState.pendingMessages.where((m) {
        if (m.status == MessageSendStatus.queued) {
          return outboxLocalIds.contains(m.localId);
        }
        return true; // keep non-queued (failed) messages as-is
      }).toList();
      if (pruned.length != initialState.pendingMessages.length) {
        initialState = initialState.copyWith(pendingMessages: pruned);
      }
    }

    if (cachedSession != null) {
      Future.microtask(() => _refreshFromCache(target));
    }
    return initialState;
  }

  Future<void> ensureLoaded() async {
    if (state.status != ConversationDetailStatus.initial) {
      return;
    }
    await load();
  }

  Future<void> load() async {
    final target = ref.read(currentConversationDetailTargetProvider);
    final requestEpoch = ++_requestEpoch;

    // SWR: when the store has already loaded successfully, preserve the
    // current state during reload (stale-while-revalidate) — even if the
    // conversation is empty (loaded-empty is a valid success state).
    final hasExistingData = state.status == ConversationDetailStatus.success;

    if (hasExistingData) {
      state = state.copyWith(
        target: target,
        isRefreshing: true,
        clearFailure: true,
        clearSendFailure: true,
      );
    } else {
      state = state.copyWith(
        target: target,
        status: ConversationDetailStatus.loading,
        messages: const [],
        historyLimited: false,
        hasOlder: false,
        hasNewer: false,
        isRefreshing: false,
        clearFailure: true,
        clearSendFailure: true,
      );
    }

    try {
      final snapshot = await ref
          .read(conversationRepositoryProvider)
          .loadConversation(target);
      if (!_isCurrentRequest(requestEpoch, target)) {
        return;
      }
      state = state.copyWith(
        target: snapshot.target,
        status: ConversationDetailStatus.success,
        title: snapshot.title,
        description: snapshot.description,
        clearDescription: snapshot.description == null,
        memberCount: snapshot.memberCount,
        messages: snapshot.messages,
        historyLimited: snapshot.historyLimited,
        hasOlder: snapshot.hasOlder,
        isRefreshing: false,
        clearFailure: true,
        clearSendFailure: true,
      );
      _persistSession();
      unawaited(refreshSavedMessageIds());
    } on AppFailure catch (failure) {
      if (!_isCurrentRequest(requestEpoch, target)) {
        return;
      }
      if (hasExistingData) {
        // SWR error: preserve existing messages, overlay failure.
        state = state.copyWith(
          isRefreshing: false,
          failure: failure,
        );
      } else {
        state = state.copyWith(
          target: target,
          status: ConversationDetailStatus.failure,
          title: target.defaultTitle,
          messages: const [],
          historyLimited: false,
          hasOlder: false,
          failure: failure,
          isRefreshing: false,
          clearSendFailure: true,
        );
      }
    }
  }

  /// Stale-while-revalidate refresh: keeps existing messages visible
  /// while fetching fresh data in the background.
  ///
  /// [reason] is a deduplication key for [RequestCoordinator]: concurrent
  /// refreshes with the same reason share a single in-flight request,
  /// while different reasons run concurrently. Defaults to
  /// `'pullToRefresh'`.
  ///
  /// If no prior data exists, falls back to [load].
  Future<void> refresh({String reason = 'pullToRefresh'}) async {
    // No existing data — use full load.
    if (state.status != ConversationDetailStatus.success) {
      return load();
    }

    return _coordinator.coordinate(reason, () async {
      final target = ref.read(currentConversationDetailTargetProvider);
      final requestEpoch = ++_requestEpoch;

      state = state.copyWith(isRefreshing: true, clearFailure: true);

      try {
        final snapshot = await ref
            .read(conversationRepositoryProvider)
            .loadConversation(target);
        if (!_isCurrentRequest(requestEpoch, target)) {
          return;
        }
        state = state.copyWith(
          target: snapshot.target,
          status: ConversationDetailStatus.success,
          title: snapshot.title,
          description: snapshot.description,
          clearDescription: snapshot.description == null,
          memberCount: snapshot.memberCount,
          messages: snapshot.messages,
          historyLimited: snapshot.historyLimited,
          hasOlder: snapshot.hasOlder,
          isRefreshing: false,
          clearFailure: true,
        );
        _persistSession();
        unawaited(refreshSavedMessageIds());
      } on AppFailure catch (failure) {
        if (!_isCurrentRequest(requestEpoch, target)) {
          return;
        }
        // Keep existing messages visible on refresh failure.
        state = state.copyWith(
          isRefreshing: false,
          failure: failure,
        );
      }
    });
  }

  /// Retries loading conversation data. When stale data is available,
  /// delegates to [refresh] to preserve it (stale-while-revalidate).
  Future<void> retry() {
    if (state.status == ConversationDetailStatus.success) {
      return refresh();
    }
    return load();
  }

  /// Called by pull-to-refresh; preserves visible messages.
  Future<void> pullToRefresh() => refresh();

  Future<void> loadOlder() async {
    final target = ref.read(currentConversationDetailTargetProvider);
    if (state.status != ConversationDetailStatus.success ||
        state.isLoadingOlder ||
        !state.hasOlder ||
        state.messages.isEmpty) {
      return;
    }

    final beforeSeq = state.messages
        .map((message) => message.seq)
        .whereType<int>()
        .fold<int?>(null, (current, next) {
      if (current == null || next < current) {
        return next;
      }
      return current;
    });
    if (beforeSeq == null) {
      return;
    }

    state = state.copyWith(isLoadingOlder: true, clearFailure: true);

    try {
      final page =
          await ref.read(conversationRepositoryProvider).loadOlderMessages(
                target,
                beforeSeq: beforeSeq,
              );
      if (ref.read(currentConversationDetailTargetProvider) != target ||
          state.status != ConversationDetailStatus.success) {
        return;
      }
      state = state.copyWith(
        messages: _prependDedupedMessages(state.messages, page.messages),
        historyLimited: state.historyLimited || page.historyLimited,
        hasOlder: page.hasOlder,
        isLoadingOlder: false,
        clearFailure: true,
      );
      _persistSession();
      unawaited(refreshSavedMessageIds());
    } on AppFailure catch (failure) {
      if (ref.read(currentConversationDetailTargetProvider) != target ||
          state.status != ConversationDetailStatus.success) {
        return;
      }
      state = state.copyWith(
        isLoadingOlder: false,
        failure: failure,
      );
    }
  }

  Future<void> loadNewer() async {
    final target = ref.read(currentConversationDetailTargetProvider);
    if (state.status != ConversationDetailStatus.success ||
        state.isLoadingNewer ||
        !state.hasNewer ||
        state.messages.isEmpty) {
      return;
    }

    final afterSeq = _maxSeq(state.messages);
    if (afterSeq == null) {
      return;
    }

    state = state.copyWith(isLoadingNewer: true, clearFailure: true);

    try {
      final page =
          await ref.read(conversationRepositoryProvider).loadNewerMessages(
                target,
                afterSeq: afterSeq,
              );
      if (ref.read(currentConversationDetailTargetProvider) != target ||
          state.status != ConversationDetailStatus.success) {
        return;
      }
      state = state.copyWith(
        messages: _appendDedupedMessages(state.messages, page.messages),
        hasNewer: page.hasNewer,
        isLoadingNewer: false,
        clearFailure: true,
      );
      _persistSession();
    } on AppFailure catch (failure) {
      if (ref.read(currentConversationDetailTargetProvider) != target ||
          state.status != ConversationDetailStatus.success) {
        return;
      }
      state = state.copyWith(
        isLoadingNewer: false,
        failure: failure,
      );
    }
  }

  void updateViewportOffset(double offset) {
    ref
        .read(conversationDetailSessionStoreProvider.notifier)
        .saveScrollOffset(state.target, offset);
  }

  Future<void> refreshSavedMessageIds() async {
    if (state.status != ConversationDetailStatus.success ||
        state.messages.isEmpty) {
      return;
    }

    final target = ref.read(currentConversationDetailTargetProvider);
    final serverId = target.serverId;
    final messageIds = state.messages.map((m) => m.id).toList(growable: false);

    try {
      final repo = ref.read(savedMessagesRepositoryProvider);
      final savedIds = await repo.checkSavedMessages(serverId, messageIds);
      if (ref.read(currentConversationDetailTargetProvider) != target ||
          state.status != ConversationDetailStatus.success) {
        return;
      }
      state = state.copyWith(savedMessageIds: savedIds);
    } on AppFailure {
      // Fail-soft: keep existing saved state.
    }
  }

  Future<void> toggleSaveMessage(String messageId) async {
    final target = ref.read(currentConversationDetailTargetProvider);
    final serverId = target.serverId;
    final isSaved = state.savedMessageIds.contains(messageId);
    final previousIds = state.savedMessageIds;

    // Optimistic update
    final updatedIds = Set<String>.of(previousIds);
    if (isSaved) {
      updatedIds.remove(messageId);
    } else {
      updatedIds.add(messageId);
    }
    state = state.copyWith(savedMessageIds: updatedIds);

    try {
      final repo = ref.read(savedMessagesRepositoryProvider);
      if (isSaved) {
        await repo.unsaveMessage(serverId, messageId);
      } else {
        await repo.saveMessage(serverId, messageId);
      }
    } on AppFailure {
      if (ref.read(currentConversationDetailTargetProvider) != target) return;
      state = state.copyWith(savedMessageIds: previousIds);
    }
  }

  Future<void> editMessage(String messageId, String newContent) async {
    final target = ref.read(currentConversationDetailTargetProvider);
    if (state.status != ConversationDetailStatus.success) return;

    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final previousMessages = state.messages;
    final messages = List<ConversationMessageSummary>.of(state.messages);
    messages[index] = messages[index].copyWith(content: newContent);
    state = state.copyWith(messages: messages);

    try {
      final repo = ref.read(conversationRepositoryProvider);
      await repo.editMessage(target, messageId: messageId, content: newContent);
      _persistSession();
    } on AppFailure {
      if (ref.read(currentConversationDetailTargetProvider) != target) return;
      state = state.copyWith(messages: previousMessages);
      rethrow;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    final target = ref.read(currentConversationDetailTargetProvider);
    if (state.status != ConversationDetailStatus.success) return;

    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final previousMessages = state.messages;
    final messages = List<ConversationMessageSummary>.of(state.messages);
    messages[index] = messages[index].copyWith(isDeleted: true);
    state = state.copyWith(messages: messages);

    try {
      final repo = ref.read(conversationRepositoryProvider);
      await repo.deleteMessage(target, messageId: messageId);
      _persistSession();
    } on AppFailure {
      if (ref.read(currentConversationDetailTargetProvider) != target) return;
      state = state.copyWith(messages: previousMessages);
      rethrow;
    }
  }

  // ---------- Pin (#534) ----------

  Future<void> pinMessage(String messageId) async {
    final target = ref.read(currentConversationDetailTargetProvider);
    if (state.status != ConversationDetailStatus.success) return;

    _togglePinLocally(messageId, isPinned: true);
    _persistSession();
    _syncPinnedListAdd(messageId);

    try {
      await ref
          .read(conversationRepositoryProvider)
          .pinMessage(target, messageId: messageId);
    } on AppFailure {
      if (ref.read(currentConversationDetailTargetProvider) != target) return;
      _togglePinLocally(messageId, isPinned: false);
      _persistSession();
      _syncPinnedListRemove(messageId);
      rethrow;
    }
  }

  Future<void> unpinMessage(String messageId) async {
    final target = ref.read(currentConversationDetailTargetProvider);
    if (state.status != ConversationDetailStatus.success) return;

    _togglePinLocally(messageId, isPinned: false);
    _persistSession();
    _syncPinnedListRemove(messageId);

    try {
      await ref
          .read(conversationRepositoryProvider)
          .unpinMessage(target, messageId: messageId);
    } on AppFailure {
      if (ref.read(currentConversationDetailTargetProvider) != target) return;
      _togglePinLocally(messageId, isPinned: true);
      _persistSession();
      _syncPinnedListAdd(messageId);
      rethrow;
    }
  }

  void _togglePinLocally(String messageId, {required bool isPinned}) {
    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    final messages = List<ConversationMessageSummary>.of(state.messages);
    messages[index] = messages[index].copyWith(isPinned: isPinned);
    state = state.copyWith(messages: messages);
  }

  /// Sync a pinned message addition to the [PinnedMessagesStore] if alive.
  void _syncPinnedListAdd(String messageId) {
    try {
      final pinnedStore = ref.read(pinnedMessagesStoreProvider.notifier);
      final msg = state.messages.where((m) => m.id == messageId).firstOrNull;
      if (msg != null) {
        pinnedStore.addMessage(msg.copyWith(isPinned: true));
      }
    } on StateError {
      // PinnedMessagesStore not alive (page closed) — nothing to sync.
    }
  }

  /// Sync a pinned message removal from the [PinnedMessagesStore] if alive.
  void _syncPinnedListRemove(String messageId) {
    try {
      ref.read(pinnedMessagesStoreProvider.notifier).removeMessage(messageId);
    } on StateError {
      // PinnedMessagesStore not alive (page closed) — nothing to sync.
    }
  }

  // ---------- Realtime handlers ----------

  void _handleMessageCreated(
    Object payload,
    ConversationDetailTarget target, {
    bool gapDetected = false,
  }) {
    final incoming = tryParseConversationIncomingMessage(
      payload,
      payloadName: 'message:new',
    );
    if (incoming == null || incoming.conversationId != target.conversationId) {
      return;
    }

    if (state.status != ConversationDetailStatus.success) {
      return;
    }

    unawaited(() async {
      final prevMaxSeq = _maxSeq(state.messages);
      ConversationMessageSummary? persisted;
      try {
        persisted =
            await ref.read(conversationRepositoryProvider).persistMessage(
                  target,
                  message: incoming.message,
                  senderId: incoming.senderId,
                );
      } catch (e, st) {
        ref.read(crashReporterProvider).captureException(e, stackTrace: st);
      }
      if (persisted == null) {
        // Persistence failed — still attempt gap recovery if needed.
        if (gapDetected) {
          try {
            await _recoverGap(target, afterSeq: prevMaxSeq);
          } catch (e, st) {
            ref.read(crashReporterProvider).captureException(e, stackTrace: st);
          }
        }
        return;
      }
      if (ref.read(currentConversationDetailTargetProvider) != target ||
          state.status != ConversationDetailStatus.success) {
        return;
      }
      state = state.copyWith(
        messages: _appendDedupedMessage(state.messages, persisted),
      );
      _persistSession();

      if (gapDetected) {
        try {
          await _recoverGap(target, afterSeq: prevMaxSeq);
        } catch (e, st) {
          ref.read(crashReporterProvider).captureException(e, stackTrace: st);
        }
      }
    }());
  }

  Future<void> _recoverGap(
    ConversationDetailTarget target, {
    required int? afterSeq,
  }) async {
    if (afterSeq == null) return;

    try {
      final page =
          await ref.read(conversationRepositoryProvider).loadNewerMessages(
                target,
                afterSeq: afterSeq,
              );
      if (ref.read(currentConversationDetailTargetProvider) != target ||
          state.status != ConversationDetailStatus.success) {
        return;
      }
      final merged = _appendDedupedMessages(state.messages, page.messages);
      if (merged.length != state.messages.length) {
        merged.sort((a, b) {
          final aSeq = a.seq;
          final bSeq = b.seq;
          if (aSeq == null && bSeq == null) return 0;
          if (aSeq == null) return 1;
          if (bSeq == null) return -1;
          return aSeq.compareTo(bSeq);
        });
        state = state.copyWith(
          messages: merged,
          hasNewer: page.hasNewer,
        );
        _persistSession();
      }
    } on AppFailure {
      // Gap recovery is best-effort; the user can still scroll to
      // trigger loadNewer manually.
    }
  }

  void _handleMessageUpdated(Object payload, ConversationDetailTarget target) {
    final updated = tryParseMessageUpdatedPayload(payload);
    if (updated == null || updated.channelId != target.conversationId) {
      return;
    }

    if (state.status != ConversationDetailStatus.success) {
      return;
    }

    unawaited(() async {
      try {
        final patched = await ref
            .read(conversationRepositoryProvider)
            .updateStoredMessageContent(
              target,
              messageId: updated.id,
              content: updated.content,
            );
        if (patched == null ||
            ref.read(currentConversationDetailTargetProvider) != target ||
            state.status != ConversationDetailStatus.success) {
          return;
        }
        final index = state.messages.indexWhere((m) => m.id == updated.id);
        if (index == -1) {
          return;
        }

        final messages = List<ConversationMessageSummary>.of(state.messages);
        messages[index] = patched;
        state = state.copyWith(messages: messages);
        _persistSession();
      } on StateError catch (_) {
        // Provider disposed mid-flight — expected during rapid navigation.
      } catch (e, st) {
        // INV-CONV-MESSAGE-UPDATE-ERROR-1: Route unexpected exceptions to
        // crash reporter instead of leaving them as unhandled future errors.
        ref.read(crashReporterProvider).captureException(e, stackTrace: st);
      }
    }());
  }

  void _handleMessageDeleted(
    Object payload,
    ConversationDetailTarget target,
  ) {
    final deleted = tryParseMessageDeletedPayload(payload);
    if (deleted == null || deleted.channelId != target.conversationId) {
      return;
    }

    if (state.status != ConversationDetailStatus.success) {
      return;
    }

    final index = state.messages.indexWhere((m) => m.id == deleted.id);
    if (index != -1 && !state.messages[index].isDeleted) {
      final messages = List<ConversationMessageSummary>.of(state.messages);
      messages[index] = messages[index].copyWith(isDeleted: true);
      state = state.copyWith(messages: messages);
      _persistSession();
      unawaited(
        ref.read(conversationRepositoryProvider).removeStoredMessage(
              target,
              messageId: deleted.id,
            ),
      );
    }
  }

  void _handleMessagePinToggled(
    Object payload,
    ConversationDetailTarget target, {
    required bool isPinned,
  }) {
    final pinned = tryParseMessagePinnedPayload(payload, isPinned: isPinned);
    if (pinned == null || pinned.channelId != target.conversationId) {
      return;
    }

    if (state.status != ConversationDetailStatus.success) {
      return;
    }

    _togglePinLocally(pinned.id, isPinned: pinned.isPinned);
    _persistSession();
    if (pinned.isPinned) {
      _syncPinnedListAdd(pinned.id);
    } else {
      _syncPinnedListRemove(pinned.id);
    }
  }

  Future<void> _refreshFromCache(ConversationDetailTarget target) async {
    if (state.status != ConversationDetailStatus.success) {
      return;
    }

    final afterSeq = _maxSeq(state.messages);
    if (afterSeq == null) {
      return;
    }

    try {
      final page =
          await ref.read(conversationRepositoryProvider).loadNewerMessages(
                target,
                afterSeq: afterSeq,
              );
      if (ref.read(currentConversationDetailTargetProvider) != target ||
          state.status != ConversationDetailStatus.success) {
        return;
      }
      if (page.messages.isEmpty) {
        return;
      }
      state = state.copyWith(
        messages: _appendDedupedMessages(state.messages, page.messages),
        hasNewer: page.hasNewer,
      );
      _persistSession();
    } on AppFailure {
      // Fail-soft: keep cached window as-is.
    } on StateError {
      // Provider container was disposed while refresh was pending.
    }
  }
}
