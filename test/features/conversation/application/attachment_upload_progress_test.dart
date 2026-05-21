import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/application/image_compressor.dart';

/// TDD tests for attachment upload progress, cancellation, and compression.
void main() {
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'channel-1',
    ),
  );

  group('upload progress tracking', () {
    test('upload reports progress 0 → partial → 100', () async {
      final repo = _FakeConversationRepository(target: target);
      final container = _createContainer(target: target, repo: repo);
      addTearDown(container.dispose);

      final store = container.read(conversationDetailStoreProvider.notifier);
      await store.load();

      store.addPendingAttachment(const PendingAttachment(
        path: '/tmp/photo.jpg',
        name: 'photo.jpg',
        mimeType: 'image/jpeg',
      ));

      // Set up progress simulation
      repo.uploadProgressSteps = [0.0, 0.5, 1.0];
      repo.uploadCompleter = Completer<String>();

      final progressValues = <double>[];
      container.listen(
        conversationDetailStoreProvider.select(
          (s) => s.uploadProgress,
        ),
        (_, next) {
          if (next.isNotEmpty) {
            progressValues.add(next.values.first);
          }
        },
        fireImmediately: false,
      );

      store.updateDraft('With attachment');
      final sendFuture = store.send();

      // Let progress callbacks fire
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      repo.uploadCompleter!.complete('att-1');
      await sendFuture;

      expect(progressValues, contains(0.5));
    });

    test('multiple attachments track progress independently', () async {
      final repo = _FakeConversationRepository(target: target);
      final container = _createContainer(target: target, repo: repo);
      addTearDown(container.dispose);

      final store = container.read(conversationDetailStoreProvider.notifier);
      await store.load();

      store.addPendingAttachment(const PendingAttachment(
        path: '/tmp/a.jpg',
        name: 'a.jpg',
        mimeType: 'image/jpeg',
      ));
      store.addPendingAttachment(const PendingAttachment(
        path: '/tmp/b.pdf',
        name: 'b.pdf',
        mimeType: 'application/pdf',
      ));

      repo.uploadResults = ['att-a', 'att-b'];

      store.updateDraft('Multi');
      await store.send();

      // Both should have completed (progress cleared after send)
      final state = container.read(conversationDetailStoreProvider);
      expect(state.uploadProgress, isEmpty);
    });

    test('progress cleared after successful send', () async {
      final repo = _FakeConversationRepository(target: target);
      final container = _createContainer(target: target, repo: repo);
      addTearDown(container.dispose);

      final store = container.read(conversationDetailStoreProvider.notifier);
      await store.load();

      store.addPendingAttachment(const PendingAttachment(
        path: '/tmp/file.pdf',
        name: 'file.pdf',
        mimeType: 'application/pdf',
      ));

      repo.uploadResults = ['att-1'];
      store.updateDraft('test');
      await store.send();

      final state = container.read(conversationDetailStoreProvider);
      expect(state.uploadProgress, isEmpty);
    });
  });

  group('cancel in-flight upload', () {
    test('cancelling upload removes attachment from pending send', () async {
      final repo = _FakeConversationRepository(target: target);
      final container = _createContainer(target: target, repo: repo);
      addTearDown(container.dispose);

      final store = container.read(conversationDetailStoreProvider.notifier);
      await store.load();

      store.addPendingAttachment(const PendingAttachment(
        path: '/tmp/big.zip',
        name: 'big.zip',
        mimeType: 'application/zip',
      ));

      // Upload will hang until cancelled
      repo.uploadCompleter = Completer<String>();
      repo.shouldHang = true;

      store.updateDraft('Cancelling');
      final sendFuture = store.send();
      await Future<void>.delayed(Duration.zero);

      // Cancel the upload
      store.cancelUpload(0);
      await Future<void>.delayed(Duration.zero);

      // Complete send (with no attachments since cancelled)
      repo.uploadCompleter!.completeError(
        DioException(
          type: DioExceptionType.cancel,
          requestOptions: RequestOptions(),
        ),
      );
      await sendFuture;

      // Message should still send (text-only, attachment was cancelled)
      final state = container.read(conversationDetailStoreProvider);
      expect(state.uploadProgress, isEmpty);
    });

    test('cancel token is passed to repository upload', () async {
      final repo = _FakeConversationRepository(target: target);
      final container = _createContainer(target: target, repo: repo);
      addTearDown(container.dispose);

      final store = container.read(conversationDetailStoreProvider.notifier);
      await store.load();

      store.addPendingAttachment(const PendingAttachment(
        path: '/tmp/file.bin',
        name: 'file.bin',
        mimeType: 'application/octet-stream',
      ));

      repo.uploadResults = ['att-1'];
      store.updateDraft('test');
      await store.send();

      // Verify cancel token was passed
      expect(repo.lastCancelTokens, isNotEmpty);
    });

    test('disposing store cancels in-flight upload token', () async {
      final repo = _FakeConversationRepository(target: target);
      final container = _createContainer(target: target, repo: repo);

      final subscription = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
      );
      addTearDown(subscription.close);

      final store = container.read(conversationDetailStoreProvider.notifier);
      await store.load();

      store.addPendingAttachment(const PendingAttachment(
        path: '/tmp/in-flight.bin',
        name: 'in-flight.bin',
        mimeType: 'application/octet-stream',
      ));

      repo.uploadCompleter = Completer<String>();
      store.updateDraft('Dispose while uploading');
      unawaited(store.send());
      await Future<void>.delayed(Duration.zero);

      expect(repo.lastCancelTokens.single?.isCancelled, isFalse);

      container.dispose();

      expect(repo.lastCancelTokens.single?.isCancelled, isTrue);
    });
  });

  group('image compression', () {
    test('compresses image before upload when size exceeds threshold',
        () async {
      final repo = _FakeConversationRepository(target: target);
      final compressor = _FakeImageCompressor();
      final container = _createContainer(
        target: target,
        repo: repo,
        compressor: compressor,
      );
      addTearDown(container.dispose);

      final store = container.read(conversationDetailStoreProvider.notifier);
      await store.load();

      store.addPendingAttachment(const PendingAttachment(
        path: '/tmp/large-photo.jpg',
        name: 'large-photo.jpg',
        mimeType: 'image/jpeg',
      ));

      compressor.compressedPath = '/tmp/large-photo-compressed.jpg';
      compressor.fileSizeBytes = 6 * 1024 * 1024; // 6MB → should compress

      repo.uploadResults = ['att-compressed'];
      store.updateDraft('Compressed');
      await store.send();

      // Compression was invoked
      expect(compressor.compressCallCount, 1);
      // Upload used compressed path, not original
      expect(
          repo.lastUploadedPaths, contains('/tmp/large-photo-compressed.jpg'));
      expect(repo.lastUploadedPaths, isNot(contains('/tmp/large-photo.jpg')));
    });

    test('deletes compressed temp image after successful upload', () async {
      final repo = _FakeConversationRepository(target: target);
      final compressor = _FakeImageCompressor();
      final container = _createContainer(
        target: target,
        repo: repo,
        compressor: compressor,
      );
      addTearDown(container.dispose);

      final store = container.read(conversationDetailStoreProvider.notifier);
      await store.load();

      store.addPendingAttachment(const PendingAttachment(
        path: '/tmp/photo.jpg',
        name: 'photo.jpg',
        mimeType: 'image/jpeg',
      ));

      compressor
        ..fileSizeBytes = 6 * 1024 * 1024
        ..compressedPath = '/tmp/photo_compressed.jpg';
      repo.uploadResults = ['att-compressed'];

      store.updateDraft('Cleanup compressed');
      await store.send();

      expect(compressor.deletedCompressedPaths, ['/tmp/photo_compressed.jpg']);
    });

    test('deletes compressed temp image after upload failure', () async {
      final repo = _FakeConversationRepository(target: target);
      final compressor = _FakeImageCompressor();
      final container = _createContainer(
        target: target,
        repo: repo,
        compressor: compressor,
      );
      addTearDown(container.dispose);

      final store = container.read(conversationDetailStoreProvider.notifier);
      await store.load();

      store.addPendingAttachment(const PendingAttachment(
        path: '/tmp/failing-photo.jpg',
        name: 'failing-photo.jpg',
        mimeType: 'image/jpeg',
      ));

      compressor
        ..fileSizeBytes = 6 * 1024 * 1024
        ..compressedPath = '/tmp/failing-photo_compressed.jpg';
      repo.uploadBehaviors = [const _UploadBehavior.fail()];

      store.updateDraft('Cleanup failed upload');
      await store.send();

      expect(
        compressor.deletedCompressedPaths,
        ['/tmp/failing-photo_compressed.jpg'],
      );
    });

    test('skips compression for small images', () async {
      final repo = _FakeConversationRepository(target: target);
      final compressor = _FakeImageCompressor();
      final container = _createContainer(
        target: target,
        repo: repo,
        compressor: compressor,
      );
      addTearDown(container.dispose);

      final store = container.read(conversationDetailStoreProvider.notifier);
      await store.load();

      store.addPendingAttachment(const PendingAttachment(
        path: '/tmp/small-photo.jpg',
        name: 'small-photo.jpg',
        mimeType: 'image/jpeg',
      ));

      compressor.fileSizeBytes = 500 * 1024; // 500KB → no compression

      repo.uploadResults = ['att-small'];
      store.updateDraft('Small');
      await store.send();

      expect(compressor.compressCallCount, 0);
      expect(repo.lastUploadedPaths, contains('/tmp/small-photo.jpg'));
    });

    test('skips compression for non-image files', () async {
      final repo = _FakeConversationRepository(target: target);
      final compressor = _FakeImageCompressor();
      final container = _createContainer(
        target: target,
        repo: repo,
        compressor: compressor,
      );
      addTearDown(container.dispose);

      final store = container.read(conversationDetailStoreProvider.notifier);
      await store.load();

      store.addPendingAttachment(const PendingAttachment(
        path: '/tmp/doc.pdf',
        name: 'doc.pdf',
        mimeType: 'application/pdf',
      ));

      repo.uploadResults = ['att-pdf'];
      store.updateDraft('PDF');
      await store.send();

      expect(compressor.compressCallCount, 0);
    });

    test('falls back to original if compression fails', () async {
      final repo = _FakeConversationRepository(target: target);
      final compressor = _FakeImageCompressor();
      final container = _createContainer(
        target: target,
        repo: repo,
        compressor: compressor,
      );
      addTearDown(container.dispose);

      final store = container.read(conversationDetailStoreProvider.notifier);
      await store.load();

      store.addPendingAttachment(const PendingAttachment(
        path: '/tmp/photo.jpg',
        name: 'photo.jpg',
        mimeType: 'image/jpeg',
      ));

      compressor.fileSizeBytes = 6 * 1024 * 1024; // 6MB
      compressor.shouldFail = true;

      repo.uploadResults = ['att-original'];
      store.updateDraft('Fallback');
      await store.send();

      // Should upload original since compression failed
      expect(repo.lastUploadedPaths, contains('/tmp/photo.jpg'));
    });
  });

  group('multi-attachment partial cancel', () {
    test('cancelling one upload still sends remaining attachments', () async {
      final repo = _FakeConversationRepository(target: target);
      final container = _createContainer(target: target, repo: repo);
      addTearDown(container.dispose);

      final store = container.read(conversationDetailStoreProvider.notifier);
      await store.load();

      store.addPendingAttachment(const PendingAttachment(
        path: '/tmp/a.jpg',
        name: 'a.jpg',
        mimeType: 'image/jpeg',
      ));
      store.addPendingAttachment(const PendingAttachment(
        path: '/tmp/b.jpg',
        name: 'b.jpg',
        mimeType: 'image/jpeg',
      ));

      // First upload will be cancelled, second succeeds
      repo.uploadBehaviors = [
        const _UploadBehavior.cancel(),
        const _UploadBehavior.succeed('att-b'),
      ];

      store.updateDraft('Partial cancel');
      await store.send();

      // Message should have been sent with only the successful attachment
      expect(repo.sentAttachmentIds, hasLength(1));
      expect(repo.sentAttachmentIds.first, ['att-b']);
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

sealed class _UploadBehavior {
  const _UploadBehavior();
  const factory _UploadBehavior.cancel() = _CancelBehavior;
  const factory _UploadBehavior.fail() = _FailBehavior;
  const factory _UploadBehavior.succeed(String id) = _SucceedBehavior;
}

class _CancelBehavior extends _UploadBehavior {
  const _CancelBehavior();
}

class _FailBehavior extends _UploadBehavior {
  const _FailBehavior();
}

class _SucceedBehavior extends _UploadBehavior {
  const _SucceedBehavior(this.id);
  final String id;
}

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({required this.target});

  final ConversationDetailTarget target;
  List<double>? uploadProgressSteps;
  Completer<String>? uploadCompleter;
  List<String>? uploadResults;
  List<_UploadBehavior>? uploadBehaviors;
  bool shouldHang = false;
  final List<CancelToken?> lastCancelTokens = [];
  final List<String> lastUploadedPaths = [];
  final List<List<String>?> sentAttachmentIds = [];
  int _uploadIndex = 0;

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    lastCancelTokens.add(cancelToken);
    lastUploadedPaths.add(attachment.path);

    if (uploadBehaviors != null && _uploadIndex < uploadBehaviors!.length) {
      final behavior = uploadBehaviors![_uploadIndex++];
      switch (behavior) {
        case _CancelBehavior():
          throw DioException(
            type: DioExceptionType.cancel,
            requestOptions: RequestOptions(),
          );
        case _FailBehavior():
          throw const UnknownFailure(
            message: 'Upload failed',
            causeType: 'uploadFailure',
          );
        case _SucceedBehavior(:final id):
          if (onSendProgress != null) {
            onSendProgress(100, 100);
          }
          return id;
      }
    }

    // Simulate progress
    if (onSendProgress != null && uploadProgressSteps != null) {
      for (final step in uploadProgressSteps!) {
        onSendProgress((step * 100).toInt(), 100);
        await Future<void>.delayed(Duration.zero);
      }
    }

    if (uploadCompleter != null) {
      return uploadCompleter!.future;
    }

    final result = uploadResults != null && _uploadIndex < uploadResults!.length
        ? uploadResults![_uploadIndex]
        : 'att-$_uploadIndex';
    _uploadIndex++;
    return result;
  }

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    return ConversationDetailSnapshot(
      target: this.target,
      title: '#channel-1',
      messages: const [],
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
  }) async {
    sentAttachmentIds.add(attachmentIds);
    return ConversationMessageSummary(
      id: 'msg-1',
      content: content,
      createdAt: DateTime.now(),
      senderType: 'human',
      messageType: 'message',
      seq: 1,
    );
  }

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
      );

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
      );

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async =>
      message;

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async =>
      null;

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

class _FakeImageCompressor implements ImageCompressor {
  int compressCallCount = 0;
  String? compressedPath;
  int fileSizeBytes = 0;
  bool shouldFail = false;
  final List<String> deletedCompressedPaths = [];

  @override
  Future<int> getFileSize(String path) async => fileSizeBytes;

  @override
  Future<String> compress(String path, {int quality = 80}) async {
    compressCallCount++;
    if (shouldFail) {
      throw Exception('Compression failed');
    }
    return compressedPath ?? path;
  }

  @override
  Future<void> deleteCompressedFile({
    required String originalPath,
    required String compressedPath,
  }) async {
    if (compressedPath != originalPath) {
      deletedCompressedPaths.add(compressedPath);
    }
  }

  @override
  bool isCompressibleImage(String mimeType) {
    return const {'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType);
  }
}

ProviderContainer _createContainer({
  required ConversationDetailTarget target,
  required _FakeConversationRepository repo,
  _FakeImageCompressor? compressor,
}) {
  return ProviderContainer(
    overrides: [
      currentConversationDetailTargetProvider.overrideWithValue(target),
      conversationRepositoryProvider.overrideWithValue(repo),
      if (compressor != null)
        imageCompressorProvider.overrideWithValue(compressor),
    ],
  );
}
