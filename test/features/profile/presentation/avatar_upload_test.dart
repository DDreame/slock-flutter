import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/profile/application/avatar_upload_service.dart';
import 'package:slock_app/features/profile/application/profile_detail_store.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/profile/presentation/page/profile_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// #575: Custom Avatar Upload — Phase A (test-only)
//
// Tests for avatar edit affordance, image picker trigger, upload API call,
// success state update, and error handling.
//
// Invariants verified:
// T1: Profile page shows edit avatar button when viewing own profile
// T2: Tapping edit avatar opens image picker
// T3: Selected image is uploaded via user API (multipart PUT /users/me)
// T4: Upload success updates displayed avatar URL (old → new)
// T5: Upload failure shows error snackbar
// ---------------------------------------------------------------------------

void main() {
  const selfProfile = MemberProfile(
    id: 'user-1',
    displayName: 'Test User',
    avatarUrl: 'https://example.com/old-avatar.png',
    isSelf: true,
  );

  const otherProfile = MemberProfile(
    id: 'user-2',
    displayName: 'Other User',
    avatarUrl: 'https://example.com/other-avatar.png',
    isSelf: false,
  );

  /// Standard test harness with AppTheme + localizations.
  Widget buildApp({
    required List<Override> overrides,
    Widget? child,
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child ?? const Scaffold(body: ProfilePage()),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // T1: Profile page shows edit avatar button when viewing own profile
  // -------------------------------------------------------------------------
  testWidgets(
    'Profile page shows edit avatar button for self profile',
    (tester) async {
      await tester.pumpWidget(
        buildApp(
          overrides: [
            currentProfileTargetProvider.overrideWithValue(
              const ProfileTarget(),
            ),
            profileDetailStoreProvider.overrideWith(
              () => _FixedProfileDetailStore(selfProfile),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Edit avatar overlay button should be visible on self profile.
      expect(
        find.byKey(const ValueKey('profile-avatar-edit-button')),
        findsOneWidget,
        reason: 'Self profile must show an edit avatar button overlay',
      );
    },
  );

  testWidgets(
    'Profile page does NOT show edit avatar button for other profile',
    (tester) async {
      await tester.pumpWidget(
        buildApp(
          overrides: [
            currentProfileTargetProvider.overrideWithValue(
              const ProfileTarget(userId: 'user-2'),
            ),
            profileDetailStoreProvider.overrideWith(
              () => _FixedProfileDetailStore(otherProfile),
            ),
          ],
          child: const Scaffold(body: ProfilePage(userId: 'user-2')),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('profile-avatar-edit-button')),
        findsNothing,
        reason: 'Other profile must not show edit avatar button',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T2: Tapping edit avatar opens image picker
  // -------------------------------------------------------------------------
  testWidgets(
    'Tapping edit avatar opens image picker',
    (tester) async {
      // Track whether image picker was invoked.
      bool pickerCalled = false;

      await tester.pumpWidget(
        buildApp(
          overrides: [
            currentProfileTargetProvider.overrideWithValue(
              const ProfileTarget(),
            ),
            profileDetailStoreProvider.overrideWith(
              () => _FixedProfileDetailStore(selfProfile),
            ),
            // Override image picker provider with a fake that records calls.
            imagePickerProvider.overrideWithValue(
              _FakeImagePicker(onPick: () => pickerCalled = true),
            ),
            avatarUploadServiceProvider.overrideWithValue(
              _FakeAvatarUploadService(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap the edit avatar button.
      await tester.tap(
        find.byKey(const ValueKey('profile-avatar-edit-button')),
      );
      await tester.pumpAndSettle();

      expect(pickerCalled, isTrue,
          reason: 'Tapping edit avatar must invoke the image picker');
    },
  );

  // -------------------------------------------------------------------------
  // T3: Selected image is uploaded via user API
  // -------------------------------------------------------------------------
  testWidgets(
    'Selected image is uploaded via user API',
    (tester) async {
      String? uploadedPath;

      await tester.pumpWidget(
        buildApp(
          overrides: [
            currentProfileTargetProvider.overrideWithValue(
              const ProfileTarget(),
            ),
            profileDetailStoreProvider.overrideWith(
              () => _FixedProfileDetailStore(selfProfile),
            ),
            // Fake picker returns a known file path.
            imagePickerProvider.overrideWithValue(
              _FakeImagePicker(resultPath: '/tmp/test-avatar.png'),
            ),
            // Fake upload service records the uploaded path.
            avatarUploadServiceProvider.overrideWithValue(
              _FakeAvatarUploadService(
                onUpload: (path) => uploadedPath = path,
                resultUrl: 'https://example.com/new-avatar.png',
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap edit avatar → picker returns file → upload triggered.
      await tester.tap(
        find.byKey(const ValueKey('profile-avatar-edit-button')),
      );
      await tester.pumpAndSettle();

      expect(uploadedPath, '/tmp/test-avatar.png',
          reason: 'The picked image path must be sent to the upload service');
    },
  );

  // -------------------------------------------------------------------------
  // T4: Upload success updates displayed avatar URL (old → new)
  // -------------------------------------------------------------------------
  testWidgets(
    'Upload success updates displayed avatar',
    (tester) async {
      // Start with a profile that has NO avatar (initials shown).
      const noAvatarProfile = MemberProfile(
        id: 'user-1',
        displayName: 'Test User',
        avatarUrl: null, // No avatar — shows initials
        isSelf: true,
      );

      await tester.pumpWidget(
        buildApp(
          overrides: [
            currentProfileTargetProvider.overrideWithValue(
              const ProfileTarget(),
            ),
            profileDetailStoreProvider.overrideWith(
              () => _FixedProfileDetailStore(noAvatarProfile),
            ),
            imagePickerProvider.overrideWithValue(
              _FakeImagePicker(resultPath: '/tmp/test-avatar.png'),
            ),
            avatarUploadServiceProvider.overrideWithValue(
              _FakeAvatarUploadService(
                resultUrl: 'https://example.com/new-avatar.png',
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Before upload: avatar shows initials (no image).
      expect(
        find.byKey(const ValueKey('profile-avatar-initials')),
        findsOneWidget,
        reason: 'Before upload, avatar should show initials (no avatarUrl)',
      );
      expect(
        find.byKey(const ValueKey('profile-avatar-image')),
        findsNothing,
        reason: 'Before upload, avatar image should not be present',
      );

      // Tap edit avatar → picker → upload → success.
      await tester.tap(
        find.byKey(const ValueKey('profile-avatar-edit-button')),
      );
      await tester.pumpAndSettle();

      // After successful upload: avatar now shows the image (not initials).
      expect(
        find.byKey(const ValueKey('profile-avatar-image')),
        findsOneWidget,
        reason: 'After upload success, avatar must show the new image',
      );
      expect(
        find.byKey(const ValueKey('profile-avatar-initials')),
        findsNothing,
        reason: 'After upload success, initials should be replaced by image',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T5: Upload failure shows error snackbar
  // -------------------------------------------------------------------------
  testWidgets(
    'Upload failure shows error snackbar',
    (tester) async {
      await tester.pumpWidget(
        buildApp(
          overrides: [
            currentProfileTargetProvider.overrideWithValue(
              const ProfileTarget(),
            ),
            profileDetailStoreProvider.overrideWith(
              () => _FixedProfileDetailStore(selfProfile),
            ),
            imagePickerProvider.overrideWithValue(
              _FakeImagePicker(resultPath: '/tmp/test-avatar.png'),
            ),
            // Upload service that throws on upload.
            avatarUploadServiceProvider.overrideWithValue(
              _FakeAvatarUploadService(
                shouldFail: true,
                errorMessage: 'File too large',
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap edit avatar → picker → upload → failure.
      await tester.tap(
        find.byKey(const ValueKey('profile-avatar-edit-button')),
      );
      await tester.pumpAndSettle();

      // Error snackbar should appear.
      expect(
        find.text('File too large'),
        findsOneWidget,
        reason: 'Upload failure must show an error snackbar with message',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Fixed profile store that returns a pre-set profile immediately.
class _FixedProfileDetailStore extends ProfileDetailStore {
  _FixedProfileDetailStore(this._profile);
  final MemberProfile _profile;

  @override
  ProfileDetailState build() => ProfileDetailState(
        status: ProfileDetailStatus.success,
        profile: _profile,
      );
}

/// Fake image picker for testing.
class _FakeImagePicker implements ImagePickerService {
  _FakeImagePicker({this.onPick, this.resultPath});

  final VoidCallback? onPick;
  final String? resultPath;

  @override
  Future<String?> pickImage() async {
    onPick?.call();
    return resultPath;
  }
}

/// Fake avatar upload service for testing.
class _FakeAvatarUploadService implements AvatarUploadService {
  _FakeAvatarUploadService({
    this.onUpload,
    this.resultUrl,
    this.shouldFail = false,
    this.errorMessage,
  });

  final void Function(String path)? onUpload;
  final String? resultUrl;
  final bool shouldFail;
  final String? errorMessage;

  @override
  Future<String> upload(String filePath) async {
    onUpload?.call(filePath);
    if (shouldFail) {
      throw AvatarUploadException(errorMessage ?? 'Upload failed');
    }
    return resultUrl ?? 'https://example.com/avatar.png';
  }
}
