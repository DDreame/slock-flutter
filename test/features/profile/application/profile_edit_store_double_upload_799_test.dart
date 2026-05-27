// =============================================================================
// #799 — ProfileEditStore Partial Failure + Double Avatar Upload Guard
//
// Root cause: save() re-uploads avatar on retry after a PATCH failure because
// selectedAvatarPath is never cleared on partial success (upload OK, PATCH KO).
//
// Fix: After successful avatar upload, clear selectedAvatarPath and set
// avatarCommitted = true so retry skips re-upload and UI can surface partial
// success state.
//
// Invariants verified:
//   INV-799-1: PATCH fails after upload → avatarCommitted = true in state
//   INV-799-2: Retry after partial failure → avatar upload NOT re-triggered
//   INV-799-3: Upload failure → retry uploads avatar again (no skip)
//   INV-799-4: Both succeed → avatarCommitted = false, selectedAvatarPath cleared
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/profile/application/avatar_upload_service.dart';
import 'package:slock_app/features/profile/application/profile_edit_store.dart';
import 'package:slock_app/features/profile/data/profile_edit_repository.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  group('#799 — ProfileEditStore double upload guard', () {
    // -------------------------------------------------------------------------
    // INV-799-1: PATCH fails after upload → avatarCommitted = true
    // -------------------------------------------------------------------------
    test(
      'PATCH fails after avatar upload → avatarCommitted = true (INV-799-1)',
      () async {
        final uploadService = _CountingAvatarUploadService(
          resultUrl: 'https://cdn.example.com/new-avatar.png',
        );
        final repository = _FakeProfileEditRepository(
          failure: const ServerFailure(
            message: 'Internal Server Error',
            statusCode: 500,
          ),
        );
        final container = ProviderContainer(overrides: [
          sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          profileEditRepositoryProvider.overrideWithValue(repository),
          avatarUploadServiceProvider.overrideWithValue(uploadService),
        ]);
        addTearDown(container.dispose);

        final store = container.read(profileEditStoreProvider.notifier);
        store.setDisplayName('Alice');
        store.setSelectedAvatarPath('/tmp/avatar.png');
        await store.save();

        final state = container.read(profileEditStoreProvider);
        expect(state.status, ProfileEditStatus.failure);
        expect(state.avatarCommitted, isTrue,
            reason: 'Avatar uploaded successfully — should be flagged');
        expect(state.avatarUrl, 'https://cdn.example.com/new-avatar.png');
        expect(uploadService.uploadCount, 1);
      },
    );

    // -------------------------------------------------------------------------
    // INV-799-2: Retry after partial failure → no re-upload
    // -------------------------------------------------------------------------
    test(
      'retry after partial failure → avatar upload NOT re-triggered (INV-799-2)',
      () async {
        var patchCallCount = 0;
        final uploadService = _CountingAvatarUploadService(
          resultUrl: 'https://cdn.example.com/new-avatar.png',
        );
        final repository = _SequenceProfileEditRepository(
          responses: [
            // First call: PATCH fails
            _PatchResponse.failure(const ServerFailure(
              message: 'Internal Server Error',
              statusCode: 500,
            )),
            // Second call (retry): PATCH succeeds
            _PatchResponse.success(const MemberProfile(
              id: 'user-1',
              displayName: 'Alice',
              description: 'Bio',
              avatarUrl: 'https://cdn.example.com/new-avatar.png',
              isSelf: true,
            )),
          ],
          onCall: () => patchCallCount++,
        );
        final container = ProviderContainer(overrides: [
          sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          profileEditRepositoryProvider.overrideWithValue(repository),
          avatarUploadServiceProvider.overrideWithValue(uploadService),
        ]);
        addTearDown(container.dispose);

        final store = container.read(profileEditStoreProvider.notifier);
        store.setDisplayName('Alice');
        store.setSelectedAvatarPath('/tmp/avatar.png');

        // First attempt: upload succeeds, PATCH fails.
        await store.save();
        expect(container.read(profileEditStoreProvider).status,
            ProfileEditStatus.failure);
        expect(uploadService.uploadCount, 1,
            reason: 'First save should upload once');

        // Retry: avatar already committed, should NOT re-upload.
        await store.save();
        expect(container.read(profileEditStoreProvider).status,
            ProfileEditStatus.success);
        expect(uploadService.uploadCount, 1,
            reason: 'Retry should NOT re-upload avatar');
        expect(patchCallCount, 2, reason: 'PATCH should be called twice');
      },
    );

    // -------------------------------------------------------------------------
    // INV-799-3: Upload failure → retry uploads avatar again
    // -------------------------------------------------------------------------
    test(
      'upload failure → retry uploads avatar again (INV-799-3)',
      () async {
        final uploadService = _SequenceAvatarUploadService(
          responses: [
            // First: upload fails
            _UploadResponse.failure(
              AvatarUploadException(
                'Network error',
                code: AvatarUploadErrorCode.uploadFailed,
              ),
            ),
            // Second (retry): upload succeeds
            _UploadResponse.success('https://cdn.example.com/new-avatar.png'),
          ],
        );
        final repository = _FakeProfileEditRepository(
          result: const MemberProfile(
            id: 'user-1',
            displayName: 'Alice',
            description: 'Bio',
            avatarUrl: 'https://cdn.example.com/new-avatar.png',
            isSelf: true,
          ),
        );
        final container = ProviderContainer(overrides: [
          sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          profileEditRepositoryProvider.overrideWithValue(repository),
          avatarUploadServiceProvider.overrideWithValue(uploadService),
        ]);
        addTearDown(container.dispose);

        final store = container.read(profileEditStoreProvider.notifier);
        store.setDisplayName('Alice');
        store.setSelectedAvatarPath('/tmp/avatar.png');

        // First attempt: upload fails.
        await store.save();
        expect(container.read(profileEditStoreProvider).status,
            ProfileEditStatus.failure);
        expect(uploadService.callCount, 1);

        // Retry: should upload again since previous upload failed.
        await store.save();
        expect(container.read(profileEditStoreProvider).status,
            ProfileEditStatus.success);
        expect(uploadService.callCount, 2,
            reason: 'Failed upload should be retried');
      },
    );

    // -------------------------------------------------------------------------
    // INV-799-4: Both succeed → avatarCommitted = false, path cleared
    // -------------------------------------------------------------------------
    test(
      'both succeed → avatarCommitted = false, selectedAvatarPath cleared '
      '(INV-799-4)',
      () async {
        final uploadService = _CountingAvatarUploadService(
          resultUrl: 'https://cdn.example.com/new-avatar.png',
        );
        final repository = _FakeProfileEditRepository(
          result: const MemberProfile(
            id: 'user-1',
            displayName: 'Alice',
            description: 'Bio',
            avatarUrl: 'https://cdn.example.com/new-avatar.png',
            isSelf: true,
          ),
        );
        final container = ProviderContainer(overrides: [
          sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          profileEditRepositoryProvider.overrideWithValue(repository),
          avatarUploadServiceProvider.overrideWithValue(uploadService),
        ]);
        addTearDown(container.dispose);

        final store = container.read(profileEditStoreProvider.notifier);
        store.setDisplayName('Alice');
        store.setSelectedAvatarPath('/tmp/avatar.png');
        await store.save();

        final state = container.read(profileEditStoreProvider);
        expect(state.status, ProfileEditStatus.success);
        expect(state.avatarCommitted, isFalse);
        expect(state.selectedAvatarPath, isNull,
            reason: 'Avatar path should be cleared on success');
        expect(uploadService.uploadCount, 1);
      },
    );
  });
}

// =============================================================================
// Fakes
// =============================================================================

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-1',
        displayName: 'Alice',
        bio: 'Original bio',
        avatarUrl: 'old-avatar.png',
        token: 'token',
      );

  @override
  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
    bool clearDisplayName = false,
    bool clearBio = false,
    bool clearAvatarUrl = false,
  }) async {
    state = state.copyWith(
      displayName: displayName,
      bio: bio,
      avatarUrl: avatarUrl,
      clearDisplayName: clearDisplayName,
      clearBio: clearBio,
      clearAvatarUrl: clearAvatarUrl,
    );
  }
}

class _FakeProfileEditRepository implements ProfileEditRepository {
  _FakeProfileEditRepository({this.result, this.failure});

  final MemberProfile? result;
  final AppFailure? failure;

  @override
  Future<MemberProfile> updateCurrentUser({
    required String displayName,
    required String bio,
  }) async {
    final failure = this.failure;
    if (failure != null) throw failure;
    return result ??
        MemberProfile(
          id: 'user-1',
          displayName: displayName,
          description: bio,
          isSelf: true,
        );
  }
}

/// A repository that returns different results on successive calls.
class _SequenceProfileEditRepository implements ProfileEditRepository {
  _SequenceProfileEditRepository({
    required this.responses,
    this.onCall,
  });

  final List<_PatchResponse> responses;
  final void Function()? onCall;
  int _callIndex = 0;

  @override
  Future<MemberProfile> updateCurrentUser({
    required String displayName,
    required String bio,
  }) async {
    onCall?.call();
    final response = responses[_callIndex.clamp(0, responses.length - 1)];
    _callIndex++;
    if (response.failure != null) throw response.failure!;
    return response.result!;
  }
}

class _PatchResponse {
  _PatchResponse.success(this.result) : failure = null;
  _PatchResponse.failure(this.failure) : result = null;

  final MemberProfile? result;
  final AppFailure? failure;
}

/// Avatar upload service that counts invocations.
class _CountingAvatarUploadService implements AvatarUploadService {
  _CountingAvatarUploadService({required this.resultUrl});

  final String resultUrl;
  int uploadCount = 0;

  @override
  Future<String> upload(String filePath) async {
    uploadCount++;
    return resultUrl;
  }
}

/// Avatar upload service that returns different results on successive calls.
class _SequenceAvatarUploadService implements AvatarUploadService {
  _SequenceAvatarUploadService({required this.responses});

  final List<_UploadResponse> responses;
  int callCount = 0;

  @override
  Future<String> upload(String filePath) async {
    final response = responses[callCount.clamp(0, responses.length - 1)];
    callCount++;
    if (response.error != null) throw response.error!;
    return response.url!;
  }
}

class _UploadResponse {
  _UploadResponse.success(this.url) : error = null;
  _UploadResponse.failure(this.error) : url = null;

  final String? url;
  final Object? error;
}
