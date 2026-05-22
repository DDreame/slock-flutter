import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/conversation_unread_repository.dart';
import 'package:slock_app/features/inbox/data/conversation_unread_repository_provider.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';

import '../../../support/support.dart';

// ---------------------------------------------------------------------------
// Migration: mock-call → state-based assertions (#478)
//
// Original file used 2 local fakes:
//   FakeInboxRepository        → replaced with shared FakeInboxRepository
//                                 from test/support/fakes/
//   _ControllableInboxRepository → kept local (Completer-based timing)
//
// createContainer() → RuntimeAppFixture + boot() + manual inbox load
//
// Tests that cannot use RuntimeAppFixture keep direct ProviderContainer
// with explicit justification:
//   - "no active server" → RuntimeAppFixture.boot() always selects a server
//   - "isRefreshing mid-flight" → needs _ControllableInboxRepository
//
// Three standalone path-only tests merged into companion state tests.
// All repo.lastFetchFilter, repo.lastFetchOffset, repo.fetchCallCount,
// repo.lastMarkReadChannelId, repo.lastMarkDoneChannelId, and
// repo.markAllReadCalled assertions replaced with InboxState assertions.
// ---------------------------------------------------------------------------

void main() {
  group('InboxStore.load', () {
    test('fetches first page and updates state to success', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedInbox([
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-1',
          channelName: 'general',
          unreadCount: 5,
        ),
        const InboxItem(
          kind: InboxItemKind.dm,
          channelId: 'dm-1',
          channelName: 'Bob',
          unreadCount: 2,
        ),
      ]);

      await fixture.boot();
      try {
        await fixture.container.read(inboxStoreProvider.notifier).load();

        final state = fixture.container.read(inboxStoreProvider);
        expect(state.status, InboxStatus.success);
        expect(state.items, hasLength(2));
        expect(state.totalCount, 2);
        expect(state.totalUnreadCount, 7);
        expect(state.hasMore, isFalse);
        expect(state.offset, 2);
      } finally {
        await fixture.dispose();
      }
    });

    test('sets status to loading then success', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedInbox([]);

      await fixture.boot();
      try {
        final states = <InboxStatus>[];
        fixture.container.listen(
          inboxStoreProvider.select((s) => s.status),
          (_, next) => states.add(next),
        );

        await fixture.container.read(inboxStoreProvider.notifier).load();

        expect(states, [InboxStatus.loading, InboxStatus.success]);
      } finally {
        await fixture.dispose();
      }
    });

    test('sets status to failure on AppFailure', () async {
      final fixture = RuntimeAppFixture();
      fixture.inboxRepository.fetchFailure =
          const NetworkFailure(message: 'offline');

      await fixture.boot();
      try {
        await fixture.container.read(inboxStoreProvider.notifier).load();

        final state = fixture.container.read(inboxStoreProvider);
        expect(state.status, InboxStatus.failure);
        expect(state.failure, isA<NetworkFailure>());
      } finally {
        await fixture.dispose();
      }
    });

    test('load with filter updates InboxState.filter', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedInbox([]);

      await fixture.boot();
      try {
        await fixture.container
            .read(inboxStoreProvider.notifier)
            .load(filter: InboxFilter.unread);

        final state = fixture.container.read(inboxStoreProvider);
        expect(state.filter, InboxFilter.unread);
      } finally {
        await fixture.dispose();
      }
    });

    // Direct ProviderContainer: RuntimeAppFixture.boot() always selects
    // a server, making it impossible to test the no-active-server path.
    // fetchCallCount retained: with an empty default response, state alone
    // cannot distinguish "fetched empty" from "never fetched."
    test('returns empty success when no active server', () async {
      final repo = FakeInboxRepository();
      final container = ProviderContainer(
        overrides: [
          inboxRepositoryProvider.overrideWithValue(repo),
          activeServerScopeIdProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      await container.read(inboxStoreProvider.notifier).load();

      final state = container.read(inboxStoreProvider);
      expect(state.status, InboxStatus.success);
      expect(state.items, isEmpty);
      // No fetch should have been made — state-only can't distinguish
      // "fetched empty" from "skipped fetch" with default empty response.
      expect(repo.fetchCallCount, 0);
    });
  });

  group('InboxStore.loadMore', () {
    test('appends next page items', () async {
      final fixture = RuntimeAppFixture();
      fixture.inboxRepository.fetchResponse = const InboxResponse(
        items: [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-1',
            unreadCount: 3,
          ),
        ],
        totalCount: 2,
        totalUnreadCount: 5,
        hasMore: true,
      );

      await fixture.boot();
      try {
        await fixture.container.read(inboxStoreProvider.notifier).load();
        expect(
          fixture.container.read(inboxStoreProvider).items,
          hasLength(1),
        );

        // Prepare second page response.
        fixture.inboxRepository.fetchResponse = const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-1',
              unreadCount: 2,
            ),
          ],
          totalCount: 2,
          totalUnreadCount: 5,
          hasMore: false,
        );

        await fixture.container.read(inboxStoreProvider.notifier).loadMore();

        final state = fixture.container.read(inboxStoreProvider);
        expect(state.items, hasLength(2));
        expect(state.items[0].channelId, 'ch-1');
        expect(state.items[1].channelId, 'dm-1');
        expect(state.hasMore, isFalse);
        expect(state.offset, 2);
      } finally {
        await fixture.dispose();
      }
    });

    test('deduplicates concurrent loadMore calls for same offset (#712)',
        () async {
      final repo = _ControllableInboxRepository();
      repo.nextResponse = const InboxResponse(
        items: [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-1',
            unreadCount: 1,
          ),
        ],
        totalCount: 2,
        totalUnreadCount: 2,
        hasMore: true,
      );
      final container = ProviderContainer(
        overrides: [
          inboxRepositoryProvider.overrideWithValue(repo),
          activeServerScopeIdProvider
              .overrideWithValue(const ServerScopeId('server-1')),
        ],
      );
      addTearDown(container.dispose);

      await container.read(inboxStoreProvider.notifier).load();
      expect(repo.fetchCallCount, 1);

      repo.fetchCompleter = Completer<InboxResponse>();
      final first = container.read(inboxStoreProvider.notifier).loadMore();
      final second = container.read(inboxStoreProvider.notifier).loadMore();
      await Future<void>.delayed(Duration.zero);

      expect(repo.fetchCallCount, 2);

      repo.fetchCompleter!.complete(
        const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-1',
              unreadCount: 1,
            ),
          ],
          totalCount: 2,
          totalUnreadCount: 2,
          hasMore: false,
        ),
      );
      await Future.wait([first, second]);

      final state = container.read(inboxStoreProvider);
      expect(state.items.map((item) => item.channelId), ['ch-1', 'dm-1']);
      expect(
          state.items.where((item) => item.channelId == 'dm-1'), hasLength(1));
      expect(state.offset, 2);
    });

    test('does nothing when hasMore is false', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedInbox([
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-1',
          unreadCount: 1,
        ),
      ]);

      await fixture.boot();
      try {
        await fixture.container.read(inboxStoreProvider.notifier).load();
        final stateBefore = fixture.container.read(inboxStoreProvider);

        await fixture.container.read(inboxStoreProvider.notifier).loadMore();

        final stateAfter = fixture.container.read(inboxStoreProvider);
        expect(stateAfter.items, hasLength(stateBefore.items.length));
        expect(stateAfter.offset, stateBefore.offset);
      } finally {
        await fixture.dispose();
      }
    });

    test('loadMore appends correct page after first page', () async {
      final fixture = RuntimeAppFixture();
      fixture.inboxRepository.fetchResponse = const InboxResponse(
        items: [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-1',
            unreadCount: 1,
          ),
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-2',
            unreadCount: 1,
          ),
        ],
        totalCount: 4,
        totalUnreadCount: 4,
        hasMore: true,
      );

      await fixture.boot();
      try {
        await fixture.container.read(inboxStoreProvider.notifier).load();
        expect(fixture.container.read(inboxStoreProvider).offset, 2);

        fixture.inboxRepository.fetchResponse = const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-3',
              unreadCount: 1,
            ),
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-4',
              unreadCount: 1,
            ),
          ],
          totalCount: 4,
          totalUnreadCount: 4,
          hasMore: false,
        );

        await fixture.container.read(inboxStoreProvider.notifier).loadMore();

        final state = fixture.container.read(inboxStoreProvider);
        // All 4 items present = both pages loaded correctly.
        expect(state.items, hasLength(4));
        expect(state.items.map((i) => i.channelId).toList(),
            ['ch-1', 'ch-2', 'ch-3', 'ch-4']);
        expect(state.offset, 4);
      } finally {
        await fixture.dispose();
      }
    });
  });

  group('InboxStore.setFilter', () {
    test('reloads with new filter and resets state', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedInbox([
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-1',
          unreadCount: 5,
        ),
      ]);

      await fixture.boot();
      try {
        await fixture.container.read(inboxStoreProvider.notifier).load();
        expect(
          fixture.container.read(inboxStoreProvider).filter,
          InboxFilter.all,
        );

        // Change response for filtered reload.
        fixture.inboxRepository.fetchResponse = const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              unreadCount: 5,
            ),
          ],
          totalCount: 1,
          totalUnreadCount: 5,
          hasMore: false,
        );

        await fixture.container
            .read(inboxStoreProvider.notifier)
            .setFilter(InboxFilter.unread);

        final state = fixture.container.read(inboxStoreProvider);
        expect(state.filter, InboxFilter.unread);
        expect(state.status, InboxStatus.success);
        // Offset resets on filter change (fresh first page).
        expect(state.offset, 1);
      } finally {
        await fixture.dispose();
      }
    });
  });

  // Before: "optimistically zeros unreadCount" and "calls repository
  //         markItemRead" were separate tests. Merged — path assertion
  //         replaced with state-only verification.
  group('InboxStore.markRead', () {
    test('optimistically zeros unreadCount for target item', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedInbox([
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-1',
          channelName: 'general',
          unreadCount: 5,
        ),
        const InboxItem(
          kind: InboxItemKind.dm,
          channelId: 'dm-1',
          channelName: 'Bob',
          unreadCount: 2,
        ),
      ]);

      await fixture.boot();
      try {
        await fixture.container.read(inboxStoreProvider.notifier).load();
        await fixture.container
            .read(inboxStoreProvider.notifier)
            .markRead(channelId: 'ch-1');

        final state = fixture.container.read(inboxStoreProvider);
        final ch1 = state.items.firstWhere((i) => i.channelId == 'ch-1');
        expect(ch1.unreadCount, 0);
        expect(state.totalUnreadCount, 2); // 7 - 5
      } finally {
        await fixture.dispose();
      }
    });

    test('retains DM item in dms filter after markRead (#712)', () async {
      final fixture = RuntimeAppFixture();
      fixture.inboxRepository.fetchResponse = const InboxResponse(
        items: [
          InboxItem(
            kind: InboxItemKind.dm,
            channelId: 'dm-1',
            channelName: 'Bob',
            unreadCount: 2,
          ),
        ],
        totalCount: 1,
        totalUnreadCount: 2,
        hasMore: false,
      );

      await fixture.boot();
      try {
        await fixture.container
            .read(inboxStoreProvider.notifier)
            .load(filter: InboxFilter.dms);

        await fixture.container
            .read(inboxStoreProvider.notifier)
            .markRead(channelId: 'dm-1');

        final state = fixture.container.read(inboxStoreProvider);
        expect(state.filter, InboxFilter.dms);
        expect(state.items.map((item) => item.channelId), ['dm-1']);
        expect(state.items.single.unreadCount, 0);
        expect(state.totalCount, 1);
        expect(state.offset, 1);
      } finally {
        await fixture.dispose();
      }
    });
  });

  group('InboxStore.markAsUnread', () {
    test('sets existing read item unread and calls API', () async {
      final inboxRepository = FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              channelName: 'general',
              unreadCount: 0,
            ),
          ],
          totalCount: 1,
          totalUnreadCount: 0,
          hasMore: false,
        ),
      );
      final unreadRepository = _FakeConversationUnreadRepository();
      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(
            const ServerScopeId('server-1'),
          ),
          inboxRepositoryProvider.overrideWithValue(inboxRepository),
          conversationUnreadRepositoryProvider
              .overrideWithValue(unreadRepository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(inboxStoreProvider.notifier).load();
      await container
          .read(inboxStoreProvider.notifier)
          .markAsUnread(channelId: 'ch-1');

      final state = container.read(inboxStoreProvider);
      expect(unreadRepository.requests, [
        (const ServerScopeId('server-1'), 'ch-1'),
      ]);
      expect(state.items.single.unreadCount, 1);
      expect(state.totalUnreadCount, 1);
    });

    test('rolls back optimistic unread state when API fails', () async {
      final inboxRepository = FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              channelName: 'general',
              unreadCount: 0,
            ),
          ],
          totalCount: 1,
          totalUnreadCount: 0,
          hasMore: false,
        ),
      );
      final unreadRepository = _FakeConversationUnreadRepository(
        failure: const NetworkFailure(message: 'offline'),
      );
      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(
            const ServerScopeId('server-1'),
          ),
          inboxRepositoryProvider.overrideWithValue(inboxRepository),
          conversationUnreadRepositoryProvider
              .overrideWithValue(unreadRepository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(inboxStoreProvider.notifier).load();
      await expectLater(
        container
            .read(inboxStoreProvider.notifier)
            .markAsUnread(channelId: 'ch-1'),
        throwsA(isA<NetworkFailure>()),
      );

      final state = container.read(inboxStoreProvider);
      expect(state.items.single.unreadCount, 0);
      expect(state.totalUnreadCount, 0);
    });

    test('preserves cached item metadata when re-inserting unread item',
        () async {
      final originalItem = InboxItem(
        kind: InboxItemKind.thread,
        channelId: 'thread-1',
        threadChannelId: 'thread-1',
        parentChannelId: 'parent-1',
        parentMessageId: 'parent-msg-1',
        channelName: 'general',
        threadTitle: 'Release checklist',
        senderName: 'Alice',
        senderId: 'user-alice',
        preview: 'Looks good',
        latestActivityPreview: 'Alice: Looks good',
        unreadCount: 0,
        firstUnreadMessageId: 'msg-1',
        lastActivityAt: DateTime.parse('2026-05-22T04:00:00Z'),
        messageType: 'message',
        isMentioned: true,
      );
      final inboxRepository = FakeInboxRepository(
        fetchResponse: InboxResponse(
          items: [originalItem],
          totalCount: 1,
          totalUnreadCount: 0,
          hasMore: false,
        ),
      );
      final unreadRepository = _FakeConversationUnreadRepository();
      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider.overrideWithValue(
            const ServerScopeId('server-1'),
          ),
          inboxRepositoryProvider.overrideWithValue(inboxRepository),
          conversationUnreadRepositoryProvider
              .overrideWithValue(unreadRepository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(inboxStoreProvider.notifier).load();
      inboxRepository.fetchResponse = const InboxResponse(
        items: [],
        totalCount: 0,
        totalUnreadCount: 0,
        hasMore: false,
      );
      await container
          .read(inboxStoreProvider.notifier)
          .setFilter(InboxFilter.unread);

      expect(container.read(inboxStoreProvider).items, isEmpty);

      await container
          .read(inboxStoreProvider.notifier)
          .markAsUnread(channelId: 'thread-1');

      final restored = container.read(inboxStoreProvider).items.single;
      expect(restored.kind, originalItem.kind);
      expect(restored.threadChannelId, originalItem.threadChannelId);
      expect(restored.parentChannelId, originalItem.parentChannelId);
      expect(restored.parentMessageId, originalItem.parentMessageId);
      expect(restored.channelName, originalItem.channelName);
      expect(restored.threadTitle, originalItem.threadTitle);
      expect(restored.senderName, originalItem.senderName);
      expect(restored.senderId, originalItem.senderId);
      expect(restored.preview, originalItem.preview);
      expect(
          restored.latestActivityPreview, originalItem.latestActivityPreview);
      expect(restored.firstUnreadMessageId, originalItem.firstUnreadMessageId);
      expect(restored.lastActivityAt, originalItem.lastActivityAt);
      expect(restored.messageType, originalItem.messageType);
      expect(restored.isMentioned, originalItem.isMentioned);
      expect(restored.unreadCount, 1);
    });
  });

  // Before: "optimistically removes item" and "calls repository markItemDone"
  //         were separate tests. Merged — path assertion replaced.
  group('InboxStore.markDone', () {
    test('optimistically removes item from list', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedInbox([
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-1',
          unreadCount: 5,
        ),
        const InboxItem(
          kind: InboxItemKind.dm,
          channelId: 'dm-1',
          unreadCount: 2,
        ),
      ]);

      await fixture.boot();
      try {
        await fixture.container.read(inboxStoreProvider.notifier).load();
        await fixture.container
            .read(inboxStoreProvider.notifier)
            .markDone(channelId: 'ch-1');

        final state = fixture.container.read(inboxStoreProvider);
        expect(state.items, hasLength(1));
        expect(state.items.first.channelId, 'dm-1');
        expect(state.totalCount, 1);
        expect(state.totalUnreadCount, 2); // 7 - 5
      } finally {
        await fixture.dispose();
      }
    });

    test('restores removed item at original position when API fails', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedInbox([
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-1',
          channelName: 'general',
          unreadCount: 5,
        ),
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-2',
          channelName: 'random',
          unreadCount: 3,
        ),
        const InboxItem(
          kind: InboxItemKind.dm,
          channelId: 'dm-1',
          channelName: 'Bob',
          unreadCount: 2,
        ),
      ]);
      fixture.inboxRepository.markDoneFailure =
          const NetworkFailure(message: 'mark done failed');

      await fixture.boot();
      try {
        await fixture.container.read(inboxStoreProvider.notifier).load();

        await fixture.container
            .read(inboxStoreProvider.notifier)
            .markDone(channelId: 'ch-2');

        final state = fixture.container.read(inboxStoreProvider);
        expect(
          state.items.map((item) => item.channelId),
          ['ch-1', 'ch-2', 'dm-1'],
        );
        expect(state.totalCount, 3);
        expect(state.totalUnreadCount, 10);
        expect(state.offset, 3);
      } finally {
        await fixture.dispose();
      }
    });
  });

  // Before: "optimistically zeros all unread counts" and "calls repository
  //         markAllRead" were separate tests. Merged — path assertion replaced.
  group('InboxStore.markAllRead', () {
    test('optimistically zeros all unread counts', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedInbox([
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-1',
          unreadCount: 5,
        ),
        const InboxItem(
          kind: InboxItemKind.dm,
          channelId: 'dm-1',
          unreadCount: 2,
        ),
      ]);

      await fixture.boot();
      try {
        await fixture.container.read(inboxStoreProvider.notifier).load();
        await fixture.container.read(inboxStoreProvider.notifier).markAllRead();

        final state = fixture.container.read(inboxStoreProvider);
        expect(state.totalUnreadCount, 0);
        for (final item in state.items) {
          expect(item.unreadCount, 0);
        }
      } finally {
        await fixture.dispose();
      }
    });

    test('retains DM items in dms filter after markAllRead (#712)', () async {
      final fixture = RuntimeAppFixture();
      fixture.inboxRepository.fetchResponse = const InboxResponse(
        items: [
          InboxItem(
            kind: InboxItemKind.dm,
            channelId: 'dm-1',
            unreadCount: 2,
          ),
          InboxItem(
            kind: InboxItemKind.dm,
            channelId: 'dm-2',
            unreadCount: 1,
          ),
        ],
        totalCount: 2,
        totalUnreadCount: 3,
        hasMore: false,
      );

      await fixture.boot();
      try {
        await fixture.container
            .read(inboxStoreProvider.notifier)
            .load(filter: InboxFilter.dms);
        await fixture.container.read(inboxStoreProvider.notifier).markAllRead();

        final state = fixture.container.read(inboxStoreProvider);
        expect(state.items.map((item) => item.channelId), ['dm-1', 'dm-2']);
        expect(state.items.every((item) => item.unreadCount == 0), isTrue);
        expect(state.totalCount, 2);
        expect(state.offset, 2);
      } finally {
        await fixture.dispose();
      }
    });
  });

  group('pagination cursor after optimistic removal', () {
    test('markDone decrements offset so loadMore fetches correct page',
        () async {
      final fixture = RuntimeAppFixture();
      fixture.inboxRepository.fetchResponse = const InboxResponse(
        items: [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-1',
            unreadCount: 2,
          ),
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-2',
            unreadCount: 1,
          ),
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-3',
            unreadCount: 3,
          ),
        ],
        totalCount: 5,
        totalUnreadCount: 6,
        hasMore: true,
      );

      await fixture.boot();
      try {
        await fixture.container.read(inboxStoreProvider.notifier).load();
        expect(fixture.container.read(inboxStoreProvider).offset, 3);

        // Remove ch-2 via markDone — offset should drop to 2.
        await fixture.container
            .read(inboxStoreProvider.notifier)
            .markDone(channelId: 'ch-2');
        expect(fixture.container.read(inboxStoreProvider).offset, 2);
        expect(
          fixture.container.read(inboxStoreProvider).items,
          hasLength(2),
        );

        // Next loadMore should use the updated offset.
        fixture.inboxRepository.fetchResponse = const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-4',
              unreadCount: 1,
            ),
          ],
          totalCount: 4,
          totalUnreadCount: 4,
          hasMore: false,
        );

        await fixture.container.read(inboxStoreProvider.notifier).loadMore();

        final state = fixture.container.read(inboxStoreProvider);
        expect(state.items, hasLength(3));
        expect(state.items.map((i) => i.channelId).toList(),
            ['ch-1', 'ch-3', 'ch-4']);
      } finally {
        await fixture.dispose();
      }
    });

    test('markRead in unread filter decrements offset so loadMore is correct',
        () async {
      final fixture = RuntimeAppFixture();
      fixture.inboxRepository.fetchResponse = const InboxResponse(
        items: [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-1',
            unreadCount: 5,
          ),
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-2',
            unreadCount: 3,
          ),
        ],
        totalCount: 4,
        totalUnreadCount: 8,
        hasMore: true,
      );

      await fixture.boot();
      try {
        // Load in unread filter mode.
        await fixture.container
            .read(inboxStoreProvider.notifier)
            .load(filter: InboxFilter.unread);
        expect(fixture.container.read(inboxStoreProvider).offset, 2);

        // Mark ch-1 read — in unread mode it gets removed.
        await fixture.container
            .read(inboxStoreProvider.notifier)
            .markRead(channelId: 'ch-1');
        expect(fixture.container.read(inboxStoreProvider).offset, 1);
        expect(
          fixture.container.read(inboxStoreProvider).items,
          hasLength(1),
        );

        // loadMore should use the decremented offset.
        fixture.inboxRepository.fetchResponse = const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-3',
              unreadCount: 2,
            ),
          ],
          totalCount: 3,
          totalUnreadCount: 5,
          hasMore: false,
        );

        await fixture.container.read(inboxStoreProvider.notifier).loadMore();

        final state = fixture.container.read(inboxStoreProvider);
        expect(state.items, hasLength(2));
        expect(state.items.map((i) => i.channelId).toList(), ['ch-2', 'ch-3']);
      } finally {
        await fixture.dispose();
      }
    });

    test('markAllRead in unread filter resets offset to 0', () async {
      final fixture = RuntimeAppFixture();
      fixture.inboxRepository.fetchResponse = const InboxResponse(
        items: [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-1',
            unreadCount: 2,
          ),
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-2',
            unreadCount: 4,
          ),
        ],
        totalCount: 4,
        totalUnreadCount: 6,
        hasMore: true,
      );

      await fixture.boot();
      try {
        await fixture.container
            .read(inboxStoreProvider.notifier)
            .load(filter: InboxFilter.unread);
        expect(fixture.container.read(inboxStoreProvider).offset, 2);

        // Mark all read — in unread mode removes all items.
        await fixture.container.read(inboxStoreProvider.notifier).markAllRead();

        final state = fixture.container.read(inboxStoreProvider);
        expect(state.offset, 0);
        expect(state.items, isEmpty);
        expect(state.totalCount, 2);
      } finally {
        await fixture.dispose();
      }
    });
  });

  group('InboxStore.refresh', () {
    test('reloads first page preserving current filter', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedInbox([
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-1',
          unreadCount: 5,
        ),
      ]);

      await fixture.boot();
      try {
        // Set filter to unread first.
        await fixture.container
            .read(inboxStoreProvider.notifier)
            .load(filter: InboxFilter.unread);

        // Change response so refresh produces observable state change.
        fixture.inboxRepository.fetchResponse = const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              unreadCount: 3,
            ),
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-1',
              unreadCount: 1,
            ),
          ],
          totalCount: 2,
          totalUnreadCount: 4,
          hasMore: false,
        );

        await fixture.container.read(inboxStoreProvider.notifier).refresh();

        final state = fixture.container.read(inboxStoreProvider);
        // Filter preserved.
        expect(state.filter, InboxFilter.unread);
        // Fresh data loaded (proves a fetch happened with reset offset).
        expect(state.items, hasLength(2));
        expect(state.totalUnreadCount, 4);
        expect(state.offset, 2);
      } finally {
        await fixture.dispose();
      }
    });
  });

  group('InboxState.visibleUnreadCount', () {
    test('counts items with unreadCount > 0', () {
      const state = InboxState(
        status: InboxStatus.success,
        items: [
          InboxItem(
              kind: InboxItemKind.channel, channelId: 'ch-1', unreadCount: 5),
          InboxItem(
              kind: InboxItemKind.channel, channelId: 'ch-2', unreadCount: 0),
          InboxItem(kind: InboxItemKind.dm, channelId: 'dm-1', unreadCount: 2),
        ],
      );

      expect(state.visibleUnreadCount, 2);
    });
  });

  group('InboxStore SWR (stale-while-revalidate)', () {
    test('refresh preserves existing items while loading', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedInbox([
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-1',
          channelName: 'general',
          unreadCount: 5,
        ),
      ]);

      await fixture.boot();
      try {
        final store = fixture.container.read(inboxStoreProvider.notifier);
        await store.load();
        expect(
          fixture.container.read(inboxStoreProvider).items,
          hasLength(1),
        );

        // Update response for refresh.
        fixture.inboxRepository.fetchResponse = const InboxResponse(
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-1',
              channelName: 'general',
              unreadCount: 3,
            ),
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-1',
              channelName: 'Bob',
              unreadCount: 1,
            ),
          ],
          totalCount: 2,
          totalUnreadCount: 4,
          hasMore: false,
        );

        await store.refresh();

        final state = fixture.container.read(inboxStoreProvider);
        expect(state.status, InboxStatus.success);
        expect(state.isRefreshing, isFalse);
        expect(state.items, hasLength(2));
        expect(state.totalUnreadCount, 4);
      } finally {
        await fixture.dispose();
      }
    });

    test('refresh keeps existing items on failure', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedInbox([
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-1',
          channelName: 'general',
          unreadCount: 5,
        ),
      ]);

      await fixture.boot();
      try {
        final store = fixture.container.read(inboxStoreProvider.notifier);
        await store.load();

        // Make next fetch fail.
        fixture.inboxRepository.failNext = true;

        await store.refresh();

        final state = fixture.container.read(inboxStoreProvider);
        // Items preserved from initial load.
        expect(state.items, hasLength(1));
        expect(state.isRefreshing, isFalse);
        expect(state.failure, isNotNull);
      } finally {
        await fixture.dispose();
      }
    });

    test('initial load with no prior data uses loading status', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedInbox([
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-1',
          channelName: 'general',
          unreadCount: 1,
        ),
      ]);

      await fixture.boot();
      try {
        await fixture.container.read(inboxStoreProvider.notifier).load();

        final state = fixture.container.read(inboxStoreProvider);
        expect(state.status, InboxStatus.success);
        expect(state.isRefreshing, isFalse);
      } finally {
        await fixture.dispose();
      }
    });

    // Direct ProviderContainer: needs _ControllableInboxRepository for
    // Completer-based timing control to observe mid-flight SWR state.
    // RuntimeAppFixture always uses FakeInboxRepository (instant responses).
    test('isRefreshing is true mid-flight during SWR refresh', () async {
      final completerRepo = _ControllableInboxRepository();
      final container = ProviderContainer(
        overrides: [
          inboxRepositoryProvider.overrideWithValue(completerRepo),
          activeServerScopeIdProvider
              .overrideWithValue(const ServerScopeId('server-1')),
        ],
      );
      addTearDown(container.dispose);

      // Initial load completes immediately.
      completerRepo.nextResponse = const InboxResponse(
        items: [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-1',
            channelName: 'general',
            unreadCount: 5,
          ),
        ],
        totalCount: 1,
        totalUnreadCount: 5,
        hasMore: false,
      );
      await container.read(inboxStoreProvider.notifier).load();
      expect(container.read(inboxStoreProvider).status, InboxStatus.success);
      expect(container.read(inboxStoreProvider).isRefreshing, isFalse);

      // Start refresh with a blocked completer.
      final refreshCompleter = Completer<InboxResponse>();
      completerRepo.fetchCompleter = refreshCompleter;

      final refreshFuture =
          container.read(inboxStoreProvider.notifier).refresh();

      // Mid-flight: isRefreshing must be true while existing data is visible.
      final midState = container.read(inboxStoreProvider);
      expect(midState.isRefreshing, isTrue,
          reason: 'isRefreshing must be true during SWR refresh');
      expect(midState.status, isNot(InboxStatus.loading),
          reason: 'SWR must not clear status to loading');
      expect(midState.items, hasLength(1),
          reason: 'Existing items must remain visible during refresh');

      // Complete refresh.
      refreshCompleter.complete(const InboxResponse(
        items: [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-1',
            channelName: 'general',
            unreadCount: 3,
          ),
          InboxItem(
            kind: InboxItemKind.dm,
            channelId: 'dm-1',
            channelName: 'Bob',
            unreadCount: 1,
          ),
        ],
        totalCount: 2,
        totalUnreadCount: 4,
        hasMore: false,
      ));
      await refreshFuture;

      final postState = container.read(inboxStoreProvider);
      expect(postState.isRefreshing, isFalse,
          reason: 'isRefreshing must be false after refresh completes');
      expect(postState.items, hasLength(2),
          reason: 'Items should update to fresh data');
      expect(postState.totalUnreadCount, 4);
    });
  });
}

class _FakeConversationUnreadRepository
    implements ConversationUnreadRepository {
  _FakeConversationUnreadRepository({this.failure});

  final AppFailure? failure;
  final List<(ServerScopeId, String)> requests = [];

  @override
  Future<void> markAsUnread(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    requests.add((serverId, channelId));
    final failure = this.failure;
    if (failure != null) throw failure;
  }
}

// ---------------------------------------------------------------------------
// Local test fake
//
// Kept local because it provides Completer-based timing control for
// testing mid-flight SWR state. The shared FakeInboxRepository does
// not support async response blocking.
// ---------------------------------------------------------------------------

/// Inbox repository with controllable fetch timing.
class _ControllableInboxRepository implements InboxRepository {
  InboxResponse? nextResponse;
  Completer<InboxResponse>? fetchCompleter;
  int fetchCallCount = 0;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    fetchCallCount += 1;
    if (fetchCompleter != null) {
      return fetchCompleter!.future;
    }
    return nextResponse!;
  }

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {}

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {}
}
