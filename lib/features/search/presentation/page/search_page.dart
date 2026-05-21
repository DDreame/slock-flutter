import 'package:flutter/foundation.dart' show listEquals, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_spacing.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/search/application/search_history_store.dart';
import 'package:slock_app/features/search/application/search_state.dart';
import 'package:slock_app/features/search/application/search_store.dart';
import 'package:slock_app/features/search/data/search_repository.dart';
import 'package:slock_app/features/search/presentation/widgets/search_channel_result_item.dart';
import 'package:slock_app/features/search/presentation/widgets/search_contact_result_item.dart';
import 'package:slock_app/features/search/presentation/widgets/search_result_item.dart';
import 'package:slock_app/features/search/presentation/widgets/search_scope_tabs.dart';
import 'package:slock_app/l10n/l10n.dart';

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

@visibleForTesting
class SearchPageDebug {
  static int searchBodyBuildCount = 0;
}

class _SearchScreen extends ConsumerStatefulWidget {
  const _SearchScreen();

  @override
  ConsumerState<_SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<_SearchScreen> {
  late final TextEditingController _controller;
  late final Widget _body;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _body = _SearchBody(controller: _controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>();
    final l10n = context.l10n;

    // INV-SELECT-669: Only watch query.isNotEmpty for the clear button.
    final showClearButton = ref.watch(
      searchStoreProvider.select((s) => s.query.isNotEmpty),
    );

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
            hintText: l10n.searchHintText,
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
          onSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.isNotEmpty) {
              ref.read(searchHistoryProvider.notifier).addQuery(trimmed);
            }
          },
          onChanged: ref.read(searchStoreProvider.notifier).updateQuery,
        ),
        actions: [
          if (showClearButton)
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
      body: _body,
    );
  }
}

class _SearchBodyState extends SearchState {
  _SearchBodyState(SearchState state)
      : super(
          query: state.query,
          status: state.status,
          scope: state.scope,
          localResults: state.localResults,
          remoteResults: state.remoteResults,
          channelResults: state.channelResults,
          contactResults: state.contactResults,
          hasMore: state.hasMore,
          isRemoteSearching: state.isRemoteSearching,
          failure: state.failure,
          senderFilter: state.senderFilter,
          sortBy: state.sortBy,
          channelFilter: state.channelFilter,
        );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _SearchBodyState &&
            runtimeType == other.runtimeType &&
            status == other.status &&
            scope == other.scope &&
            listEquals(localResults, other.localResults) &&
            listEquals(remoteResults, other.remoteResults) &&
            listEquals(channelResults, other.channelResults) &&
            listEquals(contactResults, other.contactResults) &&
            hasMore == other.hasMore &&
            isRemoteSearching == other.isRemoteSearching &&
            failure == other.failure &&
            senderFilter == other.senderFilter &&
            sortBy == other.sortBy &&
            channelFilter == other.channelFilter;
  }

  @override
  int get hashCode => Object.hash(
        status,
        scope,
        Object.hashAll(localResults),
        Object.hashAll(remoteResults),
        Object.hashAll(channelResults),
        Object.hashAll(contactResults),
        hasMore,
        isRemoteSearching,
        failure,
        senderFilter,
        sortBy,
        channelFilter,
      );
}

/// INV-SELECT-669: Separate consumer for search body — watches only
/// status/scope/results/filters without triggering AppBar rebuilds.
class _SearchBody extends ConsumerWidget {
  const _SearchBody({required this.controller});

  final TextEditingController? controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(() {
      SearchPageDebug.searchBodyBuildCount++;
      return true;
    }());
    final state = ref.watch(
      searchStoreProvider.select(_SearchBodyState.new),
    );

    return Column(
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
          child: _buildBody(context, state),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, SearchState state) {
    final l10n = context.l10n;
    return switch (state.status) {
      SearchStatus.idle => _SearchIdleView(
          controller: controller,
        ),
      SearchStatus.searching when !state.hasResults => const Center(
          key: ValueKey('search-searching'),
          child: CircularProgressIndicator(),
        ),
      SearchStatus.failure when !state.hasResults => _SearchFailureView(
          message: state.failure?.message ?? l10n.searchFailedFallback,
        ),
      _ when state.hasResults => _buildScopedResults(state),
      SearchStatus.success when !state.hasResults => Center(
          key: const ValueKey('search-empty'),
          child: Text(l10n.searchNoResults),
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
    final l10n = context.l10n;

    return ListView(
      key: const ValueKey('search-results'),
      padding: const EdgeInsets.all(16),
      children: [
        if (channelResults.isNotEmpty) ...[
          _SectionHeader(
              label: l10n.searchSectionChannels, count: channelResults.length),
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
          _SectionHeader(
              label: l10n.searchSectionContacts, count: contactResults.length),
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
          _SectionHeader(
              label: l10n.searchSectionMessages, count: results.length),
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
      SnackBar(content: Text(context.l10n.searchCouldNotOpenConversation)),
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
      return Center(
        key: const ValueKey('search-empty'),
        child: Text(context.l10n.searchNoResults),
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
      return Center(
        key: const ValueKey('search-empty'),
        child: Text(context.l10n.searchNoResults),
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
      return Center(
        key: const ValueKey('search-empty'),
        child: Text(context.l10n.searchNoResults),
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

class _SearchIdleView extends ConsumerWidget {
  const _SearchIdleView({required this.controller});

  final TextEditingController? controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchHistoryProvider);
    final l10n = context.l10n;

    if (history.isEmpty) {
      return Center(
        key: const ValueKey('search-idle'),
        child: Text(l10n.searchIdleText),
      );
    }

    return Padding(
      key: const ValueKey('search-idle'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.searchRecentTitle,
                style: AppTypography.label.copyWith(
                  color:
                      Theme.of(context).extension<AppColors>()?.textSecondary,
                ),
              ),
              TextButton(
                key: const ValueKey('search-history-clear'),
                onPressed: () {
                  ref.read(searchHistoryProvider.notifier).clearHistory();
                },
                child: Text(l10n.searchRecentClear),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final query in history)
                ActionChip(
                  label: Text(query),
                  onPressed: () {
                    controller?.text = query;
                    controller?.selection = TextSelection.fromPosition(
                      TextPosition(offset: query.length),
                    );
                    ref.read(searchStoreProvider.notifier).updateQuery(query);
                    ref.read(searchHistoryProvider.notifier).addQuery(query);
                  },
                ),
            ],
          ),
        ],
      ),
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
              child: Text(context.l10n.searchRetry),
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
          context.l10n.searchViewAll,
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
    final l10n = context.l10n;

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
                  ? l10n.searchFilterFromPrefix(state.senderFilter!)
                  : l10n.searchFilterSender,
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
              state.sortBy == SearchSortBy.newest
                  ? l10n.searchFilterNewest
                  : l10n.searchFilterOldest,
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
                  ? l10n.searchFilterInPrefix(state.channelFilter!)
                  : l10n.searchFilterChannel,
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
              label: Text(l10n.searchFilterClear),
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
    final l10n = context.l10n;
    final result = await _showTextInputDialog(
      context: context,
      title: l10n.searchFilterBySenderTitle,
      hintText: l10n.searchFilterBySenderHint,
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
    final l10n = context.l10n;
    final result = await _showTextInputDialog(
      context: context,
      title: l10n.searchFilterByChannelTitle,
      hintText: l10n.searchFilterByChannelHint,
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
  final l10n = context.l10n;
  // INV-SEARCH-CONTROLLER-DISPOSE-1: Dispose controller when dialog closes
  // to prevent memory leaks.
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
          child: Text(l10n.searchFilterCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(l10n.searchFilterApply),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
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
            context.l10n.searchLoadMore,
            style: AppTypography.label.copyWith(
              color: colors?.primary ?? Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
