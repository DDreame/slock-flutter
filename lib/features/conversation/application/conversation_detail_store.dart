import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_session_store.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/image_compressor.dart';
import 'package:slock_app/features/conversation/application/message_send_status.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/application/pinned_messages_store.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';
import 'package:slock_app/stores/session/session_store.dart';

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

class ConversationDetailStore
    extends AutoDisposeNotifier<ConversationDetailState> {
  int _requestEpoch = 0;
  int _localIdCounter = 0;
  final Set<Timer> _sentRemovalTimers = {};
  final Map<int, CancelToken> _uploadCancelTokens = {};

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
    ref.onDispose(() {
      unawaited(subscription.cancel());
      for (final timer in _sentRemovalTimers) {
        timer.cancel();
      }
      _sentRemovalTimers.clear();
    });
    final initialState = cachedSession?.toState(target) ??
        ConversationDetailState(target: target);
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

    state = state.copyWith(
      target: target,
      status: ConversationDetailStatus.loading,
      messages: const [],
      historyLimited: false,
      hasOlder: false,
      hasNewer: false,
      clearFailure: true,
      clearSendFailure: true,
    );

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
        memberCount: snapshot.memberCount,
        messages: snapshot.messages,
        historyLimited: snapshot.historyLimited,
        hasOlder: snapshot.hasOlder,
        clearFailure: true,
        clearSendFailure: true,
      );
      _persistSession();
      unawaited(refreshSavedMessageIds());
    } on AppFailure catch (failure) {
      if (!_isCurrentRequest(requestEpoch, target)) {
        return;
      }
      state = state.copyWith(
        target: target,
        status: ConversationDetailStatus.failure,
        title: target.defaultTitle,
        messages: const [],
        historyLimited: false,
        hasOlder: false,
        failure: failure,
        clearSendFailure: true,
      );
    }
  }

  Future<void> retry() => load();

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

  void updateDraft(String value) {
    state = state.copyWith(
      draft: value,
      clearSendFailure: true,
    );
  }

  void addPendingAttachment(PendingAttachment attachment) {
    state = state.copyWith(
      pendingAttachments: [...state.pendingAttachments, attachment],
      clearSendFailure: true,
    );
  }

  void removePendingAttachment(int index) {
    if (index < 0 || index >= state.pendingAttachments.length) {
      return;
    }
    final updated = List<PendingAttachment>.of(state.pendingAttachments)
      ..removeAt(index);
    state = state.copyWith(pendingAttachments: updated);
  }

  /// Cancel an in-flight upload by attachment index.
  void cancelUpload(int index) {
    final token = _uploadCancelTokens[index];
    if (token != null && !token.isCancelled) {
      token.cancel('User cancelled upload');
    }
  }

  Future<void> send() async {
    final target = ref.read(currentConversationDetailTargetProvider);
    final content = state.draft.trim();
    final pendingFiles =
        state.pendingAttachments.isNotEmpty ? state.pendingAttachments : null;
    if (state.status != ConversationDetailStatus.success ||
        (content.isEmpty && (pendingFiles == null || pendingFiles.isEmpty))) {
      return;
    }

    // Generate local ID and create pending message for optimistic insert
    final localId =
        'pending-${++_localIdCounter}-${DateTime.now().millisecondsSinceEpoch}';
    final pending = PendingMessage(
      localId: localId,
      content: content,
      createdAt: DateTime.now(),
    );

    // Optimistic insert: show message immediately, clear draft.
    // Keep pendingAttachments visible during upload so UI can overlay progress.
    state = state.copyWith(
      pendingMessages: [...state.pendingMessages, pending],
      draft: '',
      clearSendFailure: true,
    );

    try {
      final repo = ref.read(conversationRepositoryProvider);

      List<String>? attachmentIds;
      if (pendingFiles != null) {
        attachmentIds = <String>[];
        final compressor = ref.read(imageCompressorProvider);

        for (var i = 0; i < pendingFiles.length; i++) {
          final file = pendingFiles[i];
          final cancelToken = CancelToken();
          _uploadCancelTokens[i] = cancelToken;

          try {
            // Compress image if applicable and large
            var uploadFile = file;
            if (compressor.isCompressibleImage(file.mimeType)) {
              try {
                final size = await compressor.getFileSize(file.path);
                if (size > DefaultImageCompressor.compressionThresholdBytes) {
                  final compressed = await compressor.compress(file.path);
                  uploadFile = PendingAttachment(
                    path: compressed,
                    name: file.name,
                    mimeType: file.mimeType,
                  );
                }
              } catch (_) {
                // Fall back to original on compression failure
              }
            }

            // Update progress state
            state = state.copyWith(
              uploadProgress: {...state.uploadProgress, i: 0.0},
            );

            final id = await repo.uploadAttachment(
              target,
              uploadFile,
              onSendProgress: (sent, total) {
                if (total > 0) {
                  state = state.copyWith(
                    uploadProgress: {
                      ...state.uploadProgress,
                      i: sent / total,
                    },
                  );
                }
              },
              cancelToken: cancelToken,
            );
            attachmentIds.add(id);
          } on DioException catch (e) {
            if (e.type == DioExceptionType.cancel) {
              // Cancelled by user — skip this attachment
            } else {
              // Other Dio error — skip
            }
          } on AppFailure {
            // Skip failed uploads
          } finally {
            _uploadCancelTokens.remove(i);
          }
        }

        // Clear upload progress and pending attachments after all uploads
        state = state.copyWith(
          uploadProgress: const {},
          pendingAttachments: const [],
        );

        if (attachmentIds.isEmpty && content.isEmpty) {
          throw const UnknownFailure(
            message: 'All attachment uploads failed.',
            causeType: 'uploadFailure',
          );
        }
      }

      // Update pending with uploaded attachment IDs so retry preserves them
      if (attachmentIds != null && attachmentIds.isNotEmpty) {
        state = state.copyWith(
          pendingMessages: state.pendingMessages.map((m) {
            if (m.localId == localId) {
              return m.copyWith(attachmentIds: attachmentIds);
            }
            return m;
          }).toList(),
        );
      }

      final message = await repo.sendMessage(
        target,
        content,
        attachmentIds: attachmentIds,
      );
      if (ref.read(currentConversationDetailTargetProvider) != target) {
        return;
      }

      // Success: transition to sent (do NOT add canonical to messages yet)
      state = state.copyWith(
        pendingMessages: state.pendingMessages.map((m) {
          if (m.localId == localId) {
            return m.copyWith(
                status: MessageSendStatus.sent, clearFailure: true);
          }
          return m;
        }).toList(),
        clearSendFailure: true,
      );
      _persistSession();

      // After delay, remove sent indicator and add canonical message
      _scheduleSentRemoval(localId, target, confirmedMessage: message);
    } on AppFailure catch (failure) {
      if (ref.read(currentConversationDetailTargetProvider) != target) {
        return;
      }
      // Failure: update pending message status to failed
      state = state.copyWith(
        pendingMessages: state.pendingMessages.map((m) {
          if (m.localId == localId) {
            return m.copyWith(
              status: MessageSendStatus.failed,
              failure: failure,
            );
          }
          return m;
        }).toList(),
      );
      _persistSession();
    }
  }

  /// Retry sending a previously failed pending message.
  Future<void> retrySend(String localId) async {
    final target = ref.read(currentConversationDetailTargetProvider);
    final pending =
        state.pendingMessages.where((m) => m.localId == localId).firstOrNull;
    if (pending == null || pending.status != MessageSendStatus.failed) {
      return;
    }

    // Transition to sending
    state = state.copyWith(
      pendingMessages: state.pendingMessages.map((m) {
        if (m.localId == localId) {
          return m.copyWith(
            status: MessageSendStatus.sending,
            clearFailure: true,
          );
        }
        return m;
      }).toList(),
    );

    try {
      final repo = ref.read(conversationRepositoryProvider);
      final message = await repo.sendMessage(
        target,
        pending.content,
        attachmentIds: pending.attachmentIds,
      );
      if (ref.read(currentConversationDetailTargetProvider) != target) {
        return;
      }

      // Success: transition to sent (do NOT add canonical to messages yet)
      state = state.copyWith(
        pendingMessages: state.pendingMessages.map((m) {
          if (m.localId == localId) {
            return m.copyWith(
                status: MessageSendStatus.sent, clearFailure: true);
          }
          return m;
        }).toList(),
      );
      _persistSession();

      // After delay, remove sent indicator and add canonical message
      _scheduleSentRemoval(localId, target, confirmedMessage: message);
    } on AppFailure catch (failure) {
      if (ref.read(currentConversationDetailTargetProvider) != target) {
        return;
      }
      state = state.copyWith(
        pendingMessages: state.pendingMessages.map((m) {
          if (m.localId == localId) {
            return m.copyWith(
              status: MessageSendStatus.failed,
              failure: failure,
            );
          }
          return m;
        }).toList(),
      );
    }
  }

  /// Remove a failed pending message without retrying.
  void dismissPendingMessage(String localId) {
    state = state.copyWith(
      pendingMessages:
          state.pendingMessages.where((m) => m.localId != localId).toList(),
    );
    _persistSession();
  }

  void updateViewportOffset(double offset) {
    ref
        .read(conversationDetailSessionStoreProvider.notifier)
        .saveScrollOffset(state.target, offset);
  }

  void toggleSearch() {
    if (state.isSearchActive) {
      state = state.copyWith(
        isSearchActive: false,
        searchQuery: '',
        searchMatchIds: const [],
        currentSearchMatchIndex: -1,
      );
    } else {
      state = state.copyWith(isSearchActive: true);
    }
  }

  void updateSearchQuery(String query) {
    if (query.isEmpty) {
      state = state.copyWith(
        searchQuery: '',
        searchMatchIds: const [],
        currentSearchMatchIndex: -1,
      );
      return;
    }

    final lowerQuery = query.toLowerCase();
    final matchIds = state.messages
        .where((m) => m.content.toLowerCase().contains(lowerQuery))
        .map((m) => m.id)
        .toList(growable: false);
    state = state.copyWith(
      searchQuery: query,
      searchMatchIds: matchIds,
      currentSearchMatchIndex: matchIds.isEmpty ? -1 : 0,
    );
  }

  void nextSearchResult() {
    if (state.searchMatchIds.isEmpty) return;
    final next =
        (state.currentSearchMatchIndex + 1) % state.searchMatchIds.length;
    state = state.copyWith(currentSearchMatchIndex: next);
  }

  void previousSearchResult() {
    if (state.searchMatchIds.isEmpty) return;
    final prev =
        (state.currentSearchMatchIndex - 1 + state.searchMatchIds.length) %
            state.searchMatchIds.length;
    state = state.copyWith(currentSearchMatchIndex: prev);
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

  bool _isCurrentRequest(
    int requestEpoch,
    ConversationDetailTarget target,
  ) {
    return requestEpoch == _requestEpoch &&
        ref.read(currentConversationDetailTargetProvider) == target;
  }

  List<ConversationMessageSummary> _appendDedupedMessage(
    List<ConversationMessageSummary> existing,
    ConversationMessageSummary next,
  ) {
    if (existing.any((message) => message.id == next.id)) {
      return existing;
    }
    return [...existing, next];
  }

  List<ConversationMessageSummary> _prependDedupedMessages(
    List<ConversationMessageSummary> existing,
    List<ConversationMessageSummary> olderMessages,
  ) {
    final existingIds = existing.map((message) => message.id).toSet();
    final dedupedOlder = olderMessages
        .where((message) => !existingIds.contains(message.id))
        .toList(growable: false);
    if (dedupedOlder.isEmpty) {
      return existing;
    }
    return [...dedupedOlder, ...existing];
  }

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
      final persisted =
          await ref.read(conversationRepositoryProvider).persistMessage(
                target,
                message: incoming.message,
                senderId: incoming.senderId,
              );
      if (ref.read(currentConversationDetailTargetProvider) != target ||
          state.status != ConversationDetailStatus.success) {
        return;
      }
      state = state.copyWith(
        messages: _appendDedupedMessage(state.messages, persisted),
      );
      _persistSession();

      if (gapDetected) {
        await _recoverGap(target, afterSeq: prevMaxSeq);
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

  List<ConversationMessageSummary> _appendDedupedMessages(
    List<ConversationMessageSummary> existing,
    List<ConversationMessageSummary> newerMessages,
  ) {
    final existingIds = existing.map((message) => message.id).toSet();
    final dedupedNewer = newerMessages
        .where((message) => !existingIds.contains(message.id))
        .toList(growable: false);
    if (dedupedNewer.isEmpty) {
      return existing;
    }
    return [...existing, ...dedupedNewer];
  }

  /// Duration the "sent" indicator remains visible before removal.
  static const sentIndicatorDuration = Duration(seconds: 2);

  void _scheduleSentRemoval(
    String localId,
    ConversationDetailTarget target, {
    ConversationMessageSummary? confirmedMessage,
  }) {
    late final Timer timer;
    timer = Timer(sentIndicatorDuration, () {
      _sentRemovalTimers.remove(timer);
      if (ref.read(currentConversationDetailTargetProvider) != target) {
        return;
      }
      state = state.copyWith(
        messages: confirmedMessage != null
            ? _appendDedupedMessage(state.messages, confirmedMessage)
            : state.messages,
        pendingMessages:
            state.pendingMessages.where((m) => m.localId != localId).toList(),
      );
      _persistSession();
    });
    _sentRemovalTimers.add(timer);
  }

  Future<void> addReaction(String messageId, String emoji) async {
    final target = ref.read(currentConversationDetailTargetProvider);
    if (state.status != ConversationDetailStatus.success) return;

    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final currentUserId = ref.read(sessionStoreProvider).userId;
    if (currentUserId == null) return;

    final previousMessages = state.messages;
    final messages = List<ConversationMessageSummary>.of(state.messages);
    messages[index] = _addReactionToMessage(
      messages[index],
      emoji: emoji,
      userId: currentUserId,
    );
    state = state.copyWith(messages: messages);
    _persistSession();

    try {
      final repo = ref.read(conversationRepositoryProvider);
      await repo.addReaction(target, messageId: messageId, emoji: emoji);
    } on AppFailure {
      if (ref.read(currentConversationDetailTargetProvider) != target) return;
      state = state.copyWith(messages: previousMessages);
      _persistSession();
      rethrow;
    }
  }

  Future<void> removeReaction(String messageId, String emoji) async {
    final target = ref.read(currentConversationDetailTargetProvider);
    if (state.status != ConversationDetailStatus.success) return;

    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final currentUserId = ref.read(sessionStoreProvider).userId;
    if (currentUserId == null) return;

    final previousMessages = state.messages;
    final messages = List<ConversationMessageSummary>.of(state.messages);
    messages[index] = _removeReactionFromMessage(
      messages[index],
      emoji: emoji,
      userId: currentUserId,
    );
    state = state.copyWith(messages: messages);
    _persistSession();

    try {
      final repo = ref.read(conversationRepositoryProvider);
      await repo.removeReaction(target, messageId: messageId, emoji: emoji);
    } on AppFailure {
      if (ref.read(currentConversationDetailTargetProvider) != target) return;
      state = state.copyWith(messages: previousMessages);
      _persistSession();
      rethrow;
    }
  }

  /// Toggles a reaction for the current user — adds if not yet reacted,
  /// removes if already reacted.
  Future<void> toggleReaction(String messageId, String emoji) async {
    if (state.status != ConversationDetailStatus.success) return;

    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final currentUserId = ref.read(sessionStoreProvider).userId;
    if (currentUserId == null) return;

    final message = state.messages[index];
    final existingReaction =
        message.reactions.where((r) => r.emoji == emoji).firstOrNull;
    final alreadyReacted = existingReaction != null &&
        existingReaction.reactedByUser(currentUserId);

    if (alreadyReacted) {
      await removeReaction(messageId, emoji);
    } else {
      await addReaction(messageId, emoji);
    }
  }

  void _handleReactionAdded(Object payload, ConversationDetailTarget target) {
    final event = tryParseReactionEventPayload(payload);
    if (event == null || event.channelId != target.conversationId) {
      return;
    }

    if (state.status != ConversationDetailStatus.success) {
      return;
    }

    final index = state.messages.indexWhere((m) => m.id == event.messageId);
    if (index == -1) return;

    final messages = List<ConversationMessageSummary>.of(state.messages);
    messages[index] = _addReactionToMessage(
      messages[index],
      emoji: event.emoji,
      userId: event.userId,
    );
    state = state.copyWith(messages: messages);
    _persistSession();
  }

  void _handleReactionRemoved(
    Object payload,
    ConversationDetailTarget target,
  ) {
    final event = tryParseReactionEventPayload(payload);
    if (event == null || event.channelId != target.conversationId) {
      return;
    }

    if (state.status != ConversationDetailStatus.success) {
      return;
    }

    final index = state.messages.indexWhere((m) => m.id == event.messageId);
    if (index == -1) return;

    final messages = List<ConversationMessageSummary>.of(state.messages);
    messages[index] = _removeReactionFromMessage(
      messages[index],
      emoji: event.emoji,
      userId: event.userId,
    );
    state = state.copyWith(messages: messages);
    _persistSession();
  }

  ConversationMessageSummary _addReactionToMessage(
    ConversationMessageSummary message, {
    required String emoji,
    required String userId,
  }) {
    final reactions = List<MessageReaction>.of(message.reactions);
    final existingIndex = reactions.indexWhere((r) => r.emoji == emoji);
    if (existingIndex != -1) {
      final existing = reactions[existingIndex];
      if (existing.userIds.contains(userId)) return message;
      reactions[existingIndex] = MessageReaction(
        emoji: emoji,
        count: existing.count + 1,
        userIds: [...existing.userIds, userId],
      );
    } else {
      reactions.add(MessageReaction(
        emoji: emoji,
        count: 1,
        userIds: [userId],
      ));
    }
    return message.copyWith(reactions: reactions);
  }

  ConversationMessageSummary _removeReactionFromMessage(
    ConversationMessageSummary message, {
    required String emoji,
    required String userId,
  }) {
    final reactions = List<MessageReaction>.of(message.reactions);
    final existingIndex = reactions.indexWhere((r) => r.emoji == emoji);
    if (existingIndex == -1) return message;
    final existing = reactions[existingIndex];
    if (!existing.userIds.contains(userId)) return message;
    if (existing.count <= 1) {
      reactions.removeAt(existingIndex);
    } else {
      reactions[existingIndex] = MessageReaction(
        emoji: emoji,
        count: existing.count - 1,
        userIds: existing.userIds.where((id) => id != userId).toList(),
      );
    }
    return message.copyWith(reactions: reactions);
  }

  void _persistSession() {
    ref.read(conversationDetailSessionStoreProvider.notifier).saveSuccessState(
          state,
          scrollOffset: ref
                  .read(conversationDetailSessionStoreProvider)[state.target]
                  ?.scrollOffset ??
              0,
        );
  }
}
