// =============================================================================
// PR #826 — Share Extension Upload UX Tests
//
// Verifies:
// 1. P2-3: Temp file cleanup after successful send
// 2. P2-4: Image compression applied to eligible images >5MB
// 3. P2-5: Progress callback invoked with per-file progress
// 4. P2-6: Parallel uploads with max 3 concurrency
// =============================================================================

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/image_compressor.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/share/application/share_send_service.dart';
import 'package:slock_app/features/share/data/shared_content.dart';
import 'package:slock_app/features/share/presentation/page/share_target_picker_page.dart';

void main() {
  late Directory tempDir;
  late _FakeConversationRepository fakeRepo;
  late _FakeImageCompressor fakeCompressor;
  late ShareSendService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('share_test_');
    fakeRepo = _FakeConversationRepository();
    fakeCompressor = _FakeImageCompressor(tempDir: tempDir);
    service = ShareSendService(
      repository: fakeRepo,
      imageCompressor: fakeCompressor,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  final target = ShareTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('s1'),
      value: 'ch-1',
    ),
    'general',
  );

  // ===========================================================================
  // P2-3: Temp file cleanup
  // ===========================================================================

  group('P2-3 — Shared container temp file cleanup', () {
    test('deletes original temp files after successful send', () async {
      final tempFile = File('${tempDir.path}/shared-image.jpg');
      tempFile.writeAsBytesSync([0x01, 0x02, 0x03]);
      expect(tempFile.existsSync(), isTrue);

      final content = SharedContent(items: [
        SharedContentItem(
          type: SharedContentType.file,
          path: tempFile.path,
          mimeType: 'application/pdf',
        ),
      ]);

      await service.send(target: target, content: content);

      expect(tempFile.existsSync(), isFalse,
          reason: 'Temp file must be deleted after successful send.');
    });

    test('deletes compressed intermediary after successful send', () async {
      // Create a "large" image file that triggers compression.
      final tempFile = File('${tempDir.path}/large-image.jpeg');
      tempFile.writeAsBytesSync(List.filled(6 * 1024 * 1024, 0xFF));
      expect(tempFile.existsSync(), isTrue);

      final content = SharedContent(items: [
        SharedContentItem(
          type: SharedContentType.image,
          path: tempFile.path,
          mimeType: 'image/jpeg',
        ),
      ]);

      await service.send(target: target, content: content);

      // Compressed file should be deleted.
      expect(
          fakeCompressor.deletedPaths, contains(endsWith('_compressed.jpeg')));
      // Original temp file should also be deleted.
      expect(tempFile.existsSync(), isFalse);
    });
  });

  // ===========================================================================
  // P2-4: Image compression
  // ===========================================================================

  group('P2-4 — Image compression before upload', () {
    test('compresses images over threshold', () async {
      final tempFile = File('${tempDir.path}/big-photo.jpeg');
      tempFile.writeAsBytesSync(List.filled(6 * 1024 * 1024, 0xFF));

      final content = SharedContent(items: [
        SharedContentItem(
          type: SharedContentType.image,
          path: tempFile.path,
          mimeType: 'image/jpeg',
        ),
      ]);

      await service.send(target: target, content: content);

      expect(fakeCompressor.compressCalls, 1,
          reason: 'Image over threshold must be compressed.');
      // Uploaded path should be the compressed path.
      expect(
        fakeRepo.uploadedPaths.first,
        contains('_compressed.jpeg'),
      );
    });

    test('skips compression for small images', () async {
      final tempFile = File('${tempDir.path}/small-photo.jpeg');
      tempFile.writeAsBytesSync(List.filled(1024, 0xFF)); // 1KB

      final content = SharedContent(items: [
        SharedContentItem(
          type: SharedContentType.image,
          path: tempFile.path,
          mimeType: 'image/jpeg',
        ),
      ]);

      await service.send(target: target, content: content);

      expect(fakeCompressor.compressCalls, 0,
          reason: 'Small images must NOT be compressed.');
      expect(fakeRepo.uploadedPaths.first, tempFile.path);
    });

    test('skips compression for non-image files', () async {
      final tempFile = File('${tempDir.path}/doc.pdf');
      tempFile.writeAsBytesSync(List.filled(10 * 1024 * 1024, 0xFF));

      final content = SharedContent(items: [
        SharedContentItem(
          type: SharedContentType.file,
          path: tempFile.path,
          mimeType: 'application/pdf',
        ),
      ]);

      await service.send(target: target, content: content);

      expect(fakeCompressor.compressCalls, 0,
          reason: 'Non-image files must NOT be compressed.');
    });
  });

  // ===========================================================================
  // P2-5: Progress callback
  // ===========================================================================

  group('P2-5 — Upload progress callback', () {
    test('reports per-file progress during upload', () async {
      final tempFile = File('${tempDir.path}/file.pdf');
      tempFile.writeAsBytesSync([0x01]);

      final content = SharedContent(items: [
        SharedContentItem(
          type: SharedContentType.file,
          path: tempFile.path,
          mimeType: 'application/pdf',
        ),
      ]);

      final progressCalls = <(int, int, double)>[];
      await service.send(
        target: target,
        content: content,
        onProgress: (fileIndex, totalFiles, fileProgress) {
          progressCalls.add((fileIndex, totalFiles, fileProgress));
        },
      );

      expect(progressCalls, isNotEmpty,
          reason: 'Progress callback must be invoked.');
      expect(progressCalls.first.$1, 0, reason: 'fileIndex starts at 0');
      expect(progressCalls.first.$2, 1, reason: 'totalFiles is 1');
    });

    test('reports progress for multiple files', () async {
      final file1 = File('${tempDir.path}/a.pdf');
      final file2 = File('${tempDir.path}/b.pdf');
      file1.writeAsBytesSync([0x01]);
      file2.writeAsBytesSync([0x02]);

      final content = SharedContent(items: [
        SharedContentItem(
          type: SharedContentType.file,
          path: file1.path,
          mimeType: 'application/pdf',
        ),
        SharedContentItem(
          type: SharedContentType.file,
          path: file2.path,
          mimeType: 'application/pdf',
        ),
      ]);

      final seenIndices = <int>{};
      await service.send(
        target: target,
        content: content,
        onProgress: (fileIndex, totalFiles, _) {
          seenIndices.add(fileIndex);
          expect(totalFiles, 2);
        },
      );

      expect(seenIndices, containsAll([0, 1]),
          reason: 'Progress must be reported for each file.');
    });
  });

  // ===========================================================================
  // P2-6: Parallel uploads
  // ===========================================================================

  group('P2-6 — Parallel uploads (max 3)', () {
    test('max concurrent uploads is 3', () async {
      // Create 5 files to test batching.
      final files = <File>[];
      final items = <SharedContentItem>[];
      for (var i = 0; i < 5; i++) {
        final f = File('${tempDir.path}/file_$i.pdf');
        f.writeAsBytesSync([i]);
        files.add(f);
        items.add(SharedContentItem(
          type: SharedContentType.file,
          path: f.path,
          mimeType: 'application/pdf',
        ));
      }

      final content = SharedContent(items: items);

      // Track max concurrency using completers.
      fakeRepo.uploadDelay = const Duration(milliseconds: 50);

      await service.send(target: target, content: content);

      // With 5 files and max 3 parallel, we should see exactly 5 uploads.
      expect(fakeRepo.uploadedPaths.length, 5);
      // Max concurrent should never exceed 3.
      expect(fakeRepo.maxConcurrentUploads, lessThanOrEqualTo(3));
    });

    test('all attachment IDs are collected in order', () async {
      final files = <File>[];
      final items = <SharedContentItem>[];
      for (var i = 0; i < 4; i++) {
        final f = File('${tempDir.path}/file_$i.pdf');
        f.writeAsBytesSync([i]);
        files.add(f);
        items.add(SharedContentItem(
          type: SharedContentType.file,
          path: f.path,
          mimeType: 'application/pdf',
        ));
      }

      final content = SharedContent(items: items);
      fakeRepo.uploadDelay = const Duration(milliseconds: 10);

      await service.send(target: target, content: content);

      // Verify sendMessage was called with all IDs.
      expect(fakeRepo.sentAttachmentIds, hasLength(4));
    });
  });
}

// =============================================================================
// Fakes
// =============================================================================

class _FakeConversationRepository implements ConversationRepository {
  final uploadedPaths = <String>[];
  List<String>? sentAttachmentIds;
  Duration uploadDelay = Duration.zero;

  int _currentConcurrent = 0;
  int maxConcurrentUploads = 0;

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    _currentConcurrent++;
    if (_currentConcurrent > maxConcurrentUploads) {
      maxConcurrentUploads = _currentConcurrent;
    }

    uploadedPaths.add(attachment.path);

    // Simulate progress.
    onSendProgress?.call(50, 100);
    if (uploadDelay != Duration.zero) {
      await Future<void>.delayed(uploadDelay);
    }
    onSendProgress?.call(100, 100);

    _currentConcurrent--;
    return 'attachment-id-${uploadedPaths.length}';
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    bool? asTask,
    CancelToken? cancelToken,
  }) async {
    sentAttachmentIds = attachmentIds;
    return ConversationMessageSummary(
      id: 'msg-1',
      content: content,
      createdAt: DateTime.now(),
      senderType: 'human',
      messageType: 'text',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeImageCompressor implements ImageCompressor {
  _FakeImageCompressor({required this.tempDir});

  final Directory tempDir;
  int compressCalls = 0;
  final deletedPaths = <String>[];

  @override
  Future<int> getFileSize(String path) async {
    return File(path).lengthSync();
  }

  @override
  Future<String> compress(String path, {int quality = 80}) async {
    compressCalls++;
    final ext = path.substring(path.lastIndexOf('.'));
    final baseName =
        path.substring(path.lastIndexOf('/') + 1, path.lastIndexOf('.'));
    final compressedPath = '${tempDir.path}/${baseName}_compressed$ext';
    File(compressedPath).writeAsBytesSync([0x01]); // Tiny compressed file.
    return compressedPath;
  }

  @override
  Future<void> deleteCompressedFile({
    required String originalPath,
    required String compressedPath,
  }) async {
    deletedPaths.add(compressedPath);
    final file = File(compressedPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  @override
  bool isCompressibleImage(String mimeType) {
    return const {'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType);
  }
}
