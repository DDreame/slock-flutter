import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  // Phase B: wire to Share.shareXFiles from share_plus.
  return (paths) async {};
});

/// Service that exports selected messages as a styled PNG image.
///
/// Phase A stub — Phase B implements capture + share flow.
class MessageExportService {
  const MessageExportService();

  /// Exports the given [messages] as a branded PNG image and opens the
  /// system share sheet.
  ///
  /// Returns the temp file path on success, or null on failure.
  /// Messages are rendered in send-time order regardless of input order.
  Future<String?> exportSelectedMessages(
    List<ConversationMessageSummary> messages, {
    required GlobalKey boundaryKey,
  }) async {
    // Phase B: capture RepaintBoundary → PNG → shareXFilesProvider
    return null;
  }
}

/// Provider for the message export service.
///
/// Override in tests to verify capture/share calls without side effects.
final messageExportServiceProvider = Provider<MessageExportService>((ref) {
  return const MessageExportService();
});

/// The branded background color for the export card.
///
/// Used by [MessageExportCard] and asserted in tests.
const exportCardBackgroundColor = Color(0xFFF8F9FA);
