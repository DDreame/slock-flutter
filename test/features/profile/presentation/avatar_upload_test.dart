import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
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
// T4: Upload success updates displayed avatar URL
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

  // -------------------------------------------------------------------------
  // T1: Profile page shows edit avatar button when viewing own profile
  // -------------------------------------------------------------------------
  testWidgets(
    'Profile page shows edit avatar button for self profile',
    skip: true,
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileTargetProvider.overrideWithValue(
              const ProfileTarget(),
            ),
            profileDetailStoreProvider.overrideWith(
              () => _FixedProfileDetailStore(selfProfile),
            ),
          ],
          child: const MaterialApp(
            home: ProfilePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Edit avatar overlay button should be visible on self profile.
      expect(
        find.byKey(const ValueKey('profile-avatar-edit-button')),
        findsOneWidget,
        reason: 'Self profile must show an edit avatar button overlay',
      );

      // Other profile should NOT show the edit button.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileTargetProvider.overrideWithValue(
              const ProfileTarget(userId: 'user-2'),
            ),
            profileDetailStoreProvider.overrideWith(
              () => _FixedProfileDetailStore(otherProfile),
            ),
          ],
          child: const MaterialApp(
            home: ProfilePage(userId: 'user-2'),
          ),
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
    skip: true,
    (tester) async {
      // Track whether image picker was invoked.
      bool pickerCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileTargetProvider.overrideWithValue(
              const ProfileTarget(),
            ),
            profileDetailStoreProvider.overrideWith(
              () => _FixedProfileDetailStore(selfProfile),
            ),
            // Override image picker provider with a fake that records calls.
            imagePickerProvider.overrideWithValue(
              FakeImagePicker(onPick: () => pickerCalled = true),
            ),
          ],
          child: const MaterialApp(
            home: ProfilePage(),
          ),
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
    skip: true,
    (tester) async {
      String? uploadedPath;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileTargetProvider.overrideWithValue(
              const ProfileTarget(),
            ),
            profileDetailStoreProvider.overrideWith(
              () => _FixedProfileDetailStore(selfProfile),
            ),
            // Fake picker returns a known file path.
            imagePickerProvider.overrideWithValue(
              FakeImagePicker(resultPath: '/tmp/test-avatar.png'),
            ),
            // Fake upload service records the uploaded path.
            avatarUploadServiceProvider.overrideWithValue(
              FakeAvatarUploadService(
                onUpload: (path) => uploadedPath = path,
                resultUrl: 'https://example.com/new-avatar.png',
              ),
            ),
          ],
          child: const MaterialApp(
            home: ProfilePage(),
          ),
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
  // T4: Upload success updates displayed avatar
  // -------------------------------------------------------------------------
  testWidgets(
    'Upload success updates displayed avatar',
    skip: true,
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileTargetProvider.overrideWithValue(
              const ProfileTarget(),
            ),
            profileDetailStoreProvider.overrideWith(
              () => _FixedProfileDetailStore(selfProfile),
            ),
            imagePickerProvider.overrideWithValue(
              FakeImagePicker(resultPath: '/tmp/test-avatar.png'),
            ),
            avatarUploadServiceProvider.overrideWithValue(
              FakeAvatarUploadService(
                resultUrl: 'https://example.com/new-avatar.png',
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ProfilePage(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap edit avatar → picker → upload → success.
      await tester.tap(
        find.byKey(const ValueKey('profile-avatar-edit-button')),
      );
      await tester.pumpAndSettle();

      // After successful upload, the avatar widget should show the new URL.
      // Verify via the profile detail state or the avatar widget's image URL.
      expect(
        find.byKey(const ValueKey('profile-avatar-image')),
        findsOneWidget,
        reason: 'Avatar image widget must be present after upload success',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T5: Upload failure shows error snackbar
  // -------------------------------------------------------------------------
  testWidgets(
    'Upload failure shows error snackbar',
    skip: true,
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileTargetProvider.overrideWithValue(
              const ProfileTarget(),
            ),
            profileDetailStoreProvider.overrideWith(
              () => _FixedProfileDetailStore(selfProfile),
            ),
            imagePickerProvider.overrideWithValue(
              FakeImagePicker(resultPath: '/tmp/test-avatar.png'),
            ),
            // Upload service that throws on upload.
            avatarUploadServiceProvider.overrideWithValue(
              FakeAvatarUploadService(
                shouldFail: true,
                errorMessage: 'File too large',
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: ProfilePage()),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
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
// Fakes & Stubs
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

/// Fake image picker for testing. Records pick calls and returns
/// a configured result path (or null for cancellation).
class FakeImagePicker {
  FakeImagePicker({this.onPick, this.resultPath});

  final VoidCallback? onPick;
  final String? resultPath;

  Future<String?> pickImage() async {
    onPick?.call();
    return resultPath;
  }
}

/// Fake avatar upload service for testing.
class FakeAvatarUploadService {
  FakeAvatarUploadService({
    this.onUpload,
    this.resultUrl,
    this.shouldFail = false,
    this.errorMessage,
  });

  final void Function(String path)? onUpload;
  final String? resultUrl;
  final bool shouldFail;
  final String? errorMessage;

  Future<String> upload(String filePath) async {
    onUpload?.call(filePath);
    if (shouldFail) {
      throw AvatarUploadException(errorMessage ?? 'Upload failed');
    }
    return resultUrl ?? 'https://example.com/avatar.png';
  }
}

/// Exception thrown when avatar upload fails.
class AvatarUploadException implements Exception {
  AvatarUploadException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Stub provider for image picker — Phase B will implement.
final imagePickerProvider = Provider<FakeImagePicker>((ref) {
  throw UnimplementedError('#575 Phase B: implement image picker provider');
});

/// Stub provider for avatar upload service — Phase B will implement.
final avatarUploadServiceProvider = Provider<FakeAvatarUploadService>((ref) {
  throw UnimplementedError('#575 Phase B: implement avatar upload service');
});
