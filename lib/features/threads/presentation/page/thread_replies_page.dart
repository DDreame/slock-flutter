import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/threads/application/current_open_thread_target_provider.dart';
import 'package:slock_app/features/threads/application/thread_replies_state.dart';
import 'package:slock_app/features/threads/application/thread_replies_store.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/application/threads_realtime_binding.dart';
import 'package:slock_app/l10n/l10n.dart';

class ThreadRepliesPage extends StatelessWidget {
  const ThreadRepliesPage({super.key, required this.routeTarget});

  final ThreadRouteTarget? routeTarget;

  @override
  Widget build(BuildContext context) {
    final target = routeTarget;
    if (target == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.threadRepliesTitle)),
        body: Center(
          key: const ValueKey('thread-route-error'),
          child: Text(context.l10n.threadRepliesMissingContext),
        ),
      );
    }

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          context.go('/home');
        }
      },
      child: ProviderScope(
        overrides: [
          currentThreadRouteTargetProvider.overrideWithValue(target),
        ],
        child: const _ThreadRepliesScreen(),
      ),
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
    // INV-SELECT-THREAD-1: Only rebuild on fields used by this scaffold.
    // Excludes replyCount, participantIds, lastReplyAt which change
    // frequently as new replies arrive but don't affect this widget (#800).
    final (
      :status,
      :conversationTarget,
      :failure,
      :isFollowing,
      :isFollowingInFlight,
      :isDoneInFlight,
      :storeRouteTarget,
    ) = ref.watch(
      threadRepliesStoreProvider.select((s) => (
            status: s.status,
            conversationTarget: s.conversationTarget,
            failure: s.failure,
            isFollowing: s.isFollowing,
            isFollowingInFlight: s.isFollowingInFlight,
            isDoneInFlight: s.isDoneInFlight,
            storeRouteTarget: s.routeTarget,
          )),
    );
    final store = ref.read(threadRepliesStoreProvider.notifier);

    if (status == ThreadRepliesStatus.initial ||
        status == ThreadRepliesStatus.loading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.threadRepliesTitle)),
        body: const Center(
          key: ValueKey('thread-replies-loading'),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (status == ThreadRepliesStatus.failure || conversationTarget == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.threadRepliesTitle)),
        body: Center(
          key: const ValueKey('thread-replies-error'),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  failure?.userMessage(context.l10n) ??
                      context.l10n.errorUnknown,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: store.retry,
                    child: Text(context.l10n.threadRepliesRetry)),
              ],
            ),
          ),
        ),
      );
    }

    return ConversationDetailPage(
      target: conversationTarget,
      titleOverride: context.l10n.threadRepliesTitle,
      registerOpenTarget: false,
      highlightMessageId: routeTarget.highlightMessageId,
      appBarActionsBuilder: (context, ref, _) => _buildThreadActions(
        context,
        ref,
        isFollowing: isFollowing,
        isFollowingInFlight: isFollowingInFlight,
        isDoneInFlight: isDoneInFlight,
        serverId: storeRouteTarget.serverId,
      ),
    );
  }

  List<Widget> _buildThreadActions(
    BuildContext context,
    WidgetRef ref, {
    required bool isFollowing,
    required bool isFollowingInFlight,
    required bool isDoneInFlight,
    required String serverId,
  }) {
    final store = ref.read(threadRepliesStoreProvider.notifier);
    return [
      if (!isFollowing)
        IconButton(
          key: const ValueKey('thread-follow-action'),
          onPressed: isFollowingInFlight ? null : store.follow,
          icon: isFollowingInFlight
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.notifications_outlined),
          tooltip: context.l10n.threadRepliesFollowTooltip,
        ),
      IconButton(
        key: const ValueKey('thread-done-action'),
        onPressed: isDoneInFlight
            ? null
            : () async {
                await store.markDone();
                final nextState = ref.read(threadRepliesStoreProvider);
                if (nextState.isDone && context.mounted) {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/servers/$serverId/threads');
                  }
                }
              },
        icon: isDoneInFlight
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.done_all_outlined),
        tooltip: context.l10n.threadRepliesDoneTooltip,
      ),
    ];
  }
}
