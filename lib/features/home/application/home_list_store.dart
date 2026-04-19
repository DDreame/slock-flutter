import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';

final homeListStoreProvider = NotifierProvider<HomeListStore, HomeListState>(
  HomeListStore.new,
);

class HomeListStore extends Notifier<HomeListState> {
  @override
  HomeListState build() {
    final serverScopeId = ref.watch(activeServerScopeIdProvider);
    if (serverScopeId == null) {
      return const HomeListState(status: HomeListStatus.noActiveServer);
    }
    Future.microtask(() {
      if (state.status == HomeListStatus.initial) {
        load();
      }
    });
    return HomeListState(serverScopeId: serverScopeId);
  }

  Future<void> load() async {
    final serverScopeId = ref.read(activeServerScopeIdProvider);
    if (serverScopeId == null) {
      state = const HomeListState(status: HomeListStatus.noActiveServer);
      return;
    }

    state = state.copyWith(
      serverScopeId: serverScopeId,
      status: HomeListStatus.loading,
      clearFailure: true,
    );

    try {
      final snapshot = await ref.read(homeRepositoryProvider).loadWorkspace(
            serverScopeId,
          );
      state = state.copyWith(
        serverScopeId: snapshot.serverId,
        status: HomeListStatus.success,
        channels: snapshot.channels,
        directMessages: snapshot.directMessages,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(
        serverScopeId: serverScopeId,
        status: HomeListStatus.failure,
        channels: const [],
        directMessages: const [],
        failure: failure,
      );
    }
  }

  Future<void> retry() => load();

  String channelRoutePath(ChannelScopeId scopeId) {
    return '/servers/${scopeId.serverId.routeParam}/channels/${scopeId.routeParam}';
  }

  String directMessageRoutePath(DirectMessageScopeId scopeId) {
    return '/servers/${scopeId.serverId.routeParam}/dms/${scopeId.routeParam}';
  }
}
