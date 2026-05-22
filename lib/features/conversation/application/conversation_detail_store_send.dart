part of 'conversation_detail_store.dart';

/// Send/outbox-related methods for [ConversationDetailStore].
///
/// Extracted from the monolithic store to improve readability (#640).
mixin _ConversationDetailSendMixin on _ConversationDetailCoreMixin {
  int _localIdCounter = 0;
  final Set<Timer> _sentRemovalTimers = {};
  final Map<int, CancelToken> _uploadCancelTokens = {};
  final Map<String, Timer> _sendTimeoutTimers = {};
  final Map<String, CancelToken> _sendCancelTokens = {};

  /// Guard flag: set true in onDispose, checked by Timer callbacks to
  /// prevent StateError from ref.read after provider disposal (#716).
  bool _sendMixinDisposed = false;

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
    _startSendTimeout(localId, target, content,
        replyToId: replyToId,
        hasAttachments: pendingFiles != null && pendingFiles.isNotEmpty);

    // Persist session after optimistic insert so pending messages survive
    // navigation-away / provider disposal (#763).
    _persistSession();

    var failedUploadCount = 0;
    var totalAttachmentCount = 0;
    try {
      final repo = ref.read(conversationRepositoryProvider);

      List<String>? attachmentIds;
      if (pendingFiles != null) {
        attachmentIds = <String>[];
        totalAttachmentCount = pendingFiles.length;
        final compressor = ref.read(imageCompressorProvider);

        for (var i = 0; i < pendingFiles.length; i++) {
          final file = pendingFiles[i];
          final cancelToken = CancelToken();
          _uploadCancelTokens[i] = cancelToken;

          String? compressedPathToDelete;
          try {
            // Compress image if applicable and large
            var uploadFile = file;
            if (compressor.isCompressibleImage(file.mimeType)) {
              try {
                final size = await compressor.getFileSize(file.path);
                if (size > DefaultImageCompressor.compressionThresholdBytes) {
                  final compressed = await compressor.compress(file.path);
                  if (compressed != file.path) {
                    compressedPathToDelete = compressed;
                  }
                  uploadFile = PendingAttachment(
                    path: compressed,
                    name: file.name,
                    mimeType: file.mimeType,
                  );
                }
              } catch (e, st) {
                ref.read(diagnosticsCollectorProvider).error(
                  'conversation-send',
                  'Image compression failed, falling back to original: $e',
                  metadata: {'stackTrace': '$st'},
                );
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
          } on DioException catch (e, st) {
            if (e.type == DioExceptionType.cancel) {
              // Cancelled by user — skip this attachment
            } else {
              failedUploadCount++;
              ref.read(diagnosticsCollectorProvider).error(
                'conversation-send',
                'Attachment upload failed: ${e.message}',
                metadata: {
                  'attachmentIndex': '$i',
                  'attachmentName': file.name,
                  'dioType': '${e.type}',
                  'statusCode': '${e.response?.statusCode}',
                  'stackTrace': '$st',
                },
              );
            }
          } on AppFailure catch (e, st) {
            failedUploadCount++;
            ref.read(diagnosticsCollectorProvider).error(
              'conversation-send',
              'Attachment upload failed: ${e.message}',
              metadata: {
                'attachmentIndex': '$i',
                'attachmentName': file.name,
                'causeType': e.causeType ?? 'unknown',
                'stackTrace': '$st',
              },
            );
          } finally {
            _uploadCancelTokens.remove(i);
            final compressedPath = compressedPathToDelete;
            if (compressedPath != null) {
              try {
                await compressor.deleteCompressedFile(
                  originalPath: file.path,
                  compressedPath: compressedPath,
                );
              } catch (e, st) {
                ref.read(diagnosticsCollectorProvider).warning(
                  'conversation-send',
                  'Compressed image cleanup failed: $e',
                  metadata: {'stackTrace': '$st'},
                );
              }
            }
          }
        }

        // Clear upload progress and pending attachments after all uploads
        state = state.copyWith(
          uploadProgress: const {},
          pendingAttachments: const [],
        );

        if (attachmentIds.isEmpty && content.isEmpty) {
          throw UnknownFailure(
            message: failedUploadCount == 1
                ? '1 attachment failed to upload.'
                : '$failedUploadCount attachments failed to upload.',
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

      // Surface partial upload failure after clearing the send-level failure,
      // so the user sees which attachments were lost even though the message
      // itself sent successfully.
      if (failedUploadCount > 0) {
        state = state.copyWith(
          sendFailure: UnknownFailure(
            message: failedUploadCount == 1
                ? '1 attachment failed to upload.'
                : '$failedUploadCount of $totalAttachmentCount attachments '
                    'failed to upload.',
            causeType: 'partialUploadFailure',
          ),
        );
      }

      // After delay, remove sent indicator and add canonical message
      _scheduleSentRemoval(localId, target, confirmedMessage: message);
    } on AppFailure catch (failure) {
      if (ref.read(currentConversationDetailTargetProvider) != target) {
        return;
      }
      _cancelSendTimeout(localId);
      _sendCancelTokens.remove(localId);

      // CancelledFailure means the send timeout cancelled the in-flight
      // request. For text-only messages, the timeout handler already
      // transitioned to .queued — skip. For attachment messages, transition
      // to .failed so the user can retry manually (#763).
      if (failure is CancelledFailure) {
        if (pendingFiles != null && pendingFiles.isNotEmpty) {
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
          _updateHomeSidebarPreview(
            target: target,
            content: content,
            localId: localId,
            sendState: MessageSendState.failed,
          );
        }
        return;
      }

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
          // Surface partial upload loss alongside send failure so the user
          // knows which attachments were dropped before the send attempt.
          sendFailure: failedUploadCount > 0
              ? UnknownFailure(
                  message: failedUploadCount == 1
                      ? '1 attachment failed to upload.'
                      : '$failedUploadCount of $totalAttachmentCount '
                          'attachments failed to upload.',
                  causeType: 'partialUploadFailure',
                )
              : null,
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
    final retryHasAttachments =
        pending.attachmentIds != null && pending.attachmentIds!.isNotEmpty;
    _startSendTimeout(
      localId,
      target,
      pending.content,
      replyToId: pending.replyToId,
      hasAttachments: retryHasAttachments,
    );

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
      // request. For text-only messages, the timeout handler already
      // transitioned to .queued — skip. For attachment messages, transition
      // to .failed so the user can retry manually (#763).
      if (failure is CancelledFailure) {
        if (pending.attachmentIds != null &&
            pending.attachmentIds!.isNotEmpty) {
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
          _updateHomeSidebarPreview(
            target: target,
            content: pending.content,
            localId: localId,
            sendState: MessageSendState.failed,
          );
        }
        return;
      }

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

  void _scheduleSentRemoval(
    String localId,
    ConversationDetailTarget target, {
    ConversationMessageSummary? confirmedMessage,
  }) {
    late final Timer timer;
    timer = Timer(ConversationDetailStore.sentIndicatorDuration, () {
      _sentRemovalTimers.remove(timer);
      // Guard: if disposed, ref.read will throw StateError (#716).
      if (_sendMixinDisposed) return;
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
      l10n: ref.read(appLocalizationsProvider),
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
  ///
  /// [hasAttachments] is captured at call-site because `pending.attachmentIds`
  /// is only populated after uploads complete — the timer may fire while
  /// uploads are still in-flight (#763).
  void _startSendTimeout(
    String localId,
    ConversationDetailTarget target,
    String content, {
    String? replyToId,
    bool hasAttachments = false,
  }) {
    _sendTimeoutTimers[localId] =
        Timer(ConversationDetailStore.sendTimeoutDuration, () {
      _sendTimeoutTimers.remove(localId);
      // Only act if the pending message is still in sending state.
      final pending =
          state.pendingMessages.where((m) => m.localId == localId).firstOrNull;
      if (pending == null || pending.status != MessageSendStatus.sending) {
        return;
      }
      // Cancel the in-flight request BEFORE transitioning state.
      // This prevents the race where both the original request and
      // the outbox drain send the same message simultaneously.
      final cancelToken = _sendCancelTokens.remove(localId);
      if (cancelToken != null && !cancelToken.isCancelled) {
        cancelToken.cancel('Send timeout');
      }

      if (hasAttachments) {
        // Outbox does not support attachment re-upload — transition to
        // FAILED so the user sees the error and can manually retry (#763).
        state = state.copyWith(
          pendingMessages: state.pendingMessages.map((m) {
            if (m.localId == localId) {
              return m.copyWith(
                status: MessageSendStatus.failed,
                failure: const UnknownFailure(
                  message: 'Send timed out.',
                  causeType: 'SendTimeout',
                ),
              );
            }
            return m;
          }).toList(),
        );
      } else {
        // Text-only: enqueue in outbox for automatic retry.
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
      }
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
}
