import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/application/image_compressor.dart';
import 'package:slock_app/features/conversation/application/message_send_status.dart';
import 'package:slock_app/features/conversation/application/outbox_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

/// Tests for #763: Attachment Send Safety + retrySend cleanup.
///
/// Verifies:
/// 1. Attachment sends that time out transition to FAILED (not queued).
/// 2. Text-only sends still transition to queued on timeout (unchanged).
/// 3. CancelledFailure during attachment send → FAILED state.
/// 4. retrySend clears replyToMessage on success.
/// 5. CancelledFailure during attachment retrySend → FAILED state.
void main() {
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'channel-1',
    ),
  );

  group('Attachment send timeout (#763)', () {
    test('attachment send timeout transitions to FAILED (not queued)',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      fakeAsync((fake) {
        final connectivityCtrl =
            StreamController<ConnectivityStatus>.broadcast();
        final connectivity = ConnectivityService.withInitialStatus(
          ConnectivityStatus.online,
          controller: connectivityCtrl,
        );
        final repo = _ControllableConversationRepository();

        final container = ProviderContainer(
          overrides: [
            currentConversationDetailTargetProvider.overrideWithValue(target),
            conversationRepositoryProvider.overrideWithValue(repo),
            imageCompressorProvider
                .overrideWithValue(const _NoOpImageCompressor()),
            connectivityServiceProvider.overrideWithValue(connectivity),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        final sub =
            container.listen(conversationDetailStoreProvider, (_, __) {});

        container.read(conversationDetailStoreProvider.notifier).load();
        fake.flushMicrotasks();
        final store = container.read(conversationDetailStoreProvider.notifier);

        // Add attachment and draft, start send with never-completing future.
        store.addPendingAttachment(const PendingAttachment(
          path: '/tmp/photo.png',
          name: 'photo.png',
          mimeType: 'image/png',
        ));
        store.updateDraft('with attachment');
        repo.sendCompleter = Completer<ConversationMessageSummary>();
        store.send();
        fake.flushMicrotasks();

        // Verify it's in sending state with attachmentIds.
        final pending = container
            .read(conversationDetailStoreProvider)
            .pendingMessages
            .first;
        expect(pending.status, MessageSendStatus.sending);
        expect(pending.attachmentIds, isNotNull);
        expect(pending.attachmentIds, isNotEmpty);

        // Elapse the send timeout.
        fake.elapse(ConversationDetailStore.sendTimeoutDuration);
        fake.flushMicrotasks();

        // Must transition to FAILED (not queued) for attachment sends.
        final afterTimeout = container
            .read(conversationDetailStoreProvider)
            .pendingMessages
            .first;
        expect(
          afterTimeout.status,
          MessageSendStatus.failed,
          reason: 'Attachment sends must transition to FAILED on timeout '
              'because outbox does not support attachment re-upload',
        );
        expect(afterTimeout.failure, isNotNull);

        // Outbox must NOT have the message.
        final targetKey = outboxTargetKey(target);
        final outboxEntries =
            container.read(outboxStoreProvider).items[targetKey] ?? [];
        expect(
          outboxEntries,
          isEmpty,
          reason: 'Attachment messages must NOT be enqueued in outbox',
        );

        sub.close();
        container.dispose();
        connectivityCtrl.close();
        fake.flushMicrotasks();
      });
    });

    test('timeout during in-flight upload transitions to FAILED (not queued)',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      fakeAsync((fake) {
        final connectivityCtrl =
            StreamController<ConnectivityStatus>.broadcast();
        final connectivity = ConnectivityService.withInitialStatus(
          ConnectivityStatus.online,
          controller: connectivityCtrl,
        );
        final repo = _ControllableConversationRepository();
        // Keep upload in-flight — never completes until we say so.
        repo.uploadCompleter = Completer<String>();

        final container = ProviderContainer(
          overrides: [
            currentConversationDetailTargetProvider.overrideWithValue(target),
            conversationRepositoryProvider.overrideWithValue(repo),
            imageCompressorProvider
                .overrideWithValue(const _NoOpImageCompressor()),
            connectivityServiceProvider.overrideWithValue(connectivity),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        final sub =
            container.listen(conversationDetailStoreProvider, (_, __) {});

        container.read(conversationDetailStoreProvider.notifier).load();
        fake.flushMicrotasks();
        final store = container.read(conversationDetailStoreProvider.notifier);

        // Start send with attachment — upload will never complete.
        store.addPendingAttachment(const PendingAttachment(
          path: '/tmp/big-video.mp4',
          name: 'big-video.mp4',
          mimeType: 'video/mp4',
        ));
        store.updateDraft('slow upload');
        store.send();
        fake.flushMicrotasks();

        // Pending message is in sending state, attachmentIds still null
        // (upload hasn't completed).
        final pendingBefore = container
            .read(conversationDetailStoreProvider)
            .pendingMessages
            .first;
        expect(pendingBefore.status, MessageSendStatus.sending);
        expect(pendingBefore.attachmentIds, isNull,
            reason: 'Upload is still in-flight, no IDs yet');

        // Elapse the send timeout while upload is still in-flight.
        fake.elapse(ConversationDetailStore.sendTimeoutDuration);
        fake.flushMicrotasks();

        // Must transition to FAILED (not queued) because hasAttachments
        // flag was captured at call-site, not from pending.attachmentIds.
        final afterTimeout = container
            .read(conversationDetailStoreProvider)
            .pendingMessages
            .first;
        expect(
          afterTimeout.status,
          MessageSendStatus.failed,
          reason: 'Timeout during upload must transition to FAILED — '
              'hasAttachments flag captured before upload starts',
        );

        // Outbox must NOT have the message.
        final targetKey = outboxTargetKey(target);
        final outboxEntries =
            container.read(outboxStoreProvider).items[targetKey] ?? [];
        expect(
          outboxEntries,
          isEmpty,
          reason: 'Attachment messages must NOT be enqueued in outbox '
              'even when attachmentIds is still null on pending',
        );

        sub.close();
        container.dispose();
        connectivityCtrl.close();
        fake.flushMicrotasks();
      });
    });

    test('text-only send timeout still transitions to queued', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      fakeAsync((fake) {
        final connectivityCtrl =
            StreamController<ConnectivityStatus>.broadcast();
        final connectivity = ConnectivityService.withInitialStatus(
          ConnectivityStatus.online,
          controller: connectivityCtrl,
        );
        final repo = _ControllableConversationRepository();

        final container = ProviderContainer(
          overrides: [
            currentConversationDetailTargetProvider.overrideWithValue(target),
            conversationRepositoryProvider.overrideWithValue(repo),
            imageCompressorProvider
                .overrideWithValue(const _NoOpImageCompressor()),
            connectivityServiceProvider.overrideWithValue(connectivity),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        final sub =
            container.listen(conversationDetailStoreProvider, (_, __) {});

        container.read(conversationDetailStoreProvider.notifier).load();
        fake.flushMicrotasks();
        final store = container.read(conversationDetailStoreProvider.notifier);

        // Text-only send with never-completing future.
        store.updateDraft('text only');
        repo.sendCompleter = Completer<ConversationMessageSummary>();
        store.send();
        fake.flushMicrotasks();

        expect(
          container
              .read(conversationDetailStoreProvider)
              .pendingMessages
              .first
              .status,
          MessageSendStatus.sending,
        );

        // Elapse the send timeout.
        fake.elapse(ConversationDetailStore.sendTimeoutDuration);
        fake.flushMicrotasks();

        // Text-only: must transition to queued (unchanged behavior).
        expect(
          container
              .read(conversationDetailStoreProvider)
              .pendingMessages
              .first
              .status,
          MessageSendStatus.queued,
          reason:
              'Text-only sends should still transition to queued on timeout',
        );

        // Outbox MUST have the message.
        final targetKey = outboxTargetKey(target);
        expect(
          container.read(outboxStoreProvider).items[targetKey],
          hasLength(1),
          reason: 'Text-only messages must be enqueued in outbox on timeout',
        );

        sub.close();
        container.dispose();
        connectivityCtrl.close();
        fake.flushMicrotasks();
      });
    });
  });

  group('CancelledFailure attachment handling (#763)', () {
    test('CancelledFailure during attachment send transitions to FAILED',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final connectivityCtrl = StreamController<ConnectivityStatus>.broadcast();
      final connectivity = ConnectivityService.withInitialStatus(
        ConnectivityStatus.online,
        controller: connectivityCtrl,
      );
      final repo = _ControllableConversationRepository();

      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          imageCompressorProvider
              .overrideWithValue(const _NoOpImageCompressor()),
          connectivityServiceProvider.overrideWithValue(connectivity),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      container.listen(conversationDetailStoreProvider, (_, __) {});
      addTearDown(() async {
        container.dispose();
        await connectivityCtrl.close();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();
      final store = container.read(conversationDetailStoreProvider.notifier);

      // Set up attachment send that will fail with CancelledFailure.
      store.addPendingAttachment(const PendingAttachment(
        path: '/tmp/doc.pdf',
        name: 'doc.pdf',
        mimeType: 'application/pdf',
      ));
      store.updateDraft('cancelled attachment');
      repo.sendCompleter = Completer<ConversationMessageSummary>();
      final sendFuture = store.send();
      await Future<void>.delayed(Duration.zero);

      // Complete with CancelledFailure (simulates cancel token firing).
      repo.sendCompleter!.completeError(
        const CancelledFailure(message: 'Request cancelled'),
      );
      await sendFuture;

      // Must be in FAILED state (not silently dropped).
      final pending =
          container.read(conversationDetailStoreProvider).pendingMessages.first;
      expect(
        pending.status,
        MessageSendStatus.failed,
        reason: 'Attachment sends cancelled via CancelledFailure must '
            'transition to FAILED so user can retry',
      );
    });

    test('CancelledFailure during text-only send is silently handled',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final connectivityCtrl = StreamController<ConnectivityStatus>.broadcast();
      final connectivity = ConnectivityService.withInitialStatus(
        ConnectivityStatus.online,
        controller: connectivityCtrl,
      );
      final repo = _ControllableConversationRepository();

      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          imageCompressorProvider
              .overrideWithValue(const _NoOpImageCompressor()),
          connectivityServiceProvider.overrideWithValue(connectivity),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      container.listen(conversationDetailStoreProvider, (_, __) {});
      addTearDown(() async {
        container.dispose();
        await connectivityCtrl.close();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();
      final store = container.read(conversationDetailStoreProvider.notifier);

      // Text-only send that will be cancelled.
      store.updateDraft('cancelled text');
      repo.sendCompleter = Completer<ConversationMessageSummary>();
      final sendFuture = store.send();
      await Future<void>.delayed(Duration.zero);

      // Complete with CancelledFailure.
      repo.sendCompleter!.completeError(
        const CancelledFailure(message: 'Request cancelled'),
      );
      await sendFuture;

      // Text-only: timeout handler already transitioned to queued.
      // CancelledFailure should NOT override that — message stays as-is
      // (the timeout already fired and handled it).
      final pending =
          container.read(conversationDetailStoreProvider).pendingMessages.first;
      // It should still be in sending state (CancelledFailure returns early
      // without transitioning for text-only).
      expect(
        pending.status,
        isNot(MessageSendStatus.failed),
        reason: 'Text-only CancelledFailure should not set FAILED — '
            'the timeout handler manages text-only recovery via outbox',
      );
    });
  });

  group('retrySend cleanup (#763)', () {
    test('retrySend success clears replyToMessage', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final connectivityCtrl = StreamController<ConnectivityStatus>.broadcast();
      final connectivity = ConnectivityService.withInitialStatus(
        ConnectivityStatus.online,
        controller: connectivityCtrl,
      );
      final repo = _ControllableConversationRepository();

      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          imageCompressorProvider
              .overrideWithValue(const _NoOpImageCompressor()),
          connectivityServiceProvider.overrideWithValue(connectivity),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      container.listen(conversationDetailStoreProvider, (_, __) {});
      addTearDown(() async {
        container.dispose();
        await connectivityCtrl.close();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();
      final store = container.read(conversationDetailStoreProvider.notifier);

      // Set a replyTo message.
      final replyMsg = ConversationMessageSummary(
        id: 'msg-reply-target',
        content: 'Original message',
        createdAt: DateTime(2026, 5, 20, 10, 0),
        senderType: 'human',
        messageType: 'message',
      );
      store.setReplyTo(replyMsg);
      expect(
        container.read(conversationDetailStoreProvider).replyToMessage,
        isNotNull,
      );

      // First send — fails to get into failed state.
      store.updateDraft('will fail');
      repo.sendCompleter = Completer<ConversationMessageSummary>();
      final sendFuture = store.send();
      await Future<void>.delayed(Duration.zero);
      repo.sendCompleter!.completeError(
        const UnknownFailure(message: 'bad', causeType: 'test'),
      );
      await sendFuture;

      final localId = container
          .read(conversationDetailStoreProvider)
          .pendingMessages
          .first
          .localId;
      expect(
        container
            .read(conversationDetailStoreProvider)
            .pendingMessages
            .first
            .status,
        MessageSendStatus.failed,
      );

      // replyToMessage should still be set (failure preserves it).
      // Note: send() success already clears it, but failure does not.
      // After the send failure, it was cleared by the success path — actually
      // let me re-set it to verify retrySend clears it.
      store.setReplyTo(replyMsg);
      expect(
        container.read(conversationDetailStoreProvider).replyToMessage,
        isNotNull,
      );

      // retrySend — succeeds.
      repo.sendCompleter = null; // Default auto-success.
      repo.autoSendResult = _fakeMessage('msg-retry-success', 'will fail');
      await store.retrySend(localId);

      // replyToMessage must be cleared after successful retry.
      expect(
        container.read(conversationDetailStoreProvider).replyToMessage,
        isNull,
        reason: 'retrySend success must clear replyToMessage (#763)',
      );
    });

    test('retrySend CancelledFailure with attachments transitions to FAILED',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final connectivityCtrl = StreamController<ConnectivityStatus>.broadcast();
      final connectivity = ConnectivityService.withInitialStatus(
        ConnectivityStatus.online,
        controller: connectivityCtrl,
      );
      final repo = _ControllableConversationRepository();

      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          imageCompressorProvider
              .overrideWithValue(const _NoOpImageCompressor()),
          connectivityServiceProvider.overrideWithValue(connectivity),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      container.listen(conversationDetailStoreProvider, (_, __) {});
      addTearDown(() async {
        container.dispose();
        await connectivityCtrl.close();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();
      final store = container.read(conversationDetailStoreProvider.notifier);

      // First: send with attachment that fails (non-cancelled).
      store.addPendingAttachment(const PendingAttachment(
        path: '/tmp/big.zip',
        name: 'big.zip',
        mimeType: 'application/zip',
      ));
      store.updateDraft('retry cancel');
      repo.sendCompleter = Completer<ConversationMessageSummary>();
      final sendFuture = store.send();
      await Future<void>.delayed(Duration.zero);
      repo.sendCompleter!.completeError(
        const UnknownFailure(message: 'bad', causeType: 'test'),
      );
      await sendFuture;

      final localId = container
          .read(conversationDetailStoreProvider)
          .pendingMessages
          .first
          .localId;
      expect(
        container
            .read(conversationDetailStoreProvider)
            .pendingMessages
            .first
            .status,
        MessageSendStatus.failed,
      );
      // Verify attachmentIds are preserved.
      expect(
        container
            .read(conversationDetailStoreProvider)
            .pendingMessages
            .first
            .attachmentIds,
        isNotEmpty,
      );

      // Retry — will be cancelled.
      repo.sendCompleter = Completer<ConversationMessageSummary>();
      final retryFuture = store.retrySend(localId);
      await Future<void>.delayed(Duration.zero);

      // Verify sending state.
      expect(
        container
            .read(conversationDetailStoreProvider)
            .pendingMessages
            .first
            .status,
        MessageSendStatus.sending,
      );

      // Complete with CancelledFailure.
      repo.sendCompleter!.completeError(
        const CancelledFailure(message: 'timeout cancel'),
      );
      await retryFuture;

      // Must be back in FAILED state (has attachments).
      expect(
        container
            .read(conversationDetailStoreProvider)
            .pendingMessages
            .first
            .status,
        MessageSendStatus.failed,
        reason: 'retrySend CancelledFailure with attachments must '
            'transition to FAILED so user can retry again',
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

ConversationMessageSummary _fakeMessage(String id, String content) {
  return ConversationMessageSummary(
    id: id,
    content: content,
    createdAt: DateTime(2026, 5, 22, 10, 0),
    senderType: 'human',
    messageType: 'message',
  );
}

class _ControllableConversationRepository implements ConversationRepository {
  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  Completer<ConversationMessageSummary>? sendCompleter;
  ConversationMessageSummary? autoSendResult;
  List<String>? lastSendAttachmentIds;
  CancelToken? lastSendCancelToken;
  Completer<String>? uploadCompleter;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    return ConversationDetailSnapshot(
      target: target,
      title: '#channel-1',
      messages: const [],
      historyLimited: false,
      hasOlder: false,
    );
  }

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async {
    return const ConversationMessagePage(
      messages: [],
      historyLimited: false,
      hasOlder: false,
    );
  }

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async {
    return const ConversationMessagePage(
      messages: [],
      historyLimited: false,
      hasOlder: false,
    );
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    CancelToken? cancelToken,
  }) {
    lastSendAttachmentIds = attachmentIds;
    lastSendCancelToken = cancelToken;
    if (sendCompleter != null) {
      return sendCompleter!.future;
    }
    if (autoSendResult != null) {
      return Future.value(autoSendResult);
    }
    return Future.value(_fakeMessage('auto-id', content));
  }

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) {
    if (uploadCompleter != null) {
      return uploadCompleter!.future;
    }
    return Future.value('att-fake-id');
  }

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async {
    return message;
  }

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {
    return null;
  }

  @override
  Future<void> editMessage(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {}

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> pinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> unpinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> addReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async {
    return const [];
  }

  @override
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}
}

class _NoOpImageCompressor implements ImageCompressor {
  const _NoOpImageCompressor();

  @override
  Future<int> getFileSize(String path) async => 0;

  @override
  Future<String> compress(String path, {int quality = 80}) async => path;

  @override
  Future<void> deleteCompressedFile({
    required String originalPath,
    required String compressedPath,
  }) async {}

  @override
  bool isCompressibleImage(String mimeType) => false;
}
