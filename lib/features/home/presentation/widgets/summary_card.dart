import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/home/application/summary_card_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/l10n/l10n.dart';

// ---------------------------------------------------------------------------
// #861: Smart Summary Card Widget
//
// Displays a dismissable summary of "what happened while you were away" at
// the top of the Home page. Supports collapsed (single-line) and expanded
// (channel list + task changes) states. Animations: slide + fade.
// ---------------------------------------------------------------------------

/// Smart summary card shown at top of Home when user has been away ≥ 5 min.
class SummaryCard extends ConsumerStatefulWidget {
  const SummaryCard({super.key});

  @override
  ConsumerState<SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends ConsumerState<SummaryCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _isMarkingRead = false;

  late final AnimationController _dismissController;
  late final Animation<double> _dismissFade;
  late final Animation<Offset> _dismissSlide;

  @override
  void initState() {
    super.initState();
    _dismissController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _dismissFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _dismissController, curve: Curves.easeIn),
    );
    _dismissSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1),
    ).animate(
      CurvedAnimation(parent: _dismissController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _dismissController.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _dismissController.forward();
    if (mounted) {
      ref.read(summaryCardDismissedProvider.notifier).state = true;
    }
  }

  Future<void> _markAllRead() async {
    if (_isMarkingRead) return;
    setState(() => _isMarkingRead = true);

    try {
      final inbox = ref.read(inboxStoreProvider);
      final unreadChannelIds = inbox.items
          .where((item) => item.unreadCount > 0)
          .map((item) => item.channelId)
          .toList();

      // Fire mark-read for all channels in parallel (max 5 concurrent).
      final inboxNotifier = ref.read(inboxStoreProvider.notifier);

      // Optimistic: clear all badges immediately.
      for (final channelId in unreadChannelIds) {
        inboxNotifier.markRead(channelId: channelId);
      }

      await _dismiss();
    } catch (_) {
      if (mounted) {
        setState(() => _isMarkingRead = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.summaryCardMarkReadFailed),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardState = ref.watch(summaryCardStateProvider);
    final isDismissed = ref.watch(summaryCardDismissedProvider);

    if (cardState == null || isDismissed) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = context.l10n;

    return SlideTransition(
      position: _dismissSlide,
      child: FadeTransition(
        opacity: _dismissFade,
        child: Card(
          color: theme.colorScheme.surfaceContainerHighest,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row: away duration + dismiss button.
                _buildHeader(cardState, l10n),
                const SizedBox(height: 8),
                // Summary line.
                _buildSummaryLine(cardState, l10n),
                // Expanded details.
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: _isExpanded
                      ? _buildExpandedDetails(cardState, l10n, theme)
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 8),
                // Action buttons.
                _buildActions(l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(SummaryCardState cardState, AppLocalizations l10n) {
    return Row(
      children: [
        const Text('📊 ', style: TextStyle(fontSize: 16)),
        Expanded(
          child: Text(
            l10n.summaryCardAwayDuration(cardState.awayDuration.inMinutes),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        InkWell(
          onTap: _dismiss,
          borderRadius: BorderRadius.circular(12),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.close, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryLine(SummaryCardState cardState, AppLocalizations l10n) {
    final parts = <String>[];
    if (cardState.totalUnread > 0) {
      final displayCount = cardState.totalUnread > summaryCardMaxUnreadDisplay
          ? '999+'
          : '${cardState.totalUnread}';
      parts.add('💬 $displayCount ${l10n.summaryCardUnread}');
    }
    if (cardState.mentionCount > 0) {
      parts.add('📢 ${cardState.mentionCount} ${l10n.summaryCardMentions}');
    }
    if (cardState.newTaskCount > 0) {
      parts.add('📋 ${cardState.newTaskCount} ${l10n.summaryCardNewTasks}');
    }

    return Text(
      parts.join('  ·  '),
      style: const TextStyle(fontSize: 14),
    );
  }

  Widget _buildExpandedDetails(
    SummaryCardState cardState,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Channel entries.
            for (final channel in cardState.topChannels)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  _formatChannelEntry(channel, l10n),
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.87),
                  ),
                ),
              ),
            if (cardState.remainingChannelCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  l10n.summaryCardMoreChannels(cardState.remainingChannelCount),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            // Separator if both channels and tasks exist.
            if (cardState.topChannels.isNotEmpty &&
                cardState.taskChanges.isNotEmpty)
              const SizedBox(height: 8),
            // Task entries.
            for (final task in cardState.taskChanges)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  _formatTaskEntry(task, l10n),
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.87),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(AppLocalizations l10n) {
    return Row(
      children: [
        TextButton(
          onPressed: _isMarkingRead ? null : _markAllRead,
          child: Text(
            l10n.summaryCardMarkAllRead,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => setState(() => _isExpanded = !_isExpanded),
          child: Text(
            _isExpanded ? l10n.summaryCardCollapse : l10n.summaryCardExpand,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  String _formatChannelEntry(
      SummaryChannelEntry channel, AppLocalizations l10n) {
    final prefix = channel.kind == InboxItemKind.dm ? 'dm:' : '#';
    final mention =
        channel.isMentioned ? '（${l10n.summaryCardMentionedSuffix}）' : '';
    return '$prefix${channel.channelName}  '
        '${channel.unreadCount} ${l10n.summaryCardUnread}$mention';
  }

  String _formatTaskEntry(SummaryTaskChange task, AppLocalizations l10n) {
    if (task.changeType == 'assigned') {
      return '📋 task #${task.taskNumber} ${l10n.summaryCardTaskAssigned}';
    }
    return '📋 task #${task.taskNumber} → ${task.status}';
  }
}
