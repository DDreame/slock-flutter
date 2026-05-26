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
    this.avatarCommitted = false,
  });

  final String displayName;
  final String bio;
  final String? avatarUrl;
  final String? selectedAvatarPath;
  final ProfileEditStatus status;
  final AppFailure? failure;

  /// True when avatar was uploaded successfully but profile PATCH failed.
  /// Allows UI to surface partial success and prevents re-upload on retry.
  final bool avatarCommitted;

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
    bool? avatarCommitted,
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
      avatarCommitted: avatarCommitted ?? this.avatarCommitted,
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
          failure == other.failure &&
          avatarCommitted == other.avatarCommitted;

  @override
  int get hashCode => Object.hash(
        displayName,
        bio,
        avatarUrl,
        selectedAvatarPath,
        status,
        failure,
        avatarCommitted,
      );
}

final profileEditStoreProvider =
    NotifierProvider.autoDispose<ProfileEditStore, ProfileEditState>(
  ProfileEditStore.new,
);

class ProfileEditStore extends AutoDisposeNotifier<ProfileEditState> {
  bool _disposed = false;

  @override
  ProfileEditState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);

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
        if (_disposed) return;
        avatarUrl = uploadedAvatarUrl;
        // Avatar committed server-side — clear the path so retry won't
        // re-upload, and update avatarUrl optimistically (#799).
        state = state.copyWith(
          avatarUrl: uploadedAvatarUrl,
          clearSelectedAvatarPath: true,
        );
      }

      await ref.read(sessionStoreProvider.notifier).updateProfile(
            displayName: displayName,
            bio: bio,
            avatarUrl: avatarUrl,
          );
      if (_disposed) return;

      final profile =
          await ref.read(profileEditRepositoryProvider).updateCurrentUser(
                displayName: displayName,
                bio: bio,
              );
      if (_disposed) return;

      await ref.read(sessionStoreProvider.notifier).updateProfile(
            displayName: profile.displayName,
            bio: profile.description ?? bio,
            avatarUrl: profile.avatarUrl ?? avatarUrl,
          );
      if (_disposed) return;

      state = state.copyWith(
        displayName: profile.displayName,
        bio: profile.description ?? bio,
        avatarUrl: profile.avatarUrl ?? avatarUrl,
        clearSelectedAvatarPath: true,
        status: ProfileEditStatus.success,
        clearFailure: true,
        avatarCommitted: false,
      );
    } on AppFailure catch (failure) {
      if (_disposed) return;
      await _rollbackSession(
        previousSession,
        keepAvatarUrl: uploadedAvatarUrl,
      );
      if (_disposed) return;
      state = state.copyWith(
        avatarUrl: uploadedAvatarUrl,
        status: ProfileEditStatus.failure,
        failure: failure,
        avatarCommitted: uploadedAvatarUrl != null,
      );
    } on AvatarUploadException catch (error) {
      if (_disposed) return;
      await _rollbackSession(previousSession);
      if (_disposed) return;
      state = state.copyWith(
        status: ProfileEditStatus.failure,
        failure: error.failure ??
            UnknownFailure(
              message: error.message,
              causeType: error.runtimeType.toString(),
            ),
        avatarCommitted: false,
      );
    } catch (error, stackTrace) {
      if (_disposed) return;
      _reportUnexpectedError(error, stackTrace);
      await _rollbackSession(previousSession);
      if (_disposed) return;
      state = state.copyWith(
        status: ProfileEditStatus.failure,
        failure: UnknownFailure(
          message: 'Failed to update profile.',
          causeType: error.runtimeType.toString(),
        ),
        avatarCommitted: false,
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
