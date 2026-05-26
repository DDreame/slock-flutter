// =============================================================================
// #823 — ProfileEditStore Disposal Guard: 3 Await Boundaries in save()
//
// Verifies: Disposing the store during save() does NOT throw StateError.
// The `_disposed` guard silently bails out after each await boundary.
//
// Load-bearing proof:
//   Reverting the `if (_disposed) return` guards causes StateError from
//   state assignment on a disposed AutoDisposeNotifier.
// =============================================================================

import 'dart:async';

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
  group('#823 — ProfileEditStore disposal safety during save()', () {
    // -------------------------------------------------------------------------
    // 1. Dispose during avatar upload
    // -------------------------------------------------------------------------
    test('dispose during avatar upload does not throw StateError', () async {
      final uploadCompleter = Completer<String>();
      final container = ProviderContainer(overrides: [
        sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
        profileEditRepositoryProvider
            .overrideWithValue(_FakeProfileEditRepository()),
        avatarUploadServiceProvider.overrideWithValue(
          _DelayedAvatarUploadService(completer: uploadCompleter),
        ),
      ]);

      final sub = container.listen(profileEditStoreProvider, (_, __) {});
      final store = container.read(profileEditStoreProvider.notifier);
      store.setDisplayName('Test');
      store.setSelectedAvatarPath('/tmp/avatar.png');

      final saveFuture = store.save();

      // Dispose before upload completes — simulates navigation away.
      sub.close();
      container.dispose();

      // Upload completes after disposal — should not crash.
      uploadCompleter.complete('https://example.com/avatar.png');
      await saveFuture;
    });

    // -------------------------------------------------------------------------
    // 2. Dispose during repository updateCurrentUser
    // -------------------------------------------------------------------------
    test('dispose during repository update does not throw StateError',
        () async {
      final repoCompleter = Completer<MemberProfile>();
      final container = ProviderContainer(overrides: [
        sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
        profileEditRepositoryProvider.overrideWithValue(
          _DelayedProfileEditRepository(completer: repoCompleter),
        ),
        avatarUploadServiceProvider
            .overrideWithValue(_FakeAvatarUploadService()),
      ]);

      final sub = container.listen(profileEditStoreProvider, (_, __) {});
      final store = container.read(profileEditStoreProvider.notifier);
      store.setDisplayName('Test');

      final saveFuture = store.save();
      // Allow microtasks to run so save() reaches the repository await.
      await Future<void>.delayed(Duration.zero);

      // Dispose while repository call is pending.
      sub.close();
      container.dispose();

      // Repository completes after disposal — should not crash.
      repoCompleter.complete(const MemberProfile(
        id: 'user-1',
        displayName: 'Test',
        isSelf: true,
      ));
      await saveFuture;
    });

    // -------------------------------------------------------------------------
    // 3. Dispose during repository call that fails (catch branch)
    // -------------------------------------------------------------------------
    test('dispose during failed repository call does not throw StateError',
        () async {
      final repoCompleter = Completer<MemberProfile>();
      final container = ProviderContainer(overrides: [
        sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
        profileEditRepositoryProvider.overrideWithValue(
          _DelayedProfileEditRepository(completer: repoCompleter),
        ),
        avatarUploadServiceProvider
            .overrideWithValue(_FakeAvatarUploadService()),
      ]);

      final sub = container.listen(profileEditStoreProvider, (_, __) {});
      final store = container.read(profileEditStoreProvider.notifier);
      store.setDisplayName('Test');

      final saveFuture = store.save();
      await Future<void>.delayed(Duration.zero);

      sub.close();
      container.dispose();

      // Repository fails after disposal — catch block should not write state.
      repoCompleter.completeError(
        const NetworkFailure(message: 'timeout'),
      );
      await saveFuture;
    });

    // -------------------------------------------------------------------------
    // 4. Dispose during avatar upload that fails (AvatarUploadException catch)
    // -------------------------------------------------------------------------
    test('dispose during failed avatar upload does not throw StateError',
        () async {
      final uploadCompleter = Completer<String>();
      final container = ProviderContainer(overrides: [
        sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
        profileEditRepositoryProvider
            .overrideWithValue(_FakeProfileEditRepository()),
        avatarUploadServiceProvider.overrideWithValue(
          _DelayedAvatarUploadService(completer: uploadCompleter),
        ),
      ]);

      final sub = container.listen(profileEditStoreProvider, (_, __) {});
      final store = container.read(profileEditStoreProvider.notifier);
      store.setDisplayName('Test');
      store.setSelectedAvatarPath('/tmp/avatar.png');

      final saveFuture = store.save();

      sub.close();
      container.dispose();

      // Upload fails after disposal — catch block should bail out.
      uploadCompleter.completeError(
        AvatarUploadException('Upload failed'),
      );
      await saveFuture;
    });

    // -------------------------------------------------------------------------
    // 5. Dispose between avatar upload success and session update
    // -------------------------------------------------------------------------
    test('dispose after avatar upload but before state write does not throw',
        () async {
      // Use a synchronous upload so it resolves immediately, but delay
      // the session store's updateProfile.
      final sessionCompleter = Completer<void>();
      final container = ProviderContainer(overrides: [
        sessionStoreProvider
            .overrideWith(() => _DelayedSessionStore(sessionCompleter)),
        profileEditRepositoryProvider
            .overrideWithValue(_FakeProfileEditRepository()),
        avatarUploadServiceProvider
            .overrideWithValue(_FakeAvatarUploadService()),
      ]);

      final sub = container.listen(profileEditStoreProvider, (_, __) {});
      final store = container.read(profileEditStoreProvider.notifier);
      store.setDisplayName('Test');
      store.setSelectedAvatarPath('/tmp/avatar.png');

      final saveFuture = store.save();
      // Let save() reach the first session updateProfile await.
      await Future<void>.delayed(Duration.zero);

      sub.close();
      container.dispose();

      // Session update completes after disposal.
      sessionCompleter.complete();
      await saveFuture;
    });
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

/// SessionStore that delays updateProfile until a completer resolves.
class _DelayedSessionStore extends SessionStore {
  _DelayedSessionStore(this._completer);
  final Completer<void> _completer;
  int _callCount = 0;

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
    _callCount++;
    // Delay only the first call (optimistic session update).
    if (_callCount == 1) {
      await _completer.future;
    }
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
  @override
  Future<MemberProfile> updateCurrentUser({
    required String displayName,
    required String bio,
  }) async {
    return MemberProfile(
      id: 'user-1',
      displayName: displayName,
      description: bio,
      isSelf: true,
    );
  }
}

/// ProfileEditRepository that delays until a completer resolves.
class _DelayedProfileEditRepository implements ProfileEditRepository {
  _DelayedProfileEditRepository({required this.completer});
  final Completer<MemberProfile> completer;

  @override
  Future<MemberProfile> updateCurrentUser({
    required String displayName,
    required String bio,
  }) =>
      completer.future;
}

class _FakeAvatarUploadService implements AvatarUploadService {
  @override
  Future<String> upload(String filePath) async => 'https://example.com/av.png';
}

/// AvatarUploadService that delays until a completer resolves.
class _DelayedAvatarUploadService implements AvatarUploadService {
  _DelayedAvatarUploadService({required this.completer});
  final Completer<String> completer;

  @override
  Future<String> upload(String filePath) => completer.future;
}
