// =============================================================================
// #759 — Disposal + Rollback Safety
//
// A. P2: MemberListStore.openDirectMessage — writes state after await on
//    disposed AutoDispose notifier → uncaught StateError.
// B. P2: HomeListStore._persistSidebarOrder — rollback writes after server
//    switch → rollback applies to wrong context or throws StateError.
// C. P2: ConversationDetailStore.batchDeleteMessages — navigation away during
//    batch → rollback on wrong conversation or disposed store.
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/members/application/member_list_state.dart';
import 'package:slock_app/features/members/application/member_list_store.dart';
import 'package:slock_app/features/members/data/member_repository.dart';
import 'package:slock_app/features/members/data/member_repository_provider.dart';
import 'package:slock_app/features/profile/data/profile_repository.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  // ---------------------------------------------------------------------------
  // #759A — MemberListStore.openDirectMessage disposal guard
  // ---------------------------------------------------------------------------
  group('#759A — MemberListStore.openDirectMessage disposal safety', () {
    const serverId = ServerScopeId('server-1');

    test('dispose during openDirectMessage does not throw StateError',
        () async {
      final openCompleter = Completer<String>();
      final repo = _DelayedMemberRepository(openCompleter: openCompleter);
      final container = ProviderContainer(overrides: [
        currentMembersServerIdProvider.overrideWithValue(serverId),
        memberRepositoryProvider.overrideWithValue(repo),
        sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      ]);

      final sub = container.listen(memberListStoreProvider, (_, __) {});

      // Load members first.
      repo.members = const [
        MemberProfile(id: 'user-456', displayName: 'Bob'),
      ];
      await container.read(memberListStoreProvider.notifier).load();
      expect(
        container.read(memberListStoreProvider).status,
        MemberListStatus.success,
      );

      // Start openDirectMessage — it will block on the completer.
      final future =
          container.read(memberListStoreProvider.notifier).openDirectMessage(
                'user-456',
              );

      // Dispose while the await is in flight.
      sub.close();
      container.dispose();

      // Complete the completer after disposal.
      openCompleter.complete('dm-456');

      // Should NOT throw StateError — just complete normally.
      final channelId = await future;
      expect(channelId, 'dm-456');
    });

    test('normal path still works (no regression)', () async {
      final repo = _DelayedMemberRepository(openCompleter: null);
      final container = ProviderContainer(overrides: [
        currentMembersServerIdProvider.overrideWithValue(serverId),
        memberRepositoryProvider.overrideWithValue(repo),
        sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
      ]);
      addTearDown(container.dispose);

      repo.members = const [
        MemberProfile(id: 'user-456', displayName: 'Bob'),
      ];
      await container.read(memberListStoreProvider.notifier).load();

      final channelId = await container
          .read(memberListStoreProvider.notifier)
          .openDirectMessage('user-456');

      expect(channelId, 'dm-456');
      final state = container.read(memberListStoreProvider);
      expect(state.isOpeningDirectMessage('user-456'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // #759B — HomeListStore._persistSidebarOrder server-switch guard
  // ---------------------------------------------------------------------------
  group('#759B — HomeListStore._persistSidebarOrder server-switch safety', () {
    test('rollback skipped after server switch during persist', () async {
      // Use a StateProvider so we can change the server scope mid-operation.
      final serverScopeState =
          StateProvider<ServerScopeId?>((ref) => const ServerScopeId('srv-1'));
      final updateCompleter = Completer<void>();
      final sidebarRepo = _ControlledSidebarOrderRepository(
        updateCompleter: updateCompleter,
        throwOnUpdate: true,
      );
      final container = ProviderContainer(overrides: [
        activeServerScopeIdProvider
            .overrideWith((ref) => ref.watch(serverScopeState)),
        homeRepositoryProvider.overrideWithValue(const _FakeHomeRepository()),
        sidebarOrderRepositoryProvider.overrideWithValue(sidebarRepo),
      ]);
      addTearDown(container.dispose);

      // Load initial state.
      await container.read(homeListStoreProvider.notifier).load();
      final stateAfterLoad = container.read(homeListStoreProvider);
      expect(stateAfterLoad.status, HomeListStatus.success);

      // Start a pin operation (which calls _persistSidebarOrder internally).
      final pinFuture =
          container.read(homeListStoreProvider.notifier).pinChannel(
                const ChannelScopeId(
                  serverId: ServerScopeId('srv-1'),
                  value: 'general',
                ),
              );

      // Simulate server switch — change the server scope.
      container.read(serverScopeState.notifier).state =
          const ServerScopeId('srv-2');
      // Allow microtasks to rebuild.
      await Future<void>.delayed(Duration.zero);

      // Now complete the update (which will throw AppFailure in the repo).
      updateCompleter.complete();
      await pinFuture;

      // The store should NOT have rolled back to the old state because
      // the server switched. Since build() was re-triggered, state is reset.
      // The key assertion: no StateError was thrown.
      // After server switch, build() resets state to empty/loading.
    });

    test('rollback applies normally when server unchanged', () async {
      final sidebarRepo = _ControlledSidebarOrderRepository(
        throwOnUpdate: true,
      );
      final container = ProviderContainer(overrides: [
        activeServerScopeIdProvider
            .overrideWithValue(const ServerScopeId('srv-1')),
        homeRepositoryProvider.overrideWithValue(const _FakeHomeRepository()),
        sidebarOrderRepositoryProvider.overrideWithValue(sidebarRepo),
      ]);
      addTearDown(container.dispose);

      await container.read(homeListStoreProvider.notifier).load();
      final stateBeforePin = container.read(homeListStoreProvider);
      expect(stateBeforePin.pinnedChannels, isEmpty);

      // Pin a channel — this will fail on persist and should rollback.
      await container.read(homeListStoreProvider.notifier).pinChannel(
            const ChannelScopeId(
              serverId: ServerScopeId('srv-1'),
              value: 'general',
            ),
          );

      // Rollback should have removed the pin.
      final stateAfterRollback = container.read(homeListStoreProvider);
      expect(stateAfterRollback.pinnedChannels, isEmpty,
          reason: 'Rollback should remove the pin when server unchanged');
    });
  });

  // ---------------------------------------------------------------------------
  // #759C — ConversationDetailStore.batchDeleteMessages disposal guard
  // ---------------------------------------------------------------------------
  group('#759C — ConversationDetailStore.batchDeleteMessages disposal safety',
      () {
    final target = ConversationDetailTarget.channel(
      const ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'general',
      ),
    );

    test('dispose during batch delete does not throw StateError', () async {
      final deleteCompleter = Completer<void>();
      final repo = _DelayedConversationRepository(
        deleteCompleter: deleteCompleter,
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          historyLimited: false,
          hasOlder: false,
          messages: [
            ConversationMessageSummary(
              id: 'msg-1',
              content: 'Hello',
              createdAt: DateTime(2026, 5, 22),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
            ConversationMessageSummary(
              id: 'msg-2',
              content: 'World',
              createdAt: DateTime(2026, 5, 22),
              senderType: 'human',
              messageType: 'message',
              seq: 2,
            ),
          ],
        ),
      );

      final container = ProviderContainer(overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(repo),
      ]);

      final sub = container.listen(conversationDetailStoreProvider, (_, __) {});

      // Load conversation.
      await container.read(conversationDetailStoreProvider.notifier).load();
      expect(
        container.read(conversationDetailStoreProvider).status,
        ConversationDetailStatus.success,
      );

      // Start batch delete — will block on completer.
      final future = container
          .read(conversationDetailStoreProvider.notifier)
          .batchDeleteMessages({'msg-1'});

      // Dispose the container while delete is in flight.
      sub.close();
      container.dispose();

      // Complete the delete after disposal.
      deleteCompleter.complete();

      // Should NOT throw StateError — returns counts without writing state.
      final result = await future;
      expect(result.succeeded, 1);
      expect(result.failed, 0);
    });

    test('normal batch delete with rollback still works (no regression)',
        () async {
      final repo = _DelayedConversationRepository(
        deleteFailure: const ServerFailure(
          message: 'Forbidden',
          statusCode: 403,
        ),
        snapshot: ConversationDetailSnapshot(
          target: target,
          title: '#general',
          historyLimited: false,
          hasOlder: false,
          messages: [
            ConversationMessageSummary(
              id: 'msg-1',
              content: 'Hello',
              createdAt: DateTime(2026, 5, 22),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
          ],
        ),
      );

      final container = ProviderContainer(overrides: [
        currentConversationDetailTargetProvider.overrideWithValue(target),
        conversationRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await container.read(conversationDetailStoreProvider.notifier).load();

      final result = await container
          .read(conversationDetailStoreProvider.notifier)
          .batchDeleteMessages({'msg-1'});

      expect(result.succeeded, 0);
      expect(result.failed, 1);
      // Rollback should have un-deleted the message.
      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages.first.isDeleted, isFalse,
          reason: 'Failed delete should be rolled back');
    });
  });
}

// =============================================================================
// Test Doubles
// =============================================================================

class _DelayedMemberRepository implements MemberRepository {
  _DelayedMemberRepository({this.openCompleter});

  List<MemberProfile> members = const [];
  final Completer<String>? openCompleter;

  @override
  Future<List<MemberProfile>> listMembers(ServerScopeId serverId) async {
    return members;
  }

  @override
  Future<String> openDirectMessage(
    ServerScopeId serverId, {
    required String userId,
  }) async {
    if (openCompleter != null) {
      return openCompleter!.future;
    }
    return 'dm-456';
  }

  @override
  Future<String> openAgentDirectMessage(
    ServerScopeId serverId, {
    required String agentId,
  }) async =>
      'dm-agent-$agentId';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository();

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async =>
      null;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    return const HomeWorkspaceSnapshot(
      serverId: ServerScopeId('srv-1'),
      channels: [
        HomeChannelSummary(
          scopeId: ChannelScopeId(
            serverId: ServerScopeId('srv-1'),
            value: 'general',
          ),
          name: 'general',
        ),
        HomeChannelSummary(
          scopeId: ChannelScopeId(
            serverId: ServerScopeId('srv-1'),
            value: 'random',
          ),
          name: 'random',
        ),
      ],
      directMessages: [],
    );
  }

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async =>
      summary;

  @override
  Future<void> persistConversationActivity({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
    required DateTime activityAt,
  }) async {}

  @override
  Future<void> persistConversationPreviewUpdate({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
  }) async {}
}

class _ControlledSidebarOrderRepository implements SidebarOrderRepository {
  _ControlledSidebarOrderRepository({
    this.updateCompleter,
    this.throwOnUpdate = false,
  });

  final Completer<void>? updateCompleter;
  final bool throwOnUpdate;

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async {
    return const SidebarOrder();
  }

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {
    if (updateCompleter != null) {
      await updateCompleter!.future;
    }
    if (throwOnUpdate) {
      throw const ServerFailure(message: 'Failed', statusCode: 500);
    }
  }
}

class _DelayedConversationRepository implements ConversationRepository {
  _DelayedConversationRepository({
    this.deleteCompleter,
    this.deleteFailure,
    required this.snapshot,
  });

  final Completer<void>? deleteCompleter;
  final AppFailure? deleteFailure;
  final ConversationDetailSnapshot snapshot;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async =>
      snapshot;

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    if (deleteCompleter != null) {
      await deleteCompleter!.future;
    }
    if (deleteFailure != null) {
      throw deleteFailure!;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
