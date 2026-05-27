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
  bool _disposed = false;

  @override
  MemberListState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    ref.watch(currentMembersServerIdProvider);

    // INV-834: Re-fetch on WebSocket reconnect — data may be stale.
    ref.listen(realtimeServiceProvider.select((s) => s.status), (prev, next) {
      if (prev == RealtimeConnectionStatus.reconnecting &&
          next == RealtimeConnectionStatus.connected) {
        if (state.status == MemberListStatus.success) {
          load();
        }
      }
    });

    return MemberListState();
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
    );

    try {
      final sessionUserId = ref.read(sessionStoreProvider).userId;
      final members =
          await ref.read(memberRepositoryProvider).listMembers(serverId);
      if (_disposed) return;
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
      );
    } on AppFailure catch (failure) {
      if (_disposed) return;
      state = state.copyWith(
        status: MemberListStatus.failure,
        failure: failure,
        isInvitingByEmail: false,
        clearOpeningDirectMessage: true,
      );
    } catch (error, stackTrace) {
      if (_disposed) return;
      _reportUnexpectedError('load', error, stackTrace);
      state = state.copyWith(
        status: MemberListStatus.failure,
        failure: _unexpectedFailure(
          error,
          message: 'Failed to load members.',
        ),
        isInvitingByEmail: false,
        clearOpeningDirectMessage: true,
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
      if (_disposed) return;
      state = state.copyWith(isInvitingByEmail: false);
    } on AppFailure catch (failure) {
      if (_disposed) return;
      state = state.copyWith(failure: failure, isInvitingByEmail: false);
      rethrow;
    } catch (error, stackTrace) {
      if (_disposed) return;
      _reportUnexpectedError('inviteByEmail', error, stackTrace);
      final failure = _unexpectedFailure(
        error,
        message: 'Failed to send invite email.',
      );
      state = state.copyWith(failure: failure, isInvitingByEmail: false);
      throw failure;
    }
  }

  Future<String> createInvite() async {
    final serverId = ref.read(currentMembersServerIdProvider);
    state = state.copyWith(isInvitingByEmail: true, clearFailure: true);

    try {
      final inviteCode =
          await ref.read(memberRepositoryProvider).createInvite(serverId);
      if (_disposed) return inviteCode;
      state = state.copyWith(isInvitingByEmail: false);
      return inviteCode;
    } on AppFailure catch (failure) {
      if (!_disposed) {
        state = state.copyWith(failure: failure, isInvitingByEmail: false);
      }
      rethrow;
    } catch (error, stackTrace) {
      if (!_disposed) {
        _reportUnexpectedError('createInvite', error, stackTrace);
      }
      final failure = _unexpectedFailure(
        error,
        message: 'Failed to generate invite link.',
      );
      if (!_disposed) {
        state = state.copyWith(failure: failure, isInvitingByEmail: false);
      }
      throw failure;
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
      if (_disposed) return;
      state = state.copyWith(
        members: [
          for (final member in state.members)
            if (member.id == userId) member.copyWith(role: role) else member,
        ],
        updatingRoleMemberIds: {...state.updatingRoleMemberIds}..remove(userId),
      );
    } on AppFailure catch (failure) {
      if (_disposed) return;
      state = state.copyWith(
        failure: failure,
        updatingRoleMemberIds: {...state.updatingRoleMemberIds}..remove(userId),
      );
      rethrow;
    } catch (error, stackTrace) {
      if (_disposed) return;
      _reportUnexpectedError('updateMemberRole', error, stackTrace);
      final failure = _unexpectedFailure(
        error,
        message: 'Failed to update member role.',
      );
      state = state.copyWith(
        failure: failure,
        updatingRoleMemberIds: {...state.updatingRoleMemberIds}..remove(userId),
      );
      throw failure;
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
      if (_disposed) return;
      state = state.copyWith(
        members: [
          for (final member in state.members)
            if (member.id != userId) member,
        ],
        removingMemberIds: {...state.removingMemberIds}..remove(userId),
      );
    } on AppFailure catch (failure) {
      if (_disposed) return;
      state = state.copyWith(
        failure: failure,
        removingMemberIds: {...state.removingMemberIds}..remove(userId),
      );
      rethrow;
    } catch (error, stackTrace) {
      if (_disposed) return;
      _reportUnexpectedError('removeMember', error, stackTrace);
      final failure = _unexpectedFailure(
        error,
        message: 'Failed to remove member.',
      );
      state = state.copyWith(
        failure: failure,
        removingMemberIds: {...state.removingMemberIds}..remove(userId),
      );
      throw failure;
    }
  }

  Future<String> openDirectMessage(String userId) async {
    final serverId = ref.read(currentMembersServerIdProvider);
    state = state.copyWith(
      openingDirectMessageMemberId: userId,
      clearFailure: true,
    );

    try {
      final member = state.members.where((m) => m.id == userId).firstOrNull;
      if (member == null) {
        const failure = NotFoundFailure(
          message: 'Member not found',
        );
        state =
            state.copyWith(failure: failure, clearOpeningDirectMessage: true);
        throw failure;
      }
      final repo = ref.read(memberRepositoryProvider);
      final channelId = member.isAgent
          ? await repo.openAgentDirectMessage(serverId, agentId: userId)
          : await repo.openDirectMessage(serverId, userId: userId);
      if (!_disposed) {
        state = state.copyWith(clearOpeningDirectMessage: true);
      }
      return channelId;
    } on AppFailure catch (failure) {
      if (!_disposed) {
        state =
            state.copyWith(failure: failure, clearOpeningDirectMessage: true);
      }
      rethrow;
    } catch (error, stackTrace) {
      if (!_disposed) {
        _reportUnexpectedError('openDirectMessage', error, stackTrace);
      }
      final failure = _unexpectedFailure(
        error,
        message: 'Failed to open direct message.',
      );
      if (!_disposed) {
        state = state.copyWith(
          failure: failure,
          clearOpeningDirectMessage: true,
        );
      }
      throw failure;
    }
  }

  /// Update the search query for filtering the member list.
  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void _reportUnexpectedError(String method, Object error, StackTrace st) {
    try {
      ref.read(diagnosticsCollectorProvider).error(
        'MemberListStore',
        '$method failed: $error',
        metadata: {'stackTrace': st.toString()},
      );
    } catch (_) {}
    if (error is! StateError) {
      try {
        ref.read(crashReporterProvider).captureException(
          error,
          stackTrace: st,
          extra: {'store': 'MemberListStore', 'method': method},
        );
      } catch (_) {}
    }
  }

  AppFailure _unexpectedFailure(Object error, {required String message}) {
    return UnknownFailure(
      message: message,
      causeType: error.runtimeType.toString(),
    );
  }
}
