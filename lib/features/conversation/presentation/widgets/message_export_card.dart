import 'package:flutter/material.dart';

import 'package:slock_app/features/conversation/data/conversation_repository.dart';

// ---------------------------------------------------------------------------
// #568: Multi-Select Message Export — Export Card Widget
//
// A styled card that renders selected messages in send-time order with
// app branding (header, timestamp footer, branded background).
// Wrapped in a RepaintBoundary for screenshot capture.
// ---------------------------------------------------------------------------

/// Renders selected messages as a branded export card suitable for capture.
///
/// Phase A stub — Phase B implements styled layout with:
/// - App header with logo/name
/// - Messages in chronological order with sender labels
/// - Timestamp footer
/// - Branded background color
class MessageExportCard extends StatelessWidget {
  const MessageExportCard({
    super.key,
    required this.messages,
    required this.boundaryKey,
  });

  /// Messages to render, displayed in [createdAt] order.
  final List<ConversationMessageSummary> messages;

  /// Key for the RepaintBoundary used by screenshot capture.
  final GlobalKey boundaryKey;

  @override
  Widget build(BuildContext context) {
    // Phase B: styled message list with branding.
    return RepaintBoundary(
      key: boundaryKey,
      child: Container(
        key: const ValueKey('message-export-card'),
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: const SizedBox.shrink(),
      ),
    );
  }
}
