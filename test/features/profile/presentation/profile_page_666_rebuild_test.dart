import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/profile/application/profile_detail_store.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/profile/data/profile_repository_provider.dart';
import 'package:slock_app/features/profile/presentation/page/profile_page.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

/// Widget-path invariant test for #666 Fix A.
///
/// Renders the REAL ProfilePage and verifies that when only profile data
/// fields change (e.g. avatarUrl), `_ProfileDetailScreenState.build()` is
/// NOT re-invoked. Detection: if build() fires, a NEW Scaffold widget
/// instance is created; if build() is skipped, the same Scaffold instance
/// remains in the element tree (checked via `identical()`).
///
/// Container access uses an element INSIDE ProfilePage's inner ProviderScope
/// (via `find.byType(Scaffold)`) so the `currentProfileTargetProvider` override
/// is visible.
void main() {
  testWidgets(
    'scaffold widget instance unchanged when avatarUrl mutates (rebuild skipped)',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const ProfilePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial render is self-profile.
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('My Profile'), findsOneWidget);

      // Capture the Scaffold widget instance produced by _ProfileDetailScreenState.build().
      final scaffoldBefore = tester.widget<Scaffold>(find.byType(Scaffold));

      // Access the INNER container (inside ProfilePage's ProviderScope).
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold)),
      );

      // Mutate only profile data (avatarUrl) — does NOT change status/failure/hasProfile/isSelf.
      container
          .read(profileDetailStoreProvider.notifier)
          .updateAvatarUrl('https://new-avatar.png');
      await tester.pump();

      // If _ProfileDetailScreenState.build() was NOT called, the Scaffold
      // widget stays identical (same Dart object in the element tree).
      final scaffoldAfter = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        identical(scaffoldBefore, scaffoldAfter),
        isTrue,
        reason: 'Scaffold must not rebuild when only profile data changes — '
            'the .select() narrow ensures build() is skipped for avatarUrl mutations.',
      );
    },
  );

  testWidgets(
    'scaffold widget instance unchanged after multiple avatar upload ticks',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const ProfilePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffoldBefore = tester.widget<Scaffold>(find.byType(Scaffold));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold)),
      );
      final notifier = container.read(profileDetailStoreProvider.notifier);

      // Simulate multiple upload progress ticks.
      notifier.updateAvatarUrl('https://tick-1.png');
      await tester.pump();
      notifier.updateAvatarUrl('https://tick-2.png');
      await tester.pump();
      notifier.updateAvatarUrl('https://tick-3.png');
      await tester.pump();

      final scaffoldAfter = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        identical(scaffoldBefore, scaffoldAfter),
        isTrue,
        reason:
            'Scaffold must remain stable through multiple avatar mutations.',
      );
    },
  );

  testWidgets(
    'scaffold IS rebuilt on status transition (technique validation)',
    (tester) async {
      // Use a remote profile target that transitions loading → success.
      // This changes the `status` select, which MUST trigger a scaffold rebuild.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
            profileRepositoryProvider
                .overrideWithValue(const _DelayedProfileRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const ProfilePage(serverId: 'server-1', userId: 'other-456'),
          ),
        ),
      );
      // One pump to trigger the microtask-scheduled _loadProfile.
      await tester.pump();

      // Page is in loading state — capture scaffold.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final scaffoldDuringLoading =
          tester.widget<Scaffold>(find.byType(Scaffold));

      // Let the profile load complete (status: loading → success).
      await tester.pumpAndSettle();

      // Status changed, so _ProfileDetailScreenState.build() was called,
      // producing a new Scaffold instance — proves identical() is valid.
      final scaffoldAfterSuccess =
          tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        identical(scaffoldDuringLoading, scaffoldAfterSuccess),
        isFalse,
        reason:
            'Scaffold must rebuild when status changes (loading → success) — '
            'proves the identical() technique detects real rebuilds.',
      );

      // Verify the profile rendered successfully.
      expect(find.text('Bob'), findsOneWidget);
    },
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

class _DelayedProfileRepository implements ProfileRepository {
  const _DelayedProfileRepository();

  @override
  Future<MemberProfile> loadProfile(
    ServerScopeId serverId, {
    required String userId,
  }) async {
    // Small delay to simulate network fetch.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return const MemberProfile(
      id: 'other-456',
      displayName: 'Bob',
      username: 'bob',
    );
  }
}
