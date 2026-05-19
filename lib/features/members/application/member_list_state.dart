import 'package:flutter/foundation.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';

enum MemberListStatus { initial, loading, success, failure }

@immutable
class MemberListState {
  MemberListState({
    this.status = MemberListStatus.initial,
    this.members = const [],
    this.query = '',
    this.failure,
    this.isInvitingByEmail = false,
    this.openingDirectMessageMemberId,
    this.updatingRoleMemberIds = const {},
    this.removingMemberIds = const {},
  })  : humans = _computeHumans(members, query),
        agents = _computeAgents(members, query),
        canManageMembers = _computeCanManage(members);

  final MemberListStatus status;
  final List<MemberProfile> members;
  final String query;
  final AppFailure? failure;
  final bool isInvitingByEmail;
  final String? openingDirectMessageMemberId;
  final Set<String> updatingRoleMemberIds;
  final Set<String> removingMemberIds;

  /// INV-MEMBERS-CACHE-1: Cached human members, filtered by [query].
  /// Computed once in constructor — accessing does NOT re-allocate.
  final List<MemberProfile> humans;

  /// INV-MEMBERS-CACHE-1: Cached agent members, filtered by [query].
  /// Computed once in constructor — accessing does NOT re-allocate.
  final List<MemberProfile> agents;

  /// Pre-computed management permission based on self member role.
  final bool canManageMembers;

  static List<MemberProfile> _computeHumans(
    List<MemberProfile> members,
    String query,
  ) {
    final all = members.where((m) => m.type == MemberType.human).toList();
    return _applyQueryStatic(all, query);
  }

  static List<MemberProfile> _computeAgents(
    List<MemberProfile> members,
    String query,
  ) {
    final all = members.where((m) => m.type == MemberType.agent).toList();
    return _applyQueryStatic(all, query);
  }

  static bool _computeCanManage(List<MemberProfile> members) {
    for (final member in members) {
      if (member.isSelf) {
        return member.role == 'owner' || member.role == 'admin';
      }
    }
    return false;
  }

  static List<MemberProfile> _applyQueryStatic(
    List<MemberProfile> list,
    String query,
  ) {
    if (query.isEmpty) return list;
    final lower = query.toLowerCase();
    return list
        .where((m) => m.displayName.toLowerCase().contains(lower))
        .toList();
  }

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
    String? query,
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
      query: query ?? this.query,
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
          query == other.query &&
          failure == other.failure &&
          isInvitingByEmail == other.isInvitingByEmail &&
          openingDirectMessageMemberId == other.openingDirectMessageMemberId &&
          setEquals(updatingRoleMemberIds, other.updatingRoleMemberIds) &&
          setEquals(removingMemberIds, other.removingMemberIds);

  @override
  int get hashCode => Object.hash(
        status,
        Object.hashAll(members),
        query,
        failure,
        isInvitingByEmail,
        openingDirectMessageMemberId,
        Object.hashAll([...updatingRoleMemberIds]..sort()),
        Object.hashAll([...removingMemberIds]..sort()),
      );
}
