import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/threads/application/threads_realtime_binding.dart';
import 'package:slock_app/features/threads/application/threads_inbox_state.dart';
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
    final state = ref.watch(threadsInboxStoreProvider);
    final store = ref.read(threadsInboxStoreProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Threads')),
      body: switch (state.status) {
        ThreadsInboxStatus.initial ||
        ThreadsInboxStatus.loading when state.items.isEmpty =>
          const Center(
            key: ValueKey('threads-loading'),
            child: CircularProgressIndicator(),
          ),
        ThreadsInboxStatus.loading => _ThreadsListSurface(
            items: state.items,
            isRefreshing: true,
            isCompleting: state.isCompleting,
            onOpen: (item) => context.push(item.routeTarget.toLocation()),
            onDone: store.markDone,
          ),
        ThreadsInboxStatus.initial ||
        ThreadsInboxStatus.failure =>
          _ThreadsFailureView(
            message: state.failure?.message ?? 'Unable to load threads.',
            onRetry: store.retry,
          ),
        ThreadsInboxStatus.success when state.items.isEmpty => const Center(
            key: ValueKey('threads-empty'),
            child: Text('No followed threads yet.'),
          ),
        ThreadsInboxStatus.success => _ThreadsListSurface(
            items: state.items,
            isCompleting: state.isCompleting,
            onOpen: (item) => context.push(item.routeTarget.toLocation()),
            onDone: store.markDone,
          ),
      },
    );
  }
}

class _ThreadsListSurface extends StatelessWidget {
  const _ThreadsListSurface({
    required this.items,
    required this.isCompleting,
    required this.onOpen,
    required this.onDone,
    this.isRefreshing = false,
  });

  final List<ThreadInboxItem> items;
  final bool Function(String threadChannelId) isCompleting;
  final void Function(ThreadInboxItem item) onOpen;
  final Future<void> Function(ThreadInboxItem item) onDone;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView.separated(
          key: const ValueKey('threads-success'),
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            return _ThreadInboxCard(
              item: item,
              isCompleting:
                  isCompleting(item.routeTarget.threadChannelId ?? ''),
              onOpen: () => onOpen(item),
              onDone: () => onDone(item),
            );
          },
        ),
        if (isRefreshing)
          const Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(
              key: ValueKey('threads-refresh-indicator'),
            ),
          ),
      ],
    );
  }
}

class _ThreadsFailureView extends StatelessWidget {
  const _ThreadsFailureView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('threads-error'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
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
  });

  final ThreadInboxItem item;
  final bool isCompleting;
  final VoidCallback onOpen;
  final Future<void> Function() onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final threadChannelId = item.routeTarget.threadChannelId;

    return Card(
      key: ValueKey('thread-item-${item.routeTarget.parentMessageId}'),
      child: ListTile(
        onTap: onOpen,
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
              '${item.replyCount} replies'
              '${item.unreadCount > 0 ? ' • ${item.unreadCount} unread' : ''}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        trailing: threadChannelId == null
            ? const Icon(Icons.chevron_right)
            : FilledButton.tonal(
                key:
                    ValueKey('thread-done-${item.routeTarget.parentMessageId}'),
                onPressed: isCompleting ? null : onDone,
                child: Text(isCompleting ? '...' : 'Done'),
              ),
      ),
    );
  }
}
