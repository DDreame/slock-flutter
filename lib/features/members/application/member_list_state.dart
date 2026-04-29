import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';

enum MemberListStatus { initial, loading, success, failure }

@immutable
class MemberListState {
  const MemberListState({
    this.status = MemberListStatus.initial,
    this.members = const [],
    this.failure,
    this.isInvitingByEmail = false,
    this.openingDirectMessageMemberId,
    this.updatingRoleMemberIds = const {},
    this.removingMemberIds = const {},
  });

  final MemberListStatus status;
  final List<MemberProfile> members;
  final AppFailure? failure;
  final bool isInvitingByEmail;
  final String? openingDirectMessageMemberId;
  final Set<String> updatingRoleMemberIds;
  final Set<String> removingMemberIds;

  bool isOpeningDirectMessage(String userId) =>
      openingDirectMessageMemberId == userId;

  bool isUpdatingRole(String userId) => updatingRoleMemberIds.contains(userId);

  bool isRemovingMember(String userId) => removingMemberIds.contains(userId);

  bool isMutatingMember(String userId) =>
      isOpeningDirectMessage(userId) ||
      isUpdatingRole(userId) ||
      isRemovingMember(userId);

  MemberListState copyWith({
    MemberListStatus? status,
    List<MemberProfile>? members,
    AppFailure? failure,
    bool clearFailure = false,
    bool? isInvitingByEmail,
    String? openingDirectMessageMemberId,
    bool clearOpeningDirectMessage = false,
    Set<String>? updatingRoleMemberIds,
    Set<String>? removingMemberIds,
  }) {
    return MemberListState(
      status: status ?? this.status,
      members: members ?? this.members,
      failure: clearFailure ? null : (failure ?? this.failure),
      isInvitingByEmail: isInvitingByEmail ?? this.isInvitingByEmail,
      openingDirectMessageMemberId: clearOpeningDirectMessage
          ? null
          : (openingDirectMessageMemberId ?? this.openingDirectMessageMemberId),
      updatingRoleMemberIds:
          updatingRoleMemberIds ?? this.updatingRoleMemberIds,
      removingMemberIds: removingMemberIds ?? this.removingMemberIds,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberListState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          listEquals(members, other.members) &&
          failure == other.failure &&
          isInvitingByEmail == other.isInvitingByEmail &&
          openingDirectMessageMemberId == other.openingDirectMessageMemberId &&
          setEquals(updatingRoleMemberIds, other.updatingRoleMemberIds) &&
          setEquals(removingMemberIds, other.removingMemberIds);

  @override
  int get hashCode => Object.hash(
        status,
        Object.hashAll(members),
        failure,
        isInvitingByEmail,
        openingDirectMessageMemberId,
        Object.hashAll([...updatingRoleMemberIds]..sort()),
        Object.hashAll([...removingMemberIds]..sort()),
      );
}
