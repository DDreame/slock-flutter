import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/presence/application/presence_store.dart';
import 'package:slock_app/features/presence/presentation/widgets/presence_avatar.dart';

void main() {
  group('PresenceAvatar', () {
    testWidgets('shows green dot when user is online', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(presenceStoreProvider.notifier).setOnline('user-1');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: PresenceAvatar(
                userId: 'user-1',
                child: CircleAvatar(
                  key: ValueKey('test-avatar'),
                  radius: 16,
                  child: Text('A'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final dotFinder = find.byKey(const ValueKey('presence-dot-user-1'));
      expect(dotFinder, findsOneWidget);

      final dot = tester.widget<Container>(dotFinder);
      final decoration = dot.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.light.success);
    });

    testWidgets('shows yellow dot when user is idle', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(presenceStoreProvider.notifier).setIdle('user-1');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: PresenceAvatar(
                userId: 'user-1',
                child: CircleAvatar(
                  key: ValueKey('test-avatar'),
                  radius: 16,
                  child: Text('A'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final dotFinder = find.byKey(const ValueKey('presence-dot-user-1'));
      expect(dotFinder, findsOneWidget);

      final dot = tester.widget<Container>(dotFinder);
      final decoration = dot.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.light.warning);
    });

    testWidgets('shows gray dot when user is offline', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: PresenceAvatar(
                userId: 'user-1',
                child: CircleAvatar(
                  key: ValueKey('test-avatar'),
                  radius: 16,
                  child: Text('A'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final dotFinder = find.byKey(const ValueKey('presence-dot-user-1'));
      expect(dotFinder, findsOneWidget);

      final dot = tester.widget<Container>(dotFinder);
      final decoration = dot.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.light.textTertiary);
    });

    testWidgets('renders child widget', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: PresenceAvatar(
                userId: 'user-1',
                child: CircleAvatar(
                  key: ValueKey('test-avatar'),
                  radius: 16,
                  child: Text('A'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('test-avatar')), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('dot updates reactively when user comes online',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: PresenceAvatar(
                userId: 'user-1',
                child: CircleAvatar(radius: 16, child: Text('A')),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Initially offline.
      var dot = tester.widget<Container>(
        find.byKey(const ValueKey('presence-dot-user-1')),
      );
      var decoration = dot.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.light.textTertiary);

      // Set online and rebuild.
      container.read(presenceStoreProvider.notifier).setOnline('user-1');
      await tester.pump();

      dot = tester.widget<Container>(
        find.byKey(const ValueKey('presence-dot-user-1')),
      );
      decoration = dot.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.light.success);
    });

    testWidgets('hides dot when showDot is false', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: PresenceAvatar(
                userId: 'user-1',
                showDot: false,
                child: CircleAvatar(radius: 16, child: Text('A')),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('presence-dot-user-1')),
        findsNothing,
      );
    });
  });
}
