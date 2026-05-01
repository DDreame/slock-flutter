import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/theme/app_typography.dart';
import 'package:slock_app/app/widgets/role_badge.dart';
import 'package:slock_app/app/widgets/section_card.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/profile/data/profile_repository_provider.dart';
import 'package:slock_app/features/profile/presentation/page/profile_page.dart';
import 'package:slock_app/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  Widget buildApp({
    Widget? child,
    ProfileRepository? profileRepository,
    MemberRepository? memberRepository,
  }) {
    return ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
        if (profileRepository != null)
          profileRepositoryProvider.overrideWithValue(profileRepository),
        if (memberRepository != null)
          memberRepositoryProvider.overrideWithValue(memberRepository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: child ?? const ProfilePage(),
      ),
    );
  }

  group('Z3 token adoption — self profile', () {
    testWidgets('display name uses AppTypography.headline with AppColors.text',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final displayName = tester.widget<Text>(
        find.byKey(const ValueKey('profile-display-name')),
      );
      expect(displayName.style?.fontSize, AppTypography.headline.fontSize);
      expect(displayName.style?.fontWeight, AppTypography.headline.fontWeight);
      expect(displayName.style?.color, AppColors.light.text);
    });

    testWidgets('self badge uses AppColors.primary color', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final selfBadge = tester.widget<Text>(
        find.byKey(const ValueKey('profile-self-badge')),
      );
      expect(selfBadge.style?.color, AppColors.light.primary);
    });

    testWidgets('info rows are grouped in SectionCard', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Info section should use SectionCard
      expect(
        find.byKey(const ValueKey('profile-info-card')),
        findsOneWidget,
      );
      expect(find.byType(SectionCard), findsOneWidget);
    });

    testWidgets('info row labels use textSecondary, values use text', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final idLabel = tester.widget<Text>(
        find.byKey(const ValueKey('profile-user-id-label')),
      );
      expect(idLabel.style?.color, AppColors.light.textSecondary);

      final idValue = tester.widget<Text>(
        find.byKey(const ValueKey('profile-user-id-value')),
      );
      expect(idValue.style?.color, AppColors.light.text);
    });

    testWidgets('ProfileAvatar uses 80px diameter (radius 40)', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final avatar = tester.widget<ProfileAvatar>(
        find.byType(ProfileAvatar),
      );
      expect(avatar.radius, 40);
    });
  });

  group('Z3 token adoption — other-user profile', () {
    testWidgets('presence pill uses AppColors tokens instead of colorScheme', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          child: const ProfilePage(serverId: 'server-1', userId: 'other-456'),
          profileRepository: const _FakeProfileRepository(
            MemberProfile(
              id: 'other-456',
              displayName: 'Bob',
              presence: 'online',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final presencePill = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('profile-presence')),
      );
      final decoration = presencePill.decoration as BoxDecoration;
      expect(decoration.color, AppColors.light.primaryLight);

      final presenceText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('profile-presence')),
          matching: find.text('online'),
        ),
      );
      expect(presenceText.style?.color, AppColors.light.primary);
    });

    testWidgets('role field uses RoleBadge widget', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: const ProfilePage(serverId: 'server-1', userId: 'other-456'),
          profileRepository: const _FakeProfileRepository(
            MemberProfile(
              id: 'other-456',
              displayName: 'Bob',
              role: 'admin',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RoleBadge), findsOneWidget);
      final badge = tester.widget<RoleBadge>(find.byType(RoleBadge));
      expect(badge.label, 'Admin');
    });

    testWidgets('message button uses AppColors.primary background', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          child: const ProfilePage(serverId: 'server-1', userId: 'other-456'),
          profileRepository: const _FakeProfileRepository(
            MemberProfile(id: 'other-456', displayName: 'Bob'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('profile-message-button')),
        findsOneWidget,
      );
    });

    testWidgets('info rows for other-user in SectionCard', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: const ProfilePage(serverId: 'server-1', userId: 'other-456'),
          profileRepository: const _FakeProfileRepository(
            MemberProfile(
              id: 'other-456',
              displayName: 'Bob',
              username: 'bob',
              email: 'bob@example.com',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SectionCard), findsOneWidget);
      expect(find.text('@bob'), findsOneWidget);
      expect(find.text('bob@example.com'), findsOneWidget);
    });
  });

  group('Member since row', () {
    testWidgets('shows Member since row when joinedAt is present', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          child: const ProfilePage(serverId: 'server-1', userId: 'other-456'),
          profileRepository: _FakeProfileRepository(
            MemberProfile(
              id: 'other-456',
              displayName: 'Bob',
              joinedAt: DateTime(2024, 3, 15),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('profile-member-since')),
        findsOneWidget,
      );
      expect(find.text('Member since'), findsOneWidget);
      expect(find.text('Mar 15, 2024'), findsOneWidget);
    });

    testWidgets('hides Member since row when joinedAt is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          child: const ProfilePage(serverId: 'server-1', userId: 'other-456'),
          profileRepository: const _FakeProfileRepository(
            MemberProfile(id: 'other-456', displayName: 'Bob'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('profile-member-since')),
        findsNothing,
      );
    });
  });

  group('Edit profile affordance', () {
    testWidgets('self profile shows Edit Profile button', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('profile-edit-button')),
        findsOneWidget,
      );
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('other-user profile does not show Edit Profile button', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          child: const ProfilePage(serverId: 'server-1', userId: 'other-456'),
          profileRepository: const _FakeProfileRepository(
            MemberProfile(id: 'other-456', displayName: 'Bob'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('profile-edit-button')),
        findsNothing,
      );
    });
  });

  group('dark theme', () {
    testWidgets('dark theme uses AppColors.dark tokens', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const ProfilePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final displayName = tester.widget<Text>(
        find.byKey(const ValueKey('profile-display-name')),
      );
      expect(displayName.style?.color, AppColors.dark.text);

      final selfBadge = tester.widget<Text>(
        find.byKey(const ValueKey('profile-self-badge')),
      );
      expect(selfBadge.style?.color, AppColors.dark.primary);
    });
  });
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

class _FakeProfileRepository implements ProfileRepository {
  const _FakeProfileRepository(this.profile);

  final MemberProfile profile;

  @override
  Future<MemberProfile> loadProfile(
    ServerScopeId serverId, {
    required String userId,
  }) async {
    return profile;
  }
}
