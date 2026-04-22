import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/search/application/search_state.dart';
import 'package:slock_app/features/search/application/search_store.dart';
import 'package:slock_app/features/search/data/search_repository.dart';
import 'package:slock_app/features/search/presentation/widget/search_result_item.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key, required this.serverId});

  final String serverId;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        currentSearchServerIdProvider
            .overrideWithValue(ServerScopeId(serverId)),
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

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const ValueKey('search-input'),
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search messages...',
            border: InputBorder.none,
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
      body: switch (state.status) {
        SearchStatus.idle => const Center(
            key: ValueKey('search-idle'),
            child: Text('Type to search messages.'),
          ),
        SearchStatus.searching when !state.hasResults => const Center(
            key: ValueKey('search-searching'),
            child: CircularProgressIndicator(),
          ),
        SearchStatus.failure when !state.hasResults => _SearchFailureView(
            message: state.failure?.message ?? 'Search failed.',
          ),
        _ when state.hasResults => _SearchResultsList(
            state: state,
            query: state.query,
          ),
        SearchStatus.success when !state.hasResults => const Center(
            key: ValueKey('search-empty'),
            child: Text('No results found.'),
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({
    required this.state,
    required this.query,
  });

  final SearchState state;
  final String query;

  @override
  Widget build(BuildContext context) {
    final results = state.mergedResults;
    return ListView.separated(
      key: const ValueKey('search-results'),
      padding: const EdgeInsets.all(16),
      itemCount: results.length + (state.isRemoteSearching ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == results.length) {
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
    if (result.channelId == null) return;
    final serverId = ProviderScope.containerOf(context)
        .read(currentSearchServerIdProvider)
        .value;
    context.go('/servers/$serverId/channels/${result.channelId}');
  }
}

class _SearchFailureView extends StatelessWidget {
  const _SearchFailureView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('search-failure'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
