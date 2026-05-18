import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/list_action_sheet.dart';
import 'package:slock_app/app/widgets/unread_badge.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/inbox/application/conversation_projection.dart';
import 'package:slock_app/features/presence/presentation/widgets/presence_avatar.dart';
import 'package:slock_app/features/realtime/application/list_typing_indicator_store.dart';
import 'package:slock_app/l10n/app_localizations.dart';

/// Whitespace splitter for avatar-initials extraction.
///
/// Promoted from a per-call allocation inside [HomeDirectMessageRow._initials]
/// to a module-level constant, avoiding [RegExp] compilation on every row build.
@visibleForTesting
final dmRowInitialsRegex = RegExp(r'\s+');

class HomeDirectMessageRow extends StatelessWidget {
  const HomeDirectMessageRow({
    super.key,
    required this.directMessage,
    required this.onTap,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isOnline = false,
    this.isAgent = false,
    this.onTogglePin,
    this.onHide,
    this.onMoveUp,
    this.onMoveDown,
  });

  final HomeDirectMessageSummary directMessage;
  final VoidCallback onTap;
  final int unreadCount;
  final bool isPinned;
  final bool isOnline;
  final bool isAgent;
  final VoidCallback? onTogglePin;
  final VoidCallback? onHide;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final hasUnread = unreadCount > 0;

    return Material(
      color: hasUnread ? colors.primaryLight : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: _hasActions ? () => _showActionSheet(context) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal,
            vertical: AppSpacing.listItemVertical,
          ),
          child: Row(
            children: [
              if (isPinned)
                Icon(
                  Icons.push_pin,
                  size: 20,
                  color: hasUnread ? colors.primary : colors.textTertiary,
                )
              else
                SizedBox(
                  width: 32,
                  height: 32,
                  child: directMessage.peerId != null
                      ? PresenceAvatar(
                          key: ValueKey(
                            'dm-presence-${directMessage.scopeId.routeParam}',
                          ),
                          userId: directMessage.peerId!,
                          dotBorderColor:
                              hasUnread ? colors.primaryLight : colors.surface,
                          child: CircleAvatar(
                            key: const ValueKey('dm-avatar'),
                            radius: 16,
                            backgroundColor: colors.primaryLight,
                            child: Text(
                              _initials(directMessage.title),
                              style: AppTypography.label.copyWith(
                                color: colors.primary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                      : Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              key: const ValueKey('dm-avatar'),
                              radius: 16,
                              backgroundColor: colors.primaryLight,
                              child: Text(
                                _initials(directMessage.title),
                                style: AppTypography.label.copyWith(
                                  color: colors.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Positioned(
                              right: -1,
                              bottom: -1,
                              child: Container(
                                key: const ValueKey('dm-status-dot'),
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? colors.success
                                      : colors.textTertiary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: hasUnread
                                        ? colors.primaryLight
                                        : colors.surface,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            directMessage.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body.copyWith(
                              color: colors.text,
                              fontWeight:
                                  hasUnread ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (isAgent) ...[
                          const SizedBox(width: 4),
                          Container(
                            key: const ValueKey('dm-agent-badge'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primaryLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.smart_toy_outlined,
                                  size: 12,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'AGENT',
                                  style: AppTypography.caption.copyWith(
                                    color: colors.primary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Consumer(
                      key: const ValueKey('dm-row-typing-indicator'),
                      builder: (context, ref, _) {
                        final scopeKey =
                            'server:${directMessage.scopeId.serverId.value}'
                            '/dm:${directMessage.scopeId.value}';
                        final typingState = ref.watch(
                          listTypingIndicatorStoreProvider(scopeKey),
                        );
                        final colors =
                            Theme.of(context).extension<AppColors>()!;
                        if (typingState.isActive) {
                          return Text(
                            typingState.displayText!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: colors.primary,
                              fontStyle: FontStyle.italic,
                            ),
                          );
                        }
                        return Text(
                          resolvePreviewText(
                            directMessage.lastMessagePreview,
                            l10n: AppLocalizations.of(context)!,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (directMessage.lastActivityAt != null)
                    Text(
                      formatRelativeTime(directMessage.lastActivityAt!),
                      style: AppTypography.caption.copyWith(
                        color: hasUnread ? colors.primary : colors.textTertiary,
                      ),
                    ),
                  if (hasUnread) ...[
                    const SizedBox(height: 4),
                    UnreadBadge(count: unreadCount),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasActions =>
      onTogglePin != null ||
      onHide != null ||
      onMoveUp != null ||
      onMoveDown != null;

  Future<void> _showActionSheet(BuildContext context) async {
    final actions = <ListActionItem>[
      if (onMoveUp != null)
        const ListActionItem(
          key: 'dm-action-move-up',
          label: 'Move up',
          icon: Icons.arrow_upward,
        ),
      if (onMoveDown != null)
        const ListActionItem(
          key: 'dm-action-move-down',
          label: 'Move down',
          icon: Icons.arrow_downward,
        ),
      if (onTogglePin != null)
        ListActionItem(
          key: 'dm-action-toggle-pin',
          label: isPinned ? 'Unpin conversation' : 'Pin conversation',
          icon: isPinned ? Icons.push_pin_outlined : Icons.push_pin,
        ),
      if (onHide != null)
        const ListActionItem(
          key: 'dm-action-hide',
          label: 'Close conversation',
          icon: Icons.close,
        ),
    ];

    final result = await showListActionSheet(
      context: context,
      actions: actions,
      title: directMessage.title,
    );

    switch (result) {
      case 'dm-action-move-up':
        onMoveUp?.call();
      case 'dm-action-move-down':
        onMoveDown?.call();
      case 'dm-action-toggle-pin':
        onTogglePin?.call();
      case 'dm-action-hide':
        onHide?.call();
    }
  }

  static String _initials(String title) {
    final words = title.trim().split(dmRowInitialsRegex);
    if (words.isEmpty || words[0].isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}
