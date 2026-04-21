import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/stores/session/session_store.dart';

@immutable
class ProfileTarget {
  const ProfileTarget({this.userId});

  final String? userId;

  bool get isSelf => userId == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileTarget &&
          runtimeType == other.runtimeType &&
          userId == other.userId;

  @override
  int get hashCode => userId.hashCode;
}

final currentProfileTargetProvider = Provider<ProfileTarget>((ref) {
  throw UnimplementedError(
    'currentProfileTargetProvider must be overridden in a ProviderScope',
  );
});

enum ProfileDetailStatus { initial, success }

@immutable
class ProfileDetailState {
  const ProfileDetailState({
    this.status = ProfileDetailStatus.initial,
    this.profile,
  });

  final ProfileDetailStatus status;
  final MemberProfile? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileDetailState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          profile == other.profile;

  @override
  int get hashCode => Object.hash(status, profile);
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

    return ProfileDetailState(
      status: ProfileDetailStatus.success,
      profile: MemberProfile(
        id: target.userId!,
        displayName: target.userId!,
      ),
    );
  }
}
