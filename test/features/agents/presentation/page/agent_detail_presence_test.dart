import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/status_glow_ring.dart';
import 'package:slock_app/features/presence/application/presence_store.dart';
import 'package:slock_app/features/presence/presentation/widgets/presence_avatar.dart';

/// Verifies that wrapping a CircleAvatar with [PresenceAvatar] inside
/// a [StatusGlowRing] (the agent detail pattern) renders both the glow
/// ring and the presence dot correctly.
void main() {
  group('Agent detail — PresenceAvatar inside StatusGlowRing', () {
    testWidgets('renders presence dot within glow ring', (tester) async {
      final container = ProviderContainer();
      final sub = container.listen(presenceStoreProvider, (_, __) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });

      container.read(presenceStoreProvider.notifier).setOnline('agent-1');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: Center(
                child: StatusGlowRing(
                  key: ValueKey('agent-detail-glow-ring'),
                  status: GlowRingStatus.online,
                  size: 80,
                  child: PresenceAvatar(
                    key: ValueKey('agent-detail-presence'),
                    userId: 'agent-1',
                    child: CircleAvatar(
                      radius: 34,
                      child: Text('A'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Both the glow ring and presence dot should be present.
      expect(
        find.byKey(const ValueKey('agent-detail-glow-ring')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('presence-dot-agent-1')),
        findsOneWidget,
      );

      // The dot should be green (online).
      final dot = tester.widget<Container>(
        find.byKey(const ValueKey('presence-dot-agent-1')),
      );
      final decoration = dot.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.light.success);
    });

    testWidgets('shows idle dot within glow ring', (tester) async {
      final container = ProviderContainer();
      final sub = container.listen(presenceStoreProvider, (_, __) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });

      container.read(presenceStoreProvider.notifier).setIdle('agent-2');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: Center(
                child: StatusGlowRing(
                  status: GlowRingStatus.thinking,
                  size: 80,
                  child: PresenceAvatar(
                    userId: 'agent-2',
                    child: CircleAvatar(
                      radius: 34,
                      child: Text('B'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final dot = tester.widget<Container>(
        find.byKey(const ValueKey('presence-dot-agent-2')),
      );
      final decoration = dot.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.light.warning);
    });

    testWidgets('shows offline dot when agent has no presence', (tester) async {
      final container = ProviderContainer();
      final sub = container.listen(presenceStoreProvider, (_, __) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: Center(
                child: StatusGlowRing(
                  status: GlowRingStatus.offline,
                  size: 80,
                  child: PresenceAvatar(
                    userId: 'agent-3',
                    child: CircleAvatar(
                      radius: 34,
                      child: Text('C'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final dot = tester.widget<Container>(
        find.byKey(const ValueKey('presence-dot-agent-3')),
      );
      final decoration = dot.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.light.textTertiary);
    });

    testWidgets('dot updates when presence changes', (tester) async {
      final container = ProviderContainer();
      final sub = container.listen(presenceStoreProvider, (_, __) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: Center(
                child: StatusGlowRing(
                  status: GlowRingStatus.online,
                  size: 80,
                  child: PresenceAvatar(
                    userId: 'agent-4',
                    child: CircleAvatar(
                      radius: 34,
                      child: Text('D'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Initially offline.
      var dot = tester.widget<Container>(
        find.byKey(const ValueKey('presence-dot-agent-4')),
      );
      var decoration = dot.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.light.textTertiary);

      // Agent comes online.
      container.read(presenceStoreProvider.notifier).setOnline('agent-4');
      await tester.pump();

      dot = tester.widget<Container>(
        find.byKey(const ValueKey('presence-dot-agent-4')),
      );
      decoration = dot.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.light.success);
    });
  });
}
