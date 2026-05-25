import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/message_bubble.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/application/message_send_status.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_message_card.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';
import 'package:slock_app/l10n/l10n.dart';

/// Maximum bubble width as a fraction of available space.
const bubbleMaxWidthFraction = 0.78;

class ConversationMessageList extends ConsumerWidget {
  const ConversationMessageList({
    super.key,
    required this.controller,
    this.onScrollToMessage,
    this.highlightedMessageId,
    this.messageKeyBuilder,
  });

  final ScrollController controller;
  final void Function(
          String messageId, List<ConversationMessageSummary> messages)?
      onScrollToMessage;

  /// The message ID currently highlighted from a quote-jump.
  final String? highlightedMessageId;

  /// Returns a [GlobalKey] for a given message ID, used for
  /// [Scrollable.ensureVisible]-based scroll targeting.
  final GlobalKey Function(String messageId)? messageKeyBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // INV-CONV-MESSAGE-LIST-SELECT-1: Only watch the 9 fields consumed by
    // the message list. Draft, uploadProgress, replyTo, isSending, etc.
    // must NOT trigger full list rebuilds.
    final state = ref.watch(conversationDetailStoreProvider.select((s) => (
          messages: s.messages,
          pendingMessages: s.pendingMessages,
          target: s.target,
          searchMatchIds: s.searchMatchIds,
          currentSearchMatchIndex: s.currentSearchMatchIndex,
          searchQuery: s.searchQuery,
          isLoadingOlder: s.isLoadingOlder,
          hasOlder: s.hasOlder,
          historyLimited: s.historyLimited,
        )));
    final pendingCount = state.pendingMessages.length;
    final totalCount = state.messages.length + pendingCount + 1;
    // Compute maxBubbleWidth once at the list level instead of per-message
    // LayoutBuilder to avoid unnecessary layout passes.
    // Subtract horizontal list padding (16 each side) to match the inner
    // width that LayoutBuilder previously provided.
    final maxBubbleWidth =
        (MediaQuery.of(context).size.width - 32) * bubbleMaxWidthFraction;

    // Compute unread divider position from the production unread projection.
    // The divider separator index is pendingCount + unreadCount - 1, i.e.
    // between the last unread message (item[pendingCount + unreadCount - 1])
    // and the first read message (item[pendingCount + unreadCount]).
    final unreadCount = unreadCountForTarget(ref, state.target);
    final unreadSepIndex =
        unreadCount > 0 && unreadCount <= state.messages.length
            ? pendingCount + unreadCount - 1
            : -1;

    final toLocal = ref.watch(dateSeparatorToLocalProvider);

    return Semantics(
      label: context.l10n.conversationMessageListSemantics,
      child: ListView.separated(
        key: const ValueKey('conversation-success'),
        controller: controller,
        reverse: true,
        cacheExtent: 500,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        itemCount: totalCount,
        separatorBuilder: (context, index) {
          // Resolve timestamps for the items on both sides of this separator.
          // With reverse:true, item[index] is newer (below), item[index+1] is
          // older (above). Show a date chip when they fall on different days.
          final newerDate = _dateForItemAt(
              index, pendingCount, state.pendingMessages, state.messages);
          final olderDate = _dateForItemAt(
              index + 1, pendingCount, state.pendingMessages, state.messages);

          // Check if this separator is the unread boundary.
          final isUnreadBoundary = index == unreadSepIndex;

          // Date separator takes priority — wrap with unread divider if needed.
          if (newerDate != null &&
              olderDate != null &&
              !_isSameDay(newerDate, olderDate, toLocal)) {
            if (isUnreadBoundary) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _UnreadDivider(),
                  _DateSeparatorWidget(
                    key: const ValueKey('date-separator'),
                    date: newerDate,
                  ),
                ],
              );
            }
            return _DateSeparatorWidget(
              key: const ValueKey('date-separator'),
              date: newerDate,
            );
          }

          // Unread divider at this separator position.
          if (isUnreadBoundary) {
            return const _UnreadDivider();
          }

          // Grouped messages (same sender, <5min, same day) get a tighter gap.
          final newerMsg =
              _messageForItemAt(index, pendingCount, state.messages);
          final olderMsg =
              _messageForItemAt(index + 1, pendingCount, state.messages);
          if (newerMsg != null &&
              olderMsg != null &&
              _shouldGroupWith(newerMsg, olderMsg, toLocal)) {
            return const SizedBox(height: 3);
          }
          return const SizedBox(height: 12);
        },
        itemBuilder: (context, index) {
          // With reverse:true, index 0 = bottom of screen.
          // Order: pending (newest first) → messages (newest first) → header.
          if (index < pendingCount) {
            final pending = state.pendingMessages[pendingCount - 1 - index];
            return _PendingMessageCard(
              key: ValueKey('pending-${pending.localId}'),
              pending: pending,
              maxBubbleWidth: maxBubbleWidth,
            );
          }
          final adjustedIndex = index - pendingCount;
          if (adjustedIndex < state.messages.length) {
            final message =
                state.messages[state.messages.length - 1 - adjustedIndex];
            // Determine if this message should show its header by checking
            // the chronologically-previous message (index+1 in reversed list).
            final olderMsg =
                _messageForItemAt(index + 1, pendingCount, state.messages);
            final showHeader = olderMsg == null ||
                !_shouldGroupWith(message, olderMsg, toLocal);
            final isCurrentSearchMatch = state.searchMatchIds.isNotEmpty &&
                state.currentSearchMatchIndex < state.searchMatchIds.length &&
                state.searchMatchIds[state.currentSearchMatchIndex] ==
                    message.id;
            final isQuoteJumpHighlighted = highlightedMessageId == message.id;
            final messageKey = messageKeyBuilder?.call(message.id);
            return RepaintBoundary(
              key: ValueKey('repaint-boundary-${message.id}'),
              child: KeyedSubtree(
                key: messageKey,
                child: ConversationMessageCard(
                  target: state.target,
                  message: message,
                  maxBubbleWidth: maxBubbleWidth,
                  showHeader: showHeader,
                  highlightQuery: state.searchQuery,
                  isCurrentSearchMatch: isCurrentSearchMatch,
                  isQuoteJumpHighlighted: isQuoteJumpHighlighted,
                  onScrollToMessage: onScrollToMessage != null
                      ? (messageId) =>
                          onScrollToMessage!(messageId, state.messages)
                      : null,
                ),
              ),
            );
          }
          // Last item (top of screen) = history header.
          return _ConversationHistoryHeader(
            isLoadingOlder: state.isLoadingOlder,
            hasOlder: state.hasOlder,
            historyLimited: state.historyLimited,
          );
        },
      ),
    );
  }
}

/// Returns the unread message count for [target] from the projection store.
/// INV-CONV-UNREAD-COUNT-SELECT-1: Narrows watch to only the specific
/// target's count — prevents cross-channel unread changes from rebuilding
/// the active conversation's message list.
int unreadCountForTarget(WidgetRef ref, ConversationDetailTarget target) {
  switch (target.surface) {
    case ConversationSurface.channel:
      final scopeId = ChannelScopeId(
          serverId: target.serverId, value: target.conversationId);
      return ref.watch(
        unreadSourceProjectionProvider
            .select((s) => s.channelUnreadCount(scopeId)),
      );
    case ConversationSurface.directMessage:
      final scopeId = DirectMessageScopeId(
          serverId: target.serverId, value: target.conversationId);
      return ref.watch(
        unreadSourceProjectionProvider.select((s) => s.dmUnreadCount(scopeId)),
      );
  }
}

/// "New messages" divider inserted at the boundary between read and unread
/// messages in the conversation list.
class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      key: const ValueKey('unread-divider'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: colors.primary,
              thickness: 1,
              height: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              context.l10n.pendingNewMessages,
              style: AppTypography.caption.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: colors.primary,
              thickness: 1,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Normalizes a [DateTime] to the user's local timezone for day-boundary
/// comparison. Override in tests via `ProviderScope.overrides`.
final dateSeparatorToLocalProvider =
    Provider<DateTime Function(DateTime)>((ref) => (dt) => dt.toLocal());

/// Supplies the current timestamp for date separator labels.
///
/// Kept as a provider so tests can use a fixed clock instead of relying on
/// wall-clock time around UTC/local day boundaries.
final dateSeparatorNowProvider = Provider<DateTime>((ref) => DateTime.now());

/// Resolve the [ConversationMessageSummary] at [index], or null for pending/header.
ConversationMessageSummary? _messageForItemAt(
  int index,
  int pendingCount,
  List<ConversationMessageSummary> messages,
) {
  if (index < pendingCount) return null; // pending message
  final adjustedIndex = index - pendingCount;
  if (adjustedIndex < messages.length) {
    return messages[messages.length - 1 - adjustedIndex];
  }
  return null; // header
}

/// Whether [newer] should be grouped with [older] (same sender, <5min, same
/// day, neither is a system message).
bool _shouldGroupWith(
  ConversationMessageSummary newer,
  ConversationMessageSummary older,
  DateTime Function(DateTime) toLocal,
) {
  if (newer.isSystem || older.isSystem) return false;
  if (newer.senderId == null || newer.senderId != older.senderId) return false;
  final diff = newer.createdAt.difference(older.createdAt).abs();
  if (diff > const Duration(minutes: 5)) return false;
  if (!_isSameDay(newer.createdAt, older.createdAt, toLocal)) return false;
  return true;
}

/// Resolve the [DateTime] for the list item at [index], or null for the header.
DateTime? _dateForItemAt(
  int index,
  int pendingCount,
  List<PendingMessage> pendingMessages,
  List<ConversationMessageSummary> messages,
) {
  if (index < pendingCount) {
    return pendingMessages[pendingCount - 1 - index].createdAt;
  }
  final adjustedIndex = index - pendingCount;
  if (adjustedIndex < messages.length) {
    return messages[messages.length - 1 - adjustedIndex].createdAt;
  }
  // Header item — no date.
  return null;
}

/// True when [a] and [b] fall on the same local calendar day.
bool _isSameDay(DateTime a, DateTime b, DateTime Function(DateTime) toLocal) {
  final la = toLocal(a);
  final lb = toLocal(b);
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

class _DateSeparatorWidget extends ConsumerWidget {
  const _DateSeparatorWidget({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final toLocal = ref.watch(dateSeparatorToLocalProvider);
    final now = ref.watch(dateSeparatorNowProvider);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDateLabel(date, now, toLocal, l10n, locale),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDateLabel(
  DateTime date,
  DateTime now,
  DateTime Function(DateTime) toLocal,
  AppLocalizations l10n,
  String locale,
) {
  // Pass raw dates to _isSameDay — it applies toLocal once to each input.
  // Do NOT pre-convert `date` before passing to _isSameDay, or the transform
  // would be applied twice (once here, once inside _isSameDay).
  if (_isSameDay(date, now, toLocal)) return l10n.dateSeparatorToday;
  final yesterday = now.subtract(const Duration(days: 1));
  if (_isSameDay(date, yesterday, toLocal)) return l10n.dateSeparatorYesterday;
  return DateFormat.MMMEd(locale).format(toLocal(date));
}

class _ConversationHistoryHeader extends StatelessWidget {
  const _ConversationHistoryHeader({
    required this.isLoadingOlder,
    required this.hasOlder,
    required this.historyLimited,
  });

  final bool isLoadingOlder;
  final bool hasOlder;
  final bool historyLimited;

  @override
  Widget build(BuildContext context) {
    if (isLoadingOlder) {
      return const Center(
        key: ValueKey('conversation-loading-older'),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (hasOlder) {
      return const SizedBox.shrink(
        key: ValueKey('conversation-has-older'),
      );
    }

    if (historyLimited) {
      return Center(
        key: const ValueKey('conversation-history-limited'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(context.l10n.pendingEarlierHistoryLimited),
        ),
      );
    }

    return const SizedBox.shrink(
        key: ValueKey('conversation-history-complete'));
  }
}

class _PendingMessageCard extends ConsumerWidget {
  const _PendingMessageCard({
    super.key,
    required this.pending,
    required this.maxBubbleWidth,
  });

  final PendingMessage pending;
  final double maxBubbleWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isFailed = pending.status == MessageSendStatus.failed;
    final isSending = pending.status == MessageSendStatus.sending;
    final isQueued = pending.status == MessageSendStatus.queued;
    final isSent = pending.status == MessageSendStatus.sent;

    final bodyStyle = AppTypography.body.copyWith(
      color: colors.primaryForeground,
    );
    const borderRadius = BorderRadius.only(
      topLeft: Radius.circular(BubbleTokens.radiusLarge),
      topRight: Radius.circular(BubbleTokens.radiusSmall),
      bottomLeft: Radius.circular(BubbleTokens.radiusLarge),
      bottomRight: Radius.circular(BubbleTokens.radiusLarge),
    );

    final bubble = Container(
      key: ValueKey('pending-bubble-${pending.localId}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color:
            isFailed ? colors.primary.withValues(alpha: 0.6) : colors.primary,
        borderRadius: borderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pending.content, style: bodyStyle),
        ],
      ),
    );

    final statusRow = Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSending) ...[
            SizedBox(
              key: const ValueKey('pending-sending-indicator'),
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              context.l10n.pendingSending,
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
          if (isQueued) ...[
            Icon(
              Icons.schedule,
              key: const ValueKey('pending-queued-icon'),
              size: 14,
              color: colors.warning,
            ),
            const SizedBox(width: 4),
            Text(
              context.l10n.pendingQueued,
              key: const ValueKey('pending-queued-label'),
              style: AppTypography.caption.copyWith(
                color: colors.warning,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              key: const ValueKey('pending-queued-dismiss-button'),
              onPressed: () => ref
                  .read(conversationDetailStoreProvider.notifier)
                  .dismissPendingMessage(pending.localId),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                context.l10n.pendingDismiss,
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ),
          ],
          if (isSent) ...[
            Icon(
              Icons.check_circle_outline,
              key: const ValueKey('pending-sent-icon'),
              size: 14,
              color: colors.success,
            ),
            const SizedBox(width: 4),
            Text(
              context.l10n.pendingSent,
              key: const ValueKey('pending-sent-label'),
              style: AppTypography.caption.copyWith(
                color: colors.success,
              ),
            ),
          ],
          if (isFailed) ...[
            Icon(
              Icons.error_outline,
              key: const ValueKey('pending-failed-icon'),
              size: 14,
              color: colors.error,
            ),
            const SizedBox(width: 4),
            Text(
              context.l10n.pendingFailedToSend,
              key: const ValueKey('pending-failed-label'),
              style: AppTypography.caption.copyWith(
                color: colors.error,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              key: const ValueKey('pending-retry-button'),
              onPressed: () => ref
                  .read(conversationDetailStoreProvider.notifier)
                  .retrySend(pending.localId),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                context.l10n.pendingRetry,
                style: AppTypography.caption.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              key: const ValueKey('pending-dismiss-button'),
              onPressed: () => ref
                  .read(conversationDetailStoreProvider.notifier)
                  .dismissPendingMessage(pending.localId),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                context.l10n.pendingDismiss,
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            bubble,
            statusRow,
          ],
        ),
      ),
    );
  }
}
