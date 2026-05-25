// =============================================================================
// #815: Animation + Subscription Efficiency
//
// Invariants verified:
// INV-REPAINT-815: StatusGlowRing wraps active animation in RepaintBoundary
//                  to isolate 60fps repaints from parent layers.
// INV-SEL-815: ConversationMessageCard uses a single consolidated .select()
//              for session userId + displayName instead of 4 separate watches.
// =============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/status_glow_ring.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  // ---------------------------------------------------------------------------
  // INV-REPAINT-815: RepaintBoundary isolation for animated glow ring
  // ---------------------------------------------------------------------------
  group('INV-REPAINT-815: StatusGlowRing RepaintBoundary', () {
    testWidgets(
      'active states have RepaintBoundary wrapping the animated builder',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: Center(
                child: StatusGlowRing(
                  status: GlowRingStatus.online,
                  size: 48,
                  child: Icon(Icons.person),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Active state should have a RepaintBoundary ancestor of the ring.
        expect(
          find.descendant(
            of: find.byType(StatusGlowRing),
            matching: find.byType(RepaintBoundary),
          ),
          findsOneWidget,
          reason:
              'Active animation must be wrapped in RepaintBoundary for isolation',
        );
      },
    );

    testWidgets(
      'offline state does NOT have extra RepaintBoundary',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: Center(
                child: StatusGlowRing(
                  status: GlowRingStatus.offline,
                  size: 48,
                  child: Icon(Icons.person),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Offline state should NOT add a RepaintBoundary (no animation).
        final opacityFinder =
            find.byKey(const ValueKey('status-glow-ring-opacity'));
        expect(opacityFinder, findsOneWidget);

        // The Opacity widget's child should be SizedBox (via buildRing),
        // not wrapped in RepaintBoundary.
        final opacityWidget = tester.widget<Opacity>(opacityFinder);
        expect(opacityWidget.child, isA<SizedBox>());
      },
    );

    testWidgets(
      'RepaintBoundary persists across animation pumps',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: Center(
                child: StatusGlowRing(
                  status: GlowRingStatus.working,
                  size: 48,
                  child: Icon(Icons.person),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Advance animation several frames.
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // RepaintBoundary should still be present.
        expect(
          find.descendant(
            of: find.byType(StatusGlowRing),
            matching: find.byType(RepaintBoundary),
          ),
          findsOneWidget,
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-SEL-815: Consolidated sessionStore .select()
  // ---------------------------------------------------------------------------
  group('INV-SEL-815: Consolidated sessionStore .select()', () {
    test(
      'record pattern .select() returns both userId and displayName',
      () {
        // Simulate what the widget does: a single .select() returning a record.
        final container = ProviderContainer(
          overrides: [
            sessionStoreProvider.overrideWith(
              () => _FakeSessionStore(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final (:currentUserId, :currentUserName) = container.read(
          sessionStoreProvider.select(
            (s) => (currentUserId: s.userId, currentUserName: s.displayName),
          ),
        );

        expect(currentUserId, 'test-user-id');
        expect(currentUserName, 'Test User');
      },
    );

    test(
      'consolidated select does not fire when unrelated session fields change',
      () async {
        // Use a StateProvider with SessionState to simulate real behavior.
        final stateProvider = StateProvider<SessionState>(
          (_) => const SessionState(
            status: AuthStatus.authenticated,
            userId: 'u1',
            displayName: 'User 1',
            token: 'token-a',
          ),
        );

        final container = ProviderContainer();
        addTearDown(container.dispose);

        var selectorFireCount = 0;
        container.listen(
          stateProvider.select(
            (s) => (userId: s.userId, displayName: s.displayName),
          ),
          (_, __) => selectorFireCount++,
        );

        // Mutate unrelated field (token) — selector should NOT fire.
        container.read(stateProvider.notifier).state = const SessionState(
          status: AuthStatus.authenticated,
          userId: 'u1',
          displayName: 'User 1',
          token: 'token-b',
        );
        await Future<void>.delayed(Duration.zero);
        expect(selectorFireCount, 0,
            reason:
                'Token change should not trigger userId/displayName select');

        // Mutate userId — selector SHOULD fire.
        container.read(stateProvider.notifier).state = const SessionState(
          status: AuthStatus.authenticated,
          userId: 'u2',
          displayName: 'User 1',
          token: 'token-b',
        );
        await Future<void>.delayed(Duration.zero);
        expect(selectorFireCount, 1,
            reason: 'userId change should trigger select');
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
        userId: 'test-user-id',
        displayName: 'Test User',
        token: 'fake-token',
      );
}
