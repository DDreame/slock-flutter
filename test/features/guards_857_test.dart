import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/channels/application/channel_member_store.dart';
import 'package:slock_app/features/channels/data/channel_member.dart';
import 'package:slock_app/features/channels/data/channel_member_repository.dart';
import 'package:slock_app/features/channels/data/channel_member_repository_provider.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/members/application/member_list_state.dart';
import 'package:slock_app/features/members/application/member_list_store.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  // ===========================================================================
  // ConversationDetailStore — disposed guard (5 methods)
  // ===========================================================================

  group('ConversationDetailStore disposed guards', () {
    final target = ConversationDetailTarget.channel(
      const ChannelScopeId(
        serverId: ServerScopeId('srv-1'),
        value: 'ch-1',
      ),
    );

    test('editMessage does not mutate state after dispose', () async {
      final repo = _SlowConversationRepository(target);
      final savedRepo = _SlowSavedMessagesRepository();
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          savedMessagesRepositoryProvider.overrideWithValue(savedRepo),
        ],
      );
      final sub = container.listen(conversationDetailStoreProvider, (_, __) {});
      final notifier = container.read(conversationDetailStoreProvider.notifier);

      // Get store into success state with a message.
      await notifier.load();
      // Drain microtasks from unawaited refreshSavedMessageIds().
      await Future<void>.value();

      // Reset completer for the edit operation.
      repo.operationCompleter = Completer<void>();

      // Start the method — it awaits the completer.
      final future = notifier.editMessage('msg-1', 'new content');

      // Dispose before the completer fires.
      sub.close();
      container.dispose();

      // Complete with AppFailure to drive the rollback path where the guard lives.
      repo.operationCompleter.completeError(
        const UnknownFailure(message: 'test', causeType: 'test'),
      );
      await future; // Must not throw — _disposed guard returns early.
    });

    test('deleteMessage does not mutate state after dispose', () async {
      final repo = _SlowConversationRepository(target);
      final savedRepo = _SlowSavedMessagesRepository();
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          savedMessagesRepositoryProvider.overrideWithValue(savedRepo),
        ],
      );
      final sub = container.listen(conversationDetailStoreProvider, (_, __) {});
      final notifier = container.read(conversationDetailStoreProvider.notifier);

      await notifier.load();
      await Future<void>.value();
      repo.operationCompleter = Completer<void>();

      final future = notifier.deleteMessage('msg-1');

      sub.close();
      container.dispose();

      repo.operationCompleter.completeError(
        const UnknownFailure(message: 'test', causeType: 'test'),
      );
      await future;
    });

    test('pinMessage does not mutate state after dispose', () async {
      final repo = _SlowConversationRepository(target);
      final savedRepo = _SlowSavedMessagesRepository();
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          savedMessagesRepositoryProvider.overrideWithValue(savedRepo),
        ],
      );
      final sub = container.listen(conversationDetailStoreProvider, (_, __) {});
      final notifier = container.read(conversationDetailStoreProvider.notifier);

      await notifier.load();
      await Future<void>.value();
      repo.operationCompleter = Completer<void>();

      final future = notifier.pinMessage('msg-1');

      sub.close();
      container.dispose();

      repo.operationCompleter.completeError(
        const UnknownFailure(message: 'test', causeType: 'test'),
      );
      await future;
    });

    test('unpinMessage does not mutate state after dispose', () async {
      final repo = _SlowConversationRepository(target);
      final savedRepo = _SlowSavedMessagesRepository();
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          savedMessagesRepositoryProvider.overrideWithValue(savedRepo),
        ],
      );
      final sub = container.listen(conversationDetailStoreProvider, (_, __) {});
      final notifier = container.read(conversationDetailStoreProvider.notifier);

      await notifier.load();
      await Future<void>.value();
      repo.operationCompleter = Completer<void>();

      final future = notifier.unpinMessage('msg-1');

      sub.close();
      container.dispose();

      repo.operationCompleter.completeError(
        const UnknownFailure(message: 'test', causeType: 'test'),
      );
      await future;
    });

    test('toggleSaveMessage does not mutate state after dispose', () async {
      final repo = _SlowConversationRepository(target);
      final savedRepo = _SlowSavedMessagesRepository();
      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          savedMessagesRepositoryProvider.overrideWithValue(savedRepo),
        ],
      );
      final sub = container.listen(conversationDetailStoreProvider, (_, __) {});
      final notifier = container.read(conversationDetailStoreProvider.notifier);

      // toggleSaveMessage doesn't require success status, but load anyway
      // to be consistent.
      await notifier.load();
      await Future<void>.value();
      savedRepo.completer = Completer<void>();

      final future = notifier.toggleSaveMessage('msg-1');

      sub.close();
      container.dispose();

      savedRepo.completer.completeError(
        const UnknownFailure(message: 'test', causeType: 'test'),
      );
      await future;
    });
  });

  // ===========================================================================
  // MemberListStore — epoch guard for concurrent loads
  // ===========================================================================

  group('MemberListStore epoch guard', () {
    const serverId = ServerScopeId('server-1');

    test('stale load result is discarded when epoch advances', () async {
      final repo = _QueuedMemberRepository();
      final container = ProviderContainer(
        overrides: [
          currentMembersServerIdProvider.overrideWithValue(serverId),
          memberRepositoryProvider.overrideWithValue(repo),
          sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      final store = container.read(memberListStoreProvider.notifier);

      // Queue two responses: first will be slow, second will be fast.
      final firstCompleter = Completer<List<MemberProfile>>();
      final secondCompleter = Completer<List<MemberProfile>>();
      repo.completers.addAll([firstCompleter, secondCompleter]);

      // Fire both loads concurrently.
      final future1 = store.load();
      final future2 = store.load();

      // Complete second (newer) first → epoch should accept it.
      secondCompleter.complete(const [
        MemberProfile(id: 'new-user', displayName: 'New'),
      ]);
      await future2;

      // Complete first (stale) after → epoch should reject it.
      firstCompleter.complete(const [
        MemberProfile(id: 'old-user', displayName: 'Old'),
      ]);
      await future1;

      final state = container.read(memberListStoreProvider);
      expect(state.status, MemberListStatus.success);
      expect(state.members.first.displayName, 'New',
          reason: 'Stale load result must be discarded by epoch guard');
    });
  });

  // ===========================================================================
  // AgentsStore.resetAgent() — generic catch
  // ===========================================================================

  group('AgentsStore.resetAgent generic catch', () {
    test('wraps non-AppFailure and clears in-flight flag', () async {
      final fakeRepo = _FakeAgentsRepositoryForReset();
      final container = ProviderContainer(
        overrides: [
          agentsRepositoryProvider.overrideWithValue(fakeRepo),
          agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
        ],
      );
      final sub = container.listen(agentsStoreProvider, (_, __) {});
      addTearDown(() {
        sub.close();
        container.dispose();
      });

      final store = container.read(agentsStoreProvider.notifier);

      // Load an agent first.
      fakeRepo.listResult = [
        const AgentItem(
          id: 'a1',
          name: 'Bot',
          model: 'sonnet',
          runtime: 'claude',
          status: 'active',
          activity: 'working',
        ),
      ];
      await store.load();

      // Make resetAgent throw a non-AppFailure.
      fakeRepo.thrownError = StateError('reset transport failed');

      await expectLater(
        store.resetAgent('a1'),
        throwsA(isA<UnknownFailure>()),
      );

      final state = container.read(agentsStoreProvider);
      expect(state.controlActionAgentIds, isEmpty,
          reason: 'in-flight flag must be cleared in finally');
      expect(state.failure, isA<UnknownFailure>());
    });
  });

  // ===========================================================================
  // ChannelMemberStore — addHumanMember/addAgentMember generic catch
  // ===========================================================================

  group('ChannelMemberStore add-member generic catch', () {
    const serverId = ServerScopeId('server-1');
    const channelId = 'channel-1';

    late _FakeChannelMemberRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = _FakeChannelMemberRepository();
      container = ProviderContainer(
        overrides: [
          currentChannelMemberServerIdProvider.overrideWithValue(serverId),
          currentChannelMemberChannelIdProvider.overrideWithValue(channelId),
          channelMemberRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('addHumanMember wraps non-AppFailure in state', () async {
      fakeRepo.error = StateError('unexpected add failure');

      // catch-all absorbs the exception — no throw expected.
      await container
          .read(channelMemberStoreProvider.notifier)
          .addHumanMember('user-1');

      final state = container.read(channelMemberStoreProvider);
      expect(state.failure, isA<UnknownFailure>());
    });

    test('addAgentMember wraps non-AppFailure in state', () async {
      fakeRepo.error = StateError('unexpected add failure');

      // catch-all absorbs the exception — no throw expected.
      await container
          .read(channelMemberStoreProvider.notifier)
          .addAgentMember('agent-1');

      final state = container.read(channelMemberStoreProvider);
      expect(state.failure, isA<UnknownFailure>());
    });
  });
}

// =============================================================================
// Fake repositories
// =============================================================================

/// ConversationRepository that returns a success snapshot from [loadConversation]
/// and delays mutation operations (edit/delete/pin/unpin) on a Completer.
class _SlowConversationRepository implements ConversationRepository {
  _SlowConversationRepository(this._target);

  final ConversationDetailTarget _target;

  /// Completer for mutation operations (edit, delete, pin, unpin).
  /// Reset between load() and the operation under test.
  Completer<void> operationCompleter = Completer<void>();

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    return ConversationDetailSnapshot(
      target: _target,
      title: 'Test',
      messages: [
        ConversationMessageSummary(
          id: 'msg-1',
          content: 'hello',
          createdAt: DateTime(2026),
          senderType: 'human',
          messageType: 'message',
          seq: 1,
        ),
      ],
      historyLimited: false,
      hasOlder: false,
    );
  }

  @override
  Future<void> editMessage(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {
    await operationCompleter.future;
  }

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    await operationCompleter.future;
  }

  @override
  Future<void> pinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    await operationCompleter.future;
  }

  @override
  Future<void> unpinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    await operationCompleter.future;
  }

  // Stubs for other required interface methods.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Slow SavedMessagesRepository using its own completer.
class _SlowSavedMessagesRepository implements SavedMessagesRepository {
  Completer<void> completer = Completer<void>();

  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) async =>
      const {};

  @override
  Future<void> saveMessage(ServerScopeId serverId, String messageId) async {
    await completer.future;
  }

  @override
  Future<void> unsaveMessage(ServerScopeId serverId, String messageId) async {
    await completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// MemberRepository that uses a queue of completers for concurrent testing.
class _QueuedMemberRepository implements MemberRepository {
  final List<Completer<List<MemberProfile>>> completers = [];
  int _callIndex = 0;

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async {
    final completer = completers[_callIndex++];
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-123',
        displayName: 'Alice',
        token: 'test-token',
      );
}

/// AgentsRepository for resetAgent testing.
class _FakeAgentsRepositoryForReset implements AgentsRepository {
  List<AgentItem>? listResult;
  Object? thrownError;

  @override
  Future<List<AgentItem>> listAgents() async => listResult ?? [];

  @override
  Future<void> startAgent(String agentId) async {}

  @override
  Future<void> stopAgent(String agentId) async {}

  @override
  Future<void> resetAgent(String agentId, {required String mode}) async {
    if (thrownError != null) throw thrownError!;
  }

  @override
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  }) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// ChannelMemberRepository for add-member testing.
class _FakeChannelMemberRepository implements ChannelMemberRepository {
  List<ChannelMember> members = const [];
  Object? error;

  @override
  Future<List<ChannelMember>> listMembers(
    ServerScopeId serverId, {
    required String channelId,
  }) async =>
      members;

  @override
  Future<void> addHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) async {
    if (error != null) throw error!;
  }

  @override
  Future<void> addAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  }) async {
    if (error != null) throw error!;
  }

  @override
  Future<void> removeHumanMember(
    ServerScopeId serverId, {
    required String channelId,
    required String userId,
  }) async {}

  @override
  Future<void> removeAgentMember(
    ServerScopeId serverId, {
    required String channelId,
    required String agentId,
  }) async {}
}
