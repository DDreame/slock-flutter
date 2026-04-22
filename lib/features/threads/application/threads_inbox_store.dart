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
  @override
  ThreadsInboxState build() {
    final serverId = ref.watch(currentThreadsServerIdProvider);
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
      if (ref.read(currentThreadsServerIdProvider) != serverId) {
        return;
      }
      state = state.copyWith(
        status: ThreadsInboxStatus.failure,
        items: const [],
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

    state = state.copyWith(
      completingThreadIds: [...state.completingThreadIds, threadChannelId],
      clearFailure: true,
    );

    try {
      await ref.read(threadRepositoryProvider).markThreadDone(
            state.serverId,
            threadChannelId: threadChannelId,
          );
      state = state.copyWith(
        items: state.items
            .where(
                (entry) => entry.routeTarget.threadChannelId != threadChannelId)
            .toList(growable: false),
        completingThreadIds: state.completingThreadIds
            .where((id) => id != threadChannelId)
            .toList(growable: false),
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(
        completingThreadIds: state.completingThreadIds
            .where((id) => id != threadChannelId)
            .toList(growable: false),
        failure: failure,
      );
    }
  }
}
