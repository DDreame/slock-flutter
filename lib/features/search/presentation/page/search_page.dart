import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/search/application/search_state.dart';
import 'package:slock_app/features/search/application/search_store.dart';
import 'package:slock_app/features/search/data/search_repository.dart';
import 'package:slock_app/features/search/presentation/widget/search_channel_result_item.dart';
import 'package:slock_app/features/search/presentation/widget/search_contact_result_item.dart';
import 'package:slock_app/features/search/presentation/widget/search_result_item.dart';
import 'package:slock_app/features/search/presentation/widget/search_scope_tabs.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key, required this.serverId});

  final String serverId;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        currentSearchServerIdProvider.overrideWithValue(
          ServerScopeId(serverId),
        ),
      ],
      child: const _SearchScreen(),
    );
  }
}

class _SearchScreen extends ConsumerStatefulWidget {
  const _SearchScreen();

  @override
  ConsumerState<_SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<_SearchScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchStoreProvider);
    final colors = Theme.of(context).extension<AppColors>();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const ValueKey('search-input'),
          controller: _controller,
          autofocus: true,
          style: AppTypography.body.copyWith(
            color: colors?.text ?? Theme.of(context).colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: 'Search messages, channels, or contacts...',
            hintStyle: AppTypography.body.copyWith(
              color: colors?.textTertiary ??
                  Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            border: InputBorder.none,
            prefixIcon: Icon(
              Icons.search,
              size: 20,
              color: colors?.textTertiary ??
                  Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 20,
            ),
          ),
          onChanged: ref.read(searchStoreProvider.notifier).updateQuery,
        ),
        actions: [
          if (state.query.isNotEmpty)
            IconButton(
              key: const ValueKey('search-clear'),
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                ref.read(searchStoreProvider.notifier).clear();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          SearchScopeTabs(
            activeScope: state.scope,
            messageCount:
                state.status == SearchStatus.idle ? null : state.messageCount,
            channelCount:
                state.status == SearchStatus.idle ? null : state.channelCount,
            contactCount:
                state.status == SearchStatus.idle ? null : state.contactCount,
            onScopeChanged: ref.read(searchStoreProvider.notifier).setScope,
          ),
          if (state.status != SearchStatus.idle)
            _FilterChipBar(state: state, ref: ref),
          Expanded(
            child: _buildBody(state),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(SearchState state) {
    return switch (state.status) {
      SearchStatus.idle => const Center(
          key: ValueKey('search-idle'),
          child: Text('Type to search messages, channels, or contacts.'),
        ),
      SearchStatus.searching when !state.hasResults => const Center(
          key: ValueKey('search-searching'),
          child: CircularProgressIndicator(),
        ),
      SearchStatus.failure when !state.hasResults => _SearchFailureView(
          message: state.failure?.message ?? 'Search failed.',
        ),
      _ when state.hasResults => _buildScopedResults(state),
      SearchStatus.success when !state.hasResults => const Center(
          key: ValueKey('search-empty'),
          child: Text('No results found.'),
        ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildScopedResults(SearchState state) {
    switch (state.scope) {
      case SearchScope.all:
        return _SearchAllResultsList(state: state, query: state.query);
      case SearchScope.messages:
        return _SearchMessageResultsList(state: state, query: state.query);
      case SearchScope.channels:
        return _SearchChannelResultsList(state: state, query: state.query);
      case SearchScope.contacts:
        return _SearchContactResultsList(state: state, query: state.query);
    }
  }
}

/// Shows all results (messages + channels + contacts) in a combined list.
class _SearchAllResultsList extends StatelessWidget {
  const _SearchAllResultsList({required this.state, required this.query});

  final SearchState state;
  final String query;

  @override
  Widget build(BuildContext context) {
    final results = state.mergedResults;
    final channelResults = state.channelResults;
    final contactResults = state.contactResults;

    return ListView(
      key: const ValueKey('search-results'),
      padding: const EdgeInsets.all(16),
      children: [
        if (channelResults.isNotEmpty) ...[
          _SectionHeader(label: 'Channels', count: channelResults.length),
          const SizedBox(height: 8),
          for (final channel in channelResults.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SearchChannelResultItem(
                result: channel,
                query: query,
                onTap: () => _navigateToChannel(context, channel),
              ),
            ),
          if (channelResults.length > 3)
            _ViewAllButton(
              onTap: () {
                final store = ProviderScope.containerOf(context)
                    .read(searchStoreProvider.notifier);
                store.setScope(SearchScope.channels);
              },
            ),
          const SizedBox(height: 16),
        ],
        if (contactResults.isNotEmpty) ...[
          _SectionHeader(label: 'Contacts', count: contactResults.length),
          const SizedBox(height: 8),
          for (final contact in contactResults.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SearchContactResultItem(
                result: contact,
                query: query,
                onTap: () => _navigateToContact(context, contact),
              ),
            ),
          if (contactResults.length > 3)
            _ViewAllButton(
              onTap: () {
                final store = ProviderScope.containerOf(context)
                    .read(searchStoreProvider.notifier);
                store.setScope(SearchScope.contacts);
              },
            ),
          const SizedBox(height: 16),
        ],
        if (results.isNotEmpty) ...[
          _SectionHeader(label: 'Messages', count: results.length),
          const SizedBox(height: 8),
          for (final result in results)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SearchResultItem(
                result: result,
                query: query,
                onTap: () => _navigateToConversation(context, result),
              ),
            ),
          if (state.isRemoteSearching)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          if (state.hasMore && !state.isRemoteSearching)
            _LoadMoreButton(
              onTap: () {
                final store = ProviderScope.containerOf(context)
                    .read(searchStoreProvider.notifier);
                store.loadMore();
              },
            ),
        ],
      ],
    );
  }

  void _navigateToChannel(BuildContext context, SearchChannelResult channel) {
    final serverId = ProviderScope.containerOf(context)
        .read(currentSearchServerIdProvider)
        .value;
    final segment = channel.surface == 'direct_message' ? 'dms' : 'channels';
    context.push('/servers/$serverId/$segment/${channel.channelId}');
  }

  void _navigateToContact(BuildContext context, SearchContactResult contact) {
    _openContactDm(context, contact);
  }

  void _navigateToConversation(
    BuildContext context,
    SearchResultMessage result,
  ) {
    _pushMessageInContext(context, result);
  }
}

/// Navigate to a message in its conversation context.
///
/// If the message started a thread, navigates to the thread replies page.
/// Otherwise, navigates to the channel/DM with a `messageId` query parameter
/// so the conversation page can scroll to the matched message.
void _pushMessageInContext(BuildContext context, SearchResultMessage result) {
  if (result.channelId == null) return;
  final serverId = ProviderScope.containerOf(context)
      .read(currentSearchServerIdProvider)
      .value;

  final message = result.message;

  // If the message started a thread, navigate to thread replies.
  if (message.threadId != null && message.threadId!.isNotEmpty) {
    final threadUri = Uri(
      path: '/servers/$serverId/threads/${message.id}/replies',
      queryParameters: {
        'channelId': result.channelId!,
        'threadChannelId': message.threadId!,
      },
    );
    context.push(threadUri.toString());
    return;
  }

  // Navigate to channel/DM with messageId for scroll-to-message context.
  final segment = result.surface == 'direct_message' ? 'dms' : 'channels';
  final uri = Uri(
    path: '/servers/$serverId/$segment/${result.channelId}',
    queryParameters: {'messageId': message.id},
  );
  context.push(uri.toString());
}

/// Open or create a DM with a contact and navigate to it.
Future<void> _openContactDm(
  BuildContext context,
  SearchContactResult contact,
) async {
  final container = ProviderScope.containerOf(context);
  final serverId = container.read(currentSearchServerIdProvider);
  final memberRepo = container.read(memberRepositoryProvider);

  try {
    final channelId = await memberRepo.openDirectMessage(
      serverId,
      userId: contact.identityId,
    );
    if (!context.mounted) return;
    context.push('/servers/${serverId.value}/dms/$channelId');
  } on AppFailure {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open conversation.')),
    );
  }
}

/// Shows only message results.
class _SearchMessageResultsList extends StatelessWidget {
  const _SearchMessageResultsList({required this.state, required this.query});

  final SearchState state;
  final String query;

  @override
  Widget build(BuildContext context) {
    final results = state.mergedResults;
    if (results.isEmpty && !state.isRemoteSearching) {
      return const Center(
        key: ValueKey('search-empty'),
        child: Text('No results found.'),
      );
    }
    final hasTrailer =
        state.isRemoteSearching || (state.hasMore && !state.isRemoteSearching);
    return ListView.separated(
      key: const ValueKey('search-results'),
      padding: const EdgeInsets.all(16),
      itemCount: results.length + (hasTrailer ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == results.length) {
          if (state.isRemoteSearching) {
            return const Center(
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
          return _LoadMoreButton(
            onTap: () {
              final store = ProviderScope.containerOf(context)
                  .read(searchStoreProvider.notifier);
              store.loadMore();
            },
          );
        }
        final result = results[index];
        return SearchResultItem(
          result: result,
          query: query,
          onTap: () => _navigateToConversation(context, result),
        );
      },
    );
  }

  void _navigateToConversation(
    BuildContext context,
    SearchResultMessage result,
  ) {
    _pushMessageInContext(context, result);
  }
}

/// Shows only channel/DM results.
class _SearchChannelResultsList extends StatelessWidget {
  const _SearchChannelResultsList({required this.state, required this.query});

  final SearchState state;
  final String query;

  @override
  Widget build(BuildContext context) {
    final results = state.channelResults;
    if (results.isEmpty) {
      return const Center(
        key: ValueKey('search-empty'),
        child: Text('No results found.'),
      );
    }
    return ListView.separated(
      key: const ValueKey('search-channel-results'),
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final channel = results[index];
        return SearchChannelResultItem(
          result: channel,
          query: query,
          onTap: () => _navigateToChannel(context, channel),
        );
      },
    );
  }

  void _navigateToChannel(BuildContext context, SearchChannelResult channel) {
    final serverId = ProviderScope.containerOf(context)
        .read(currentSearchServerIdProvider)
        .value;
    final segment = channel.surface == 'direct_message' ? 'dms' : 'channels';
    context.push('/servers/$serverId/$segment/${channel.channelId}');
  }
}

/// Shows only contact results.
class _SearchContactResultsList extends StatelessWidget {
  const _SearchContactResultsList({required this.state, required this.query});

  final SearchState state;
  final String query;

  @override
  Widget build(BuildContext context) {
    final results = state.contactResults;
    if (results.isEmpty) {
      return const Center(
        key: ValueKey('search-empty'),
        child: Text('No results found.'),
      );
    }
    return ListView.separated(
      key: const ValueKey('search-contact-results'),
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final contact = results[index];
        return SearchContactResultItem(
          result: contact,
          query: query,
          onTap: () => _openContactDm(context, contact),
        );
      },
    );
  }
}

class _SearchFailureView extends ConsumerWidget {
  const _SearchFailureView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      key: const ValueKey('search-failure'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('search-retry'),
              onPressed: ref.read(searchStoreProvider.notifier).retry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>();
    return Row(
      children: [
        Text(
          label,
          style: AppTypography.label.copyWith(
            color: colors?.textSecondary ??
                Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '($count)',
          style: AppTypography.caption.copyWith(
            color: colors?.textTertiary ??
                Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ViewAllButton extends StatelessWidget {
  const _ViewAllButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>();
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: onTap,
        child: Text(
          'View all',
          style: AppTypography.label.copyWith(
            color: colors?.primary ?? Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Filter chip bar displayed below scope tabs when results are visible.
class _FilterChipBar extends StatelessWidget {
  const _FilterChipBar({required this.state, required this.ref});

  final SearchState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final store = ref.read(searchStoreProvider.notifier);
    final colors = Theme.of(context).extension<AppColors>();

    return Padding(
      key: const ValueKey('search-filter-bar'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
        vertical: AppSpacing.xs,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          // Sender filter chip.
          FilterChip(
            key: const ValueKey('search-filter-sender'),
            label: Text(
              state.senderFilter != null
                  ? 'From: ${state.senderFilter}'
                  : 'Sender',
            ),
            selected: state.senderFilter != null,
            onSelected: (_) => _showSenderInput(context, store),
            onDeleted: state.senderFilter != null
                ? () => store.setSenderFilter(null)
                : null,
          ),

          // Sort toggle chip.
          ChoiceChip(
            key: const ValueKey('search-filter-sort'),
            label: Text(
              state.sortBy == SearchSortBy.newest ? 'Newest' : 'Oldest',
            ),
            selected: state.sortBy != SearchSortBy.newest,
            onSelected: (_) {
              store.setSortBy(
                state.sortBy == SearchSortBy.newest
                    ? SearchSortBy.oldest
                    : SearchSortBy.newest,
              );
            },
          ),

          // Channel filter chip.
          FilterChip(
            key: const ValueKey('search-filter-channel'),
            label: Text(
              state.channelFilter != null
                  ? 'In: ${state.channelFilter}'
                  : 'Channel',
            ),
            selected: state.channelFilter != null,
            onSelected: (_) => _showChannelInput(context, store),
            onDeleted: state.channelFilter != null
                ? () => store.setChannelFilter(null)
                : null,
          ),

          // Clear all filters.
          if (state.hasActiveFilters)
            ActionChip(
              key: const ValueKey('search-filter-clear'),
              label: const Text('Clear'),
              avatar: Icon(
                Icons.clear,
                size: 16,
                color: colors?.textTertiary,
              ),
              onPressed: store.clearFilters,
            ),
        ],
      ),
    );
  }

  Future<void> _showSenderInput(
    BuildContext context,
    SearchStore store,
  ) async {
    final result = await _showTextInputDialog(
      context: context,
      title: 'Filter by sender',
      hintText: 'Enter sender name…',
      initialValue: state.senderFilter,
    );
    if (result != null) {
      store.setSenderFilter(result.isEmpty ? null : result);
    }
  }

  Future<void> _showChannelInput(
    BuildContext context,
    SearchStore store,
  ) async {
    final result = await _showTextInputDialog(
      context: context,
      title: 'Filter by channel',
      hintText: 'Enter channel name…',
      initialValue: state.channelFilter,
    );
    if (result != null) {
      store.setChannelFilter(result.isEmpty ? null : result);
    }
  }
}

/// Simple text input dialog for filter values.
Future<String?> _showTextInputDialog({
  required BuildContext context,
  required String title,
  required String hintText,
  String? initialValue,
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        key: const ValueKey('search-filter-input'),
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hintText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Apply'),
        ),
      ],
    ),
  );
}

/// "Load more" button shown when `hasMore` is true.
class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>();
    return Center(
      key: const ValueKey('search-load-more'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: TextButton(
          onPressed: onTap,
          child: Text(
            'Load more',
            style: AppTypography.label.copyWith(
              color: colors?.primary ?? Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
