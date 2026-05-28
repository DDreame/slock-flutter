// =============================================================================
// #846 — ES Diacritics + Activity Log L10n + Dead Code + Remnants
//
// Load-bearing tests proving l10n wire-up for new #846 changes:
//
// 1. SwipeToMarkRead renders ZH action label (not hardcoded English)
// 2. SwipeToMarkRead renders ES accented action label (diacritics test)
// 3. Activity log formatting uses ZH labels (not EN)
// 4. Activity log formatting uses ES labels (diacritics preserved)
// 5. conversationDefaultTitleDm renders ZH (not EN "Direct message")
// 6. userFallbackDisplayName renders ZH (not EN "User")
//
// Falsification: reverting production code to hardcoded English strings
// must make the non-EN locale tests RED.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/swipe_to_mark_read.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/l10n/app_localizations_provider.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Group 1: SwipeToMarkRead l10n proof
  // ---------------------------------------------------------------------------
  group('SwipeToMarkRead l10n (#846)', () {
    testWidgets(
      'renders ZH mark-read label, not hardcoded English',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            home: Scaffold(
              body: ListView(
                children: [
                  SwipeToMarkRead(
                    itemKey: 'zh-test',
                    enabled: true,
                    onMarkRead: () {},
                    child: const SizedBox(height: 60, child: Text('Row')),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Swipe left to reveal the background label.
        await tester.drag(
          find.byKey(const ValueKey('swipe-action-zh-test')),
          const Offset(-200, 0),
        );
        await tester.pump();

        // ZH: "标为已读"
        expect(
          find.text('标为已读'),
          findsOneWidget,
          reason: 'Must render ZH mark-read label',
        );
        // Must NOT show the old hardcoded English.
        expect(
          find.text('Mark Read'),
          findsNothing,
          reason: 'Hardcoded EN must not appear in ZH locale',
        );
      },
    );

    testWidgets(
      'renders ES accented mark-read label (diacritics proof)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            home: Scaffold(
              body: ListView(
                children: [
                  SwipeToMarkRead(
                    itemKey: 'es-test',
                    enabled: true,
                    onMarkRead: () {},
                    child: const SizedBox(height: 60, child: Text('Row')),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Swipe left to reveal the background label.
        await tester.drag(
          find.byKey(const ValueKey('swipe-action-es-test')),
          const Offset(-200, 0),
        );
        await tester.pump();

        // ES: "Marcar como leído" — accented í in "leído"
        expect(
          find.text('Marcar como leído'),
          findsOneWidget,
          reason: 'Must render ES accented mark-read label with í in leído',
        );
        // Must NOT show the EN fallback.
        expect(
          find.text('Mark Read'),
          findsNothing,
          reason: 'EN label must not appear in ES locale',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group 2: Activity log l10n — _formatActivityLogEntry via AgentsStore
  // ---------------------------------------------------------------------------
  group('Activity log l10n (#846)', () {
    AgentItem makeAgent({
      String id = 'agent-1',
      String name = 'Bot',
      String activity = 'online',
    }) {
      return AgentItem(
        id: id,
        name: name,
        model: 'sonnet',
        runtime: 'claude',
        status: 'active',
        activity: activity,
      );
    }

    test('ZH locale formats activity log with Chinese labels', () async {
      final zhL10n = lookupAppLocalizations(const Locale('zh'));
      final fakeRepo = _FakeAgentsRepository();
      final container = ProviderContainer(
        overrides: [
          agentsRepositoryProvider.overrideWithValue(fakeRepo),
          agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
          appLocalizationsProvider.overrideWithValue(zhL10n),
        ],
      );
      final sub = container.listen(agentsStoreProvider, (_, __) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });

      fakeRepo.listResult = [makeAgent(id: 'a1')];
      await container.read(agentsStoreProvider.notifier).load();

      container.read(agentsStoreProvider.notifier).updateActivity(
            'a1',
            'thinking',
            'analyzing',
            timestamp: DateTime(2026, 5, 1, 10, 0, 0),
          );

      final log = container.read(agentsStoreProvider).activityLogFor('a1');
      expect(log, hasLength(1));
      // ZH: "思考中: analyzing" (no trailing …)
      expect(
        log.first.entry,
        '思考中: analyzing',
        reason: 'Activity log must use ZH label without trailing ellipsis',
      );
    });

    test('ZH locale formats working activity with Chinese label', () async {
      final zhL10n = lookupAppLocalizations(const Locale('zh'));
      final fakeRepo = _FakeAgentsRepository();
      final container = ProviderContainer(
        overrides: [
          agentsRepositoryProvider.overrideWithValue(fakeRepo),
          agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
          appLocalizationsProvider.overrideWithValue(zhL10n),
        ],
      );
      final sub = container.listen(agentsStoreProvider, (_, __) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });

      fakeRepo.listResult = [makeAgent(id: 'a1')];
      await container.read(agentsStoreProvider.notifier).load();

      container.read(agentsStoreProvider.notifier).updateActivity(
            'a1',
            'working',
            'building feature',
            timestamp: DateTime(2026, 5, 1, 10, 0, 0),
          );

      final log = container.read(agentsStoreProvider).activityLogFor('a1');
      expect(log, hasLength(1));
      // ZH: "工作中: building feature"
      expect(
        log.first.entry,
        '工作中: building feature',
        reason: 'Activity log must use ZH "工作中" label',
      );
    });

    test('ES locale formats activity log with Spanish labels (diacritics)',
        () async {
      final esL10n = lookupAppLocalizations(const Locale('es'));
      final fakeRepo = _FakeAgentsRepository();
      final container = ProviderContainer(
        overrides: [
          agentsRepositoryProvider.overrideWithValue(fakeRepo),
          agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
          appLocalizationsProvider.overrideWithValue(esL10n),
        ],
      );
      final sub = container.listen(agentsStoreProvider, (_, __) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });

      fakeRepo.listResult = [makeAgent(id: 'a1')];
      await container.read(agentsStoreProvider.notifier).load();

      container.read(agentsStoreProvider.notifier).updateActivity(
            'a1',
            'thinking',
            'step 1',
            timestamp: DateTime(2026, 5, 1, 10, 0, 0),
          );

      final log = container.read(agentsStoreProvider).activityLogFor('a1');
      expect(log, hasLength(1));
      // ES: "Pensando: step 1"
      expect(
        log.first.entry,
        'Pensando: step 1',
        reason: 'Activity log must use ES label "Pensando"',
      );
    });

    test('ES locale offline renders "Sin conexión" (diacritics)', () async {
      final esL10n = lookupAppLocalizations(const Locale('es'));
      final fakeRepo = _FakeAgentsRepository();
      final container = ProviderContainer(
        overrides: [
          agentsRepositoryProvider.overrideWithValue(fakeRepo),
          agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
          appLocalizationsProvider.overrideWithValue(esL10n),
        ],
      );
      final sub = container.listen(agentsStoreProvider, (_, __) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });

      fakeRepo.listResult = [makeAgent(id: 'a1')];
      await container.read(agentsStoreProvider.notifier).load();

      container.read(agentsStoreProvider.notifier).updateActivity(
            'a1',
            'offline',
            null,
            timestamp: DateTime(2026, 5, 1, 10, 0, 0),
          );

      final log = container.read(agentsStoreProvider).activityLogFor('a1');
      expect(log, hasLength(1));
      // ES: "Sin conexión" — accented ó
      expect(
        log.first.entry,
        'Sin conexión',
        reason: 'Activity log offline must use ES "Sin conexión" with ó',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Group 3: conversationDefaultTitleDm l10n
  // ---------------------------------------------------------------------------
  group('ConversationDetailTarget.localizedDefaultTitle l10n (#846)', () {
    test('ZH locale returns 私信 for DM target', () {
      final zhL10n = lookupAppLocalizations(const Locale('zh'));
      final target = ConversationDetailTarget.directMessage(
        const DirectMessageScopeId(
          serverId: ServerScopeId('s1'),
          value: 'c1',
        ),
      );

      expect(
        target.localizedDefaultTitle(zhL10n),
        '私信',
        reason: 'DM default title must be ZH "私信"',
      );
    });

    test('ES locale returns "Mensaje directo" for DM target', () {
      final esL10n = lookupAppLocalizations(const Locale('es'));
      final target = ConversationDetailTarget.directMessage(
        const DirectMessageScopeId(
          serverId: ServerScopeId('s1'),
          value: 'c1',
        ),
      );

      expect(
        target.localizedDefaultTitle(esL10n),
        'Mensaje directo',
        reason: 'DM default title must be ES "Mensaje directo"',
      );
    });

    test('channel target still returns #conversationId regardless of locale',
        () {
      final zhL10n = lookupAppLocalizations(const Locale('zh'));
      final target = ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('s1'),
          value: 'general',
        ),
      );

      expect(
        target.localizedDefaultTitle(zhL10n),
        '#general',
        reason: 'Channel default title is not localized',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Group 4: userFallbackDisplayName l10n
  // ---------------------------------------------------------------------------
  group('userFallbackDisplayName l10n (#846)', () {
    test('ZH locale returns 用户', () {
      final zhL10n = lookupAppLocalizations(const Locale('zh'));
      expect(
        zhL10n.userFallbackDisplayName,
        '用户',
        reason: 'userFallbackDisplayName must be ZH "用户"',
      );
    });

    test('ES locale returns "Usuario"', () {
      final esL10n = lookupAppLocalizations(const Locale('es'));
      expect(
        esL10n.userFallbackDisplayName,
        'Usuario',
        reason: 'userFallbackDisplayName must be ES "Usuario"',
      );
    });

    test('EN locale returns "User"', () {
      final enL10n = lookupAppLocalizations(const Locale('en'));
      expect(
        enL10n.userFallbackDisplayName,
        'User',
        reason: 'userFallbackDisplayName must be EN "User"',
      );
    });
  });
}

// =============================================================================
// Test Doubles
// =============================================================================

class _FakeAgentsRepository implements AgentsRepository {
  List<AgentItem> listResult = [];

  @override
  Future<List<AgentItem>> listAgents() async => listResult;

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
      [];
}
