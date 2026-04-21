import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/profile/application/profile_detail_store.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  test('self profile resolves displayName and userId from session', () {
    final container = ProviderContainer(
      overrides: [
        currentProfileTargetProvider.overrideWithValue(
          const ProfileTarget(),
        ),
        sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(profileDetailStoreProvider);

    expect(state.status, ProfileDetailStatus.success);
    expect(state.profile, isNotNull);
    expect(state.profile!.id, 'user-123');
    expect(state.profile!.displayName, 'Alice');
    expect(state.profile!.isSelf, isTrue);
    expect(state.profile!.avatarUrl, isNull);
  });

  test('self profile falls back when session has no displayName', () {
    final container = ProviderContainer(
      overrides: [
        currentProfileTargetProvider.overrideWithValue(
          const ProfileTarget(),
        ),
        sessionStoreProvider.overrideWith(
          () => _FakeSessionStore(displayName: null),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(profileDetailStoreProvider);

    expect(state.status, ProfileDetailStatus.success);
    expect(state.profile!.displayName, 'User');
    expect(state.profile!.id, 'user-123');
    expect(state.profile!.isSelf, isTrue);
  });

  test('self profile falls back when session has no userId', () {
    final container = ProviderContainer(
      overrides: [
        currentProfileTargetProvider.overrideWithValue(
          const ProfileTarget(),
        ),
        sessionStoreProvider.overrideWith(
          () => _FakeSessionStore(userId: null),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(profileDetailStoreProvider);

    expect(state.status, ProfileDetailStatus.success);
    expect(state.profile!.id, 'unknown');
    expect(state.profile!.isSelf, isTrue);
  });

  test('other-user profile shows userId as displayName', () {
    final container = ProviderContainer(
      overrides: [
        currentProfileTargetProvider.overrideWithValue(
          const ProfileTarget(userId: 'other-456'),
        ),
        sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(profileDetailStoreProvider);

    expect(state.status, ProfileDetailStatus.success);
    expect(state.profile!.id, 'other-456');
    expect(state.profile!.displayName, 'other-456');
    expect(state.profile!.isSelf, isFalse);
  });

  test('target matching own userId resolves as self profile', () {
    final container = ProviderContainer(
      overrides: [
        currentProfileTargetProvider.overrideWithValue(
          const ProfileTarget(userId: 'user-123'),
        ),
        sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(profileDetailStoreProvider);

    expect(state.profile!.isSelf, isTrue);
    expect(state.profile!.displayName, 'Alice');
  });
}

class _FakeSessionStore extends SessionStore {
  _FakeSessionStore({this.userId = 'user-123', this.displayName = 'Alice'});

  final String? userId;
  final String? displayName;

  @override
  SessionState build() => SessionState(
        status: AuthStatus.authenticated,
        userId: userId,
        displayName: displayName,
        token: 'test-token',
      );
}
