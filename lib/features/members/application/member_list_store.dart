import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/members/application/member_list_state.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/stores/session/session_store.dart';

final currentMembersServerIdProvider = Provider<ServerScopeId>((ref) {
  throw UnimplementedError(
    'currentMembersServerIdProvider must be overridden in a ProviderScope',
  );
});

final memberListStoreProvider =
    AutoDisposeNotifierProvider<MemberListStore, MemberListState>(
  MemberListStore.new,
  dependencies: [currentMembersServerIdProvider],
);

class MemberListStore extends AutoDisposeNotifier<MemberListState> {
  @override
  MemberListState build() {
    ref.watch(currentMembersServerIdProvider);
    return const MemberListState();
  }

  Future<void> ensureLoaded() async {
    if (state.status == MemberListStatus.loading ||
        state.status == MemberListStatus.success) {
      return;
    }
    await load();
  }

  Future<void> load() async {
    final serverId = ref.read(currentMembersServerIdProvider);
    state = state.copyWith(
      status: MemberListStatus.loading,
      clearFailure: true,
      clearOpeningDirectMessage: true,
    );

    try {
      final sessionUserId = ref.read(sessionStoreProvider).userId;
      final members =
          await ref.read(memberRepositoryProvider).listMembers(serverId);
      state = state.copyWith(
        status: MemberListStatus.success,
        members: members
            .map(
              (member) => sessionUserId == member.id
                  ? member.copyWith(isSelf: true)
                  : member,
            )
            .toList(growable: false),
        clearFailure: true,
        clearOpeningDirectMessage: true,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(
        status: MemberListStatus.failure,
        failure: failure,
        clearOpeningDirectMessage: true,
      );
    }
  }

  Future<String> openDirectMessage(String userId) async {
    final serverId = ref.read(currentMembersServerIdProvider);
    state = state.copyWith(
      openingDirectMessageMemberId: userId,
      clearFailure: true,
    );

    try {
      final channelId =
          await ref.read(memberRepositoryProvider).openDirectMessage(
                serverId,
                userId: userId,
              );
      state = state.copyWith(clearOpeningDirectMessage: true);
      return channelId;
    } on AppFailure catch (failure) {
      state = state.copyWith(
        failure: failure,
        clearOpeningDirectMessage: true,
      );
      rethrow;
    }
  }
}
