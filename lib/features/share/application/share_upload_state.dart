import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State of the share upload operation.
@immutable
class ShareUploadState {
  const ShareUploadState({
    this.isUploading = false,
    this.currentFileIndex = 0,
    this.totalFiles = 0,
    this.currentFileProgress = 0.0,
  });

  /// Whether a share upload is currently in progress.
  final bool isUploading;

  /// Index of the file currently being uploaded (0-based).
  final int currentFileIndex;

  /// Total number of files in this share operation.
  final int totalFiles;

  /// Upload progress of the current file (0.0–1.0).
  final double currentFileProgress;

  /// Overall progress across all files (0.0–1.0).
  double get overallProgress {
    if (totalFiles == 0) return 0.0;
    final completedFiles = currentFileIndex;
    return (completedFiles + currentFileProgress) / totalFiles;
  }

  ShareUploadState copyWith({
    bool? isUploading,
    int? currentFileIndex,
    int? totalFiles,
    double? currentFileProgress,
  }) {
    return ShareUploadState(
      isUploading: isUploading ?? this.isUploading,
      currentFileIndex: currentFileIndex ?? this.currentFileIndex,
      totalFiles: totalFiles ?? this.totalFiles,
      currentFileProgress: currentFileProgress ?? this.currentFileProgress,
    );
  }
}

/// Provides the current state of share upload progress.
///
/// Updated by the share-send flow in [_ShareTargetRoute] when uploading
/// attachments. UI widgets can watch this provider to show progress.
final shareUploadStateProvider =
    StateProvider<ShareUploadState>((ref) => const ShareUploadState());
