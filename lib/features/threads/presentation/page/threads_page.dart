import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/widgets/app_error_view.dart';
import 'package:slock_app/app/widgets/list_action_sheet.dart';
import 'package:slock_app/app/widgets/swipe_action_wrapper.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/core/haptic/haptic_service.dart';
import 'package:slock_app/features/threads/application/threads_realtime_binding.dart';
import 'package:slock_app/features/threads/application/threads_inbox_state.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/features/threads/application/threads_inbox_store.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';

class ThreadsPage extends StatelessWidget {
  final String serverId;

  const ThreadsPage({super.key, required this.serverId});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        currentThreadsServerIdProvider
            .overrideWithValue(ServerScopeId(serverId)),
      ],
      child: const _ThreadsScreen(),
    );
  }
}

class _ThreadsScreen extends ConsumerWidget {
  const _ThreadsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(threadsInboxRealtimeBindingProvider);
    // INV-SEL-816: Narrow .select() to scaffold-driving fields only.
    // completingThreadIds is consumed exclusively by _ThreadsListSurface,
    // so changes to it no longer rebuild the entire page scaffold.
    final (:status, :items, :failure) = ref.watch(
      threadsInboxStoreProvider.select(
        (s) => (status: s.status, items: s.items, failure: s.failure),
      ),
    );
    final store = ref.read(threadsInboxStoreProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.threadsTitle)),
      body: switch (status) {
        ThreadsInboxStatus.initial ||
        ThreadsInboxStatus.loading when items.isEmpty =>
          const Center(
            key: ValueKey('threads-loading'),
            child: CircularProgressIndicator(),
          ),
        ThreadsInboxStatus.loading => _ThreadsListSurface(
            items: items,
            onOpen: (item) => context.push(item.routeTarget.toLocation()),
            onDone: store.markDone,
            onRefresh: store.load,
          ),
        ThreadsInboxStatus.initial ||
        ThreadsInboxStatus.failure =>
          AppErrorView(
            message:
                failure?.userMessage(context.l10n) ?? context.l10n.errorUnknown,
            onRetry: () => store.retry(),
          ),
        ThreadsInboxStatus.success when items.isEmpty => Center(
            key: const ValueKey('threads-empty'),
            child: Text(context.l10n.threadsEmpty),
          ),
        ThreadsInboxStatus.success => _ThreadsListSurface(
            items: items,
            onOpen: (item) => context.push(item.routeTarget.toLocation()),
            onDone: store.markDone,
            onRefresh: store.load,
          ),
      },
    );
  }
}

class _ThreadsListSurface extends ConsumerWidget {
  const _ThreadsListSurface({
    required this.items,
    required this.onOpen,
    required this.onDone,
    required this.onRefresh,
  });

  final List<ThreadInboxItem> items;
  final void Function(ThreadInboxItem item) onOpen;
  final Future<void> Function(ThreadInboxItem item) onDone;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // INV-SEL-816: Watch completingThreadIds here (leaf) instead of in the
    // scaffold — only this list surface rebuilds when completion state changes.
    final completingThreadIds = ref.watch(
      threadsInboxStoreProvider.select((s) => s.completingThreadIds),
    );

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        key: const ValueKey('threads-success'),
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          final threadChannelId = item.routeTarget.threadChannelId ?? '';
          return _ThreadInboxCard(
            item: item,
            isCompleting: completingThreadIds.contains(threadChannelId),
            onOpen: () => onOpen(item),
            onDone: () => onDone(item),
            onHaptic: () => ref.read(hapticServiceProvider).mediumImpact(),
          );
        },
      ),
    );
  }
}

class _ThreadInboxCard extends StatelessWidget {
  const _ThreadInboxCard({
    required this.item,
    required this.isCompleting,
    required this.onOpen,
    required this.onDone,
    this.onHaptic,
  });

  final ThreadInboxItem item;
  final bool isCompleting;
  final VoidCallback onOpen;
  final Future<void> Function() onDone;
  final Future<void> Function()? onHaptic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    final threadChannelId = item.routeTarget.threadChannelId;
    final canMarkDone = threadChannelId != null && !isCompleting;

    return SwipeActionWrapper(
      itemKey: item.routeTarget.parentMessageId,
      enabled: canMarkDone,
      action: SwipeActionConfig(
        label: context.l10n.threadsSwipeDone,
        icon: Icons.done,
        color: colors.success,
        dismisses: true,
      ),
      onAction: onDone,
      onThresholdHaptic: onHaptic,
      child: Card(
        key: ValueKey('thread-item-${item.routeTarget.parentMessageId}'),
        child: ListTile(
          onTap: onOpen,
          onLongPress: threadChannelId != null
              ? () => _showThreadActions(context)
              : null,
          title: Text(item.resolvedTitle),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.senderName != null)
                Text(
                  item.senderName!,
                  style: theme.textTheme.labelMedium,
                ),
              if (item.preview != null && item.preview!.isNotEmpty)
                Text(
                  item.preview!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 4),
              Text(
                '${context.l10n.threadsRepliesCount(item.replyCount)}'
                '${item.unreadCount > 0 ? ' \u2022 ${context.l10n.threadsUnreadCount(item.unreadCount)}' : ''}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }

  Future<void> _showThreadActions(BuildContext context) async {
    final actions = <ListActionItem>[
      ListActionItem(
        key: 'thread-action-open',
        label: context.l10n.threadsActionOpen,
        icon: Icons.open_in_new,
      ),
      if (!isCompleting)
        ListActionItem(
          key: 'thread-action-done',
          label: context.l10n.threadsActionDone,
          icon: Icons.done,
        ),
    ];

    final result = await showListActionSheet(
      context: context,
      actions: actions,
      title: item.resolvedTitle,
      onOpenHaptic: onHaptic,
    );

    switch (result) {
      case 'thread-action-open':
        onOpen();
      case 'thread-action-done':
        onDone();
    }
  }
}
