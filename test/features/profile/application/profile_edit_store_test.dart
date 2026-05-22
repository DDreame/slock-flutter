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
  test('save optimistically updates session and keeps server response',
      () async {
    final repository = _FakeProfileEditRepository(
      result: const MemberProfile(
        id: 'user-1',
        displayName: 'Server Alice',
        description: 'Server bio',
        avatarUrl: 'https://example.com/server.png',
        isSelf: true,
      ),
    );
    final sessionStore = _FakeSessionStore();
    final container = ProviderContainer(overrides: [
      sessionStoreProvider.overrideWith(() => sessionStore),
      profileEditRepositoryProvider.overrideWithValue(repository),
      avatarUploadServiceProvider.overrideWithValue(_FakeAvatarUploadService()),
    ]);
    addTearDown(container.dispose);

    final store = container.read(profileEditStoreProvider.notifier);
    store.setDisplayName('New Alice');
    store.setBio('New bio');
    await store.save();

    expect(repository.requests.single, ('New Alice', 'New bio'));
    expect(container.read(profileEditStoreProvider).status,
        ProfileEditStatus.success);
    expect(container.read(sessionStoreProvider).displayName, 'Server Alice');
    expect(container.read(sessionStoreProvider).bio, 'Server bio');
    expect(
      container.read(sessionStoreProvider).avatarUrl,
      'https://example.com/server.png',
    );
  });

  test('save keeps uploaded avatar when later profile PATCH fails', () async {
    final repository = _FakeProfileEditRepository(
      failure: const UnknownFailure(message: 'Patch failed'),
    );
    final sessionStore = _FakeSessionStore();
    final avatarUploadService = _FakeAvatarUploadService(
      resultUrl: 'uploaded-avatar.png',
    );
    final container = ProviderContainer(overrides: [
      sessionStoreProvider.overrideWith(() => sessionStore),
      profileEditRepositoryProvider.overrideWithValue(repository),
      avatarUploadServiceProvider.overrideWithValue(avatarUploadService),
    ]);
    addTearDown(container.dispose);

    final store = container.read(profileEditStoreProvider.notifier);
    store.setDisplayName('Broken Alice');
    store.setBio('Broken bio');
    store.setSelectedAvatarPath('/tmp/new-avatar.png');
    await store.save();

    expect(container.read(profileEditStoreProvider).status,
        ProfileEditStatus.failure);
    expect(container.read(sessionStoreProvider).displayName, 'Alice');
    expect(container.read(sessionStoreProvider).bio, 'Original bio');
    expect(
        container.read(sessionStoreProvider).avatarUrl, 'uploaded-avatar.png');
  });

  test('save rolls back optimistic session update on API failure', () async {
    final repository = _FakeProfileEditRepository(
      failure: const UnknownFailure(message: 'Nope'),
    );
    final sessionStore = _FakeSessionStore();
    final container = ProviderContainer(overrides: [
      sessionStoreProvider.overrideWith(() => sessionStore),
      profileEditRepositoryProvider.overrideWithValue(repository),
      avatarUploadServiceProvider.overrideWithValue(_FakeAvatarUploadService()),
    ]);
    addTearDown(container.dispose);

    final store = container.read(profileEditStoreProvider.notifier);
    store.setDisplayName('Broken Alice');
    store.setBio('Broken bio');
    await store.save();

    expect(container.read(profileEditStoreProvider).status,
        ProfileEditStatus.failure);
    expect(container.read(sessionStoreProvider).displayName, 'Alice');
    expect(container.read(sessionStoreProvider).bio, 'Original bio');
    expect(container.read(sessionStoreProvider).avatarUrl, 'old-avatar.png');
  });
}

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
  final requests = <(String, String)>[];

  @override
  Future<MemberProfile> updateCurrentUser({
    required String displayName,
    required String bio,
  }) async {
    requests.add((displayName, bio));
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

class _FakeAvatarUploadService implements AvatarUploadService {
  _FakeAvatarUploadService({this.resultUrl = 'uploaded-avatar.png'});

  final String resultUrl;

  @override
  Future<String> upload(String filePath) async => resultUrl;
}
