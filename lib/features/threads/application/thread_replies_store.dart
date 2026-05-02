import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/threads/application/known_thread_channel_ids_provider.dart';
import 'package:slock_app/features/threads/application/thread_replies_state.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';

final currentThreadRouteTargetProvider = Provider<ThreadRouteTarget>((ref) {
  throw UnimplementedError(
    'currentThreadRouteTargetProvider must be overridden.',
  );
});

final threadRepliesStoreProvider =
    NotifierProvider.autoDispose<ThreadRepliesStore, ThreadRepliesState>(
  ThreadRepliesStore.new,
  dependencies: [currentThreadRouteTargetProvider],
);

class ThreadRepliesStore extends AutoDisposeNotifier<ThreadRepliesState> {
  @override
  ThreadRepliesState build() {
    final routeTarget = ref.watch(currentThreadRouteTargetProvider);
    Future.microtask(() {
      if (state.status == ThreadRepliesStatus.initial) {
        ensureLoaded();
      }
    });
    return ThreadRepliesState(routeTarget: routeTarget);
  }

  Future<void> ensureLoaded() async {
    if (state.status != ThreadRepliesStatus.initial) {
      return;
    }
    await load();
  }

  Future<void> load() async {
    final routeTarget = ref.read(currentThreadRouteTargetProvider);
    state = state.copyWith(
      routeTarget: routeTarget,
      status: ThreadRepliesStatus.loading,
      clearFailure: true,
    );

    try {
      final resolvedThread = routeTarget.threadChannelId != null
          ? null
          : await ref.read(threadRepositoryProvider).resolveThread(routeTarget);
      if (ref.read(currentThreadRouteTargetProvider) != routeTarget) {
        return;
      }

      final nextTarget = resolvedThread == null
          ? routeTarget
          : routeTarget.copyWith(
              threadChannelId: resolvedThread.threadChannelId,
            );
      state = state.copyWith(
        routeTarget: nextTarget,
        status: ThreadRepliesStatus.success,
        resolvedThreadChannelId:
            nextTarget.threadChannelId ?? resolvedThread?.threadChannelId,
        replyCount: resolvedThread?.replyCount ?? state.replyCount,
        participantIds: resolvedThread?.participantIds ?? state.participantIds,
        lastReplyAt: resolvedThread?.lastReplyAt ?? state.lastReplyAt,
        clearFailure: true,
      );
      final threadChannelId = state.resolvedThreadChannelId;
      if (threadChannelId != null) {
        final ids = ref.read(knownThreadChannelIdsProvider);
        ref.read(knownThreadChannelIdsProvider.notifier).state = {
          ...ids,
          threadChannelId,
        };
        unawaited(_markRead(routeTarget, threadChannelId));
      }
    } on AppFailure catch (failure) {
      if (ref.read(currentThreadRouteTargetProvider) != routeTarget) {
        return;
      }
      state = state.copyWith(
        status: ThreadRepliesStatus.failure,
        failure: failure,
      );
    }
  }

  Future<void> retry() => load();

  Future<void> follow() async {
    if (state.status != ThreadRepliesStatus.success ||
        state.isFollowing ||
        state.isFollowingInFlight) {
      return;
    }

    final routeTarget = state.routeTarget;
    state = state.copyWith(isFollowingInFlight: true, clearFailure: true);

    try {
      await ref.read(threadRepositoryProvider).followThread(routeTarget);
      if (ref.read(currentThreadRouteTargetProvider) != routeTarget) {
        return;
      }
      state = state.copyWith(
        routeTarget: routeTarget.copyWith(isFollowed: true),
        isFollowingInFlight: false,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      if (ref.read(currentThreadRouteTargetProvider) != routeTarget) {
        return;
      }
      state = state.copyWith(
        isFollowingInFlight: false,
        failure: failure,
      );
    }
  }

  Future<void> markDone() async {
    final threadChannelId = state.resolvedThreadChannelId;
    if (state.status != ThreadRepliesStatus.success ||
        state.isDone ||
        state.isDoneInFlight ||
        threadChannelId == null) {
      return;
    }

    final routeTarget = state.routeTarget;
    state = state.copyWith(isDoneInFlight: true, clearFailure: true);

    try {
      await ref.read(threadRepositoryProvider).markThreadDone(
            ServerScopeId(routeTarget.serverId),
            threadChannelId: threadChannelId,
          );
      if (ref.read(currentThreadRouteTargetProvider) != routeTarget) {
        return;
      }
      state = state.copyWith(
        isDoneInFlight: false,
        isDone: true,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      if (ref.read(currentThreadRouteTargetProvider) != routeTarget) {
        return;
      }
      state = state.copyWith(
        isDoneInFlight: false,
        failure: failure,
      );
    }
  }

  Future<void> _markRead(
    ThreadRouteTarget routeTarget,
    String threadChannelId,
  ) async {
    try {
      await ref.read(threadRepositoryProvider).markThreadRead(
            ServerScopeId(routeTarget.serverId),
            threadChannelId: threadChannelId,
          );
    } on AppFailure {
      return;
    }
  }
}
