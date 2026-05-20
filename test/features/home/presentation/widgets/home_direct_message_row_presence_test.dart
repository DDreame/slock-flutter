import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/presentation/widgets/home_direct_message_row.dart';
import 'package:slock_app/features/presence/application/presence_store.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  const serverId = ServerScopeId('test-server');

  HomeDirectMessageSummary makeDm({
    String id = 'dm-1',
    String title = 'Test User',
    String? peerId,
    bool isAgent = false,
  }) {
    return HomeDirectMessageSummary(
      scopeId: DirectMessageScopeId(serverId: serverId, value: id),
      title: title,
      peerId: peerId,
      isAgent: isAgent,
    );
  }

  Widget buildRow(
    ProviderContainer container, {
    required HomeDirectMessageSummary dm,
    bool isOnline = false,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HomeDirectMessageRow(
            directMessage: dm,
            onTap: () {},
            isOnline: isOnline,
          ),
        ),
      ),
    );
  }

  group('HomeDirectMessageRow — presence integration', () {
    testWidgets('uses PresenceAvatar when peerId is set', (tester) async {
      final container = ProviderContainer(
        overrides: [
          homeNowProvider.overrideWith((ref) => Stream.value(DateTime.now())),
        ],
      );
      final sub = container.listen(presenceStoreProvider, (_, __) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });

      container.read(presenceStoreProvider.notifier).setOnline('user-123');

      await tester.pumpWidget(
        buildRow(
          container,
          dm: makeDm(peerId: 'user-123'),
        ),
      );
      await tester.pump();

      // PresenceAvatar renders a key like 'presence-dot-user-123'.
      expect(
        find.byKey(const ValueKey('presence-dot-user-123')),
        findsOneWidget,
      );

      // The dot should be green (online).
      final dot = tester.widget<Container>(
        find.byKey(const ValueKey('presence-dot-user-123')),
      );
      final decoration = dot.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.light.success);
    });

    testWidgets('shows yellow dot when peer is idle', (tester) async {
      final container = ProviderContainer(
        overrides: [
          homeNowProvider.overrideWith((ref) => Stream.value(DateTime.now())),
        ],
      );
      final sub = container.listen(presenceStoreProvider, (_, __) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });

      container.read(presenceStoreProvider.notifier).setIdle('user-123');

      await tester.pumpWidget(
        buildRow(
          container,
          dm: makeDm(peerId: 'user-123'),
        ),
      );
      await tester.pump();

      final dot = tester.widget<Container>(
        find.byKey(const ValueKey('presence-dot-user-123')),
      );
      final decoration = dot.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.light.warning);
    });

    testWidgets('shows gray dot when peer is offline', (tester) async {
      final container = ProviderContainer(
        overrides: [
          homeNowProvider.overrideWith((ref) => Stream.value(DateTime.now())),
        ],
      );
      final sub = container.listen(presenceStoreProvider, (_, __) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });

      await tester.pumpWidget(
        buildRow(
          container,
          dm: makeDm(peerId: 'user-123'),
        ),
      );
      await tester.pump();

      final dot = tester.widget<Container>(
        find.byKey(const ValueKey('presence-dot-user-123')),
      );
      final decoration = dot.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.light.textTertiary);
    });

    testWidgets('falls back to inline status dot when peerId is null',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          homeNowProvider.overrideWith((ref) => Stream.value(DateTime.now())),
        ],
      );
      final sub = container.listen(presenceStoreProvider, (_, __) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });

      await tester.pumpWidget(
        buildRow(
          container,
          dm: makeDm(), // no peerId
          isOnline: true,
        ),
      );
      await tester.pump();

      // Should find the inline status dot (not PresenceAvatar).
      expect(
        find.byKey(const ValueKey('dm-status-dot')),
        findsOneWidget,
      );

      // PresenceAvatar dot should NOT be present.
      expect(
        find.byKey(const ValueKey('presence-dot-user-123')),
        findsNothing,
      );
    });

    testWidgets('presence dot updates reactively', (tester) async {
      final container = ProviderContainer(
        overrides: [
          homeNowProvider.overrideWith((ref) => Stream.value(DateTime.now())),
        ],
      );
      final sub = container.listen(presenceStoreProvider, (_, __) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });

      await tester.pumpWidget(
        buildRow(
          container,
          dm: makeDm(peerId: 'user-123'),
        ),
      );
      await tester.pump();

      // Initially offline (gray).
      var dot = tester.widget<Container>(
        find.byKey(const ValueKey('presence-dot-user-123')),
      );
      var decoration = dot.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.light.textTertiary);

      // User comes online.
      container.read(presenceStoreProvider.notifier).setOnline('user-123');
      await tester.pump();

      dot = tester.widget<Container>(
        find.byKey(const ValueKey('presence-dot-user-123')),
      );
      decoration = dot.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.light.success);
    });
  });
}
