import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';

final serverListStoreProvider =
    NotifierProvider<ServerListStore, ServerListState>(
  ServerListStore.new,
);

class ServerListStore extends Notifier<ServerListState> {
  @override
  ServerListState build() {
    Future.microtask(() {
      if (state.status == ServerListStatus.initial) {
        load();
      }
    });
    return const ServerListState();
  }

  Future<void> load() async {
    state = state.copyWith(
      status: ServerListStatus.loading,
      clearFailure: true,
    );

    try {
      final servers =
          await ref.read(serverListRepositoryProvider).loadServers();
      state = state.copyWith(
        status: ServerListStatus.success,
        servers: servers,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(
        status: ServerListStatus.failure,
        failure: failure,
      );
    }
  }

  Future<void> retry() => load();
}
