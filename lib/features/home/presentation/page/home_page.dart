import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/presentation/widgets/home_channel_row.dart';
import 'package:slock_app/features/home/presentation/widgets/home_direct_message_row.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeListStoreProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeListStoreProvider);
    final store = ref.read(homeListStoreProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Slock')),
      body: switch (state.status) {
        HomeListStatus.initial ||
        HomeListStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        HomeListStatus.failure => _HomeErrorState(
            message: state.failure?.message ?? 'Unable to load conversations.',
            onRetry: store.retry,
          ),
        HomeListStatus.success when state.isEmpty => const _HomeEmptyState(),
        HomeListStatus.success => ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              const _HomeSectionHeader(title: 'Channels'),
              for (final channel in state.channels)
                HomeChannelRow(
                  key: ValueKey('channel-${channel.scopeId.routeParam}'),
                  channel: channel,
                  onTap: () =>
                      context.go(store.channelRoutePath(channel.scopeId)),
                ),
              const _HomeSectionHeader(title: 'Direct Messages'),
              for (final directMessage in state.directMessages)
                HomeDirectMessageRow(
                  key: ValueKey('dm-${directMessage.scopeId.routeParam}'),
                  directMessage: directMessage,
                  onTap: () => context
                      .go(store.directMessageRoutePath(directMessage.scopeId)),
                ),
            ],
          ),
      },
    );
  }
}

class _HomeSectionHeader extends StatelessWidget {
  const _HomeSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  const _HomeEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('No channels or direct messages yet.'),
    );
  }
}

class _HomeErrorState extends StatelessWidget {
  const _HomeErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

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
