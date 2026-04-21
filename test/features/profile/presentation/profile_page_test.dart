import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/profile/application/profile_detail_store.dart';
import 'package:slock_app/features/profile/presentation/page/profile_page.dart';
import 'package:slock_app/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:slock_app/features/settings/presentation/page/settings_page.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  testWidgets('self profile shows avatar, displayName, userId, and self badge',
      (tester) async {
    await tester.pumpWidget(
      _buildApp(child: const ProfilePage()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProfileAvatar), findsOneWidget);
    expect(
        find.byKey(const ValueKey('profile-avatar-initials')), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-display-name')), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-user-id')), findsOneWidget);
    expect(find.text('user-123'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-self-badge')), findsOneWidget);
    expect(find.text('This is you'), findsOneWidget);
    expect(find.text('My Profile'), findsOneWidget);
  });

  testWidgets(
      'other-user profile shows userId as display name without self badge',
      (tester) async {
    await tester.pumpWidget(
      _buildApp(child: const ProfilePage(userId: 'other-456')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProfileAvatar), findsOneWidget);
    expect(find.text('O'), findsOneWidget);
    expect(find.text('other-456'), findsAtLeast(1));
    expect(find.byKey(const ValueKey('profile-self-badge')), findsNothing);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('settings page shows My Profile tile', (tester) async {
    await tester.pumpWidget(
      _buildApp(child: const SettingsPage()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings-my-profile')), findsOneWidget);
    expect(find.text('My Profile'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('ProfileAvatar shows initials when no avatarUrl', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const ProfileAvatar(displayName: 'Bob', radius: 30),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('profile-avatar-initials')), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('ProfileAvatar shows ? for empty displayName', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const ProfileAvatar(displayName: '', radius: 30),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('?'), findsOneWidget);
  });
}

Widget _buildApp({required Widget child}) {
  return ProviderScope(
    overrides: [
      sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
    ],
    child: MaterialApp(home: child),
  );
}

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-123',
        displayName: 'Alice',
        token: 'test-token',
      );
}
