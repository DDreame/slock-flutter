import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/image_compressor.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/share/data/shared_content.dart';
import 'package:slock_app/features/share/presentation/page/share_target_picker_page.dart';

/// Progress callback for share upload operations.
///
/// [fileIndex] is the 0-based index of the file being uploaded.
/// [totalFiles] is the total number of files to upload.
/// [fileProgress] is the 0.0–1.0 progress for the current file.
typedef ShareUploadProgressCallback = void Function(
  int fileIndex,
  int totalFiles,
  double fileProgress,
);

/// Maximum number of concurrent uploads during share.
const int _maxParallelUploads = 3;

/// Orchestrates uploading attachments and sending a message for the
/// share-from-other-app flow.
///
/// Supports:
/// - Image compression via [ImageCompressor] (P2-4)
/// - Per-file progress reporting (P2-5)
/// - Parallel uploads with max concurrency of 3 (P2-6)
/// - Shared container temp file cleanup after success (P2-3)
class ShareSendService {
  const ShareSendService({
    required this.repository,
    required this.imageCompressor,
  });

  final ConversationRepository repository;
  final ImageCompressor imageCompressor;

  /// Uploads any attachment items, then sends a message with the combined
  /// text and attachment IDs to the chosen conversation.
  ///
  /// [onProgress] is called per-file with current upload progress.
  /// After successful send, temp files in the shared container are cleaned up.
  Future<void> send({
    required ShareTarget target,
    required SharedContent content,
    ShareUploadProgressCallback? onProgress,
  }) async {
    final detailTarget = target.isChannel
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

    final attachmentItems = content.attachmentItems;
    final totalFiles = attachmentItems.length;

    // P2-4: Compress images before upload and track which paths to clean up.
    final prepared = await _prepareAttachments(attachmentItems);

    // P2-6: Upload in parallel batches of _maxParallelUploads.
    final attachmentIds = List<String?>.filled(totalFiles, null);
    for (var batchStart = 0;
        batchStart < totalFiles;
        batchStart += _maxParallelUploads) {
      final batchEnd = (batchStart + _maxParallelUploads).clamp(0, totalFiles);
      final futures = <Future<void>>[];

      for (var i = batchStart; i < batchEnd; i++) {
        futures.add(_uploadSingle(
          detailTarget: detailTarget,
          prepared: prepared[i],
          fileIndex: i,
          totalFiles: totalFiles,
          onProgress: onProgress,
        ).then((id) => attachmentIds[i] = id));
      }

      await Future.wait(futures);
    }

    final ids = attachmentIds.whereType<String>().toList();

    // Send the message.
    final text = content.combinedText.trim();
    await repository.sendMessage(
      detailTarget,
      text,
      attachmentIds: ids.isNotEmpty ? ids : null,
    );

    // P2-3: Clean up temp files from shared container after successful send.
    await _cleanupTempFiles(prepared);
  }

  /// P2-4: Compress eligible images and return prepared paths.
  Future<List<_PreparedAttachment>> _prepareAttachments(
    List<SharedContentItem> items,
  ) async {
    final results = <_PreparedAttachment>[];
    for (final item in items) {
      final mimeType = item.mimeType ?? 'application/octet-stream';
      final name = _extractFilename(item.path);

      if (imageCompressor.isCompressibleImage(mimeType)) {
        try {
          final fileSize = await imageCompressor.getFileSize(item.path);
          if (fileSize > DefaultImageCompressor.compressionThresholdBytes) {
            final compressedPath = await imageCompressor.compress(item.path);
            results.add(_PreparedAttachment(
              originalPath: item.path,
              uploadPath: compressedPath,
              name: name,
              mimeType: mimeType,
              wasCompressed: true,
            ));
            continue;
          }
        } catch (_) {
          // Fall back to original on compression failure.
        }
      }

      results.add(_PreparedAttachment(
        originalPath: item.path,
        uploadPath: item.path,
        name: name,
        mimeType: mimeType,
        wasCompressed: false,
      ));
    }
    return results;
  }

  /// Uploads a single file with progress reporting.
  Future<String> _uploadSingle({
    required ConversationDetailTarget detailTarget,
    required _PreparedAttachment prepared,
    required int fileIndex,
    required int totalFiles,
    ShareUploadProgressCallback? onProgress,
  }) async {
    return repository.uploadAttachment(
      detailTarget,
      PendingAttachment(
        path: prepared.uploadPath,
        name: prepared.name,
        mimeType: prepared.mimeType,
      ),
      onSendProgress: onProgress != null
          ? (sent, total) {
              final progress = total > 0 ? sent / total : 0.0;
              onProgress(fileIndex, totalFiles, progress.clamp(0.0, 1.0));
            }
          : null,
    );
  }

  /// P2-3: Deletes shared container temp files and compressed intermediaries.
  Future<void> _cleanupTempFiles(List<_PreparedAttachment> prepared) async {
    for (final item in prepared) {
      // Delete compressed intermediary if different from original.
      if (item.wasCompressed && item.uploadPath != item.originalPath) {
        try {
          await imageCompressor.deleteCompressedFile(
            originalPath: item.originalPath,
            compressedPath: item.uploadPath,
          );
        } catch (_) {
          // Best-effort cleanup.
        }
      }
      // Delete the original shared container temp file.
      try {
        final file = File(item.originalPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Best-effort cleanup.
      }
    }
  }
}

/// Internal model tracking an attachment through compression → upload → cleanup.
class _PreparedAttachment {
  const _PreparedAttachment({
    required this.originalPath,
    required this.uploadPath,
    required this.name,
    required this.mimeType,
    required this.wasCompressed,
  });

  /// Original file path from the share extension's shared container.
  final String originalPath;

  /// Path to upload (may be a compressed copy or same as [originalPath]).
  final String uploadPath;

  /// Display filename.
  final String name;

  /// MIME type.
  final String mimeType;

  /// Whether this file was compressed (and thus [uploadPath] differs from
  /// [originalPath]).
  final bool wasCompressed;
}

String _extractFilename(String path) {
  final lastSep = path.lastIndexOf('/');
  if (lastSep == -1) return path;
  return path.substring(lastSep + 1);
}

/// Provides a [ShareSendService] backed by the app's
/// [ConversationRepository] and [ImageCompressor].
final shareSendServiceProvider = Provider<ShareSendService>((ref) {
  return ShareSendService(
    repository: ref.read(conversationRepositoryProvider),
    imageCompressor: ref.read(imageCompressorProvider),
  );
});
