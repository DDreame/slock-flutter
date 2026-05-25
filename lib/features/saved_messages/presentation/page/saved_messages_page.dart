import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/app_loading_indicator.dart';
import 'package:slock_app/app/widgets/empty_state_widget.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_state.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_store.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart';
import 'package:slock_app/l10n/l10n.dart';

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
      () => ref.read(savedMessagesStoreProvider.notifier).ensureLoaded(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(savedMessagesStoreProvider);
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Saved',
          style: AppTypography.title.copyWith(color: colors.text),
        ),
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      backgroundColor: colors.surface,
      body: switch (state.status) {
        SavedMessagesStatus.initial ||
        SavedMessagesStatus.loading when state.items.isEmpty =>
          const AppLoadingIndicator(),
        SavedMessagesStatus.loading => _SavedMessagesListSurface(
            state: state,
            isRefreshing: true,
          ),
        SavedMessagesStatus.initial ||
        SavedMessagesStatus.failure =>
          _SavedMessagesFailureView(
            message: state.failure?.userMessage(context.l10n) ??
                context.l10n.errorUnknown,
            onRetry: ref.read(savedMessagesStoreProvider.notifier).retry,
          ),
        SavedMessagesStatus.success when state.items.isEmpty =>
          const EmptyStateWidget(
            key: ValueKey('saved-messages-empty'),
            icon: Icons.bookmark_outline,
            title: 'No saved messages',
            subtitle: 'Long-press a message and tap "Save" to bookmark it.\n'
                'Saved messages appear here for quick reference.',
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

class _SavedMessagesList extends ConsumerStatefulWidget {
  const _SavedMessagesList({required this.state});

  final SavedMessagesState state;

  @override
  ConsumerState<_SavedMessagesList> createState() => _SavedMessagesListState();
}

class _SavedMessagesListState extends ConsumerState<_SavedMessagesList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(savedMessagesStoreProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.state.items;
    return RefreshIndicator(
      onRefresh: () => ref.read(savedMessagesStoreProvider.notifier).load(),
      child: ListView.separated(
        key: const ValueKey('saved-messages-list'),
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final item = items[index];
          return _SavedMessageCard(
            item: item,
            onTap: () => _navigateToSource(context, item),
            onUnsave: () => ref
                .read(savedMessagesStoreProvider.notifier)
                .unsaveMessage(item.message.id),
          );
        },
      ),
    );
  }

  void _navigateToSource(
    BuildContext context,
    SavedMessageItem item,
  ) {
    final serverId = ProviderScope.containerOf(
      context,
    ).read(currentSavedMessagesServerIdProvider).value;

    // Thread messages navigate to the thread replies page.
    // Mirrors the search page contract (search_page.dart:280-287):
    //   path: /threads/${parentMessageId}/replies
    //   query: channelId, threadChannelId, messageId
    if (item.isThreadMessage) {
      final parentId = item.threadRouteParentId!;
      final queryParams = <String, String>{
        'channelId': item.channelId,
        if (item.threadChannelId != null && item.threadChannelId!.isNotEmpty)
          'threadChannelId': item.threadChannelId!,
        // Highlight the exact saved message within the thread.
        if (item.message.id != parentId) 'messageId': item.message.id,
      };
      final uri = Uri(
        path: '/servers/$serverId/threads/$parentId/replies',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      context.push(uri.toString());
      return;
    }

    // Channel/DM messages navigate to the conversation with highlight.
    final segment = item.surface == 'direct_message' ? 'dms' : 'channels';
    context.push(
      '/servers/$serverId/$segment/${item.channelId}'
      '?messageId=${item.message.id}',
    );
  }
}

class _SavedMessageCard extends StatelessWidget {
  const _SavedMessageCard({
    required this.item,
    required this.onTap,
    required this.onUnsave,
  });

  final SavedMessageItem item;
  final VoidCallback onTap;
  final VoidCallback onUnsave;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final message = item.message;

    return InkWell(
      key: ValueKey('saved-message-${message.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(AppSpacing.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: avatar + sender + channel + actions
            Row(
              children: [
                _SenderAvatar(
                  name: message.senderLabel,
                  colors: colors,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          message.senderLabel,
                          style:
                              AppTypography.label.copyWith(color: colors.text),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        _sourceLabel(item),
                        style: AppTypography.caption
                            .copyWith(color: colors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Unsave action
                IconButton(
                  key: ValueKey('saved-message-unsave-${message.id}'),
                  icon: Icon(
                    Icons.bookmark_remove_outlined,
                    size: 20,
                    color: colors.textSecondary,
                  ),
                  onPressed: onUnsave,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  tooltip: 'Unsave',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // Message content preview
            Padding(
              padding: const EdgeInsets.only(
                left: 32 + AppSpacing.sm, // avatar width + gap
              ),
              child: Text(
                message.content,
                style: AppTypography.body.copyWith(color: colors.text),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // Footer: timestamp
            Padding(
              padding: const EdgeInsets.only(
                left: 32 + AppSpacing.sm,
              ),
              child: Text(
                formatRelativeTime(message.createdAt),
                style:
                    AppTypography.caption.copyWith(color: colors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sourceLabel(SavedMessageItem item) {
    if (item.surface == 'direct_message') {
      return '\u00b7 DM';
    }
    if (item.channelName != null) {
      return '\u00b7 # ${item.channelName}';
    }
    return '';
  }
}

class _SenderAvatar extends StatelessWidget {
  const _SenderAvatar({
    required this.name,
    required this.colors,
  });

  final String name;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTypography.label.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w600,
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
    final colors = Theme.of(context).extension<AppColors>()!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
