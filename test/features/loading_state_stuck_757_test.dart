// =============================================================================
// #757 — Loading State Stuck Pattern
//
// A. P1: SavedMessagesStore.loadMore — isLoadingMore stuck true on non-AppFailure
// B. P1: ThreadRepliesStore.load — status stuck at loading on non-AppFailure
// C. P2: ServerListStore — isCreating/deletingServerIds/leavingServerIds/
//         savingServerIds/isJoiningInvite never reset on non-AppFailure
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_state.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_store.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/servers/data/server_list_repository.dart';
import 'package:slock_app/features/servers/data/server_list_repository_provider.dart';
import 'package:slock_app/features/threads/application/thread_replies_state.dart';
import 'package:slock_app/features/threads/application/thread_replies_store.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';

void main() {
  // ---------------------------------------------------------------------------
  // #757A — SavedMessagesStore.loadMore resets isLoadingMore on non-AppFailure
  // ---------------------------------------------------------------------------
  group('#757A — SavedMessagesStore.loadMore non-AppFailure recovery', () {
    const serverId = ServerScopeId('server-1');

    test('non-AppFailure resets isLoadingMore flag', () async {
      final repo = _FakeSavedMessagesRepository();
      final container = ProviderContainer(overrides: [
        currentSavedMessagesServerIdProvider.overrideWithValue(serverId),
        savedMessagesRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      // Load initial page so loadMore is enabled.
      repo.listResult = SavedMessagesPage(
        items: [
          SavedMessageItem(
            message: ConversationMessageSummary(
              id: 'msg-1',
              content: 'Hello',
              createdAt: DateTime(2026, 5, 22),
              senderType: 'human',
              messageType: 'message',
            ),
            channelId: 'ch1',
          ),
        ],
        hasMore: true,
      );
      await container.read(savedMessagesStoreProvider.notifier).load();
      expect(
        container.read(savedMessagesStoreProvider).status,
        SavedMessagesStatus.success,
      );

      // Trigger non-AppFailure on next loadMore.
      repo.throwNonAppFailure = true;
      await container.read(savedMessagesStoreProvider.notifier).loadMore();

      final state = container.read(savedMessagesStoreProvider);
      expect(state.isLoadingMore, isFalse,
          reason: '#757: isLoadingMore must reset on non-AppFailure');
      expect(state.failure, isA<UnknownFailure>());
    });

    test('AppFailure still resets isLoadingMore (unchanged behavior)',
        () async {
      final repo = _FakeSavedMessagesRepository();
      final container = ProviderContainer(overrides: [
        currentSavedMessagesServerIdProvider.overrideWithValue(serverId),
        savedMessagesRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      repo.listResult = SavedMessagesPage(
        items: [
          SavedMessageItem(
            message: ConversationMessageSummary(
              id: 'msg-1',
              content: 'Hello',
              createdAt: DateTime(2026, 5, 22),
              senderType: 'human',
              messageType: 'message',
            ),
            channelId: 'ch1',
          ),
        ],
        hasMore: true,
      );
      await container.read(savedMessagesStoreProvider.notifier).load();

      repo.throwAppFailure = true;
      await container.read(savedMessagesStoreProvider.notifier).loadMore();

      final state = container.read(savedMessagesStoreProvider);
      expect(state.isLoadingMore, isFalse);
      expect(state.failure, isA<AppFailure>());
    });
  });

  // ---------------------------------------------------------------------------
  // #757B — ThreadRepliesStore.load resets status on non-AppFailure
  // ---------------------------------------------------------------------------
  group('#757B — ThreadRepliesStore.load non-AppFailure recovery', () {
    const routeTarget = ThreadRouteTarget(
      serverId: 'server-1',
      parentChannelId: 'ch-1',
      parentMessageId: 'msg-1',
    );

    test('non-AppFailure transitions status to failure', () async {
      final repo = _FakeThreadRepository(throwNonAppFailure: true);
      final container = ProviderContainer(overrides: [
        currentThreadRouteTargetProvider.overrideWithValue(routeTarget),
        threadRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await container.read(threadRepliesStoreProvider.notifier).load();

      final state = container.read(threadRepliesStoreProvider);
      expect(state.status, ThreadRepliesStatus.failure,
          reason: '#757: status must not stay stuck at loading');
      expect(state.failure, isA<UnknownFailure>());
    });

    test('AppFailure transitions status to failure (unchanged)', () async {
      final repo = _FakeThreadRepository(throwAppFailure: true);
      final container = ProviderContainer(overrides: [
        currentThreadRouteTargetProvider.overrideWithValue(routeTarget),
        threadRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await container.read(threadRepliesStoreProvider.notifier).load();

      final state = container.read(threadRepliesStoreProvider);
      expect(state.status, ThreadRepliesStatus.failure);
      expect(state.failure, isA<AppFailure>());
    });

    test('retry works after non-AppFailure recovery', () async {
      final repo = _FakeThreadRepository(throwNonAppFailure: true);
      final container = ProviderContainer(overrides: [
        currentThreadRouteTargetProvider.overrideWithValue(routeTarget),
        threadRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      // First load fails.
      await container.read(threadRepliesStoreProvider.notifier).load();
      expect(
        container.read(threadRepliesStoreProvider).status,
        ThreadRepliesStatus.failure,
      );

      // Fix the error and retry.
      repo.throwNonAppFailure = false;
      repo.resolvedThread = const ResolvedThreadChannel(
        threadChannelId: 'thread-ch-1',
        replyCount: 3,
        participantIds: [],
      );
      await container.read(threadRepliesStoreProvider.notifier).retry();

      final state = container.read(threadRepliesStoreProvider);
      expect(state.status, ThreadRepliesStatus.success);
    });
  });

  // ---------------------------------------------------------------------------
  // #757C — ServerListStore resets flags on non-AppFailure
  // ---------------------------------------------------------------------------
  group('#757C — ServerListStore non-AppFailure flag recovery', () {
    test('createServer resets isCreating on non-AppFailure', () async {
      final repo = _FakeServerListRepository(throwNonAppFailure: true);
      final container = ProviderContainer(overrides: [
        serverListRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      // Load servers first.
      repo.throwNonAppFailure = false;
      await container.read(serverListStoreProvider.notifier).load();
      repo.throwNonAppFailure = true;

      try {
        await container.read(serverListStoreProvider.notifier).createServer(
              'Test',
            );
      } catch (_) {}

      final state = container.read(serverListStoreProvider);
      expect(state.isCreating, isFalse,
          reason: '#757: isCreating must reset on non-AppFailure');
      expect(state.failure, isA<UnknownFailure>());
    });

    test('deleteServer resets deletingServerIds on non-AppFailure', () async {
      final repo = _FakeServerListRepository(throwNonAppFailure: true);
      final container = ProviderContainer(overrides: [
        serverListRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      // Load servers first.
      repo.throwNonAppFailure = false;
      repo.servers = [
        const ServerSummary(id: 'srv-1', name: 'Test'),
      ];
      await container.read(serverListStoreProvider.notifier).load();
      repo.throwNonAppFailure = true;

      try {
        await container.read(serverListStoreProvider.notifier).deleteServer(
              'srv-1',
            );
      } catch (_) {}

      final state = container.read(serverListStoreProvider);
      expect(state.deletingServerIds, isEmpty,
          reason: '#757: deletingServerIds must reset on non-AppFailure');
      expect(state.failure, isA<UnknownFailure>());
    });

    test('leaveServer resets leavingServerIds on non-AppFailure', () async {
      final repo = _FakeServerListRepository(throwNonAppFailure: true);
      final container = ProviderContainer(overrides: [
        serverListRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      // Load servers first.
      repo.throwNonAppFailure = false;
      repo.servers = [
        const ServerSummary(id: 'srv-1', name: 'Test'),
      ];
      await container.read(serverListStoreProvider.notifier).load();
      repo.throwNonAppFailure = true;

      try {
        await container.read(serverListStoreProvider.notifier).leaveServer(
              'srv-1',
            );
      } catch (_) {}

      final state = container.read(serverListStoreProvider);
      expect(state.leavingServerIds, isEmpty,
          reason: '#757: leavingServerIds must reset on non-AppFailure');
      expect(state.failure, isA<UnknownFailure>());
    });

    test('renameServer resets savingServerIds on non-AppFailure', () async {
      final repo = _FakeServerListRepository(throwNonAppFailure: true);
      final container = ProviderContainer(overrides: [
        serverListRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      // Load servers first.
      repo.throwNonAppFailure = false;
      repo.servers = [
        const ServerSummary(id: 'srv-1', name: 'Old Name'),
      ];
      await container.read(serverListStoreProvider.notifier).load();
      repo.throwNonAppFailure = true;

      try {
        await container
            .read(serverListStoreProvider.notifier)
            .renameServer('srv-1', 'New Name');
      } catch (_) {}

      final state = container.read(serverListStoreProvider);
      expect(state.savingServerIds, isEmpty,
          reason: '#757: savingServerIds must reset on non-AppFailure');
      expect(state.failure, isA<UnknownFailure>());
    });

    test('acceptInvite resets isJoiningInvite on non-AppFailure', () async {
      final repo = _FakeServerListRepository(throwNonAppFailure: true);
      final container = ProviderContainer(overrides: [
        serverListRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      // Load servers first.
      repo.throwNonAppFailure = false;
      await container.read(serverListStoreProvider.notifier).load();
      repo.throwNonAppFailure = true;

      try {
        await container
            .read(serverListStoreProvider.notifier)
            .acceptInvite('https://example.com/invite?token=abc');
      } catch (_) {}

      final state = container.read(serverListStoreProvider);
      expect(state.isJoiningInvite, isFalse,
          reason: '#757: isJoiningInvite must reset on non-AppFailure');
      expect(state.failure, isA<UnknownFailure>());
    });
  });

  // ---------------------------------------------------------------------------
  // #757D — Throwing diagnostics collector does not re-break state reset
  // ---------------------------------------------------------------------------
  group('#757D — Throwing diagnostics collector resilience', () {
    test('SavedMessagesStore.loadMore resets even when reporter throws',
        () async {
      final repo = _FakeSavedMessagesRepository();
      final container = ProviderContainer(overrides: [
        currentSavedMessagesServerIdProvider
            .overrideWithValue(const ServerScopeId('server-1')),
        savedMessagesRepositoryProvider.overrideWithValue(repo),
        diagnosticsCollectorProvider
            .overrideWithValue(_ThrowingDiagnosticsCollector()),
      ]);
      addTearDown(container.dispose);

      repo.listResult = SavedMessagesPage(
        items: [
          SavedMessageItem(
            message: ConversationMessageSummary(
              id: 'msg-1',
              content: 'Hello',
              createdAt: DateTime(2026, 5, 22),
              senderType: 'human',
              messageType: 'message',
            ),
            channelId: 'ch1',
          ),
        ],
        hasMore: true,
      );
      await container.read(savedMessagesStoreProvider.notifier).load();

      repo.throwNonAppFailure = true;
      await container.read(savedMessagesStoreProvider.notifier).loadMore();

      final state = container.read(savedMessagesStoreProvider);
      expect(state.isLoadingMore, isFalse,
          reason: '#757: isLoadingMore must reset even when reporter throws');
      expect(state.failure, isA<UnknownFailure>());
    });

    test('ThreadRepliesStore.load resets even when reporter throws', () async {
      final repo = _FakeThreadRepository(throwNonAppFailure: true);
      final container = ProviderContainer(overrides: [
        currentThreadRouteTargetProvider.overrideWithValue(
          const ThreadRouteTarget(
            serverId: 'server-1',
            parentChannelId: 'ch-1',
            parentMessageId: 'msg-1',
          ),
        ),
        threadRepositoryProvider.overrideWithValue(repo),
        diagnosticsCollectorProvider
            .overrideWithValue(_ThrowingDiagnosticsCollector()),
      ]);
      addTearDown(container.dispose);

      await container.read(threadRepliesStoreProvider.notifier).load();

      final state = container.read(threadRepliesStoreProvider);
      expect(state.status, ThreadRepliesStatus.failure,
          reason: '#757: status must reset even when reporter throws');
      expect(state.failure, isA<UnknownFailure>());
    });

    test('ServerListStore.createServer resets even when reporter throws',
        () async {
      final repo = _FakeServerListRepository(throwNonAppFailure: true);
      final container = ProviderContainer(overrides: [
        serverListRepositoryProvider.overrideWithValue(repo),
        diagnosticsCollectorProvider
            .overrideWithValue(_ThrowingDiagnosticsCollector()),
      ]);
      addTearDown(container.dispose);

      // Load servers first.
      repo.throwNonAppFailure = false;
      await container.read(serverListStoreProvider.notifier).load();
      repo.throwNonAppFailure = true;

      try {
        await container.read(serverListStoreProvider.notifier).createServer(
              'Test',
            );
      } catch (_) {}

      final state = container.read(serverListStoreProvider);
      expect(state.isCreating, isFalse,
          reason: '#757: isCreating must reset even when reporter throws');
      expect(state.failure, isA<UnknownFailure>());
    });
  });
}

class _FakeSavedMessagesRepository implements SavedMessagesRepository {
  SavedMessagesPage? listResult;
  bool throwNonAppFailure = false;
  bool throwAppFailure = false;

  @override
  Future<SavedMessagesPage> listSavedMessages(
    ServerScopeId serverId, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (offset > 0) {
      if (throwNonAppFailure) {
        throw StateError('Simulated non-AppFailure in loadMore');
      }
      if (throwAppFailure) {
        throw const NetworkFailure(message: 'Connection lost');
      }
    }
    return listResult ?? const SavedMessagesPage(items: [], hasMore: false);
  }

  @override
  Future<void> saveMessage(ServerScopeId serverId, String messageId) async {}

  @override
  Future<void> unsaveMessage(ServerScopeId serverId, String messageId) async {}

  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) async =>
      const {};
}

class _FakeThreadRepository implements ThreadRepository {
  _FakeThreadRepository({
    this.throwNonAppFailure = false,
    this.throwAppFailure = false,
  });

  bool throwNonAppFailure;
  bool throwAppFailure;
  ResolvedThreadChannel? resolvedThread;

  @override
  Future<ResolvedThreadChannel> resolveThread(ThreadRouteTarget target) async {
    if (throwNonAppFailure) {
      throw const FormatException('Simulated non-AppFailure in resolveThread');
    }
    if (throwAppFailure) {
      throw const NotFoundFailure(message: 'Thread not found');
    }
    return resolvedThread ??
        const ResolvedThreadChannel(
          threadChannelId: 'thread-ch-1',
          replyCount: 0,
          participantIds: [],
        );
  }

  @override
  Future<void> markThreadUndone(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}

  @override
  Future<void> markThreadRead(
    ServerScopeId serverId, {
    required String threadChannelId,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeServerListRepository
    implements ServerListRepository, ServerListMutationRepository {
  _FakeServerListRepository({this.throwNonAppFailure = false});

  bool throwNonAppFailure;
  List<ServerSummary> servers = const [];

  @override
  Future<List<ServerSummary>> loadServers() async {
    if (throwNonAppFailure) {
      throw RangeError('Simulated non-AppFailure in loadServers');
    }
    return servers;
  }

  @override
  Future<ServerSummary> createServer({
    required String name,
    required String slug,
  }) async {
    if (throwNonAppFailure) {
      throw StateError('Simulated non-AppFailure in createServer');
    }
    return ServerSummary(id: 'new-srv', name: name);
  }

  @override
  Future<String> renameServer(String serverId, {required String name}) async {
    if (throwNonAppFailure) {
      throw StateError('Simulated non-AppFailure in renameServer');
    }
    return name;
  }

  @override
  Future<void> deleteServer(String serverId) async {
    if (throwNonAppFailure) {
      throw StateError('Simulated non-AppFailure in deleteServer');
    }
  }

  @override
  Future<void> leaveServer(String serverId) async {
    if (throwNonAppFailure) {
      throw StateError('Simulated non-AppFailure in leaveServer');
    }
  }

  @override
  Future<AcceptInviteResult> acceptInvite(String token) async {
    if (throwNonAppFailure) {
      throw StateError('Simulated non-AppFailure in acceptInvite');
    }
    return const AcceptInviteResult(serverId: 'srv-new');
  }

  @override
  Future<InviteInfo> getInviteInfo(String token) async {
    if (throwNonAppFailure) {
      throw StateError('Simulated non-AppFailure in getInviteInfo');
    }
    return const InviteInfo(workspaceName: 'Test Workspace');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingDiagnosticsCollector extends DiagnosticsCollector {
  @override
  void error(String tag, String message, {Map<String, dynamic>? metadata}) {
    throw StateError('Diagnostics collector crash: $message');
  }
}
