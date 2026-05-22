import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/profile/application/avatar_upload_service.dart';
import 'package:slock_app/features/profile/data/profile_edit_repository.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

enum ProfileEditStatus { idle, saving, success, failure }

@immutable
class ProfileEditState {
  const ProfileEditState({
    this.displayName = '',
    this.bio = '',
    this.avatarUrl,
    this.selectedAvatarPath,
    this.status = ProfileEditStatus.idle,
    this.failure,
  });

  final String displayName;
  final String bio;
  final String? avatarUrl;
  final String? selectedAvatarPath;
  final ProfileEditStatus status;
  final AppFailure? failure;

  bool get isSaving => status == ProfileEditStatus.saving;

  ProfileEditState copyWith({
    String? displayName,
    String? bio,
    String? avatarUrl,
    bool clearAvatarUrl = false,
    String? selectedAvatarPath,
    bool clearSelectedAvatarPath = false,
    ProfileEditStatus? status,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return ProfileEditState(
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      selectedAvatarPath: clearSelectedAvatarPath
          ? null
          : (selectedAvatarPath ?? this.selectedAvatarPath),
      status: status ?? this.status,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileEditState &&
          runtimeType == other.runtimeType &&
          displayName == other.displayName &&
          bio == other.bio &&
          avatarUrl == other.avatarUrl &&
          selectedAvatarPath == other.selectedAvatarPath &&
          status == other.status &&
          failure == other.failure;

  @override
  int get hashCode => Object.hash(
        displayName,
        bio,
        avatarUrl,
        selectedAvatarPath,
        status,
        failure,
      );
}

final profileEditStoreProvider =
    NotifierProvider.autoDispose<ProfileEditStore, ProfileEditState>(
  ProfileEditStore.new,
);

class ProfileEditStore extends AutoDisposeNotifier<ProfileEditState> {
  @override
  ProfileEditState build() {
    final session = ref.read(sessionStoreProvider);
    return ProfileEditState(
      displayName: session.displayName ?? '',
      bio: session.bio ?? '',
      avatarUrl: session.avatarUrl,
    );
  }

  void setDisplayName(String value) {
    state = state.copyWith(displayName: value, clearFailure: true);
  }

  void setBio(String value) {
    state = state.copyWith(bio: value, clearFailure: true);
  }

  void setSelectedAvatarPath(String path) {
    state = state.copyWith(selectedAvatarPath: path, clearFailure: true);
  }

  Future<void> pickAvatar() async {
    final path = await ref.read(imagePickerProvider).pickImage();
    if (path == null) return;
    setSelectedAvatarPath(path);
  }

  Future<void> save() async {
    final displayName = state.displayName.trim();
    final bio = state.bio.trim();
    if (displayName.isEmpty) {
      state = state.copyWith(
        status: ProfileEditStatus.failure,
        failure: const ValidationFailure(
          message: 'Display name is required.',
          causeType: 'empty_display_name',
        ),
      );
      return;
    }

    final previousSession = ref.read(sessionStoreProvider);
    final selectedAvatarPath = state.selectedAvatarPath;
    String? uploadedAvatarUrl;
    state = state.copyWith(
      status: ProfileEditStatus.saving,
      clearFailure: true,
    );

    try {
      var avatarUrl = state.avatarUrl;
      if (selectedAvatarPath != null) {
        uploadedAvatarUrl = await ref.read(avatarUploadServiceProvider).upload(
              selectedAvatarPath,
            );
        avatarUrl = uploadedAvatarUrl;
      }

      await ref.read(sessionStoreProvider.notifier).updateProfile(
            displayName: displayName,
            bio: bio,
            avatarUrl: avatarUrl,
          );

      final profile =
          await ref.read(profileEditRepositoryProvider).updateCurrentUser(
                displayName: displayName,
                bio: bio,
              );

      await ref.read(sessionStoreProvider.notifier).updateProfile(
            displayName: profile.displayName,
            bio: profile.description ?? bio,
            avatarUrl: profile.avatarUrl ?? avatarUrl,
          );

      state = state.copyWith(
        displayName: profile.displayName,
        bio: profile.description ?? bio,
        avatarUrl: profile.avatarUrl ?? avatarUrl,
        clearSelectedAvatarPath: true,
        status: ProfileEditStatus.success,
        clearFailure: true,
      );
    } on AppFailure catch (failure) {
      await _rollbackSession(
        previousSession,
        keepAvatarUrl: uploadedAvatarUrl,
      );
      state = state.copyWith(
        avatarUrl: uploadedAvatarUrl,
        status: ProfileEditStatus.failure,
        failure: failure,
      );
    } on AvatarUploadException catch (error) {
      await _rollbackSession(previousSession);
      state = state.copyWith(
        status: ProfileEditStatus.failure,
        failure: UnknownFailure(
          message: error.message,
          causeType: error.runtimeType.toString(),
        ),
      );
    } catch (error, stackTrace) {
      _reportUnexpectedError(error, stackTrace);
      await _rollbackSession(previousSession);
      state = state.copyWith(
        status: ProfileEditStatus.failure,
        failure: UnknownFailure(
          message: 'Failed to update profile.',
          causeType: error.runtimeType.toString(),
        ),
      );
    }
  }

  Future<void> _rollbackSession(
    SessionState previousSession, {
    String? keepAvatarUrl,
  }) {
    final avatarUrl = keepAvatarUrl ?? previousSession.avatarUrl;
    return ref.read(sessionStoreProvider.notifier).updateProfile(
          displayName: previousSession.displayName,
          bio: previousSession.bio,
          avatarUrl: avatarUrl,
          clearDisplayName: previousSession.displayName == null,
          clearBio: previousSession.bio == null,
          clearAvatarUrl: avatarUrl == null,
        );
  }

  void _reportUnexpectedError(Object error, StackTrace stackTrace) {
    try {
      ref.read(crashReporterProvider).captureException(
        error,
        stackTrace: stackTrace,
        extra: const {'operation': 'ProfileEditStore.save'},
      );
    } catch (_) {
      // Crash reporting is best-effort; rollback must still complete.
    }
  }
}
