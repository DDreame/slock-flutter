import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import 'package:slock_app/features/conversation/data/conversation_repository.dart';

// ---------------------------------------------------------------------------
// #568: Multi-Select Message Export
//
// Orchestrates: gather selected messages → render MessageExportCard →
// capture via RepaintBoundary → share PNG via share_plus.
// ---------------------------------------------------------------------------

/// Signature for the share seam — wraps share_plus for testability.
typedef ShareXFiles = Future<void> Function(List<String> paths);

/// Injectable share seam provider.
///
/// Production: calls `Share.shareXFiles([XFile(path)])`.
/// Tests: override to record shared paths without platform channel.
final shareXFilesProvider = Provider<ShareXFiles>((ref) {
  return (paths) async {
    await Share.shareXFiles(paths.map((p) => XFile(p)).toList());
  };
});

/// Signature for the gallery save seam — wraps [Gal.putImage] for testability.
typedef SaveToGallery = Future<void> Function(String path);

/// Injectable gallery save seam provider.
///
/// Production: calls `Gal.putImage(path)`.
/// Tests: override to record saved paths without platform channel.
final saveToGalleryProvider = Provider<SaveToGallery>((ref) {
  return (path) async {
    await Gal.putImage(path);
  };
});

/// Service that exports selected messages as a styled PNG image.
///
/// Captures the RepaintBoundary identified by [boundaryKey], saves the result
/// as a temporary PNG file, then shares via [shareXFilesProvider].
class MessageExportService {
  const MessageExportService({
    this.shareXFiles,
    this.saveToGallery,
    @visibleForTesting this.onImageDisposed,
  });

  /// The share function injected by the provider. Null in tests using fakes.
  final ShareXFiles? shareXFiles;

  /// The gallery save function injected by the provider.
  final SaveToGallery? saveToGallery;

  final VoidCallback? onImageDisposed;

  /// Exports the given [messages] as a branded PNG image and opens the
  /// system share sheet.
  ///
  /// Returns the temp file path on success, or null on failure.
  /// Messages are rendered in send-time order regardless of input order.
  ///
  /// Previous export temp files are cleaned up at the start of each export
  /// (#741), ensuring the current file survives long enough for the share
  /// sheet to finish reading it (the share sheet may still be reading after
  /// `shareXFiles` returns on mobile platforms).
  Future<String?> exportSelectedMessages(
    List<ConversationMessageSummary> messages, {
    required GlobalKey boundaryKey,
  }) async {
    try {
      // 0. Clean up previous export temp files (#741).
      cleanupPreviousExportFiles();

      // 1. Find the RepaintBoundary render object.
      final context = boundaryKey.currentContext;
      if (context == null) return null;
      final boundary = context.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // 2. Capture as image at 3x pixel ratio for sharp output.
      final image = await boundary.toImage(pixelRatio: 3.0);
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) return null;

        // 3. Save to temporary file (synchronous write for test compatibility).
        final dir = Directory.systemTemp;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = '${dir.path}/slock_export_$timestamp.png';
        final file = File(filePath);
        file.writeAsBytesSync(byteData.buffer.asUint8List());

        // 4. Share via injectable seam.
        if (shareXFiles != null) {
          await shareXFiles!([filePath]);
        }

        return filePath;
      } finally {
        image.dispose();
        onImageDisposed?.call();
      }
    } catch (_) {
      return null;
    }
  }

  /// Deletes any leftover `slock_export_*.png` files from previous exports
  /// that are older than [minAge].
  ///
  /// Called at the start of each new export to prevent unbounded disk usage
  /// while keeping recent files alive for share sheet consumers (#741).
  /// Files younger than [minAge] are preserved to avoid deleting a file that
  /// a mobile share target may still be reading.
  @visibleForTesting
  static void cleanupPreviousExportFiles({
    Duration minAge = const Duration(seconds: 60),
  }) {
    try {
      final dir = Directory.systemTemp;
      final now = DateTime.now();
      final entries = dir.listSync();
      for (final entry in entries) {
        if (entry is File &&
            entry.path.contains('slock_export_') &&
            entry.path.endsWith('.png')) {
          try {
            final stat = entry.statSync();
            final age = now.difference(stat.modified);
            if (age >= minAge) {
              entry.deleteSync();
            }
          } catch (_) {
            // Best-effort — file may be locked by share sheet.
          }
        }
      }
    } catch (_) {
      // Best-effort — don't fail the export if cleanup fails.
    }
  }

  /// Captures the RepaintBoundary as a PNG and saves it to the device gallery.
  ///
  /// Returns the temp file path on success, or null on failure/permission denied.
  /// Requires photo library permission (iOS) or storage permission (Android <29).
  Future<String?> saveExportToGallery({
    required GlobalKey boundaryKey,
  }) async {
    try {
      // 1. Find the RepaintBoundary render object (sync, before async gap).
      final context = boundaryKey.currentContext;
      if (context == null) return null;
      final boundary = context.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // 2. Check permission.
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) return null;
      }

      // 3. Capture at 3x for sharp output.
      final image = await boundary.toImage(pixelRatio: 3.0);
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) return null;

        // 4. Save to temp file then copy to gallery.
        final dir = Directory.systemTemp;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = '${dir.path}/slock_export_$timestamp.png';
        final file = File(filePath);
        file.writeAsBytesSync(byteData.buffer.asUint8List());

        // 5. Save to gallery via injectable seam.
        if (saveToGallery != null) {
          await saveToGallery!(filePath);
        }

        return filePath;
      } finally {
        image.dispose();
        onImageDisposed?.call();
      }
    } catch (_) {
      return null;
    }
  }
}

/// Provider for the message export service.
///
/// Override in tests to verify capture/share calls without side effects.
final messageExportServiceProvider = Provider<MessageExportService>((ref) {
  return MessageExportService(
    shareXFiles: ref.watch(shareXFilesProvider),
    saveToGallery: ref.watch(saveToGalleryProvider),
  );
});

/// The branded background color for the export card.
///
/// Used by [MessageExportCard] and asserted in tests.
const exportCardBackgroundColor = Color(0xFFF8F9FA);
