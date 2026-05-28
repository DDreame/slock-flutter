// =============================================================================
// #706 — Problem B: Attachment upload error surfacing
//
// Individual attachment upload failures must:
// 1. Log to diagnostics with attachment name, index, and error details
// 2. Surface partial failure via sendFailure state
// =============================================================================

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/application/image_compressor.dart';
import 'package:slock_app/features/conversation/application/message_send_status.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';

void main() {
  late ProviderContainer container;
  late _FakeConversationRepository fakeRepo;
  late DiagnosticsCollector diagnostics;

  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(serverId: ServerScopeId('s1'), value: 'ch1'),
  );

  setUp(() {
    fakeRepo = _FakeConversationRepository();
    diagnostics = DiagnosticsCollector();
    container = ProviderContainer(overrides: [
      currentConversationDetailTargetProvider.overrideWithValue(target),
      conversationRepositoryProvider.overrideWithValue(fakeRepo),
      realtimeReductionIngressProvider.overrideWithValue(
        RealtimeReductionIngress(),
      ),
      imageCompressorProvider.overrideWithValue(const _NoOpImageCompressor()),
      diagnosticsCollectorProvider.overrideWithValue(diagnostics),
    ]);
  });

  tearDown(() => container.dispose());

  ConversationDetailStore store() =>
      container.read(conversationDetailStoreProvider.notifier);

  ConversationDetailState state() =>
      container.read(conversationDetailStoreProvider);

  Future<void> loadConversation() async {
    fakeRepo.snapshot = ConversationDetailSnapshot(
      target: target,
      title: 'test',
      messages: const [],
      historyLimited: false,
      hasOlder: false,
    );
    await store().load();
  }

  group('#706 — Attachment upload error surfacing', () {
    test('single upload failure logs diagnostic with attachment details',
        () async {
      await loadConversation();
      const a = PendingAttachment(
        path: '/tmp/a.pdf',
        name: 'report.pdf',
        mimeType: 'application/pdf',
      );
      const b = PendingAttachment(
        path: '/tmp/b.png',
        name: 'photo.png',
        mimeType: 'image/png',
      );
      store().addPendingAttachment(a);
      store().addPendingAttachment(b);
      store().updateDraft('with files');
      fakeRepo.failUploadIndices = {0}; // First upload fails
      fakeRepo.sendResult = ConversationMessageSummary(
        id: 'msg-1',
        content: 'with files',
        createdAt: DateTime.now(),
        senderType: 'human',
        messageType: 'message',
      );

      await store().send();

      // Diagnostic must be logged for the failed upload
      final errorEntries = diagnostics.entries
          .where((e) =>
              e.level == DiagnosticsLevel.error && e.tag == 'conversation-send')
          .toList();

      expect(errorEntries, hasLength(1),
          reason: 'One failed upload → one diagnostic error entry');
      expect(errorEntries.first.message, contains('Attachment upload failed'));
      expect(errorEntries.first.metadata?['attachmentIndex'], '0');
      expect(errorEntries.first.metadata?['attachmentName'], 'report.pdf');
    });

    test('partial upload failure surfaces sendFailure in state', () async {
      await loadConversation();
      const a = PendingAttachment(
        path: '/tmp/a.pdf',
        name: 'a.pdf',
        mimeType: 'application/pdf',
      );
      const b = PendingAttachment(
        path: '/tmp/b.png',
        name: 'b.png',
        mimeType: 'image/png',
      );
      store().addPendingAttachment(a);
      store().addPendingAttachment(b);
      store().updateDraft('mixed');
      fakeRepo.failUploadIndices = {0}; // First upload fails
      fakeRepo.sendResult = ConversationMessageSummary(
        id: 'msg-1',
        content: 'mixed',
        createdAt: DateTime.now(),
        senderType: 'human',
        messageType: 'message',
      );

      await store().send();

      // sendFailure should be set with partial upload info
      expect(state().sendFailure, isNotNull,
          reason: 'Partial upload failure must surface to user');
      expect(state().sendFailure!.causeType, 'partialUploadFailure');
      expect(state().sendFailure!.message, contains('1'));
    });

    test('DioException (non-cancel) logs diagnostic', () async {
      await loadConversation();
      const a = PendingAttachment(
        path: '/tmp/a.pdf',
        name: 'network-fail.pdf',
        mimeType: 'application/pdf',
      );
      store().addPendingAttachment(a);
      store().updateDraft('dio fail');
      fakeRepo.failWithDioException = true;
      fakeRepo.sendResult = ConversationMessageSummary(
        id: 'msg-1',
        content: 'dio fail',
        createdAt: DateTime.now(),
        senderType: 'human',
        messageType: 'message',
      );

      await store().send();

      final errorEntries = diagnostics.entries
          .where((e) =>
              e.level == DiagnosticsLevel.error && e.tag == 'conversation-send')
          .toList();

      expect(errorEntries, hasLength(1));
      expect(errorEntries.first.message, contains('Attachment upload failed'));
      expect(
          errorEntries.first.metadata?['attachmentName'], 'network-fail.pdf');
      expect(errorEntries.first.metadata?['dioType'],
          contains('connectionTimeout'));
    });

    test('all uploads fail with text still sends (text-only fallback)',
        () async {
      await loadConversation();
      const a = PendingAttachment(
        path: '/tmp/a.pdf',
        name: 'a.pdf',
        mimeType: 'application/pdf',
      );
      store().addPendingAttachment(a);
      store().updateDraft('fallback text');
      fakeRepo.failUploadIndices = {0}; // All uploads fail
      fakeRepo.sendResult = ConversationMessageSummary(
        id: 'msg-1',
        content: 'fallback text',
        createdAt: DateTime.now(),
        senderType: 'human',
        messageType: 'message',
      );

      await store().send();

      // Text message should still send even though upload failed
      expect(state().pendingMessages, hasLength(1));
      expect(state().pendingMessages.first.status, MessageSendStatus.sent);
      // Diagnostic logged
      expect(
          diagnostics.entries
              .where((e) => e.level == DiagnosticsLevel.error)
              .length,
          1);
    });

    test('multiple upload failures log diagnostic for each', () async {
      await loadConversation();
      const a = PendingAttachment(
        path: '/tmp/a.pdf',
        name: 'a.pdf',
        mimeType: 'application/pdf',
      );
      const b = PendingAttachment(
        path: '/tmp/b.png',
        name: 'b.png',
        mimeType: 'image/png',
      );
      const c = PendingAttachment(
        path: '/tmp/c.txt',
        name: 'c.txt',
        mimeType: 'text/plain',
      );
      store().addPendingAttachment(a);
      store().addPendingAttachment(b);
      store().addPendingAttachment(c);
      store().updateDraft('multi-fail');
      fakeRepo.failUploadIndices = {0, 2}; // First and third fail
      fakeRepo.sendResult = ConversationMessageSummary(
        id: 'msg-1',
        content: 'multi-fail',
        createdAt: DateTime.now(),
        senderType: 'human',
        messageType: 'message',
      );

      await store().send();

      // Two diagnostics logged
      final errorEntries = diagnostics.entries
          .where((e) =>
              e.level == DiagnosticsLevel.error && e.tag == 'conversation-send')
          .toList();
      expect(errorEntries, hasLength(2));

      // sendFailure reports count
      expect(state().sendFailure, isNotNull);
      expect(state().sendFailure!.message, contains('2'));
      expect(state().sendFailure!.message, contains('3'));
    });

    test(
        'partial upload failure + sendMessage failure still surfaces upload loss',
        () async {
      // Regression: partial uploads fail, then sendMessage also throws.
      // The user must still be told about the dropped attachments.
      await loadConversation();
      const a = PendingAttachment(
        path: '/tmp/a.pdf',
        name: 'a.pdf',
        mimeType: 'application/pdf',
      );
      const b = PendingAttachment(
        path: '/tmp/b.png',
        name: 'b.png',
        mimeType: 'image/png',
      );
      store().addPendingAttachment(a);
      store().addPendingAttachment(b);
      store().updateDraft('will fail send');
      fakeRepo.failUploadIndices = {0}; // First upload fails
      fakeRepo.shouldFail = true; // sendMessage also fails

      await store().send();

      // The pending message should be marked failed (send failure).
      expect(state().pendingMessages, hasLength(1));
      expect(state().pendingMessages.first.status, MessageSendStatus.failed);

      // sendFailure must surface the partial upload loss even though the
      // final send also failed — so the user knows an attachment was dropped.
      expect(state().sendFailure, isNotNull,
          reason:
              'Partial upload loss must be surfaced even when send also fails');
      expect(state().sendFailure!.causeType, 'partialUploadFailure');
      expect(state().sendFailure!.message, contains('1'));

      // Diagnostic for the upload failure must still be logged.
      final errorEntries = diagnostics.entries
          .where((e) =>
              e.level == DiagnosticsLevel.error &&
              e.tag == 'conversation-send' &&
              e.message.contains('Attachment upload failed'))
          .toList();
      expect(errorEntries, hasLength(1));
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeConversationRepository implements ConversationRepository {
  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  ConversationDetailSnapshot? snapshot;
  ConversationMessageSummary? sendResult;
  List<String>? lastSentAttachmentIds;
  List<PendingAttachment> uploadedAttachments = [];
  bool shouldFail = false;
  bool failWithDioException = false;
  Set<int> failUploadIndices = {};
  int _uploadCallIndex = 0;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    return snapshot!;
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
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final index = _uploadCallIndex++;
    if (failWithDioException || failUploadIndices.contains(index)) {
      if (failWithDioException) {
        throw DioException(
          type: DioExceptionType.connectionTimeout,
          requestOptions: RequestOptions(path: '/upload'),
          message: 'Connection timeout',
        );
      }
      throw const UnknownFailure(
        message: 'Upload failed',
        causeType: 'test',
      );
    }
    uploadedAttachments.add(attachment);
    return 'att-${uploadedAttachments.length}';
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    CancelToken? cancelToken,
  }) async {
    lastSentAttachmentIds = attachmentIds;
    if (shouldFail) {
      throw const UnknownFailure(
        message: 'Test failure',
        causeType: 'test',
      );
    }
    return sendResult!;
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
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> pinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> unpinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    throw UnimplementedError();
  }

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
  }) async {
    throw UnimplementedError();
  }
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
