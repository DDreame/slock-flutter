import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/relative_time_text.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/presentation/widgets/home_channel_row.dart';
import 'package:slock_app/l10n/app_localizations.dart';

/// #812: Verify that parent home rows do NOT rebuild when homeNowProvider ticks.
/// Only the [RelativeTimeText] leaf should rebuild.
void main() {
  group('RelativeTimeText leaf isolation', () {
    testWidgets('RelativeTimeText rebuilds on homeNow tick', (tester) async {
      final controller = StreamController<DateTime>();
      addTearDown(controller.close);

      final container = ProviderContainer(
        overrides: [
          homeNowProvider.overrideWith(
            (ref) => controller.stream,
          ),
        ],
      );
      addTearDown(container.dispose);
      // Keepalive the provider during test
      final sub = container.listen(homeNowProvider, (_, __) {});
      addTearDown(sub.close);

      // Emit initial time
      final time1 = DateTime(2026, 5, 20, 10, 0, 0);
      final base = DateTime(2026, 5, 20, 9, 55, 0); // 5 minutes ago
      controller.add(time1);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: RelativeTimeText(
                time: base,
                style: const TextStyle(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Initial: 5 minutes ago
      expect(find.text('5m ago'), findsOneWidget);

      // Emit a new tick: 10 minutes later
      final time2 = DateTime(2026, 5, 20, 10, 10, 0);
      controller.add(time2);
      await tester.pump();

      // Now shows 15 minutes ago
      expect(find.text('15m ago'), findsOneWidget);
    });

    testWidgets(
        'HomeChannelRow does NOT rebuild when homeNowProvider ticks '
        '(only RelativeTimeText leaf rebuilds)', (tester) async {
      final controller = StreamController<DateTime>();
      addTearDown(controller.close);

      final container = ProviderContainer(
        overrides: [
          homeNowProvider.overrideWith(
            (ref) => controller.stream,
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(homeNowProvider, (_, __) {});
      addTearDown(sub.close);

      final time1 = DateTime(2026, 5, 20, 10, 0, 0);
      controller.add(time1);

      var parentBuildCount = 0;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: _BuildCounter(
                onBuild: () => parentBuildCount++,
                child: HomeChannelRow(
                  channel: HomeChannelSummary(
                    scopeId: const ChannelScopeId(
                      serverId: ServerScopeId('s1'),
                      value: 'c1',
                    ),
                    name: 'general',
                    lastActivityAt: DateTime(2026, 5, 20, 9, 55, 0),
                  ),
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Record build count after initial render
      final initialBuildCount = parentBuildCount;

      // Emit a new time tick
      final time2 = DateTime(2026, 5, 20, 10, 5, 0);
      controller.add(time2);
      await tester.pump();

      // Parent build count should NOT have increased —
      // homeNowProvider is only watched by RelativeTimeText leaf
      expect(parentBuildCount, initialBuildCount,
          reason:
              'HomeChannelRow should not rebuild when homeNowProvider ticks');

      // But the time text should have updated (leaf rebuilt)
      expect(find.text('10m ago'), findsOneWidget);
    });
  });
}

/// Helper widget that tracks how many times its child's subtree triggers a build
/// of the wrapper. Used to verify that a parent does not rebuild when a leaf
/// provider changes.
class _BuildCounter extends StatelessWidget {
  const _BuildCounter({required this.onBuild, required this.child});

  final VoidCallback onBuild;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return child;
  }
}
