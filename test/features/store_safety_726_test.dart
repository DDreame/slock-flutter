// =============================================================================
// #726 — Store Safety (3 P1 guard additions)
//
// A. P1: SavedMessagesStore.unsaveMessage stale snapshot
// B. P1: AgentsStore.ensureLoaded concurrent bypass
// C. P1: BaseUrlSettingsStore.testConnection re-entrancy
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_state.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_store.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';
import 'package:slock_app/features/settings/data/base_url_connection_tester.dart';
import 'package:slock_app/stores/base_url/base_url_settings_store.dart';
import 'package:slock_app/stores/theme/theme_mode_store.dart'
    show sharedPreferencesProvider;

void main() {
  // ===========================================================================
  // A. SavedMessagesStore — single-item rollback preserves concurrent additions
  // ===========================================================================
  group('#726A — SavedMessagesStore.unsaveMessage stale snapshot', () {
    const serverId = ServerScopeId('server-1');
    late _InterleaveableSavedMessagesRepository repo;
    late ProviderContainer container;

    setUp(() {
      repo = _InterleaveableSavedMessagesRepository();
      container = ProviderContainer(overrides: [
        currentSavedMessagesServerIdProvider.overrideWithValue(serverId),
        savedMessagesRepositoryProvider.overrideWithValue(repo),
      ]);
    });

    tearDown(() => container.dispose());

    SavedMessagesStore store() =>
        container.read(savedMessagesStoreProvider.notifier);
    SavedMessagesState state() => container.read(savedMessagesStoreProvider);

    test('unsave rollback preserves items added by concurrent loadMore',
        () async {
      // Setup: initial load with 2 items and hasMore=true.
      repo.listResults = [
        SavedMessagesPage(
          items: [
            SavedMessageItem(
              message: ConversationMessageSummary(
                id: 'msg-1',
                content: 'First',
                createdAt: DateTime(2026),
                senderType: 'human',
                messageType: 'message',
              ),
              channelId: 'ch1',
            ),
            SavedMessageItem(
              message: ConversationMessageSummary(
                id: 'msg-2',
                content: 'Second',
                createdAt: DateTime(2026),
                senderType: 'human',
                messageType: 'message',
              ),
              channelId: 'ch1',
            ),
          ],
          hasMore: true,
        ),
        // loadMore page:
        SavedMessagesPage(
          items: [
            SavedMessageItem(
              message: ConversationMessageSummary(
                id: 'msg-3',
                content: 'Third (from loadMore)',
                createdAt: DateTime(2026),
                senderType: 'human',
                messageType: 'message',
              ),
              channelId: 'ch1',
            ),
          ],
          hasMore: false,
        ),
      ];

      await store().load();
      expect(state().items.length, 2);

      // Start unsave of msg-1 — but make the API hang until we release it.
      repo.unsaveCompleter = Completer<void>();
      final unsaveFuture = store().unsaveMessage('msg-1');

      // While unsave API is in flight, loadMore completes and adds msg-3.
      await store().loadMore();
      expect(
          state().items.map((i) => i.message.id).toList(), ['msg-2', 'msg-3']);

      // Now make unsave fail — triggers rollback.
      repo.unsaveCompleter!.completeError(
        const UnknownFailure(message: 'Network error', causeType: 'test'),
      );
      await unsaveFuture;

      // Rollback must re-insert msg-1 but preserve msg-3 from loadMore.
      final ids = state().items.map((i) => i.message.id).toList();
      expect(ids, contains('msg-1'),
          reason: 'Rolled-back item must be re-inserted');
      expect(ids, contains('msg-3'),
          reason: 'loadMore additions must be preserved on rollback');
      expect(ids, contains('msg-2'));
    });

    test('unsave success does not re-insert item', () async {
      repo.listResults = [
        SavedMessagesPage(
          items: [
            SavedMessageItem(
              message: ConversationMessageSummary(
                id: 'msg-1',
                content: 'Hello',
                createdAt: DateTime(2026),
                senderType: 'human',
                messageType: 'message',
              ),
              channelId: 'ch1',
            ),
          ],
          hasMore: false,
        ),
      ];

      await store().load();
      await store().unsaveMessage('msg-1');

      expect(state().items, isEmpty);
    });
  });

  // ===========================================================================
  // B. AgentsStore — ensureLoaded Completer prevents duplicate API calls
  // ===========================================================================
  group('#726B — AgentsStore.ensureLoaded concurrent bypass', () {
    late _CountingAgentsRepository repo;
    late ProviderContainer container;
    late ProviderSubscription<AgentsState> sub;

    setUp(() {
      repo = _CountingAgentsRepository();
      container = ProviderContainer(overrides: [
        agentsRepositoryProvider.overrideWithValue(repo),
        agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
      ]);
      sub = container.listen(agentsStoreProvider, (_, __) {});
    });

    tearDown(() {
      sub.close();
      container.dispose();
    });

    test('3 concurrent ensureLoaded() calls produce exactly 1 API call',
        () async {
      // All three callers await the same in-flight load.
      final f1 = container.read(agentsStoreProvider.notifier).ensureLoaded();
      final f2 = container.read(agentsStoreProvider.notifier).ensureLoaded();
      final f3 = container.read(agentsStoreProvider.notifier).ensureLoaded();

      await Future.wait([f1, f2, f3]);

      expect(repo.listAgentsCallCount, 1,
          reason: 'Completer guard must prevent duplicate loads');
      expect(container.read(agentsStoreProvider).status, AgentsStatus.success);
    });

    test('ensureLoaded after successful load is a no-op', () async {
      await container.read(agentsStoreProvider.notifier).ensureLoaded();
      expect(repo.listAgentsCallCount, 1);

      // Second call — status is now success, should not fire another load.
      await container.read(agentsStoreProvider.notifier).ensureLoaded();
      expect(repo.listAgentsCallCount, 1);
    });

    test('ensureLoaded after failed load allows retry', () async {
      repo.shouldFail = true;
      await container.read(agentsStoreProvider.notifier).ensureLoaded();
      // Status should be failure — ensureLoaded must have caught the error.
      expect(container.read(agentsStoreProvider).status, AgentsStatus.failure);
      expect(repo.listAgentsCallCount, 1);

      // Fix the repo and call ensureLoaded on a fresh state (retry via load).
      repo.shouldFail = false;
      await container.read(agentsStoreProvider.notifier).load();
      expect(container.read(agentsStoreProvider).status, AgentsStatus.success);
      expect(repo.listAgentsCallCount, 2);
    });
  });

  // ===========================================================================
  // C. BaseUrlSettingsStore — testConnection re-entrancy guard
  // ===========================================================================
  group('#726C — BaseUrlSettingsStore.testConnection re-entrancy', () {
    late _SlowConnectionTester tester;
    late ProviderContainer container;

    Future<ProviderContainer> buildContainer(
        _SlowConnectionTester connectionTester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      return ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        baseUrlConnectionTesterProvider.overrideWithValue(connectionTester),
      ]);
    }

    test('second testConnection while first is in-flight is dropped', () async {
      tester = _SlowConnectionTester();
      container = await buildContainer(tester);

      final notifier = container.read(baseUrlSettingsStoreProvider.notifier);
      notifier.setApiBaseUrl('https://api.example.com');

      // Start first testConnection — it will hang on the completer.
      final first = notifier.testConnection();

      // Start second testConnection immediately — should be dropped.
      final second = notifier.testConnection();
      await second; // Returns immediately (guard).

      // Complete the first test.
      tester.apiCompleter.complete(ConnectionTestResult.reachable);
      await first;

      expect(tester.apiCallCount, 1,
          reason: 'Re-entrancy guard must drop second call');
      expect(
        container.read(baseUrlSettingsStoreProvider).apiTestResult,
        ConnectionTestResult.reachable,
      );
    });

    test('testConnection is available again after first completes', () async {
      tester = _SlowConnectionTester();
      container = await buildContainer(tester);

      final notifier = container.read(baseUrlSettingsStoreProvider.notifier);
      notifier.setApiBaseUrl('https://api.example.com');

      // First test.
      tester.apiCompleter.complete(ConnectionTestResult.reachable);
      await notifier.testConnection();
      expect(tester.apiCallCount, 1);

      // Reset completer for second independent call.
      tester.apiCompleter = Completer<ConnectionTestResult>();
      tester.apiCompleter.complete(ConnectionTestResult.timeout);
      await notifier.testConnection();
      expect(tester.apiCallCount, 2,
          reason: 'Guard resets after completion, allowing new tests');
    });

    tearDown(() => container.dispose());
  });
}

// =============================================================================
// Test Doubles
// =============================================================================

/// SavedMessagesRepository that supports interleaved async operations.
class _InterleaveableSavedMessagesRepository
    implements SavedMessagesRepository {
  List<SavedMessagesPage> listResults = [];
  int _listCallCount = 0;
  Completer<void>? unsaveCompleter;

  @override
  Future<SavedMessagesPage> listSavedMessages(
    ServerScopeId serverId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final index = _listCallCount++;
    if (index < listResults.length) return listResults[index];
    return const SavedMessagesPage(items: [], hasMore: false);
  }

  @override
  Future<void> unsaveMessage(ServerScopeId serverId, String messageId) async {
    if (unsaveCompleter != null) {
      await unsaveCompleter!.future;
    }
  }

  @override
  Future<void> saveMessage(ServerScopeId serverId, String messageId) async {}

  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) async =>
      {};
}

/// AgentsRepository that counts API calls.
class _CountingAgentsRepository implements AgentsRepository {
  int listAgentsCallCount = 0;
  bool shouldFail = false;

  @override
  Future<List<AgentItem>> listAgents() async {
    listAgentsCallCount++;
    if (shouldFail) {
      throw const UnknownFailure(message: 'Load failed', causeType: 'test');
    }
    return [
      const AgentItem(
        id: 'a1',
        name: 'Bot',
        model: 'sonnet',
        runtime: 'claude',
        status: 'active',
        activity: 'online',
      ),
    ];
  }

  @override
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  }) async =>
      [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// BaseUrlConnectionTester with controllable latency via Completers.
class _SlowConnectionTester extends BaseUrlConnectionTester {
  Completer<ConnectionTestResult> apiCompleter =
      Completer<ConnectionTestResult>();
  int apiCallCount = 0;

  _SlowConnectionTester() : super();

  @override
  Future<ConnectionTestResult> testApi(String baseUrl) async {
    apiCallCount++;
    return apiCompleter.future;
  }

  @override
  Future<ConnectionTestResult> testRealtime(String realtimeUrl) async {
    return ConnectionTestResult.reachable;
  }
}
