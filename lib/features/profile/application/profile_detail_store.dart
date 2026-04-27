import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/profile/data/profile_repository_provider.dart';
import 'package:slock_app/stores/session/session_store.dart';

@immutable
class ProfileTarget {
  const ProfileTarget({this.userId, this.serverId});

  final String? userId;
  final ServerScopeId? serverId;

  bool get isSelf => userId == null;

  bool get canLoadRemote => !isSelf && serverId != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileTarget &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          serverId == other.serverId;

  @override
  int get hashCode => Object.hash(userId, serverId);
}

final currentProfileTargetProvider = Provider<ProfileTarget>((ref) {
  throw UnimplementedError(
    'currentProfileTargetProvider must be overridden in a ProviderScope',
  );
});

enum ProfileDetailStatus { initial, loading, success, failure }

@immutable
class ProfileDetailState {
  const ProfileDetailState({
    this.status = ProfileDetailStatus.initial,
    this.profile,
    this.failure,
    this.isOpeningDirectMessage = false,
  });

  final ProfileDetailStatus status;
  final MemberProfile? profile;
  final AppFailure? failure;
  final bool isOpeningDirectMessage;

  ProfileDetailState copyWith({
    ProfileDetailStatus? status,
    MemberProfile? profile,
    AppFailure? failure,
    bool clearFailure = false,
    bool? isOpeningDirectMessage,
  }) {
    return ProfileDetailState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      failure: clearFailure ? null : (failure ?? this.failure),
      isOpeningDirectMessage:
          isOpeningDirectMessage ?? this.isOpeningDirectMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileDetailState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          profile == other.profile &&
          failure == other.failure &&
          isOpeningDirectMessage == other.isOpeningDirectMessage;

  @override
  int get hashCode =>
      Object.hash(status, profile, failure, isOpeningDirectMessage);
}

final profileDetailStoreProvider =
    NotifierProvider<ProfileDetailStore, ProfileDetailState>(
  ProfileDetailStore.new,
  dependencies: [currentProfileTargetProvider],
);

class ProfileDetailStore extends Notifier<ProfileDetailState> {
  @override
  ProfileDetailState build() {
    final target = ref.watch(currentProfileTargetProvider);
    final session = ref.read(sessionStoreProvider);

    if (target.isSelf || target.userId == session.userId) {
      return ProfileDetailState(
        status: ProfileDetailStatus.success,
        profile: MemberProfile(
          id: session.userId ?? 'unknown',
          displayName: session.displayName ?? 'User',
          isSelf: true,
        ),
      );
    }

    if (!target.canLoadRemote) {
      return const ProfileDetailState(
        status: ProfileDetailStatus.failure,
        failure: UnknownFailure(
          message: 'Profile requires a server-scoped route.',
          causeType: 'invalid_profile_target',
        ),
      );
    }

    scheduleMicrotask(_loadProfile);

    return const ProfileDetailState(status: ProfileDetailStatus.loading);
  }

  Future<void> retry() => _loadProfile();

  Future<String> openDirectMessage() async {
    final target = ref.read(currentProfileTargetProvider);
    final userId = target.userId;
    final serverId = target.serverId;

    if (userId == null || serverId == null) {
      throw const UnknownFailure(
        message: 'Direct message is unavailable for this profile.',
        causeType: 'invalid_profile_target',
      );
    }

    state = state.copyWith(clearFailure: true, isOpeningDirectMessage: true);

    try {
      final channelId = await ref
          .read(memberRepositoryProvider)
          .openDirectMessage(serverId, userId: userId);
      state = state.copyWith(isOpeningDirectMessage: false);
      return channelId;
    } on AppFailure catch (failure) {
      state = state.copyWith(failure: failure, isOpeningDirectMessage: false);
      rethrow;
    }
  }

  Future<void> _loadProfile() async {
    final target = ref.read(currentProfileTargetProvider);
    final userId = target.userId;
    final serverId = target.serverId;

    if (userId == null || serverId == null) {
      return;
    }

    state = state.copyWith(
      status: ProfileDetailStatus.loading,
      clearFailure: true,
    );

    try {
      final profile = await ref
          .read(profileRepositoryProvider)
          .loadProfile(serverId, userId: userId);
      state = state.copyWith(
        status: ProfileDetailStatus.success,
        profile: profile,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      state = state.copyWith(
        status: ProfileDetailStatus.failure,
        failure: failure,
      );
    }
  }
}
