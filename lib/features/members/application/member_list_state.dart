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
    this.openingDirectMessageMemberId,
  });

  final MemberListStatus status;
  final List<MemberProfile> members;
  final AppFailure? failure;
  final String? openingDirectMessageMemberId;

  bool isOpeningDirectMessage(String userId) =>
      openingDirectMessageMemberId == userId;

  MemberListState copyWith({
    MemberListStatus? status,
    List<MemberProfile>? members,
    AppFailure? failure,
    bool clearFailure = false,
    String? openingDirectMessageMemberId,
    bool clearOpeningDirectMessage = false,
  }) {
    return MemberListState(
      status: status ?? this.status,
      members: members ?? this.members,
      failure: clearFailure ? null : (failure ?? this.failure),
      openingDirectMessageMemberId: clearOpeningDirectMessage
          ? null
          : (openingDirectMessageMemberId ?? this.openingDirectMessageMemberId),
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
          openingDirectMessageMemberId == other.openingDirectMessageMemberId;

  @override
  int get hashCode => Object.hash(
        status,
        Object.hashAll(members),
        failure,
        openingDirectMessageMemberId,
      );
}
