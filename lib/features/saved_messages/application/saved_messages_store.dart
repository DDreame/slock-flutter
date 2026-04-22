import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_state.dart';
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
  @override
  SavedMessagesState build() {
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
      state = state.copyWith(
        status: SavedMessagesStatus.success,
        items: page.items,
        hasMore: page.hasMore,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(
        status: SavedMessagesStatus.failure,
        failure: failure,
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore ||
        state.status != SavedMessagesStatus.success ||
        state.items.isEmpty) {
      return;
    }

    final serverId = ref.read(currentSavedMessagesServerIdProvider);

    try {
      final repo = ref.read(savedMessagesRepositoryProvider);
      final page = await repo.listSavedMessages(
        serverId,
        offset: state.items.length,
      );
      state = state.copyWith(
        items: [...state.items, ...page.items],
        hasMore: page.hasMore,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(failure: failure);
    }
  }

  void removeLocally(String messageId) {
    state = state.copyWith(
      items: state.items
          .where((item) => item.message.id != messageId)
          .toList(growable: false),
    );
  }

  void retry() => load();
}
