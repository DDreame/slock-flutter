import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/profile/application/profile_detail_store.dart';
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

      // Mutate only profile data (avatarUrl) — does NOT change status/failure/hasProfile/isSelf.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProfilePage)),
      );
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
    'scaffold widget instance unchanged after second avatarUrl mutation',
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
        tester.element(find.byType(ProfilePage)),
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
    'scaffold DOES rebuild when a scaffold-watched field changes (regression guard)',
    (tester) async {
      // Use a self-profile (no remote load needed).
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

      expect(find.text('My Profile'), findsOneWidget);

      final scaffoldBefore = tester.widget<Scaffold>(find.byType(Scaffold));

      // Force a rebuild by invalidating the provider (resets status from success → initial → success).
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProfilePage)),
      );
      container.invalidate(profileDetailStoreProvider);
      await tester.pump();

      // Status changed (even momentarily), so _ProfileDetailScreenState.build()
      // MUST have been called, producing a new Scaffold instance.
      final scaffoldAfter = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        identical(scaffoldBefore, scaffoldAfter),
        isFalse,
        reason: 'Scaffold must rebuild when status changes — '
            'proves the identical() technique is valid.',
      );
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
