import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/members/application/member_list_state.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
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
      isInvitingByEmail: false,
      clearOpeningDirectMessage: true,
      updatingRoleMemberIds: const {},
      removingMemberIds: const {},
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
        isInvitingByEmail: false,
        clearOpeningDirectMessage: true,
        updatingRoleMemberIds: const {},
        removingMemberIds: const {},
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(
        status: MemberListStatus.failure,
        failure: failure,
        isInvitingByEmail: false,
        clearOpeningDirectMessage: true,
        updatingRoleMemberIds: const {},
        removingMemberIds: const {},
      );
    }
  }

  Future<void> inviteByEmail(String email) async {
    final serverId = ref.read(currentMembersServerIdProvider);
    final normalizedEmail = email.trim();
    state = state.copyWith(isInvitingByEmail: true, clearFailure: true);

    try {
      await ref
          .read(memberRepositoryProvider)
          .inviteByEmail(serverId, email: normalizedEmail);
      state = state.copyWith(isInvitingByEmail: false);
    } on AppFailure catch (failure) {
      state = state.copyWith(failure: failure, isInvitingByEmail: false);
      rethrow;
    }
  }

  Future<String> createInvite() async {
    final serverId = ref.read(currentMembersServerIdProvider);
    state = state.copyWith(isInvitingByEmail: true, clearFailure: true);

    try {
      final inviteCode =
          await ref.read(memberRepositoryProvider).createInvite(serverId);
      state = state.copyWith(isInvitingByEmail: false);
      return inviteCode;
    } on AppFailure catch (failure) {
      state = state.copyWith(failure: failure, isInvitingByEmail: false);
      rethrow;
    }
  }

  Future<void> updateMemberRole(String userId, String role) async {
    final serverId = ref.read(currentMembersServerIdProvider);
    final updatingRoleMemberIds = {...state.updatingRoleMemberIds, userId};
    state = state.copyWith(
      clearFailure: true,
      updatingRoleMemberIds: updatingRoleMemberIds,
    );

    try {
      await ref
          .read(memberRepositoryProvider)
          .updateMemberRole(serverId, userId: userId, role: role);
      state = state.copyWith(
        members: [
          for (final member in state.members)
            if (member.id == userId) member.copyWith(role: role) else member,
        ],
        updatingRoleMemberIds: {...state.updatingRoleMemberIds}..remove(userId),
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(
        failure: failure,
        updatingRoleMemberIds: {...state.updatingRoleMemberIds}..remove(userId),
      );
      rethrow;
    }
  }

  Future<void> removeMember(String userId) async {
    final serverId = ref.read(currentMembersServerIdProvider);
    state = state.copyWith(
      clearFailure: true,
      removingMemberIds: {...state.removingMemberIds, userId},
    );

    try {
      await ref
          .read(memberRepositoryProvider)
          .removeMember(serverId, userId: userId);
      state = state.copyWith(
        members: [
          for (final member in state.members)
            if (member.id != userId) member,
        ],
        removingMemberIds: {...state.removingMemberIds}..remove(userId),
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(
        failure: failure,
        removingMemberIds: {...state.removingMemberIds}..remove(userId),
      );
      rethrow;
    }
  }

  Future<String> openDirectMessage(String userId) async {
    final serverId = ref.read(currentMembersServerIdProvider);
    state = state.copyWith(
      openingDirectMessageMemberId: userId,
      clearFailure: true,
    );

    try {
      final channelId = await ref
          .read(memberRepositoryProvider)
          .openDirectMessage(serverId, userId: userId);
      state = state.copyWith(clearOpeningDirectMessage: true);
      return channelId;
    } on AppFailure catch (failure) {
      state = state.copyWith(failure: failure, clearOpeningDirectMessage: true);
      rethrow;
    }
  }
}
