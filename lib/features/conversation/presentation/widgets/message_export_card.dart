import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:slock_app/features/conversation/application/message_export_service.dart';
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
/// Messages are sorted by [createdAt] in ascending (chronological) order.
/// Layout:
/// - App header with "Slock" branding
/// - Messages list with sender name + content
/// - Timestamp footer
/// - Branded background color ([exportCardBackgroundColor])
class MessageExportCard extends StatefulWidget {
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
  State<MessageExportCard> createState() => _MessageExportCardState();
}

class _MessageExportCardState extends State<MessageExportCard> {
  // INV-SEL-816: Cache the sorted list so it is computed once per
  // messages change, not on every parent rebuild.
  late List<ConversationMessageSummary> _sorted;

  @override
  void initState() {
    super.initState();
    _sorted = _sortMessages(widget.messages);
  }

  @override
  void didUpdateWidget(MessageExportCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.messages, widget.messages)) {
      _sorted = _sortMessages(widget.messages);
    }
  }

  static List<ConversationMessageSummary> _sortMessages(
    List<ConversationMessageSummary> messages,
  ) {
    return List<ConversationMessageSummary>.from(messages)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Widget build(BuildContext context) {
    // Determine timestamp range for footer.
    final earliest = _sorted.first.createdAt;
    final latest = _sorted.last.createdAt;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final footerText = _sorted.length == 1
        ? dateFormat.format(earliest)
        : '${dateFormat.format(earliest)} – ${dateFormat.format(latest)}';

    return RepaintBoundary(
      key: widget.boundaryKey,
      child: Container(
        key: const ValueKey('message-export-card'),
        color: exportCardBackgroundColor,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── App branding header ──
            const Center(
              child: Text(
                'Slock',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),
            const SizedBox(height: 12),

            // ── Messages ──
            ..._sorted.map((msg) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        msg.senderName ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF555555),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        msg.content,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF1A1A1A),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                )),

            // ── Timestamp footer ──
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),
            const SizedBox(height: 8),
            Center(
              child: Text(
                footerText,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF999999),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
