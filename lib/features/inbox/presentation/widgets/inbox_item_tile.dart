import 'package:flutter/material.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/features/inbox/application/conversation_projection.dart';
import 'package:slock_app/l10n/l10n.dart';

// ---------------------------------------------------------------------------
// #509: Redesigned inbox item tile — full item anatomy per Z2 mockup.
//
// Layout: [avatar 40×40] [sender + source + @mention + preview + time] [count]
// Unread items: accent-soft bg + 3px left bar + bold sender + accent time + pill
// Read items: transparent bg + no bar + normal weight + tertiary time + no pill
// ---------------------------------------------------------------------------

/// Design tokens for the inbox item tile.
const double _kAvatarSize = 40;
const double _kUnreadBarWidth = 3;

/// A single inbox item row with full anatomy: avatar, sender name, source
/// badge, @mention badge, preview text, time, and unread count pill.
///
/// Visually distinguishes unread items (accent background + left bar + bold)
/// from read items (transparent background + normal weight).
class InboxItemTile extends StatelessWidget {
  const InboxItemTile({
    super.key,
    required this.projection,
    required this.isMentioned,
    required this.onTap,
    this.channelId,
  });

  final ConversationProjection projection;

  /// Whether any unread message in this conversation @mentions the current user.
  final bool isMentioned;

  /// Called when the tile is tapped (navigate to conversation).
  final VoidCallback onTap;

  /// Raw channel ID for widget keying. Falls back to [projection.channelId].
  final String? channelId;

  String get _keyId => channelId ?? projection.channelId ?? projection.id;

  bool get _isUnread => projection.unreadCount > 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;

    final content = InkWell(
      onTap: onTap,
      child: _isUnread
          ? _buildUnreadContainer(colors, l10n)
          : _buildReadContainer(colors, l10n),
    );

    return content;
  }

  // -------------------------------------------------------------------------
  // Unread item: accent-soft bg + 3px left bar
  // -------------------------------------------------------------------------

  Widget _buildUnreadContainer(AppColors colors, AppLocalizations l10n) {
    return Container(
      key: ValueKey('inbox-tile-unread-indicator-$_keyId'),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        border: Border(
          left: BorderSide(
            color: colors.primary,
            width: _kUnreadBarWidth,
          ),
        ),
      ),
      child: _buildTileContent(colors, l10n),
    );
  }

  // -------------------------------------------------------------------------
  // Read item: transparent bg, no bar
  // -------------------------------------------------------------------------

  Widget _buildReadContainer(AppColors colors, AppLocalizations l10n) {
    return _buildTileContent(colors, l10n);
  }

  // -------------------------------------------------------------------------
  // Shared tile content: avatar + text columns + count
  // -------------------------------------------------------------------------

  Widget _buildTileContent(AppColors colors, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
        vertical: AppSpacing.listItemVertical,
      ),
      child: Row(
        children: [
          _buildAvatar(colors),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: _buildTextColumn(colors, l10n)),
          if (_isUnread) ...[
            const SizedBox(width: AppSpacing.sm),
            _buildCountPill(colors, l10n),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Avatar (40×40 circle)
  // -------------------------------------------------------------------------

  Widget _buildAvatar(AppColors colors) {
    final (bgColor, icon) = switch (projection.kind) {
      ConversationProjectionKind.channel => (
          colors.success.withValues(alpha: 0.12),
          Icons.tag,
        ),
      ConversationProjectionKind.dm => (
          colors.warning.withValues(alpha: 0.12),
          Icons.chat_bubble_outline,
        ),
      ConversationProjectionKind.thread => (
          colors.primary.withValues(alpha: 0.12),
          Icons.subdirectory_arrow_right,
        ),
    };

    return Container(
      key: ValueKey('inbox-tile-avatar-$_keyId'),
      width: _kAvatarSize,
      height: _kAvatarSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: colors.textSecondary),
    );
  }

  // -------------------------------------------------------------------------
  // Text column: [sender + source + @mention] [preview] — with time
  // -------------------------------------------------------------------------

  Widget _buildTextColumn(AppColors colors, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: sender name + source badge + @mention badge + time
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      projection.senderName ?? projection.title,
                      style: AppTypography.body.copyWith(
                        color: colors.text,
                        fontWeight:
                            _isUnread ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (projection.sourceLabel != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    _buildSourceBadge(colors),
                  ],
                  if (isMentioned) ...[
                    const SizedBox(width: AppSpacing.xs),
                    _buildMentionBadge(colors, l10n),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _buildTime(colors, l10n),
          ],
        ),

        const SizedBox(height: 2),

        // Row 2: preview text (2-line clamp)
        Text(
          projection.previewText,
          style: AppTypography.bodySmall.copyWith(
            color: _isUnread ? colors.text : colors.textTertiary,
            fontWeight: _isUnread ? FontWeight.w500 : FontWeight.w400,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Source badge (11px pill)
  // -------------------------------------------------------------------------

  Widget _buildSourceBadge(AppColors colors) {
    final isDm = projection.kind == ConversationProjectionKind.dm;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: isDm
            ? colors.primary.withValues(alpha: 0.08)
            : colors.textTertiary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        projection.sourceLabel!,
        style: AppTypography.caption.copyWith(
          color: isDm ? colors.primary : colors.textTertiary,
          fontSize: 11,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // @mention badge (10px "@you")
  // -------------------------------------------------------------------------

  Widget _buildMentionBadge(AppColors colors, AppLocalizations l10n) {
    return Container(
      key: ValueKey('inbox-tile-mention-badge-$_keyId'),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        l10n.inboxMentionBadge,
        style: AppTypography.caption.copyWith(
          color: colors.primary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Time display (12px tabular-nums)
  // -------------------------------------------------------------------------

  Widget _buildTime(AppColors colors, AppLocalizations l10n) {
    if (projection.lastActivityAt == null) return const SizedBox.shrink();
    return Text(
      _formatTime(projection.lastActivityAt!, l10n),
      key: ValueKey('inbox-tile-time-$_keyId'),
      style: AppTypography.label.copyWith(
        color: _isUnread ? colors.primary : colors.textTertiary,
        fontWeight: _isUnread ? FontWeight.w600 : FontWeight.w400,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Count pill
  // -------------------------------------------------------------------------

  Widget _buildCountPill(AppColors colors, AppLocalizations l10n) {
    return Container(
      key: ValueKey('inbox-tile-count-$_keyId'),
      child: Container(
        key: ValueKey('inbox-unread-badge-$_keyId'),
        constraints: const BoxConstraints(minWidth: 20),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          projection.unreadCount > 99
              ? l10n.inboxUnreadCountOverflow
              : '${projection.unreadCount}',
          style: AppTypography.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Time formatting
  // -------------------------------------------------------------------------

  static String _formatTime(DateTime time, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return l10n.inboxTimeNow;
    if (diff.inMinutes < 60) return l10n.inboxTimeMinutes(diff.inMinutes);
    if (diff.inHours < 24) return l10n.inboxTimeHours(diff.inHours);
    if (diff.inDays < 7) return l10n.inboxTimeDays(diff.inDays);
    return '${time.month}/${time.day}';
  }
}
