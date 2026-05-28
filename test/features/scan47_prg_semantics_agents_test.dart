// =============================================================================
// Scan #47 PR G — Semantics load-bearing tests (3 widgets).
//
// Each test proves the Semantics wrapper provides correct label/role/state.
// Removing the Semantics wrapping → test RED.
// =============================================================================

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/agents/presentation/page/agents_page.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart';

void main() {
  // ===========================================================================
  // S1: _StatusGroupHeader — Semantics(button, expanded, label)
  // ===========================================================================
  group('Scan #47 Semantics — _StatusGroupHeader', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('has button role and expanded state', (tester) async {
      final handle = tester.ensureSemantics();

      final repo = _FakeAgentsRepo([
        _makeAgent(id: 'a1', activity: 'working'),
        _makeAgent(id: 'a2', activity: 'working'),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsRepositoryProvider.overrideWithValue(repo),
            agentsMachinesLoaderProvider
                .overrideWithValue(() async => const []),
            sharedPreferencesProvider.overrideWithValue(prefs),
            realtimeReductionIngressProvider
                .overrideWithValue(RealtimeReductionIngress()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TickerMode(
              enabled: false,
              child: AgentsPage(serverId: 'server-1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the status group header.
      final headerFinder =
          find.byKey(const ValueKey('status-header-status:working'));
      expect(headerFinder, findsOneWidget);

      final semantics = tester.getSemantics(headerFinder);
      final data = semantics.getSemanticsData();

      // Must have button flag.
      expect(
        data.flagsCollection.isButton,
        isTrue,
        reason: 'Removing Semantics(button: true) → no button flag → RED.',
      );

      // Must have expanded state (header is NOT collapsed initially).
      expect(
        data.flagsCollection.isExpanded,
        Tristate.isTrue,
        reason: 'Removing Semantics(expanded: true) → no expanded state → RED.',
      );

      // Must have label containing status + count.
      expect(
        data.label,
        contains('2'),
        reason: 'Label must include count (2 agents).',
      );

      handle.dispose();
    });
  });

  // ===========================================================================
  // S2: _AgentRow — Semantics(button, label with name + activity)
  // ===========================================================================
  group('Scan #47 Semantics — _AgentRow', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('has button role and label with name and activity',
        (tester) async {
      final handle = tester.ensureSemantics();

      final repo = _FakeAgentsRepo([
        _makeAgent(id: 'a1', name: 'Alice', activity: 'thinking'),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            agentsRepositoryProvider.overrideWithValue(repo),
            agentsMachinesLoaderProvider
                .overrideWithValue(() async => const []),
            sharedPreferencesProvider.overrideWithValue(prefs),
            realtimeReductionIngressProvider
                .overrideWithValue(RealtimeReductionIngress()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TickerMode(
              enabled: false,
              child: AgentsPage(serverId: 'server-1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the agent row by key.
      final rowFinder = find.byKey(const ValueKey('agent-a1'));
      expect(rowFinder, findsOneWidget);

      final semantics = tester.getSemantics(rowFinder);
      final data = semantics.getSemanticsData();

      // Must have button flag.
      expect(
        data.flagsCollection.isButton,
        isTrue,
        reason: 'Removing Semantics(button: true) → no button flag → RED.',
      );

      // Label must include agent name.
      expect(
        data.label,
        contains('Alice'),
        reason: 'Label must include agent name. '
            'Removing Semantics wrapper → empty label → RED.',
      );

      // Label must include activity text (not just name).
      // The l10n produces "Alice, Thinking" (en).
      expect(
        data.label,
        contains('hinking'),
        reason: 'Label must include activity text. '
            'Removing activity from agentsRowSemantics → RED.',
      );

      // Must have onLongPressHint (exposed via customSemanticsActionIds).
      expect(
        data.customSemanticsActionIds,
        isNotNull,
        reason: 'Removing onLongPressHint → no custom action IDs → RED.',
      );
      expect(
        data.customSemanticsActionIds,
        isNotEmpty,
        reason: 'Removing onLongPressHint → empty custom action IDs → RED.',
      );

      handle.dispose();
    });
  });

  // ===========================================================================
  // S3: _MentionSuggestionOverlay — Semantics(namesRoute, label)
  // ===========================================================================
  group('Scan #47 Semantics — _MentionSuggestionOverlay', () {
    testWidgets('overlay has namesRoute semantics and items have labels',
        (tester) async {
      final handle = tester.ensureSemantics();

      final members = [
        const ChannelMember(
          id: 'm1',
          channelId: 'ch-1',
          userId: 'u1',
          userName: 'Bob',
        ),
        const ChannelMember(
          id: 'm2',
          channelId: 'ch-1',
          agentId: 'a1',
          agentName: 'Claude',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: buildMentionSuggestionOverlay(
              key: const ValueKey('mention-overlay-test'),
              members: members,
              onSelect: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // The overlay container should have namesRoute semantics.
      final overlayFinder = find.byKey(const ValueKey('mention-overlay-test'));
      expect(overlayFinder, findsOneWidget);

      final overlaySem = tester.getSemantics(overlayFinder);
      final overlayData = overlaySem.getSemanticsData();
      expect(
        overlayData.flagsCollection.namesRoute,
        isTrue,
        reason:
            'Removing Semantics(namesRoute: true) → no namesRoute flag → RED.',
      );
      expect(
        overlayData.label,
        isNotEmpty,
        reason: 'Removing Semantics wrapper → empty label → RED.',
      );

      // Each suggestion row should have button semantics with a label.
      final row0Finder = find.byKey(const ValueKey('mention-suggestion-0'));
      expect(row0Finder, findsOneWidget);

      final row0Sem = tester.getSemantics(row0Finder);
      final row0Data = row0Sem.getSemanticsData();
      expect(
        row0Data.flagsCollection.isButton,
        isTrue,
        reason: 'Row must have button semantics. Removing → RED.',
      );
      expect(
        row0Data.label,
        contains('Bob'),
        reason: 'Row label must mention member name. Removing → RED.',
      );

      handle.dispose();
    });
  });
}

// =============================================================================
// Test helpers
// =============================================================================

AgentItem _makeAgent({
  String id = 'agent-1',
  String name = 'Bot',
  String activity = 'online',
  String? activityDetail,
}) {
  return AgentItem(
    id: id,
    name: name,
    model: 'sonnet',
    runtime: 'claude',
    status: activity == 'offline' ? 'stopped' : 'active',
    activity: activity,
    activityDetail: activityDetail,
  );
}

class _FakeAgentsRepo implements AgentsRepository, AgentsMutationRepository {
  _FakeAgentsRepo(this._items);

  final List<AgentItem> _items;

  @override
  Future<List<AgentItem>> listAgents() async => List.of(_items);

  @override
  Future<AgentItem> createAgent(AgentMutationInput input) async =>
      throw UnimplementedError();

  @override
  Future<AgentItem> updateAgent(
          String agentId, AgentMutationInput input) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteAgent(String agentId) async {}

  @override
  Future<void> startAgent(String agentId) async {}

  @override
  Future<void> stopAgent(String agentId) async {}

  @override
  Future<void> resetAgent(String agentId, {required String mode}) async {}

  @override
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  }) async =>
      const [];
}
