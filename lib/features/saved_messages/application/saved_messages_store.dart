import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_state.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';

final currentSavedMessagesServerIdProvider = Provider<ServerScopeId>((ref) {
  throw UnimplementedError(
    'currentSavedMessagesServerIdProvider must be overridden.',
  );
});

final savedMessagesStoreProvider =
    NotifierProvider.autoDispose<SavedMessagesStore, SavedMessagesState>(
  SavedMessagesStore.new,
  dependencies: [currentSavedMessagesServerIdProvider],
);

class SavedMessagesStore extends AutoDisposeNotifier<SavedMessagesState> {
  /// Prevents post-await state mutations after the store is disposed.
  bool _disposed = false;

  @override
  SavedMessagesState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);

    // INV-834: Re-fetch on WebSocket reconnect — data may be stale.
    ref.listen(realtimeServiceProvider.select((s) => s.status), (prev, next) {
      if (prev == RealtimeConnectionStatus.reconnecting &&
          next == RealtimeConnectionStatus.connected) {
        if (state.status == SavedMessagesStatus.success) {
          load();
        }
      }
    });

    return const SavedMessagesState();
  }

  Future<void> load() async {
    final serverId = ref.read(currentSavedMessagesServerIdProvider);
    state = state.copyWith(
      status: SavedMessagesStatus.loading,
      clearFailure: true,
    );

    try {
      final repo = ref.read(savedMessagesRepositoryProvider);
      final page = await repo.listSavedMessages(serverId);
      if (_disposed) return;
      state = state.copyWith(
        status: SavedMessagesStatus.success,
        items: page.items,
        hasMore: page.hasMore,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      if (_disposed) return;
      state = state.copyWith(
        status: SavedMessagesStatus.failure,
        failure: failure,
      );
    } catch (error) {
      if (_disposed) return;
      state = state.copyWith(
        status: SavedMessagesStatus.failure,
        failure: UnknownFailure(
          message: 'Failed to load saved messages.',
          causeType: error.runtimeType.toString(),
        ),
      );
    }
  }

  /// Idempotent load guard — only calls [load] when status is [initial].
  ///
  /// Returns the [Future] from [load] so callers can observe completion
  /// and errors propagate to state (#714).
  Future<void> ensureLoaded() async {
    if (state.status == SavedMessagesStatus.initial) {
      await load();
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore ||
        state.status != SavedMessagesStatus.success ||
        state.isLoadingMore ||
        state.items.isEmpty) {
      return;
    }

    state = state.copyWith(isLoadingMore: true);
    final serverId = ref.read(currentSavedMessagesServerIdProvider);

    try {
      final repo = ref.read(savedMessagesRepositoryProvider);
      final page = await repo.listSavedMessages(
        serverId,
        offset: state.items.length,
      );
      if (_disposed) return;
      state = state.copyWith(
        items: [...state.items, ...page.items],
        hasMore: page.hasMore,
        isLoadingMore: false,
      );
    } on AppFailure catch (failure) {
      if (_disposed) return;
      state = state.copyWith(failure: failure, isLoadingMore: false);
    } catch (e, st) {
      if (_disposed) return;
      try {
        ref.read(diagnosticsCollectorProvider).error(
          'SavedMessagesStore',
          'loadMore failed: $e',
          metadata: {'stackTrace': st.toString()},
        );
      } catch (_) {}
      state = state.copyWith(
        failure: UnknownFailure(
          message: 'Failed to load more saved messages.',
          causeType: e.runtimeType.toString(),
        ),
        isLoadingMore: false,
      );
    }
  }

  void removeLocally(String messageId) {
    state = state.copyWith(
      items: state.items
          .where((item) => item.message.id != messageId)
          .toList(growable: false),
    );
  }

  Future<void> unsaveMessage(String messageId) async {
    final serverId = ref.read(currentSavedMessagesServerIdProvider);

    // Capture only the single item being removed (not the full list)
    // so that concurrent loadMore() additions are preserved on rollback (#726).
    final removedItem = state.items.cast<SavedMessageItem?>().firstWhere(
          (item) => item!.message.id == messageId,
          orElse: () => null,
        );
    final removedIndex =
        removedItem != null ? state.items.indexOf(removedItem) : -1;

    removeLocally(messageId);

    try {
      final repo = ref.read(savedMessagesRepositoryProvider);
      await repo.unsaveMessage(serverId, messageId);
    } on AppFailure {
      if (_disposed) return;
      // Re-insert the single item at its original position instead of
      // restoring the entire previous snapshot — preserves any items
      // added by concurrent loadMore().
      if (removedItem != null) {
        final currentItems = state.items.toList();
        final insertAt = removedIndex.clamp(0, currentItems.length);
        currentItems.insert(insertAt, removedItem);
        state = state.copyWith(items: currentItems);
      }
    }
  }

  void retry() => load();
}
