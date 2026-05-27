import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/threads/application/threads_inbox_state.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';

final currentThreadsServerIdProvider = Provider<ServerScopeId>((ref) {
  throw UnimplementedError(
    'currentThreadsServerIdProvider must be overridden.',
  );
});

final threadsInboxStoreProvider =
    NotifierProvider.autoDispose<ThreadsInboxStore, ThreadsInboxState>(
  ThreadsInboxStore.new,
  dependencies: [currentThreadsServerIdProvider],
);

class ThreadsInboxStore extends AutoDisposeNotifier<ThreadsInboxState> {
  bool _disposed = false;

  @override
  ThreadsInboxState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    final serverId = ref.watch(currentThreadsServerIdProvider);

    // INV-834: Re-fetch on WebSocket reconnect — data may be stale.
    ref.listen(realtimeServiceProvider.select((s) => s.status), (prev, next) {
      if (prev == RealtimeConnectionStatus.reconnecting &&
          next == RealtimeConnectionStatus.connected) {
        if (state.status == ThreadsInboxStatus.success) {
          load();
        }
      }
    });

    Future.microtask(() {
      if (state.status == ThreadsInboxStatus.initial) {
        load();
      }
    });
    return ThreadsInboxState(serverId: serverId);
  }

  Future<void> load() async {
    final serverId = ref.read(currentThreadsServerIdProvider);
    state = state.copyWith(
      serverId: serverId,
      status: ThreadsInboxStatus.loading,
      clearFailure: true,
    );

    try {
      final items = await ref
          .read(threadRepositoryProvider)
          .loadFollowedThreads(serverId);
      if (_disposed) return;
      if (ref.read(currentThreadsServerIdProvider) != serverId) {
        return;
      }
      state = state.copyWith(
        status: ThreadsInboxStatus.success,
        items: items,
        completingThreadIds: const [],
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      if (_disposed) return;
      if (ref.read(currentThreadsServerIdProvider) != serverId) {
        return;
      }
      // INV-NET-DEGRADE-1: preserve stale data on refresh failure.
      // Only clear items on first-load failure (no existing data).
      final hasExistingData = state.items.isNotEmpty;
      state = state.copyWith(
        status: hasExistingData
            ? ThreadsInboxStatus.success
            : ThreadsInboxStatus.failure,
        items: hasExistingData ? null : const [],
        completingThreadIds: const [],
        failure: failure,
      );
    }
  }

  Future<void> retry() => load();

  Future<void> markDone(ThreadInboxItem item) async {
    final threadChannelId = item.routeTarget.threadChannelId;
    if (threadChannelId == null || state.isCompleting(threadChannelId)) {
      return;
    }

    // Optimistically remove the item from the list immediately so that
    // the Dismissible animation and store state stay consistent.
    final previousItems = state.items;
    state = state.copyWith(
      items: state.items
          .where(
              (entry) => entry.routeTarget.threadChannelId != threadChannelId)
          .toList(growable: false),
      completingThreadIds: [
        ...state.completingThreadIds,
        threadChannelId,
      ],
      clearFailure: true,
    );

    try {
      await ref.read(threadRepositoryProvider).markThreadDone(
            state.serverId,
            threadChannelId: threadChannelId,
          );
    } on AppFailure catch (failure) {
      // Restore the item on failure so the user can retry.
      try {
        state = state.copyWith(
          items: previousItems,
          failure: failure,
        );
      } on StateError catch (_) {
        // Provider disposed mid-flight — state write guard.
      }
    } catch (error) {
      try {
        state = state.copyWith(
          items: previousItems,
          failure: UnknownFailure(
            message: 'Failed to mark thread done.',
            causeType: error.runtimeType.toString(),
          ),
        );
      } on StateError catch (_) {
        // Provider disposed mid-flight — state write guard.
      }
    } finally {
      try {
        state = state.copyWith(
          completingThreadIds: state.completingThreadIds
              .where((id) => id != threadChannelId)
              .toList(growable: false),
        );
      } on StateError catch (_) {
        // Provider disposed mid-flight — finally guard.
      }
    }
  }
}
