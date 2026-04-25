import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/threads/application/current_open_thread_target_provider.dart';
import 'package:slock_app/features/threads/application/thread_replies_state.dart';
import 'package:slock_app/features/threads/application/thread_replies_store.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/application/threads_realtime_binding.dart';

class ThreadRepliesPage extends StatelessWidget {
  const ThreadRepliesPage({super.key, required this.routeTarget});

  final ThreadRouteTarget? routeTarget;

  @override
  Widget build(BuildContext context) {
    final target = routeTarget;
    if (target == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thread replies')),
        body: const Center(
          key: ValueKey('thread-route-error'),
          child: Text('Missing thread route context.'),
        ),
      );
    }

    return ProviderScope(
      overrides: [
        currentThreadRouteTargetProvider.overrideWithValue(target),
      ],
      child: const _ThreadRepliesScreen(),
    );
  }
}

class _ThreadRepliesScreen extends ConsumerWidget {
  const _ThreadRepliesScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeTarget = ref.watch(currentThreadRouteTargetProvider);
    ref.watch(currentOpenThreadRegistrationProvider(routeTarget));
    ref.watch(threadRepliesRealtimeBindingProvider);
    final state = ref.watch(threadRepliesStoreProvider);
    final store = ref.read(threadRepliesStoreProvider.notifier);

    if (state.status == ThreadRepliesStatus.initial ||
        state.status == ThreadRepliesStatus.loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thread replies')),
        body: const Center(
          key: ValueKey('thread-replies-loading'),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (state.status == ThreadRepliesStatus.failure ||
        state.conversationTarget == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thread replies')),
        body: Center(
          key: const ValueKey('thread-replies-error'),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.failure?.message ?? 'Unable to open thread replies.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: store.retry, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    return ConversationDetailPage(
      target: state.conversationTarget!,
      titleOverride: 'Thread replies',
      registerOpenTarget: false,
      appBarActionsBuilder: (context, ref, _) => _buildThreadActions(
        context,
        ref,
        state,
      ),
    );
  }

  List<Widget> _buildThreadActions(
    BuildContext context,
    WidgetRef ref,
    ThreadRepliesState state,
  ) {
    final store = ref.read(threadRepliesStoreProvider.notifier);
    return [
      if (!state.isFollowing)
        IconButton(
          key: const ValueKey('thread-follow-action'),
          onPressed: state.isFollowingInFlight ? null : store.follow,
          icon: state.isFollowingInFlight
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.notifications_outlined),
          tooltip: 'Follow thread',
        ),
      IconButton(
        key: const ValueKey('thread-done-action'),
        onPressed: state.isDoneInFlight
            ? null
            : () async {
                await store.markDone();
                final nextState = ref.read(threadRepliesStoreProvider);
                if (nextState.isDone && context.mounted && context.canPop()) {
                  context.pop();
                }
              },
        icon: state.isDoneInFlight
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.done_all_outlined),
        tooltip: 'Mark thread done',
      ),
    ];
  }
}
