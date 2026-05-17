import 'dart:async';

import 'package:dio/dio.dart';
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
  final Map<String, Timer> _sendTimeoutTimers = {};
  final Map<String, CancelToken> _sendCancelTokens = {};
  final RequestCoordinator _coordinator = RequestCoordinator();

  /// Maximum duration a message can stay in [MessageSendStatus.sending]
  /// before being auto-transitioned to queued via the outbox.
  static const sendTimeoutDuration = Duration(seconds: 30);

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

  void updateDraft(String value) {
    state = state.copyWith(
      draft: value,
      clearSendFailure: true,
    );
  }

  void setReplyTo(ConversationMessageSummary message) {
    state = state.copyWith(replyToMessage: message);
  }

  void clearReplyTo() {
    state = state.copyWith(clearReplyToMessage: true);
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
    final replyToId = state.replyToMessage?.id;
    final pendingFiles =
        state.pendingAttachments.isNotEmpty ? state.pendingAttachments : null;
    if (state.status != ConversationDetailStatus.success ||
        (content.isEmpty && (pendingFiles == null || pendingFiles.isEmpty))) {
      return;
    }

    // Offline path: queue text-only messages in the outbox for later sending.
    // Attachment uploads are not supported offline.
    final connectivity = ref.read(connectivityServiceProvider);
    if (!connectivity.isOnline &&
        (pendingFiles == null || pendingFiles.isEmpty)) {
      final localId =
          'pending-${++_localIdCounter}-${DateTime.now().millisecondsSinceEpoch}';
      final pending = PendingMessage(
        localId: localId,
        content: content,
        createdAt: DateTime.now(),
        replyToId: replyToId,
        status: MessageSendStatus.queued,
      );

      // Optimistic insert with queued status — user sees it's waiting.
      state = state.copyWith(
        pendingMessages: [...state.pendingMessages, pending],
        draft: '',
        clearSendFailure: true,
      );

      // Update Home sidebar preview to "未发送，点击重试" for queued messages
      // (PM groups queued+failed under the same semantic preview).
      _updateHomeSidebarPreview(
        target: target,
        content: content,
        localId: localId,
        sendState: MessageSendState.failed,
      );

      // Enqueue in the outbox for later drain.
      // Use the same localId so the drain callback can find the
      // pending message and reconcile the conversation state.
      ref.read(outboxStoreProvider.notifier).enqueue(
            target,
            content,
            replyToId: replyToId,
            localId: localId,
          );
      _persistSession();
      return;
    }

    // Generate local ID and create pending message for optimistic insert
    final localId =
        'pending-${++_localIdCounter}-${DateTime.now().millisecondsSinceEpoch}';
    final pending = PendingMessage(
      localId: localId,
      content: content,
      createdAt: DateTime.now(),
      replyToId: replyToId,
    );

    // Optimistic insert: show message immediately, clear draft.
    // Keep pendingAttachments visible during upload so UI can overlay progress.
    // Keep replyToMessage until send succeeds — failure should preserve it.
    state = state.copyWith(
      pendingMessages: [...state.pendingMessages, pending],
      draft: '',
      clearSendFailure: true,
    );

    // Update Home sidebar preview to "正在发送..." so the user sees
    // the in-flight state when navigating back to the home screen.
    _updateHomeSidebarPreview(
      target: target,
      content: content,
      localId: localId,
      sendState: MessageSendState.sending,
    );

    // Start send timeout. If the send takes longer than sendTimeoutDuration,
    // auto-transition to queued and enqueue in the outbox.
    // Create a CancelToken so the timeout can cancel the in-flight request.
    final sendCancelToken = CancelToken();
    _sendCancelTokens[localId] = sendCancelToken;
    if (pendingFiles == null || pendingFiles.isEmpty) {
      _startSendTimeout(localId, target, content, replyToId: replyToId);
    }

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
        replyToId: replyToId,
        cancelToken: sendCancelToken,
      );
      if (ref.read(currentConversationDetailTargetProvider) != target) {
        return;
      }

      // Success: cancel timeout, remove from outbox (handles late-success
      // after timeout race), transition to sent, clear reply preview.
      _cancelSendTimeout(localId);
      _sendCancelTokens.remove(localId);
      ref.read(outboxStoreProvider.notifier).removeItem(target, localId);
      state = state.copyWith(
        pendingMessages: state.pendingMessages.map((m) {
          if (m.localId == localId) {
            return m.copyWith(
                status: MessageSendStatus.sent, clearFailure: true);
          }
          return m;
        }).toList(),
        clearSendFailure: true,
        clearReplyToMessage: true,
      );
      _persistSession();

      // After delay, remove sent indicator and add canonical message
      _scheduleSentRemoval(localId, target, confirmedMessage: message);
    } on AppFailure catch (failure) {
      if (ref.read(currentConversationDetailTargetProvider) != target) {
        return;
      }
      _cancelSendTimeout(localId);
      _sendCancelTokens.remove(localId);

      // CancelledFailure means the send timeout cancelled the in-flight
      // request. The timeout handler already transitioned to .queued and
      // enqueued in the outbox — skip the failure transition.
      if (failure is CancelledFailure) return;

      if (failure.isRetryable &&
          (pendingFiles == null || pendingFiles.isEmpty)) {
        // Retryable failure on text-only message: hand off to the outbox
        // for automatic retry on reconnect.
        ref.read(outboxStoreProvider.notifier).enqueue(
              target,
              content,
              replyToId: replyToId,
              localId: localId,
            );
        // Transition visible UI to queued so the user sees the real state.
        state = state.copyWith(
          pendingMessages: state.pendingMessages.map((m) {
            if (m.localId == localId) {
              return m.copyWith(status: MessageSendStatus.queued);
            }
            return m;
          }).toList(),
        );
        _persistSession();

        // Update Home sidebar to "未发送，点击重试" — PM groups
        // queued+failed under the same semantic preview.
        _updateHomeSidebarPreview(
          target: target,
          content: content,
          localId: localId,
          sendState: MessageSendState.failed,
        );
      } else {
        // Non-retryable or has attachments: mark as failed for manual retry.
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

        // Update Home sidebar preview to "未发送，点击重试" so the user
        // sees the failure state on the home screen.
        _updateHomeSidebarPreview(
          target: target,
          content: content,
          localId: localId,
          sendState: MessageSendState.failed,
        );
      }
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

    // Update Home sidebar preview back to "正在发送..." on retry.
    _updateHomeSidebarPreview(
      target: target,
      content: pending.content,
      localId: localId,
      sendState: MessageSendState.sending,
    );

    // Start send timeout (same as send()) for text-only retries.
    // Create a CancelToken so the timeout can cancel the in-flight request.
    final sendCancelToken = CancelToken();
    _sendCancelTokens[localId] = sendCancelToken;
    if (pending.attachmentIds == null || pending.attachmentIds!.isEmpty) {
      _startSendTimeout(
        localId,
        target,
        pending.content,
        replyToId: pending.replyToId,
      );
    }

    try {
      final repo = ref.read(conversationRepositoryProvider);
      final message = await repo.sendMessage(
        target,
        pending.content,
        attachmentIds: pending.attachmentIds,
        replyToId: pending.replyToId,
        cancelToken: sendCancelToken,
      );
      if (ref.read(currentConversationDetailTargetProvider) != target) {
        return;
      }

      // Success: cancel timeout, remove from outbox (handles late-success
      // after timeout race), transition to sent.
      _cancelSendTimeout(localId);
      _sendCancelTokens.remove(localId);
      ref.read(outboxStoreProvider.notifier).removeItem(target, localId);
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
      _cancelSendTimeout(localId);
      _sendCancelTokens.remove(localId);

      // CancelledFailure means the send timeout cancelled the in-flight
      // request. The timeout handler already transitioned to .queued and
      // enqueued in the outbox — skip the failure transition.
      if (failure is CancelledFailure) return;

      if (failure.isRetryable &&
          (pending.attachmentIds == null || pending.attachmentIds!.isEmpty)) {
        // Retryable failure: hand off to outbox for automatic retry.
        ref.read(outboxStoreProvider.notifier).enqueue(
              target,
              pending.content,
              replyToId: pending.replyToId,
              localId: localId,
            );
        state = state.copyWith(
          pendingMessages: state.pendingMessages.map((m) {
            if (m.localId == localId) {
              return m.copyWith(status: MessageSendStatus.queued);
            }
            return m;
          }).toList(),
        );
        _persistSession();

        // Update Home sidebar to "未发送，点击重试" — PM groups
        // queued+failed under the same semantic preview.
        _updateHomeSidebarPreview(
          target: target,
          content: pending.content,
          localId: localId,
          sendState: MessageSendState.failed,
        );
      } else {
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

        // Update Home sidebar preview to "未发送，点击重试" on retry failure.
        _updateHomeSidebarPreview(
          target: target,
          content: pending.content,
          localId: localId,
          sendState: MessageSendState.failed,
        );
      }
    }
  }

  /// Remove a failed or queued pending message without retrying.
  void dismissPendingMessage(String localId) {
    final target = ref.read(currentConversationDetailTargetProvider);
    state = state.copyWith(
      pendingMessages:
          state.pendingMessages.where((m) => m.localId != localId).toList(),
    );
    // Also remove from the outbox to prevent phantom sends.
    ref.read(outboxStoreProvider.notifier).removeItem(target, localId);
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

  // ---------- Multi-select mode (#537) ----------

  /// Enters selection mode with [firstMessageId] auto-selected.
  void enterSelectionMode(String firstMessageId) {
    if (state.status != ConversationDetailStatus.success) return;
    state = state.copyWith(
      isSelectionMode: true,
      selectedMessageIds: {firstMessageId},
    );
  }

  /// Exits selection mode and clears all selections.
  void exitSelectionMode() {
    state = state.copyWith(
      isSelectionMode: false,
      selectedMessageIds: const {},
    );
  }

  /// Toggles whether [messageId] is in the current selection set.
  void toggleMessageSelection(String messageId) {
    if (!state.isSelectionMode) return;
    final updated = Set<String>.of(state.selectedMessageIds);
    if (updated.contains(messageId)) {
      updated.remove(messageId);
    } else {
      updated.add(messageId);
    }
    state = state.copyWith(selectedMessageIds: updated);
  }

  /// Batch-deletes all selected messages and exits selection mode.
  Future<void> batchDeleteMessages(Set<String> ids) async {
    final target = ref.read(currentConversationDetailTargetProvider);
    if (state.status != ConversationDetailStatus.success) return;

    // Optimistic: mark all selected messages as deleted.
    final messages = List<ConversationMessageSummary>.of(state.messages);
    for (final id in ids) {
      final index = messages.indexWhere((m) => m.id == id);
      if (index != -1) {
        messages[index] = messages[index].copyWith(isDeleted: true);
      }
    }
    state = state.copyWith(
      messages: messages,
      isSelectionMode: false,
      selectedMessageIds: const {},
    );

    // Fire delete requests (best-effort, no rollback on partial failure).
    final repo = ref.read(conversationRepositoryProvider);
    for (final id in ids) {
      try {
        await repo.deleteMessage(target, messageId: id);
      } on AppFailure {
        // Individual message delete failure is silently tolerated in batch.
      }
    }
    _persistSession();
  }

  /// Batch-saves all selected messages and exits selection mode.
  Future<void> batchSaveMessages(Set<String> ids) async {
    final target = ref.read(currentConversationDetailTargetProvider);
    if (state.status != ConversationDetailStatus.success) return;

    // Optimistic: add all selected message IDs to savedMessageIds.
    final previousSaved = state.savedMessageIds;
    final updatedSaved = Set<String>.of(previousSaved)..addAll(ids);
    state = state.copyWith(
      savedMessageIds: updatedSaved,
      isSelectionMode: false,
      selectedMessageIds: const {},
    );

    // Fire save requests (best-effort, no rollback on partial failure).
    final serverId = target.serverId;
    final repo = ref.read(savedMessagesRepositoryProvider);
    for (final id in ids) {
      try {
        await repo.saveMessage(serverId, id);
      } on AppFailure {
        // Individual message save failure is silently tolerated in batch.
      }
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

  /// Updates the Home sidebar preview to reflect an outgoing message's
  /// send state (sending / failed).
  ///
  /// Called from [send] and [retrySend] so the Home sidebar shows
  /// "正在发送..." or "未发送，点击重试" while a message is in-flight or
  /// has failed, making [MessageSendState] reachable in a production
  /// preview path.
  void _updateHomeSidebarPreview({
    required ConversationDetailTarget target,
    required String content,
    required String localId,
    required MessageSendState sendState,
  }) {
    final preview = MessagePreviewResolver.resolve(
      content: content,
      sendState: sendState,
    );
    final now = DateTime.now();
    final notifier = ref.read(homeListStoreProvider.notifier);
    switch (target.surface) {
      case ConversationSurface.channel:
        notifier.updateChannelLastMessage(
          conversationId: target.conversationId,
          messageId: localId,
          preview: preview,
          activityAt: now,
        );
        break;
      case ConversationSurface.directMessage:
        notifier.updateDmLastMessage(
          conversationId: target.conversationId,
          messageId: localId,
          preview: preview,
          activityAt: now,
        );
        break;
    }
  }

  /// Start a timeout timer for a sending message. If the send takes longer
  /// than [sendTimeoutDuration], cancel the in-flight request and enqueue
  /// the message in the outbox for automatic retry.
  void _startSendTimeout(
    String localId,
    ConversationDetailTarget target,
    String content, {
    String? replyToId,
  }) {
    _sendTimeoutTimers[localId] = Timer(sendTimeoutDuration, () {
      _sendTimeoutTimers.remove(localId);
      // Only act if the pending message is still in sending state.
      final pending =
          state.pendingMessages.where((m) => m.localId == localId).firstOrNull;
      if (pending == null || pending.status != MessageSendStatus.sending) {
        return;
      }
      // Cancel the in-flight request BEFORE enqueuing in the outbox.
      // This prevents the race where both the original request and
      // the outbox drain send the same message simultaneously.
      final cancelToken = _sendCancelTokens.remove(localId);
      if (cancelToken != null && !cancelToken.isCancelled) {
        cancelToken.cancel('Send timeout');
      }
      // Enqueue in outbox and transition to queued.
      ref.read(outboxStoreProvider.notifier).enqueue(
            target,
            content,
            replyToId: replyToId,
            localId: localId,
          );
      state = state.copyWith(
        pendingMessages: state.pendingMessages.map((m) {
          if (m.localId == localId) {
            return m.copyWith(status: MessageSendStatus.queued);
          }
          return m;
        }).toList(),
      );
      _persistSession();

      // Update Home sidebar to "未发送，点击重试" — PM groups
      // queued+failed under the same semantic preview.
      _updateHomeSidebarPreview(
        target: target,
        content: content,
        localId: localId,
        sendState: MessageSendState.failed,
      );
    });
  }

  /// Cancel a send timeout timer (called on success or explicit failure).
  void _cancelSendTimeout(String localId) {
    _sendTimeoutTimers.remove(localId)?.cancel();
  }

  /// Callback invoked by the [OutboxStore] when a queued message is
  /// successfully sent or fails with a non-retryable error.
  ///
  /// Reconciles the optimistic pending message in the conversation state.
  void _onOutboxDrain(
    ConversationDetailTarget target,
    String localId,
    ConversationMessageSummary? serverMessage,
    AppFailure? failure,
  ) {
    // Only reconcile if this store is still active for the same target.
    final currentTarget = ref.read(currentConversationDetailTargetProvider);
    if (currentTarget != target) return;

    final pendingMsg =
        state.pendingMessages.where((m) => m.localId == localId).firstOrNull;
    if (pendingMsg == null) return;

    // Skip if the original in-flight request already resolved this message
    // (late-success-after-timeout race). The success path already removed
    // the outbox entry, so this drain callback is a stale echo.
    if (pendingMsg.status == MessageSendStatus.sent) return;

    if (serverMessage != null) {
      // Success: transition to sent, then schedule removal + canonical insert.
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
      _scheduleSentRemoval(localId, target, confirmedMessage: serverMessage);
    } else if (failure != null) {
      // Non-retryable failure: mark as failed for user retry.
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

      // Update Home sidebar to "未发送，点击重试" on outbox drain failure.
      _updateHomeSidebarPreview(
        target: target,
        content: pendingMsg.content,
        localId: localId,
        sendState: MessageSendState.failed,
      );
    }
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
