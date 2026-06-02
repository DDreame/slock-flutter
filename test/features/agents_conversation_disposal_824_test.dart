// =============================================================================
// #824 — AgentsStore Disposal Guards + ConversationDetailStore Graceful Return
//
// Verifies:
// 1. AgentsStore: Disposing during startAgent/stopAgent does not throw
//    StateError — finally/catch blocks bail out on _disposed.
// 2. ConversationDetailStore: _isCurrentRequest() returns false when disposed
//    instead of throwing StateError from ref.read on a disposed container.
//
// Load-bearing proof:
//   Reverting the guards causes StateError (Bad state: Tried to read a
//   provider from a ProviderContainer that was already disposed).
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:dio/dio.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';

void main() {
  // ===========================================================================
  // Part 1: AgentsStore disposal guards in finally/catch blocks
  // ===========================================================================

  group('#824 — AgentsStore disposal safety', () {
    late ProviderContainer container;
    late ProviderSubscription<AgentsState> sub;

    AgentsStore store() => container.read(agentsStoreProvider.notifier);

    test('dispose during startAgent does not throw StateError', () async {
      final completer = Completer<void>();
      final repo = _DelayedAgentsRepository(startCompleter: completer);

      container = ProviderContainer(overrides: [
        agentsRepositoryProvider.overrideWithValue(repo),
        agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
      ]);
      sub = container.listen(agentsStoreProvider, (_, __) {});

      // Load agents first so store has items.
      repo.listResult = [_makeAgent()];
      await store().load();

      // Start agent — hangs on completer.
      final startFuture = store().startAgent('agent-1');

      // Dispose before startAgent completes.
      sub.close();
      container.dispose();

      // Complete the network call — finally block should bail out.
      completer.complete();
      await startFuture;
    });

    test('dispose during stopAgent does not throw StateError', () async {
      final completer = Completer<void>();
      final repo = _DelayedAgentsRepository(stopCompleter: completer);

      container = ProviderContainer(overrides: [
        agentsRepositoryProvider.overrideWithValue(repo),
        agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
      ]);
      sub = container.listen(agentsStoreProvider, (_, __) {});

      repo.listResult = [_makeAgent()];
      await store().load();

      final stopFuture = store().stopAgent('agent-1');

      sub.close();
      container.dispose();

      completer.complete();
      await stopFuture;
    });

    test('dispose during failed startAgent does not throw StateError',
        () async {
      final completer = Completer<void>();
      final repo = _DelayedAgentsRepository(startCompleter: completer);

      container = ProviderContainer(overrides: [
        agentsRepositoryProvider.overrideWithValue(repo),
        agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
      ]);
      sub = container.listen(agentsStoreProvider, (_, __) {});

      repo.listResult = [_makeAgent()];
      await store().load();

      final startFuture = store().startAgent('agent-1');

      sub.close();
      container.dispose();

      // Fail the network call — catch + finally blocks should bail out.
      completer.completeError(const NetworkFailure(message: 'timeout'));
      await startFuture;
    });

    test('dispose during resetAgent does not throw StateError', () async {
      final completer = Completer<void>();
      final repo = _DelayedAgentsRepository(resetCompleter: completer);

      container = ProviderContainer(overrides: [
        agentsRepositoryProvider.overrideWithValue(repo),
        agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
      ]);
      sub = container.listen(agentsStoreProvider, (_, __) {});

      repo.listResult = [_makeAgent()];
      await store().load();

      final resetFuture = store().resetAgent('agent-1');

      sub.close();
      container.dispose();

      // Complete the reset — catch + finally blocks should bail out.
      completer.completeError(const NetworkFailure(message: 'timeout'));
      await resetFuture;
    });
  });

  // ===========================================================================
  // Part 2: ConversationDetailStore _isCurrentRequest graceful return
  // ===========================================================================

  group('#824 — ConversationDetailStore _isCurrentRequest disposal safety', () {
    final target = ConversationDetailTarget.channel(
      const ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'general',
      ),
    );

    test('dispose during load does not throw StateError from _isCurrentRequest',
        () async {
      final loadCompleter = Completer<ConversationDetailSnapshot>();
      final repo = _DelayedConversationRepository(
        loadCompleter: loadCompleter,
      );

      final container = ProviderContainer(overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );

      final loadFuture =
          container.read(conversationDetailStoreProvider.notifier).load();

      // Dispose while load is pending — _isCurrentRequest will be called
      // after the completer resolves.
      sub.close();
      container.dispose();

      // Complete the load — _isCurrentRequest should return false gracefully.
      loadCompleter.complete(ConversationDetailSnapshot(
        target: target,
        title: 'General',
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ));
      await loadFuture;
    });

    test(
        'dispose during failed load does not throw StateError from _isCurrentRequest',
        () async {
      final loadCompleter = Completer<ConversationDetailSnapshot>();
      final repo = _DelayedConversationRepository(
        loadCompleter: loadCompleter,
      );

      final container = ProviderContainer(overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );

      final loadFuture =
          container.read(conversationDetailStoreProvider.notifier).load();

      // #860: loadLocalMessages() introduces an async gap before
      // loadConversation(). Pump a microtask so the load progresses past
      // the local-seed step and actually awaits loadCompleter.
      await Future<void>.delayed(Duration.zero);

      sub.close();
      container.dispose();

      // Fail the load — catch block's _isCurrentRequest should not throw.
      loadCompleter.completeError(const NetworkFailure(message: 'timeout'));
      await loadFuture;
    });
  });
}

// =============================================================================
// Test helpers
// =============================================================================

AgentItem _makeAgent({
  String id = 'agent-1',
  String name = 'Bot',
  String status = 'active',
  String activity = 'online',
}) {
  return AgentItem(
    id: id,
    name: name,
    model: 'sonnet',
    runtime: 'claude',
    status: status,
    activity: activity,
  );
}

// =============================================================================
// AgentsStore fakes
// =============================================================================

class _DelayedAgentsRepository implements AgentsRepository {
  _DelayedAgentsRepository({
    this.startCompleter,
    this.stopCompleter,
    this.resetCompleter,
  });

  final Completer<void>? startCompleter;
  final Completer<void>? stopCompleter;
  final Completer<void>? resetCompleter;
  List<AgentItem> listResult = [];

  @override
  Future<List<AgentItem>> listAgents() async => listResult;

  @override
  Future<void> startAgent(String agentId) =>
      startCompleter?.future ?? Future.value();

  @override
  Future<void> stopAgent(String agentId) =>
      stopCompleter?.future ?? Future.value();

  @override
  Future<void> resetAgent(String agentId, {required String mode}) =>
      resetCompleter?.future ?? Future.value();

  @override
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  }) async =>
      const [];
}

// =============================================================================
// ConversationDetailStore fakes
// =============================================================================

class _DelayedConversationRepository implements ConversationRepository {
  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  _DelayedConversationRepository({required this.loadCompleter});
  final Completer<ConversationDetailSnapshot> loadCompleter;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) =>
      loadCompleter.future;

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
      );

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
      );

  @override
  Future<ConversationMessagePage> loadMessageContext(
    ConversationDetailTarget target, {
    required String messageId,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
        hasNewer: false,
      );

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    bool? asTask,
    String? clientId,
    CancelToken? cancelToken,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> editMessage(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {}

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> pinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> unpinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async =>
      const [];

  @override
  Future<void> addReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}
}
