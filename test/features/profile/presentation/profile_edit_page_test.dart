import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/profile/application/avatar_upload_service.dart';
import 'package:slock_app/features/profile/data/profile_edit_repository.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/profile/presentation/page/profile_edit_page.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  testWidgets('form renders current profile fields and validates name',
      (tester) async {
    await tester
        .pumpWidget(_buildApp(repository: _FakeProfileEditRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-edit-display-name')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('profile-edit-bio')), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Original bio'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('profile-edit-display-name')),
      '',
    );
    await tester.tap(find.byKey(const ValueKey('profile-edit-save')));
    await tester.pump();

    expect(find.text('Display name is required.'), findsOneWidget);
  });

  testWidgets('save shows loading and calls profile update API',
      (tester) async {
    final completer = Completer<MemberProfile>();
    final repository = _FakeProfileEditRepository(completer: completer);

    await tester.pumpWidget(_buildApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('profile-edit-display-name')),
      'Updated Alice',
    );
    await tester.enterText(
      find.byKey(const ValueKey('profile-edit-bio')),
      'Updated bio',
    );
    await tester.tap(find.byKey(const ValueKey('profile-edit-save')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('profile-edit-saving-indicator')),
      findsOneWidget,
    );
    expect(repository.requests.single, ('Updated Alice', 'Updated bio'));

    completer.complete(const MemberProfile(
      id: 'user-1',
      displayName: 'Updated Alice',
      description: 'Updated bio',
      isSelf: true,
    ));
    await tester.pumpAndSettle();
  });
}

Widget _buildApp({required _FakeProfileEditRepository repository}) {
  final router = GoRouter(
    initialLocation: '/profile/edit',
    routes: [
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const ProfileEditPage(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('home')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      profileEditRepositoryProvider.overrideWithValue(repository),
      avatarUploadServiceProvider.overrideWithValue(_FakeAvatarUploadService()),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
    ),
  );
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
  _FakeProfileEditRepository({this.completer});

  final Completer<MemberProfile>? completer;
  final requests = <(String, String)>[];

  @override
  Future<MemberProfile> updateCurrentUser({
    required String displayName,
    required String bio,
  }) async {
    requests.add((displayName, bio));
    final completer = this.completer;
    if (completer != null) return completer.future;
    return MemberProfile(
      id: 'user-1',
      displayName: displayName,
      description: bio,
      isSelf: true,
    );
  }
}

class _FakeAvatarUploadService implements AvatarUploadService {
  @override
  Future<String> upload(String filePath) async => 'uploaded-avatar.png';
}
