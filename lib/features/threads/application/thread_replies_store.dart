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
  bool _disposed = false;

  @override
  ThreadRepliesState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
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
      if (!_isCurrentRoute(routeTarget)) {
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
        if (_disposed) return;
        final ids = ref.read(knownThreadChannelIdsProvider);
        ref.read(knownThreadChannelIdsProvider.notifier).state = {
          ...ids,
          threadChannelKey(routeTarget.serverId, threadChannelId),
        };
        unawaited(_markRead(routeTarget, threadChannelId));
      }
    } on AppFailure catch (failure) {
      if (!_isCurrentRoute(routeTarget)) {
        return;
      }
      state = state.copyWith(
        status: ThreadRepliesStatus.failure,
        failure: failure,
      );
    } catch (e, st) {
      if (!_isCurrentRoute(routeTarget)) {
        return;
      }
      try {
        ref.read(diagnosticsCollectorProvider).error(
          'ThreadRepliesStore',
          'load failed: $e',
          metadata: {'stackTrace': st.toString()},
        );
      } catch (_) {}
      state = state.copyWith(
        status: ThreadRepliesStatus.failure,
        failure: UnknownFailure(
          message: 'Failed to load thread.',
          causeType: e.runtimeType.toString(),
        ),
      );
    }
  }

  Future<void> retry() => load();

  bool _isCurrentRoute(ThreadRouteTarget routeTarget) {
    if (_disposed) return false;
    return ref.read(currentThreadRouteTargetProvider) == routeTarget;
  }

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
      if (!_isCurrentRoute(routeTarget)) {
        return;
      }
      state = state.copyWith(
        routeTarget: routeTarget.copyWith(isFollowed: true),
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      if (!_isCurrentRoute(routeTarget)) {
        return;
      }
      state = state.copyWith(failure: failure);
    } catch (error) {
      if (!_isCurrentRoute(routeTarget)) {
        return;
      }
      state = state.copyWith(
        failure: UnknownFailure(
          message: 'Failed to follow thread.',
          causeType: error.runtimeType.toString(),
        ),
      );
    } finally {
      if (_isCurrentRoute(routeTarget)) {
        state = state.copyWith(isFollowingInFlight: false);
      }
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
      if (!_isCurrentRoute(routeTarget)) {
        return;
      }
      state = state.copyWith(
        isDone: true,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      if (!_isCurrentRoute(routeTarget)) {
        return;
      }
      state = state.copyWith(failure: failure);
    } catch (error) {
      if (!_isCurrentRoute(routeTarget)) {
        return;
      }
      state = state.copyWith(
        failure: UnknownFailure(
          message: 'Failed to mark thread done.',
          causeType: error.runtimeType.toString(),
        ),
      );
    } finally {
      if (_isCurrentRoute(routeTarget)) {
        state = state.copyWith(isDoneInFlight: false);
      }
    }
  }

  Future<void> _markRead(
    ThreadRouteTarget routeTarget,
    String threadChannelId,
  ) async {
    if (_disposed) return;
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
