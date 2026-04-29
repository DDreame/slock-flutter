import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_state.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_store.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart';

class SavedMessagesPage extends StatelessWidget {
  const SavedMessagesPage({super.key, required this.serverId});

  final String serverId;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        currentSavedMessagesServerIdProvider.overrideWithValue(
          ServerScopeId(serverId),
        ),
      ],
      child: const _SavedMessagesScreen(),
    );
  }
}

class _SavedMessagesScreen extends ConsumerStatefulWidget {
  const _SavedMessagesScreen();

  @override
  ConsumerState<_SavedMessagesScreen> createState() =>
      _SavedMessagesScreenState();
}

class _SavedMessagesScreenState extends ConsumerState<_SavedMessagesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(savedMessagesStoreProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(savedMessagesStoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Messages')),
      body: switch (state.status) {
        SavedMessagesStatus.initial ||
        SavedMessagesStatus.loading when state.items.isEmpty =>
          const Center(child: CircularProgressIndicator()),
        SavedMessagesStatus.loading => _SavedMessagesListSurface(
            state: state,
            isRefreshing: true,
          ),
        SavedMessagesStatus.initial ||
        SavedMessagesStatus.failure =>
          _SavedMessagesFailureView(
            message: state.failure?.message ?? 'Failed to load saved messages.',
            onRetry: ref.read(savedMessagesStoreProvider.notifier).retry,
          ),
        SavedMessagesStatus.success when state.items.isEmpty => const Center(
            child: Text('No saved messages yet.'),
          ),
        SavedMessagesStatus.success => _SavedMessagesListSurface(state: state),
      },
    );
  }
}

class _SavedMessagesListSurface extends StatelessWidget {
  const _SavedMessagesListSurface({
    required this.state,
    this.isRefreshing = false,
  });

  final SavedMessagesState state;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _SavedMessagesList(state: state),
        if (isRefreshing)
          const Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(
              key: ValueKey('saved-messages-refresh-indicator'),
            ),
          ),
      ],
    );
  }
}

class _SavedMessagesList extends ConsumerWidget {
  const _SavedMessagesList({required this.state});

  final SavedMessagesState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = state.items;
    return ListView.separated(
      key: const ValueKey('saved-messages-list'),
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == items.length - 1 && state.hasMore) {
          Future.microtask(
            () => ref.read(savedMessagesStoreProvider.notifier).loadMore(),
          );
        }
        final item = items[index];
        return _SavedMessageCard(
          item: item,
          onTap: () => _navigateToConversation(context, ref, item),
          onLongPress: () => _showUnsaveSheet(context, ref, item),
        );
      },
    );
  }

  void _navigateToConversation(
    BuildContext context,
    WidgetRef ref,
    SavedMessageItem item,
  ) {
    final serverId = ProviderScope.containerOf(
      context,
    ).read(currentSavedMessagesServerIdProvider).value;
    final segment = item.surface == 'direct_message' ? 'dms' : 'channels';
    context.push('/servers/$serverId/$segment/${item.channelId}');
  }

  void _showUnsaveSheet(
    BuildContext context,
    WidgetRef ref,
    SavedMessageItem item,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('saved-message-action-unsave'),
              leading: const Icon(Icons.bookmark_remove),
              title: const Text('Unsave message'),
              onTap: () {
                Navigator.of(context).pop();
                ref
                    .read(savedMessagesStoreProvider.notifier)
                    .unsaveMessage(item.message.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedMessageCard extends StatelessWidget {
  const _SavedMessageCard({
    required this.item,
    required this.onTap,
    this.onLongPress,
  });

  final SavedMessageItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = item.message;

    return GestureDetector(
      onLongPress: onLongPress,
      child: InkWell(
        key: ValueKey('saved-message-${message.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.channelName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '#${item.channelName}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      message.senderLabel,
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                  Text(
                    formatRelativeTime(message.createdAt),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                message.content,
                style: theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedMessagesFailureView extends StatelessWidget {
  const _SavedMessagesFailureView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
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
