import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/inbox/application/conversation_projection.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/unread/application/unread_source_projection.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';

/// Sentinel so `createContainer(server: null)` actually passes null
/// instead of falling through to the default serverId.
const _sentinel = ServerScopeId('__sentinel__');

void main() {
  const serverId = ServerScopeId('server-1');

  // Reusable channel / DM scope IDs.
  const channelGeneral = ChannelScopeId(
    serverId: serverId,
    value: 'ch-general',
  );
  const channelRandom = ChannelScopeId(
    serverId: serverId,
    value: 'ch-random',
  );
  const dmAlice = DirectMessageScopeId(
    serverId: serverId,
    value: 'dm-alice',
  );

  // ---------------------------------------------------------------
  // Helper: build a container with overridable state for each store.
  // ---------------------------------------------------------------
  ProviderContainer createContainer({
    InboxState? inboxState,
    HomeListState? homeState,
    ServerScopeId? server = _sentinel,
  }) {
    final effectiveServer = identical(server, _sentinel) ? serverId : server;
    final container = ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(effectiveServer),
        inboxStoreProvider.overrideWith(() => _FakeInboxStore(
              inboxState ?? const InboxState(),
            )),
        homeListStoreProvider.overrideWith(() => _FakeHomeListStore(
              homeState ?? HomeListState(),
            )),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('unreadSourceProjectionProvider', () {
    test('returns empty state when inbox is not yet loaded', () {
      final container = createContainer(
        inboxState: const InboxState(status: InboxStatus.initial),
      );

      final state = container.read(unreadSourceProjectionProvider);

      expect(state.isLoaded, false);
      expect(state.sources, isEmpty);
      expect(state.totalUnreadCount, 0);
    });

    test('returns empty state when serverId is null', () {
      final container = createContainer(
        server: null,
        inboxState: const InboxState(status: InboxStatus.success),
      );

      final state = container.read(unreadSourceProjectionProvider);

      expect(state.isLoaded, false);
      expect(state.sources, isEmpty);
    });

    test('projects channel inbox item as visible when in home list', () {
      final container = createContainer(
        inboxState: const InboxState(
          status: InboxStatus.success,
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-general',
              channelName: 'general',
              senderName: 'Alice',
              preview: 'Hello everyone',
              unreadCount: 5,
            ),
          ],
        ),
        homeState: HomeListState(
          status: HomeListStatus.success,
          channels: [
            const HomeChannelSummary(
              scopeId: channelGeneral,
              name: 'general',
            ),
          ],
        ),
      );

      final state = container.read(unreadSourceProjectionProvider);

      expect(state.isLoaded, true);
      expect(state.sources, hasLength(1));
      expect(state.sources.first.kind, ConversationProjectionKind.channel);
      expect(state.sources.first.title, 'general');
      expect(state.sources.first.previewText, 'Hello everyone');
      expect(state.sources.first.senderName, 'Alice');
      expect(state.sources.first.unreadCount, 5);
      expect(
        state.sources.first.visibility,
        UnreadSourceVisibility.visible,
      );
      expect(state.channelUnreadCount(channelGeneral), 5);
      expect(state.hasChannelUnread(channelGeneral), true);
    });

    test('projects channel as hidden when NOT in home list', () {
      final container = createContainer(
        inboxState: const InboxState(
          status: InboxStatus.success,
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-random',
              channelName: 'random',
              preview: 'Noise',
              unreadCount: 2,
            ),
          ],
        ),
        homeState: HomeListState(
          status: HomeListStatus.success,
          channels: [], // ch-random not listed
        ),
      );

      final state = container.read(unreadSourceProjectionProvider);

      expect(state.sources, hasLength(1));
      expect(
        state.sources.first.visibility,
        UnreadSourceVisibility.hidden,
      );
      expect(state.channelUnreadCount(channelRandom), 2);
    });

    test('projects DM inbox item as visible when in home list', () {
      final container = createContainer(
        inboxState: const InboxState(
          status: InboxStatus.success,
          items: [
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-alice',
              channelName: 'Alice',
              senderName: 'Alice',
              preview: 'Hey',
              unreadCount: 3,
            ),
          ],
        ),
        homeState: HomeListState(
          status: HomeListStatus.success,
          directMessages: [
            const HomeDirectMessageSummary(
              scopeId: dmAlice,
              title: 'Alice',
            ),
          ],
        ),
      );

      final state = container.read(unreadSourceProjectionProvider);

      expect(state.sources, hasLength(1));
      expect(state.sources.first.kind, ConversationProjectionKind.dm);
      expect(
        state.sources.first.visibility,
        UnreadSourceVisibility.visible,
      );
      expect(state.dmUnreadCount(dmAlice), 3);
      expect(state.hasDmUnread(dmAlice), true);
    });

    test('projects DM as hidden when NOT in home list', () {
      final container = createContainer(
        inboxState: const InboxState(
          status: InboxStatus.success,
          items: [
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-alice',
              channelName: 'Alice',
              preview: 'Hey',
              unreadCount: 1,
            ),
          ],
        ),
        homeState: HomeListState(
          status: HomeListStatus.success,
          directMessages: [],
        ),
      );

      final state = container.read(unreadSourceProjectionProvider);

      expect(
        state.sources.first.visibility,
        UnreadSourceVisibility.hidden,
      );
    });

    test('threads are hidden (no dedicated tab row)', () {
      final container = createContainer(
        inboxState: const InboxState(
          status: InboxStatus.success,
          items: [
            InboxItem(
              kind: InboxItemKind.thread,
              channelId: 'thread-ch-1',
              threadChannelId: 'thread-ch-1',
              channelName: 'general',
              threadTitle: 'Bug fix',
              senderName: 'Carol',
              preview: 'Fixed it',
              unreadCount: 4,
            ),
          ],
        ),
        homeState: HomeListState(
          status: HomeListStatus.success,
        ),
      );

      final state = container.read(unreadSourceProjectionProvider);

      expect(state.sources, hasLength(1));
      expect(state.sources.first.kind, ConversationProjectionKind.thread);
      expect(
        state.sources.first.visibility,
        UnreadSourceVisibility.hidden,
      );
    });

    test('skips items with unreadCount <= 0', () {
      final container = createContainer(
        inboxState: const InboxState(
          status: InboxStatus.success,
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-general',
              channelName: 'general',
              preview: 'Read',
              unreadCount: 0,
            ),
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-alice',
              channelName: 'Alice',
              preview: 'Hi',
              unreadCount: 3,
            ),
          ],
        ),
        homeState: HomeListState(
          status: HomeListStatus.success,
          directMessages: [
            const HomeDirectMessageSummary(
              scopeId: dmAlice,
              title: 'Alice',
            ),
          ],
        ),
      );

      final state = container.read(unreadSourceProjectionProvider);

      // Only dm-alice has unreads.
      expect(state.sources, hasLength(1));
      expect(state.sources.first.kind, ConversationProjectionKind.dm);
      expect(state.channelUnreadCount(channelGeneral), 0);
    });

    test('mixed sources produce correct per-id lookups and totals', () {
      final container = createContainer(
        inboxState: const InboxState(
          status: InboxStatus.success,
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-general',
              channelName: 'general',
              preview: 'A',
              unreadCount: 3,
            ),
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-random',
              channelName: 'random',
              preview: 'B',
              unreadCount: 2,
            ),
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-alice',
              channelName: 'Alice',
              preview: 'C',
              unreadCount: 4,
            ),
            InboxItem(
              kind: InboxItemKind.thread,
              channelId: 'thread-1',
              threadChannelId: 'thread-1',
              channelName: 'general',
              threadTitle: 'Thread 1',
              preview: 'D',
              unreadCount: 1,
            ),
          ],
        ),
        homeState: HomeListState(
          status: HomeListStatus.success,
          channels: [
            const HomeChannelSummary(
              scopeId: channelGeneral,
              name: 'general',
            ),
            // ch-random NOT in home list → hidden
          ],
          directMessages: [
            const HomeDirectMessageSummary(
              scopeId: dmAlice,
              title: 'Alice',
            ),
          ],
        ),
      );

      final state = container.read(unreadSourceProjectionProvider);

      expect(state.sources, hasLength(4));
      expect(state.channelUnreadCount(channelGeneral), 3);
      expect(state.channelUnreadCount(channelRandom), 2);
      expect(state.dmUnreadCount(dmAlice), 4);
      expect(state.channelUnreadTotal, 5); // 3 + 2
      expect(state.dmUnreadTotal, 4);
      expect(state.threadUnreadTotal, 1);
      expect(state.totalUnreadCount, 10); // 3 + 2 + 4 + 1

      // Visibility split.
      expect(state.visibleSources, hasLength(2)); // general, alice
      expect(state.hiddenSources, hasLength(2)); // random, thread
      expect(state.hiddenSources.first.title, 'random');
    });

    test('pinned channels count as visible', () {
      final container = createContainer(
        inboxState: const InboxState(
          status: InboxStatus.success,
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-general',
              channelName: 'general',
              preview: 'Pinned!',
              unreadCount: 7,
            ),
          ],
        ),
        homeState: HomeListState(
          status: HomeListStatus.success,
          pinnedChannels: [
            const HomeChannelSummary(
              scopeId: channelGeneral,
              name: 'general',
            ),
          ],
          channels: [], // not in non-pinned list
        ),
      );

      final state = container.read(unreadSourceProjectionProvider);

      expect(
        state.sources.first.visibility,
        UnreadSourceVisibility.visible,
      );
    });

    test('pinned DMs count as visible', () {
      final container = createContainer(
        inboxState: const InboxState(
          status: InboxStatus.success,
          items: [
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-alice',
              channelName: 'Alice',
              preview: 'Pinned DM',
              unreadCount: 2,
            ),
          ],
        ),
        homeState: HomeListState(
          status: HomeListStatus.success,
          pinnedDirectMessages: [
            const HomeDirectMessageSummary(
              scopeId: dmAlice,
              title: 'Alice',
            ),
          ],
          directMessages: [],
        ),
      );

      final state = container.read(unreadSourceProjectionProvider);

      expect(
        state.sources.first.visibility,
        UnreadSourceVisibility.visible,
      );
    });

    test('home not loaded yet → optimistically marks all visible', () {
      final container = createContainer(
        inboxState: const InboxState(
          status: InboxStatus.success,
          items: [
            InboxItem(
              kind: InboxItemKind.channel,
              channelId: 'ch-general',
              channelName: 'general',
              preview: 'Before home loads',
              unreadCount: 1,
            ),
            InboxItem(
              kind: InboxItemKind.dm,
              channelId: 'dm-alice',
              channelName: 'Alice',
              preview: 'Before home loads',
              unreadCount: 1,
            ),
          ],
        ),
        homeState: HomeListState(
          status: HomeListStatus.initial, // not loaded
        ),
      );

      final state = container.read(unreadSourceProjectionProvider);

      expect(state.isLoaded, true);
      for (final s in state.sources) {
        expect(s.visibility, UnreadSourceVisibility.visible);
      }
    });

    test('unknown kind projects as channel and uses channel lookup', () {
      final container = createContainer(
        inboxState: const InboxState(
          status: InboxStatus.success,
          items: [
            InboxItem(
              kind: InboxItemKind.unknown,
              channelId: 'ch-general',
              channelName: 'general',
              preview: 'Mystery',
              unreadCount: 2,
            ),
          ],
        ),
        homeState: HomeListState(
          status: HomeListStatus.success,
          channels: [
            const HomeChannelSummary(
              scopeId: channelGeneral,
              name: 'general',
            ),
          ],
        ),
      );

      final state = container.read(unreadSourceProjectionProvider);

      expect(state.sources.first.kind, ConversationProjectionKind.channel);
      expect(
        state.sources.first.visibility,
        UnreadSourceVisibility.visible,
      );
      expect(state.channelUnreadCount(channelGeneral), 2);
    });

    test('threads do NOT contribute to channel or DM lookup maps', () {
      final container = createContainer(
        inboxState: const InboxState(
          status: InboxStatus.success,
          items: [
            InboxItem(
              kind: InboxItemKind.thread,
              channelId: 'thread-ch-1',
              threadChannelId: 'thread-ch-1',
              channelName: 'general',
              preview: 'Reply',
              unreadCount: 3,
            ),
          ],
        ),
        homeState: HomeListState(
          status: HomeListStatus.success,
        ),
      );

      final state = container.read(unreadSourceProjectionProvider);

      expect(state.channelUnreadCounts, isEmpty);
      expect(state.dmUnreadCounts, isEmpty);
      expect(state.threadUnreadTotal, 3);
    });
  });
}

// ---------------------------------------------------------------------------
// Minimal fake stores for provider overrides.
// ---------------------------------------------------------------------------

/// Fake InboxStore that returns a fixed [InboxState] from [build].
class _FakeInboxStore extends InboxStore {
  _FakeInboxStore(this._initial);
  final InboxState _initial;

  @override
  InboxState build() => _initial;
}

/// Fake HomeListStore that returns a fixed [HomeListState] from [build].
class _FakeHomeListStore extends HomeListStore {
  _FakeHomeListStore(this._initial);
  final HomeListState _initial;

  @override
  HomeListState build() => _initial;
}
