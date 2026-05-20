// Phase A — #638 DM Agent Activity Status
//
// 6 skip:true tests proving the current code fails to surface rich agent
// activity in DM rows. Phase B will:
// 1. Replace isOnline: bool with agentActivity: AgentDisplayStatus?
// 2. Render distinct dot colors per activity state
// 3. Preserve PresenceAvatar for human DM rows

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agent_display_status.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/presentation/widgets/home_direct_message_row.dart';
import 'package:slock_app/features/presence/application/presence_store.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  const serverId = ServerScopeId('test-server');

  HomeDirectMessageSummary makeDm({
    String id = 'dm-agent-1',
    String title = 'TestBot',
    String? peerId,
    bool isAgent = true,
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
    AgentDisplayStatus? agentActivity,
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
            isAgent: true,
            agentActivity: agentActivity,
          ),
        ),
      ),
    );
  }

  group('HomeDirectMessageRow — agent activity status (#638)', () {
    // T1: Agent with 'thinking' activity shows warning-colored pulse dot.
    testWidgets(
      'T1: thinking activity shows warning dot',
      // Phase B — agentActivity param now wired
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            homeNowProvider.overrideWith((ref) => Stream.value(DateTime.now())),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildRow(
            container,
            dm: makeDm(),
            agentActivity: AgentDisplayStatus.thinking,
          ),
        );
        await tester.pump();

        final dot = tester.widget<Container>(
          find.byKey(const ValueKey('dm-status-dot')),
        );
        final decoration = dot.decoration! as BoxDecoration;
        expect(
          decoration.color,
          AppColors.light.warning,
          reason: 'Thinking agents should show warning (amber) dot',
        );
      },
    );

    // T2: Agent with 'working' activity shows warning-colored pulse dot.
    testWidgets(
      'T2: working activity shows warning dot',
      // Phase B — DONE
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            homeNowProvider.overrideWith((ref) => Stream.value(DateTime.now())),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildRow(
            container,
            dm: makeDm(),
            agentActivity: AgentDisplayStatus.working,
          ),
        );
        await tester.pump();

        final dot = tester.widget<Container>(
          find.byKey(const ValueKey('dm-status-dot')),
        );
        final decoration = dot.decoration! as BoxDecoration;
        expect(
          decoration.color,
          AppColors.light.warning,
          reason: 'Working agents should show warning (amber) dot',
        );
      },
    );

    // T3: Agent with 'error' activity shows error-colored dot.
    testWidgets(
      'T3: error activity shows error dot',
      // Phase B — DONE
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            homeNowProvider.overrideWith((ref) => Stream.value(DateTime.now())),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildRow(
            container,
            dm: makeDm(),
            agentActivity: AgentDisplayStatus.error,
          ),
        );
        await tester.pump();

        final dot = tester.widget<Container>(
          find.byKey(const ValueKey('dm-status-dot')),
        );
        final decoration = dot.decoration! as BoxDecoration;
        expect(
          decoration.color,
          AppColors.light.error,
          reason: 'Error agents should show error (red) dot',
        );
      },
    );

    // T4: Agent with 'online' activity shows success-colored dot.
    testWidgets(
      'T4: online activity shows success dot',
      // Phase B — DONE
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            homeNowProvider.overrideWith((ref) => Stream.value(DateTime.now())),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildRow(
            container,
            dm: makeDm(),
            agentActivity: AgentDisplayStatus.online,
          ),
        );
        await tester.pump();

        final dot = tester.widget<Container>(
          find.byKey(const ValueKey('dm-status-dot')),
        );
        final decoration = dot.decoration! as BoxDecoration;
        expect(
          decoration.color,
          AppColors.light.success,
          reason: 'Online agents should show success (green) dot',
        );
      },
    );

    // T5: Agent with 'offline' activity shows tertiary-colored dot.
    testWidgets(
      'T5: offline activity shows tertiary dot',
      // Phase B — DONE
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            homeNowProvider.overrideWith((ref) => Stream.value(DateTime.now())),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          buildRow(
            container,
            dm: makeDm(),
            agentActivity: AgentDisplayStatus.offline,
          ),
        );
        await tester.pump();

        final dot = tester.widget<Container>(
          find.byKey(const ValueKey('dm-status-dot')),
        );
        final decoration = dot.decoration! as BoxDecoration;
        expect(
          decoration.color,
          AppColors.light.textTertiary,
          reason: 'Offline agents should show tertiary (grey) dot',
        );
      },
    );

    // T6: Human DM rows still use PresenceAvatar (no agentActivity param).
    testWidgets(
      'T6: human DM row uses PresenceAvatar unchanged',
      // Phase B — DONE
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

        container.read(presenceStoreProvider.notifier).setOnline('user-456');

        final humanDm = makeDm(
          id: 'dm-human-1',
          title: 'Alice',
          peerId: 'user-456',
          isAgent: false,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: HomeDirectMessageRow(
                  directMessage: humanDm,
                  onTap: () {},
                  isOnline: false,
                  isAgent: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Human DMs should use PresenceAvatar — the presence dot key.
        expect(
          find.byKey(const ValueKey('presence-dot-user-456')),
          findsOneWidget,
          reason: 'Human DMs must use PresenceAvatar with presence-dot key',
        );

        // Should NOT have the inline status dot.
        expect(
          find.byKey(const ValueKey('dm-status-dot')),
          findsNothing,
          reason: 'Human DMs must not show inline status dot',
        );

        // The dot should be green (online via PresenceStore).
        final dot = tester.widget<Container>(
          find.byKey(const ValueKey('presence-dot-user-456')),
        );
        final decoration = dot.decoration! as BoxDecoration;
        expect(
          decoration.color,
          AppColors.light.success,
          reason: 'Human presence dot should reflect PresenceStore status',
        );
      },
    );
  });
}
