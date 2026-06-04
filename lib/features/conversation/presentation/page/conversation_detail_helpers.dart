import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/deep_link_resource_error_view.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/application/outbox_store.dart';
import 'package:slock_app/features/home/application/dm_scope_map_provider.dart';
import 'package:slock_app/features/presence/application/presence_store.dart';
import 'package:slock_app/l10n/l10n.dart';

// ---------------------------------------------------------------------------
// Standalone helper widgets extracted from conversation_detail_page.dart
// to reduce god-widget LOC.
// ---------------------------------------------------------------------------

class ConversationFailureView extends StatelessWidget {
  const ConversationFailureView(
      {super.key, required this.state, required this.onRetry});

  final ConversationDetailState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = state.failure;
    if (DeepLinkResourceErrorView.handles(failure)) {
      return DeepLinkResourceErrorView(failure: failure!);
    }

    return Center(
      key: const ValueKey('conversation-error'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.conversationLoadFailed(state.resolvedTitle),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              state.failure?.userMessage(context.l10n) ??
                  context.l10n.errorUnknown,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: onRetry,
                child: Text(context.l10n.conversationRetry)),
          ],
        ),
      ),
    );
  }
}

class ConversationEmptyView extends StatelessWidget {
  const ConversationEmptyView({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Center(
      key: const ValueKey('conversation-empty'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: colors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.l10n.conversationEmpty(title),
              textAlign: TextAlign.center,
              style: AppTypography.title.copyWith(color: colors.text),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.l10n.conversationEmptySubtitle,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DM presence subtitle — shown in the app bar for direct messages.
// ---------------------------------------------------------------------------

class DmPresenceSubtitle extends ConsumerWidget {
  const DmPresenceSubtitle({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // #654: O(1) map lookup via dmScopeMapProvider instead of O(3n) linear scan.
    final peerId = ref.watch(
      dmScopeMapProvider.select((map) => map[conversationId]?.peerId),
    );
    if (peerId == null) return const SizedBox.shrink();

    final status = ref.watch(
      presenceStoreProvider.select((s) => s.statusOf(peerId)),
    );
    final colors = Theme.of(context).extension<AppColors>()!;

    final dotColor = switch (status) {
      UserPresenceStatus.online => colors.success,
      UserPresenceStatus.idle => colors.warning,
      UserPresenceStatus.offline => colors.textTertiary,
    };
    final statusText = switch (status) {
      UserPresenceStatus.online => context.l10n.conversationPresenceOnline,
      UserPresenceStatus.idle => context.l10n.conversationPresenceIdle,
      UserPresenceStatus.offline => context.l10n.conversationPresenceOffline,
    };

    return Row(
      key: const ValueKey('conversation-dm-presence'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          statusText,
          style: AppTypography.caption.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Banner shown in place of the composer when the channel is archived.
class ArchivedChannelBanner extends StatelessWidget {
  const ArchivedChannelBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      key: const ValueKey('archived-channel-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      color: colors.textTertiary.withValues(alpha: 0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.archive_outlined, size: 16, color: colors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            context.l10n.channelArchivedBanner,
            style: AppTypography.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Banner shown at the top of the conversation when the device is offline.
///
/// Benefits from Riverpod lifecycle management, caching, and .select().
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectivityStatusProvider);
    if (status == ConnectivityStatus.online) return const SizedBox.shrink();

    final colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      key: const ValueKey('offline-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: colors.warning.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 16, color: colors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              context.l10n.conversationOfflineBanner,
              style: AppTypography.caption.copyWith(color: colors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

/// B131: Banner shown above the composer when the outbox has failed messages
/// for the current conversation.
///
/// Shows "N message(s) failed to send" with a "Retry" button that invokes
/// [OutboxStore.retryAllFailed].
class OutboxFailedBanner extends ConsumerWidget {
  const OutboxFailedBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(currentConversationDetailTargetProvider);
    final targetKey = outboxTargetKey(target);
    final failedCount = ref.watch(
      outboxStoreProvider.select((s) => s.failedCountForTarget(targetKey)),
    );
    if (failedCount == 0) return const SizedBox.shrink();

    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = context.l10n;
    return Container(
      key: const ValueKey('outbox-failed-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: colors.error.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: colors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.outboxFailedBanner(failedCount),
              style: AppTypography.caption.copyWith(color: colors.error),
            ),
          ),
          TextButton(
            key: const ValueKey('outbox-failed-retry-button'),
            onPressed: () {
              ref.read(outboxStoreProvider.notifier).retryAllFailed(target);
            },
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              l10n.pendingRetry,
              style: AppTypography.caption.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
