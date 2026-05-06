import 'package:flutter/foundation.dart';

/// Progress state for a single attachment upload.
enum AttachmentUploadStatus {
  /// Upload is in progress.
  uploading,

  /// Upload completed successfully.
  completed,

  /// Upload was cancelled by the user.
  cancelled,

  /// Upload failed.
  failed,
}

/// Tracks the upload progress of a single pending attachment.
@immutable
class AttachmentUploadProgress {
  const AttachmentUploadProgress({
    this.status = AttachmentUploadStatus.uploading,
    this.progress = 0.0,
  });

  /// Current upload status.
  final AttachmentUploadStatus status;

  /// Upload progress as a fraction 0.0 to 1.0.
  final double progress;

  AttachmentUploadProgress copyWith({
    AttachmentUploadStatus? status,
    double? progress,
  }) {
    return AttachmentUploadProgress(
      status: status ?? this.status,
      progress: progress ?? this.progress,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttachmentUploadProgress &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          progress == other.progress;

  @override
  int get hashCode => Object.hash(status, progress);
}
