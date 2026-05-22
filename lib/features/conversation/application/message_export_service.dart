import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Service that exports selected messages as a styled PNG image.
///
/// Captures the RepaintBoundary identified by [boundaryKey], saves the result
/// as a temporary PNG file, then shares via [shareXFilesProvider].
class MessageExportService {
  const MessageExportService({this.shareXFiles});

  /// The share function injected by the provider. Null in tests using fakes.
  final ShareXFiles? shareXFiles;

  /// Exports the given [messages] as a branded PNG image and opens the
  /// system share sheet.
  ///
  /// Returns the temp file path on success, or null on failure.
  /// Messages are rendered in send-time order regardless of input order.
  Future<String?> exportSelectedMessages(
    List<ConversationMessageSummary> messages, {
    required GlobalKey boundaryKey,
  }) async {
    String? filePath;
    try {
      // 1. Find the RepaintBoundary render object.
      final context = boundaryKey.currentContext;
      if (context == null) return null;
      final boundary = context.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // 2. Capture as image at 3x pixel ratio for sharp output.
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      // 3. Save to temporary file (synchronous write for test compatibility).
      final dir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      filePath = '${dir.path}/slock_export_$timestamp.png';
      final file = File(filePath);
      file.writeAsBytesSync(byteData.buffer.asUint8List());

      // 4. Share via injectable seam.
      if (shareXFiles != null) {
        await shareXFiles!([filePath]);
      }

      return filePath;
    } catch (_) {
      return null;
    } finally {
      // Clean up temp file after share completes (or on failure) to
      // prevent unbounded disk usage from export operations (#723).
      if (filePath != null) {
        try {
          final file = File(filePath);
          if (file.existsSync()) {
            file.deleteSync();
          }
        } catch (_) {
          // Best-effort cleanup — don't fail the export if delete fails.
        }
      }
    }
  }
}

/// Provider for the message export service.
///
/// Override in tests to verify capture/share calls without side effects.
final messageExportServiceProvider = Provider<MessageExportService>((ref) {
  return MessageExportService(shareXFiles: ref.watch(shareXFilesProvider));
});

/// The branded background color for the export card.
///
/// Used by [MessageExportCard] and asserted in tests.
const exportCardBackgroundColor = Color(0xFFF8F9FA);
