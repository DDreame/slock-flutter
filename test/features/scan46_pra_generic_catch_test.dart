// =============================================================================
// Scan #46 PR A — Load-bearing tests for systemic generic catch + rollback.
//
// Each test throws a non-AppFailure (FormatException) from the repository layer
// and verifies that:
//   1. The mutation does NOT crash (no unhandled exception propagates).
//   2. The optimistic state is rolled back correctly.
//
// Removing any `catch (_)` block from the production code causes the
// corresponding test to FAIL (go RED):
//   - For non-rethrowing mutations: FormatException propagates → unhandled → RED.
//   - For rethrowing mutations: rollback doesn't execute → state assertion → RED.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
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
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/conversation_unread_repository.dart';
import 'package:slock_app/features/inbox/data/conversation_unread_repository_provider.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_store.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';
import 'package:slock_app/features/tasks/data/tasks_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/data/thread_repository.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  // ===========================================================================
  // HomeListStore
  // ===========================================================================

  group('HomeListStore generic catch', () {
    // -------------------------------------------------------------------------
    // T1: load() — non-AppFailure sets failure state (not stuck in loading)
    // -------------------------------------------------------------------------
    test(
      'PRA-T1: HomeListStore.load() catches non-AppFailure, sets failure',
      () async {
        final homeRepo = _ThrowingHomeRepo();
        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            homeRepositoryProvider.overrideWithValue(homeRepo),
            homeWorkspaceSnapshotLoaderProvider.overrideWithValue(
              (serverId) => homeRepo.loadWorkspace(serverId),
            ),
            sidebarOrderRepositoryProvider.overrideWithValue(
              _NoOpSidebarOrderRepo(),
            ),
            homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
            tasksRepositoryProvider.overrideWithValue(_NoOpTasksRepo()),
            agentsRepositoryProvider.overrideWithValue(_NoOpAgentsRepo()),
            threadRepositoryProvider.overrideWithValue(_NoOpThreadRepo()),
          ],
        );
        final sub = container.listen(homeListStoreProvider, (_, __) {});
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        // Wait for auto-load to succeed.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(homeListStoreProvider).status,
          HomeListStatus.success,
        );

        // Now make repo throw FormatException on next load.
        homeRepo.shouldThrow = true;
        await container.read(homeListStoreProvider.notifier).load();

        final state = container.read(homeListStoreProvider);
        expect(
          state.status,
          HomeListStatus.failure,
          reason: 'PRA-T1: non-AppFailure in load() must set failure status. '
              'Removing catch (error) leaves status stuck in loading → RED.',
        );
        expect(state.failure, isNotNull);
      },
    );

    // -------------------------------------------------------------------------
    // T2: refresh() — non-AppFailure clears isRefreshing + sets failure
    // -------------------------------------------------------------------------
    test(
      'PRA-T2: HomeListStore.refresh() catches non-AppFailure, clears isRefreshing',
      () async {
        final homeRepo = _ThrowingHomeRepo();
        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            homeRepositoryProvider.overrideWithValue(homeRepo),
            homeWorkspaceSnapshotLoaderProvider.overrideWithValue(
              (serverId) => homeRepo.loadWorkspace(serverId),
            ),
            sidebarOrderRepositoryProvider.overrideWithValue(
              _NoOpSidebarOrderRepo(),
            ),
            homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
            tasksRepositoryProvider.overrideWithValue(_NoOpTasksRepo()),
            agentsRepositoryProvider.overrideWithValue(_NoOpAgentsRepo()),
            threadRepositoryProvider.overrideWithValue(_NoOpThreadRepo()),
          ],
        );
        final sub = container.listen(homeListStoreProvider, (_, __) {});
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        // Wait for auto-load to succeed.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(homeListStoreProvider).status,
          HomeListStatus.success,
        );

        // Now make repo throw FormatException on next refresh.
        homeRepo.shouldThrow = true;
        await container.read(homeListStoreProvider.notifier).refresh();

        final state = container.read(homeListStoreProvider);
        expect(
          state.isRefreshing,
          isFalse,
          reason:
              'PRA-T2: non-AppFailure in refresh() must clear isRefreshing. '
              'Removing catch (error) leaves isRefreshing stuck true → RED.',
        );
        expect(state.failure, isNotNull);
      },
    );

    // -------------------------------------------------------------------------
    // T3: _persistSidebarOrder — non-AppFailure rolls back sidebar order
    // -------------------------------------------------------------------------
    test(
      'PRA-T3: HomeListStore sidebar persist catches non-AppFailure, rolls back',
      () async {
        final homeRepo = _ThrowingHomeRepo(
          snapshot: HomeWorkspaceSnapshot(
            serverId: const ServerScopeId('s1'),
            channels: [
              HomeChannelSummary(
                scopeId: const ChannelScopeId(
                  serverId: ServerScopeId('s1'),
                  value: 'ch-a',
                ),
                name: 'alpha',
                lastActivityAt: DateTime.utc(2026, 5, 20),
              ),
              HomeChannelSummary(
                scopeId: const ChannelScopeId(
                  serverId: ServerScopeId('s1'),
                  value: 'ch-b',
                ),
                name: 'beta',
                lastActivityAt: DateTime.utc(2026, 5, 19),
              ),
            ],
            directMessages: const [],
          ),
        );
        final sidebarRepo = _ThrowingSidebarOrderRepo();
        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            homeRepositoryProvider.overrideWithValue(homeRepo),
            homeWorkspaceSnapshotLoaderProvider.overrideWithValue(
              (serverId) => homeRepo.loadWorkspace(serverId),
            ),
            sidebarOrderRepositoryProvider.overrideWithValue(sidebarRepo),
            homeMachineCountLoaderProvider.overrideWithValue((_) async => 0),
            tasksRepositoryProvider.overrideWithValue(_NoOpTasksRepo()),
            agentsRepositoryProvider.overrideWithValue(_NoOpAgentsRepo()),
            threadRepositoryProvider.overrideWithValue(_NoOpThreadRepo()),
          ],
        );
        final sub = container.listen(homeListStoreProvider, (_, __) {});
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        // Wait for auto-load.
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(
          container.read(homeListStoreProvider).status,
          HomeListStatus.success,
        );

        // Make sidebar persist throw FormatException.
        sidebarRepo.shouldThrow = true;

        // Move channel — triggers _persistSidebarOrder internally.
        await container.read(homeListStoreProvider.notifier).moveChannel(
              const ChannelScopeId(
                serverId: ServerScopeId('s1'),
                value: 'ch-b',
              ),
              moveUp: true,
            );

        // The sidebar order should be rolled back (ch-a still first).
        final state = container.read(homeListStoreProvider);
        final channelIds = state.channels.map((c) => c.scopeId.value).toList();
        expect(
          channelIds,
          ['ch-a', 'ch-b'],
          reason: 'PRA-T3: non-AppFailure in _persistSidebarOrder must roll '
              'back the sidebar order. Removing catch (_) lets the exception '
              'propagate without rollback → order stays swapped → RED.',
        );
      },
    );
  });

  // ===========================================================================
  // InboxStore
  // ===========================================================================

  group('InboxStore generic catch', () {
    // -------------------------------------------------------------------------
    // T4: markRead — non-AppFailure triggers rollback
    // -------------------------------------------------------------------------
    test(
      'PRA-T4: InboxStore.markRead() catches non-AppFailure, rolls back',
      () async {
        final inboxRepo = _ThrowingInboxRepo(
          items: const [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              channelName: 'general',
              unreadCount: 5,
            ),
          ],
        );
        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            inboxRepositoryProvider.overrideWithValue(inboxRepo),
            conversationUnreadRepositoryProvider
                .overrideWithValue(_NoOpUnreadRepo()),
          ],
        );
        final sub = container.listen(inboxStoreProvider, (_, __) {});
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        await container.read(inboxStoreProvider.notifier).load();
        expect(
          container.read(inboxStoreProvider).items[0].unreadCount,
          5,
        );

        // Make markItemRead throw FormatException.
        inboxRepo.throwOnMarkRead = true;
        await container
            .read(inboxStoreProvider.notifier)
            .markRead(channelId: 'ch-1');

        final state = container.read(inboxStoreProvider);
        expect(
          state.items.any((i) => i.channelId == 'ch-1' && i.unreadCount == 5),
          isTrue,
          reason: 'PRA-T4: non-AppFailure in markRead must roll back unread '
              'count. Removing catch (_) leaves it as 0 → RED.',
        );
      },
    );

    // -------------------------------------------------------------------------
    // T5: markAsUnread — non-AppFailure triggers rollback
    // -------------------------------------------------------------------------
    test(
      'PRA-T5: InboxStore.markAsUnread() catches non-AppFailure, rolls back',
      () async {
        final inboxRepo = _ThrowingInboxRepo(
          items: const [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              channelName: 'general',
              unreadCount: 0,
            ),
          ],
        );
        final unreadRepo = _ThrowingUnreadRepo();
        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            inboxRepositoryProvider.overrideWithValue(inboxRepo),
            conversationUnreadRepositoryProvider.overrideWithValue(unreadRepo),
          ],
        );
        final sub = container.listen(inboxStoreProvider, (_, __) {});
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        await container.read(inboxStoreProvider.notifier).load();
        expect(
          container.read(inboxStoreProvider).items[0].unreadCount,
          0,
        );

        // Make markAsUnread throw FormatException.
        unreadRepo.shouldThrow = true;
        await container
            .read(inboxStoreProvider.notifier)
            .markAsUnread(channelId: 'ch-1');

        final state = container.read(inboxStoreProvider);
        expect(
          state.items[0].unreadCount,
          0,
          reason: 'PRA-T5: non-AppFailure in markAsUnread must roll back. '
              'Removing catch (_) leaves unreadCount as 1 → RED.',
        );
      },
    );

    // -------------------------------------------------------------------------
    // T6: markDone — non-AppFailure triggers rollback (re-insert)
    // -------------------------------------------------------------------------
    test(
      'PRA-T6: InboxStore.markDone() catches non-AppFailure, rolls back',
      () async {
        final inboxRepo = _ThrowingInboxRepo(
          items: const [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              channelName: 'general',
              unreadCount: 3,
            ),
          ],
        );
        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            inboxRepositoryProvider.overrideWithValue(inboxRepo),
            conversationUnreadRepositoryProvider
                .overrideWithValue(_NoOpUnreadRepo()),
          ],
        );
        final sub = container.listen(inboxStoreProvider, (_, __) {});
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        await container.read(inboxStoreProvider.notifier).load();
        expect(container.read(inboxStoreProvider).items, hasLength(1));

        // Make markItemDone throw FormatException.
        inboxRepo.throwOnMarkDone = true;
        await container
            .read(inboxStoreProvider.notifier)
            .markDone(channelId: 'ch-1');

        final state = container.read(inboxStoreProvider);
        expect(
          state.items,
          hasLength(1),
          reason: 'PRA-T6: non-AppFailure in markDone must re-insert the '
              'removed item. Removing catch (_) leaves items empty → RED.',
        );
        expect(state.items[0].channelId, 'ch-1');
      },
    );

    // -------------------------------------------------------------------------
    // T7: markAllRead — non-AppFailure triggers rollback
    // -------------------------------------------------------------------------
    test(
      'PRA-T7: InboxStore.markAllRead() catches non-AppFailure, rolls back',
      () async {
        final inboxRepo = _ThrowingInboxRepo(
          items: const [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              channelName: 'general',
              unreadCount: 5,
            ),
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-1',
              channelName: 'Alice',
              unreadCount: 3,
            ),
          ],
        );
        final container = ProviderContainer(
          overrides: [
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            inboxRepositoryProvider.overrideWithValue(inboxRepo),
            conversationUnreadRepositoryProvider
                .overrideWithValue(_NoOpUnreadRepo()),
          ],
        );
        final sub = container.listen(inboxStoreProvider, (_, __) {});
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        await container.read(inboxStoreProvider.notifier).load();
        expect(container.read(inboxStoreProvider).totalUnreadCount, 8);

        // Make markAllRead throw FormatException.
        inboxRepo.throwOnMarkAllRead = true;
        await container.read(inboxStoreProvider.notifier).markAllRead();

        final state = container.read(inboxStoreProvider);
        expect(
          state.totalUnreadCount,
          8,
          reason: 'PRA-T7: non-AppFailure in markAllRead must roll back all '
              'unread counts. Removing catch (_) leaves totalUnread=0 → RED.',
        );
      },
    );
  });

  // ===========================================================================
  // ConversationDetailStore
  // ===========================================================================

  group('ConversationDetailStore generic catch', () {
    final target = ConversationDetailTarget.channel(
      const ChannelScopeId(
        serverId: ServerScopeId('s1'),
        value: 'general',
      ),
    );

    ConversationMessageSummary msg(String id, int seq, {String content = ''}) =>
        ConversationMessageSummary(
          id: id,
          content: content.isEmpty ? 'msg-$seq' : content,
          createdAt: DateTime.utc(2026, 5, 20),
          senderType: 'human',
          messageType: 'message',
          seq: seq,
        );

    // -------------------------------------------------------------------------
    // T8: toggleSaveMessage — non-AppFailure rolls back savedMessageIds
    // -------------------------------------------------------------------------
    test(
      'PRA-T8: toggleSaveMessage catches non-AppFailure, rolls back',
      () async {
        final repo = _ThrowingConversationRepo(
          snapshot: ConversationDetailSnapshot(
            target: target,
            title: '#general',
            messages: [msg('m1', 1)],
            historyLimited: false,
            hasOlder: false,
          ),
        );
        final savedRepo = _ThrowingSavedMessagesRepo();
        final container = ProviderContainer(
          overrides: [
            currentConversationDetailTargetProvider.overrideWithValue(target),
            conversationRepositoryProvider.overrideWithValue(repo),
            savedMessagesRepositoryProvider.overrideWithValue(savedRepo),
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          ],
        );
        final sub = container.listen(
          conversationDetailStoreProvider,
          (_, __) {},
        );
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        await container.read(conversationDetailStoreProvider.notifier).load();
        expect(
          container.read(conversationDetailStoreProvider).savedMessageIds,
          isEmpty,
        );

        // Make saveMessage throw FormatException.
        savedRepo.throwOnSave = true;
        await container
            .read(conversationDetailStoreProvider.notifier)
            .toggleSaveMessage('m1');

        expect(
          container.read(conversationDetailStoreProvider).savedMessageIds,
          isEmpty,
          reason: 'PRA-T8: non-AppFailure in toggleSaveMessage must roll back '
              'savedMessageIds. Removing catch (_) leaves m1 in the set → RED.',
        );
      },
    );

    // -------------------------------------------------------------------------
    // T9: editMessage — non-AppFailure rolls back content
    // -------------------------------------------------------------------------
    test(
      'PRA-T9: editMessage catches non-AppFailure, rolls back content',
      () async {
        final repo = _ThrowingConversationRepo(
          snapshot: ConversationDetailSnapshot(
            target: target,
            title: '#general',
            messages: [msg('m1', 1, content: 'original')],
            historyLimited: false,
            hasOlder: false,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            currentConversationDetailTargetProvider.overrideWithValue(target),
            conversationRepositoryProvider.overrideWithValue(repo),
            savedMessagesRepositoryProvider
                .overrideWithValue(_NoOpSavedMessagesRepo()),
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          ],
        );
        final sub = container.listen(
          conversationDetailStoreProvider,
          (_, __) {},
        );
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        await container.read(conversationDetailStoreProvider.notifier).load();
        await Future<void>.value(); // Drain refreshSavedMessageIds microtask.

        // Make editMessage throw FormatException.
        repo.throwOnEdit = true;
        await expectLater(
          () => container
              .read(conversationDetailStoreProvider.notifier)
              .editMessage('m1', 'edited'),
          throwsA(isA<FormatException>()),
        );

        final state = container.read(conversationDetailStoreProvider);
        expect(
          state.messages[0].content,
          'original',
          reason: 'PRA-T9: non-AppFailure in editMessage must roll back '
              'content. Removing catch (_) skips rollback → content stays '
              '"edited" → RED.',
        );
      },
    );

    // -------------------------------------------------------------------------
    // T10: deleteMessage — non-AppFailure rolls back isDeleted
    // -------------------------------------------------------------------------
    test(
      'PRA-T10: deleteMessage catches non-AppFailure, rolls back isDeleted',
      () async {
        final repo = _ThrowingConversationRepo(
          snapshot: ConversationDetailSnapshot(
            target: target,
            title: '#general',
            messages: [msg('m1', 1)],
            historyLimited: false,
            hasOlder: false,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            currentConversationDetailTargetProvider.overrideWithValue(target),
            conversationRepositoryProvider.overrideWithValue(repo),
            savedMessagesRepositoryProvider
                .overrideWithValue(_NoOpSavedMessagesRepo()),
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          ],
        );
        final sub = container.listen(
          conversationDetailStoreProvider,
          (_, __) {},
        );
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        await container.read(conversationDetailStoreProvider.notifier).load();
        await Future<void>.value();

        // Make deleteMessage throw FormatException.
        repo.throwOnDelete = true;
        await expectLater(
          () => container
              .read(conversationDetailStoreProvider.notifier)
              .deleteMessage('m1'),
          throwsA(isA<FormatException>()),
        );

        final state = container.read(conversationDetailStoreProvider);
        expect(
          state.messages[0].isDeleted,
          isFalse,
          reason: 'PRA-T10: non-AppFailure in deleteMessage must roll back '
              'isDeleted. Removing catch (_) skips rollback → isDeleted stays '
              'true → RED.',
        );
      },
    );

    // -------------------------------------------------------------------------
    // T11: pinMessage — non-AppFailure rolls back isPinned
    // -------------------------------------------------------------------------
    test(
      'PRA-T11: pinMessage catches non-AppFailure, rolls back isPinned',
      () async {
        final repo = _ThrowingConversationRepo(
          snapshot: ConversationDetailSnapshot(
            target: target,
            title: '#general',
            messages: [msg('m1', 1)],
            historyLimited: false,
            hasOlder: false,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            currentConversationDetailTargetProvider.overrideWithValue(target),
            conversationRepositoryProvider.overrideWithValue(repo),
            savedMessagesRepositoryProvider
                .overrideWithValue(_NoOpSavedMessagesRepo()),
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          ],
        );
        final sub = container.listen(
          conversationDetailStoreProvider,
          (_, __) {},
        );
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        await container.read(conversationDetailStoreProvider.notifier).load();
        await Future<void>.value();

        // Make pinMessage throw FormatException.
        repo.throwOnPin = true;
        await expectLater(
          () => container
              .read(conversationDetailStoreProvider.notifier)
              .pinMessage('m1'),
          throwsA(isA<FormatException>()),
        );

        final state = container.read(conversationDetailStoreProvider);
        expect(
          state.messages[0].isPinned,
          isFalse,
          reason: 'PRA-T11: non-AppFailure in pinMessage must roll back '
              'isPinned. Removing catch (_) skips rollback → isPinned stays '
              'true → RED.',
        );
      },
    );

    // -------------------------------------------------------------------------
    // T12: unpinMessage — non-AppFailure rolls back isPinned
    // -------------------------------------------------------------------------
    test(
      'PRA-T12: unpinMessage catches non-AppFailure, rolls back isPinned',
      () async {
        final repo = _ThrowingConversationRepo(
          snapshot: ConversationDetailSnapshot(
            target: target,
            title: '#general',
            messages: [
              ConversationMessageSummary(
                id: 'm1',
                content: 'pinned-msg',
                createdAt: DateTime.utc(2026, 5, 20),
                senderType: 'human',
                messageType: 'message',
                seq: 1,
                isPinned: true,
              ),
            ],
            historyLimited: false,
            hasOlder: false,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            currentConversationDetailTargetProvider.overrideWithValue(target),
            conversationRepositoryProvider.overrideWithValue(repo),
            savedMessagesRepositoryProvider
                .overrideWithValue(_NoOpSavedMessagesRepo()),
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          ],
        );
        final sub = container.listen(
          conversationDetailStoreProvider,
          (_, __) {},
        );
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        await container.read(conversationDetailStoreProvider.notifier).load();
        await Future<void>.value();
        expect(
          container.read(conversationDetailStoreProvider).messages[0].isPinned,
          isTrue,
        );

        // Make unpinMessage throw FormatException.
        repo.throwOnUnpin = true;
        await expectLater(
          () => container
              .read(conversationDetailStoreProvider.notifier)
              .unpinMessage('m1'),
          throwsA(isA<FormatException>()),
        );

        final state = container.read(conversationDetailStoreProvider);
        expect(
          state.messages[0].isPinned,
          isTrue,
          reason: 'PRA-T12: non-AppFailure in unpinMessage must roll back '
              'isPinned to true. Removing catch (_) skips rollback → isPinned '
              'stays false → RED.',
        );
      },
    );

    // -------------------------------------------------------------------------
    // T13: addReaction — non-AppFailure rolls back reaction
    // -------------------------------------------------------------------------
    test(
      'PRA-T13: addReaction catches non-AppFailure, rolls back reaction',
      () async {
        final repo = _ThrowingConversationRepo(
          snapshot: ConversationDetailSnapshot(
            target: target,
            title: '#general',
            messages: [msg('m1', 1)],
            historyLimited: false,
            hasOlder: false,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            currentConversationDetailTargetProvider.overrideWithValue(target),
            conversationRepositoryProvider.overrideWithValue(repo),
            savedMessagesRepositoryProvider
                .overrideWithValue(_NoOpSavedMessagesRepo()),
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          ],
        );
        final sub = container.listen(
          conversationDetailStoreProvider,
          (_, __) {},
        );
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        await container.read(conversationDetailStoreProvider.notifier).load();
        await Future<void>.value();

        // Make addReaction throw FormatException.
        repo.throwOnAddReaction = true;
        await expectLater(
          () => container
              .read(conversationDetailStoreProvider.notifier)
              .addReaction('m1', '👍'),
          throwsA(isA<FormatException>()),
        );

        final state = container.read(conversationDetailStoreProvider);
        expect(
          state.messages[0].reactions,
          isEmpty,
          reason: 'PRA-T13: non-AppFailure in addReaction must roll back the '
              'reaction. Removing catch (_) skips rollback → reaction stays '
              'added → RED.',
        );
      },
    );

    // -------------------------------------------------------------------------
    // T14: removeReaction — non-AppFailure rolls back reaction
    // -------------------------------------------------------------------------
    test(
      'PRA-T14: removeReaction catches non-AppFailure, rolls back reaction',
      () async {
        final repo = _ThrowingConversationRepo(
          snapshot: ConversationDetailSnapshot(
            target: target,
            title: '#general',
            messages: [
              ConversationMessageSummary(
                id: 'm1',
                content: 'msg-1',
                createdAt: DateTime.utc(2026, 5, 20),
                senderType: 'human',
                messageType: 'message',
                seq: 1,
                reactions: const [
                  MessageReaction(
                    emoji: '👍',
                    count: 1,
                    userIds: ['user-1'],
                  ),
                ],
              ),
            ],
            historyLimited: false,
            hasOlder: false,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            currentConversationDetailTargetProvider.overrideWithValue(target),
            conversationRepositoryProvider.overrideWithValue(repo),
            savedMessagesRepositoryProvider
                .overrideWithValue(_NoOpSavedMessagesRepo()),
            activeServerScopeIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          ],
        );
        final sub = container.listen(
          conversationDetailStoreProvider,
          (_, __) {},
        );
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        await container.read(conversationDetailStoreProvider.notifier).load();
        await Future<void>.value();
        expect(
          container.read(conversationDetailStoreProvider).messages[0].reactions,
          hasLength(1),
        );

        // Make removeReaction throw FormatException.
        repo.throwOnRemoveReaction = true;
        await expectLater(
          () => container
              .read(conversationDetailStoreProvider.notifier)
              .removeReaction('m1', '👍'),
          throwsA(isA<FormatException>()),
        );

        final state = container.read(conversationDetailStoreProvider);
        expect(
          state.messages[0].reactions,
          hasLength(1),
          reason: 'PRA-T14: non-AppFailure in removeReaction must roll back. '
              'Removing catch (_) skips rollback → reactions becomes empty → '
              'RED.',
        );
        expect(state.messages[0].reactions[0].emoji, '👍');
      },
    );
  });

  // ===========================================================================
  // SavedMessagesStore
  // ===========================================================================

  group('SavedMessagesStore generic catch', () {
    // -------------------------------------------------------------------------
    // T15: unsaveMessage — non-AppFailure re-inserts removed item
    // -------------------------------------------------------------------------
    test(
      'PRA-T15: unsaveMessage catches non-AppFailure, re-inserts item',
      () async {
        final savedRepo = _ThrowingSavedMessagesRepo();
        savedRepo.pageResult = SavedMessagesPage(
          items: [
            SavedMessageItem(
              message: ConversationMessageSummary(
                id: 'msg-1',
                content: 'saved content',
                createdAt: DateTime.utc(2026, 5, 20),
                senderType: 'human',
                messageType: 'message',
                seq: 1,
              ),
              channelId: 'ch-1',
            ),
          ],
          hasMore: false,
        );
        final container = ProviderContainer(
          overrides: [
            currentSavedMessagesServerIdProvider
                .overrideWithValue(const ServerScopeId('s1')),
            savedMessagesRepositoryProvider.overrideWithValue(savedRepo),
          ],
        );
        final sub = container.listen(
          savedMessagesStoreProvider,
          (_, __) {},
        );
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        await container.read(savedMessagesStoreProvider.notifier).load();
        expect(
          container.read(savedMessagesStoreProvider).items,
          hasLength(1),
        );

        // Make unsaveMessage throw FormatException.
        savedRepo.throwOnUnsave = true;
        await container
            .read(savedMessagesStoreProvider.notifier)
            .unsaveMessage('msg-1');

        final state = container.read(savedMessagesStoreProvider);
        expect(
          state.items,
          hasLength(1),
          reason: 'PRA-T15: non-AppFailure in unsaveMessage must re-insert '
              'the removed item. Removing catch (_) leaves items empty → RED.',
        );
        expect(state.items[0].message.id, 'msg-1');
      },
    );
  });
}

// =============================================================================
// Fakes — HomeListStore
// =============================================================================

class _ThrowingHomeRepo implements HomeRepository {
  _ThrowingHomeRepo({HomeWorkspaceSnapshot? snapshot})
      : _snapshot = snapshot ??
            const HomeWorkspaceSnapshot(
              serverId: ServerScopeId('s1'),
              channels: [],
              directMessages: [],
            );

  final HomeWorkspaceSnapshot _snapshot;
  bool shouldThrow = false;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    if (shouldThrow) throw const FormatException('simulated non-AppFailure');
    return _snapshot;
  }

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async =>
      null;

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
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _ThrowingSidebarOrderRepo implements SidebarOrderRepository {
  bool shouldThrow = false;

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async =>
      const SidebarOrder();

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {
    if (shouldThrow) throw const FormatException('simulated non-AppFailure');
  }
}

class _NoOpSidebarOrderRepo implements SidebarOrderRepository {
  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async =>
      const SidebarOrder();

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {}
}

class _NoOpTasksRepo implements TasksRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoOpAgentsRepo implements AgentsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoOpThreadRepo implements ThreadRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// =============================================================================
// Fakes — InboxStore
// =============================================================================

class _ThrowingInboxRepo implements InboxRepository {
  _ThrowingInboxRepo({List<InboxItem> items = const []}) : _items = items;

  final List<InboxItem> _items;
  bool throwOnMarkRead = false;
  bool throwOnMarkDone = false;
  bool throwOnMarkAllRead = false;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async =>
      InboxResponse(
        items: _items,
        totalCount: _items.length,
        totalUnreadCount: _items.fold(0, (sum, i) => sum + i.unreadCount),
        hasMore: false,
      );

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    if (throwOnMarkRead) {
      throw const FormatException('simulated non-AppFailure');
    }
  }

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    if (throwOnMarkDone) {
      throw const FormatException('simulated non-AppFailure');
    }
  }

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {
    if (throwOnMarkAllRead) {
      throw const FormatException('simulated non-AppFailure');
    }
  }
}

class _ThrowingUnreadRepo implements ConversationUnreadRepository {
  bool shouldThrow = false;

  @override
  Future<void> markAsUnread(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    if (shouldThrow) throw const FormatException('simulated non-AppFailure');
  }
}

class _NoOpUnreadRepo implements ConversationUnreadRepository {
  @override
  Future<void> markAsUnread(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}
}

// =============================================================================
// Fakes — ConversationDetailStore
// =============================================================================

class _ThrowingConversationRepo implements ConversationRepository {
  _ThrowingConversationRepo({required this.snapshot});

  final ConversationDetailSnapshot snapshot;
  bool throwOnEdit = false;
  bool throwOnDelete = false;
  bool throwOnPin = false;
  bool throwOnUnpin = false;
  bool throwOnAddReaction = false;
  bool throwOnRemoveReaction = false;

  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async =>
      snapshot;

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
        hasNewer: false,
      );

  @override
  Future<void> editMessage(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {
    if (throwOnEdit) throw const FormatException('simulated non-AppFailure');
  }

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    if (throwOnDelete) throw const FormatException('simulated non-AppFailure');
  }

  @override
  Future<void> pinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    if (throwOnPin) throw const FormatException('simulated non-AppFailure');
  }

  @override
  Future<void> unpinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    if (throwOnUnpin) throw const FormatException('simulated non-AppFailure');
  }

  @override
  Future<void> addReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {
    if (throwOnAddReaction) {
      throw const FormatException('simulated non-AppFailure');
    }
  }

  @override
  Future<void> removeReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {
    if (throwOnRemoveReaction) {
      throw const FormatException('simulated non-AppFailure');
    }
  }

  @override
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NoOpSavedMessagesRepo implements SavedMessagesRepository {
  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) async =>
      const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _ThrowingSavedMessagesRepo implements SavedMessagesRepository {
  bool throwOnSave = false;
  bool throwOnUnsave = false;
  SavedMessagesPage? pageResult;

  @override
  Future<SavedMessagesPage> listSavedMessages(
    ServerScopeId serverId, {
    int limit = 50,
    int offset = 0,
  }) async =>
      pageResult ?? const SavedMessagesPage(items: [], hasMore: false);

  @override
  Future<void> saveMessage(ServerScopeId serverId, String messageId) async {
    if (throwOnSave) throw const FormatException('simulated non-AppFailure');
  }

  @override
  Future<void> unsaveMessage(ServerScopeId serverId, String messageId) async {
    if (throwOnUnsave) throw const FormatException('simulated non-AppFailure');
  }

  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) async =>
      const {};
}

// =============================================================================
// Fakes — Session
// =============================================================================

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-1',
        displayName: 'Test User',
        token: 'fake-token',
      );
}
