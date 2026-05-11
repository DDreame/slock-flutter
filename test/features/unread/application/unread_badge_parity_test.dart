import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';

/// Regression tests for the algebraic invariant:
///   totalUnreadCount == sum(visibleSources) + sum(hiddenSources)
///   badge == sum(visibleSources.map(s => s.unreadCount))
///
/// These ensure the badge shown on tabs equals the sum of
/// the visible unread source rows the user can actually see.
void main() {
  const serverId = ServerScopeId('server-1');

  ProviderContainer createContainer({
    required List<InboxItem> inboxItems,
    required HomeListState homeState,
  }) {
    final container = ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(serverId),
        inboxStoreProvider.overrideWith(
          () => _FakeInboxStore(InboxState(
            status: InboxStatus.success,
            items: inboxItems,
          )),
        ),
        homeListStoreProvider.overrideWith(
          () => _FakeHomeListStore(homeState),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('badge-list parity invariant', () {
    test('totalUnreadCount == sum of visible + hidden source unread counts',
        () {
      final container = createContainer(
        inboxItems: const [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-general',
            channelName: 'general',
            unreadCount: 5,
          ),
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-hidden',
            channelName: 'hidden',
            unreadCount: 3,
          ),
          InboxItem(
            kind: InboxItemKind.dm,
            channelId: 'dm-alice',
            channelName: 'Alice',
            unreadCount: 2,
          ),
          InboxItem(
            kind: InboxItemKind.thread,
            channelId: 'thread-1',
            channelName: 'Thread',
            unreadCount: 1,
          ),
        ],
        homeState: const HomeListState(
          status: HomeListStatus.success,
          channels: [
            HomeChannelSummary(
              scopeId: ChannelScopeId(serverId: serverId, value: 'ch-general'),
              name: 'general',
            ),
          ],
          directMessages: [
            HomeDirectMessageSummary(
              scopeId: DirectMessageScopeId(
                serverId: serverId,
                value: 'dm-alice',
              ),
              title: 'Alice',
            ),
          ],
        ),
      );

      final state = container.read(unreadSourceProjectionProvider);

      // Algebraic invariant: total == visible + hidden
      final visibleSum =
          state.visibleSources.fold<int>(0, (sum, s) => sum + s.unreadCount);
      final hiddenSum =
          state.hiddenSources.fold<int>(0, (sum, s) => sum + s.unreadCount);
      expect(
        state.totalUnreadCount,
        visibleSum + hiddenSum,
        reason: 'totalUnreadCount must equal visible + hidden sums',
      );

      // Visible sources: ch-general (5) + dm-alice (2) = 7
      expect(visibleSum, 7);

      // Hidden sources: ch-hidden (3) + thread-1 (1) = 4
      expect(hiddenSum, 4);

      // Total = 11
      expect(state.totalUnreadCount, 11);

      // Verify sub-totals
      expect(state.channelUnreadTotal, 8); // 5 + 3
      expect(state.dmUnreadTotal, 2);
      expect(state.threadUnreadTotal, 1);
    });

    test('all visible channels: badge equals sum of all channel unreads', () {
      final container = createContainer(
        inboxItems: const [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-a',
            channelName: 'A',
            unreadCount: 10,
          ),
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-b',
            channelName: 'B',
            unreadCount: 20,
          ),
        ],
        homeState: const HomeListState(
          status: HomeListStatus.success,
          channels: [
            HomeChannelSummary(
              scopeId: ChannelScopeId(serverId: serverId, value: 'ch-a'),
              name: 'A',
            ),
            HomeChannelSummary(
              scopeId: ChannelScopeId(serverId: serverId, value: 'ch-b'),
              name: 'B',
            ),
          ],
        ),
      );

      final state = container.read(unreadSourceProjectionProvider);

      expect(state.visibleSources.length, 2);
      expect(state.hiddenSources, isEmpty);

      final visibleSum =
          state.visibleSources.fold<int>(0, (sum, s) => sum + s.unreadCount);
      expect(visibleSum, state.totalUnreadCount);
      expect(visibleSum, 30);
    });

    test('no visible sources: badge is zero but total is non-zero', () {
      final container = createContainer(
        inboxItems: const [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-hidden',
            channelName: 'hidden',
            unreadCount: 5,
          ),
          InboxItem(
            kind: InboxItemKind.thread,
            channelId: 'thread-1',
            channelName: 'Thread',
            unreadCount: 3,
          ),
        ],
        homeState: const HomeListState(
          status: HomeListStatus.success,
        ),
      );

      final state = container.read(unreadSourceProjectionProvider);

      final visibleSum =
          state.visibleSources.fold<int>(0, (sum, s) => sum + s.unreadCount);
      expect(visibleSum, 0, reason: 'No visible sources → badge is 0');
      expect(state.totalUnreadCount, 8);
      expect(state.hiddenSources.length, 2);
    });

    test('pinned channels contribute to visible badge', () {
      final container = createContainer(
        inboxItems: const [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-pinned',
            channelName: 'pinned',
            unreadCount: 7,
          ),
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-unpinned',
            channelName: 'unpinned',
            unreadCount: 3,
          ),
        ],
        homeState: const HomeListState(
          status: HomeListStatus.success,
          pinnedChannels: [
            HomeChannelSummary(
              scopeId: ChannelScopeId(serverId: serverId, value: 'ch-pinned'),
              name: 'pinned',
            ),
          ],
        ),
      );

      final state = container.read(unreadSourceProjectionProvider);

      expect(state.visibleSources.length, 1);
      expect(state.visibleSources.first.unreadCount, 7);

      final visibleSum =
          state.visibleSources.fold<int>(0, (sum, s) => sum + s.unreadCount);
      expect(visibleSum, 7);

      expect(state.hiddenSources.length, 1);
      expect(state.hiddenSources.first.unreadCount, 3);

      // Invariant holds
      expect(state.totalUnreadCount, visibleSum + 3);
    });

    test('home not loaded: all sources optimistically visible', () {
      final container = createContainer(
        inboxItems: const [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-a',
            channelName: 'A',
            unreadCount: 4,
          ),
          InboxItem(
            kind: InboxItemKind.dm,
            channelId: 'dm-b',
            channelName: 'B',
            unreadCount: 6,
          ),
        ],
        homeState: const HomeListState(
          status: HomeListStatus.initial,
        ),
      );

      final state = container.read(unreadSourceProjectionProvider);

      // All non-thread sources should be visible optimistically
      expect(state.visibleSources.length, 2);
      expect(state.hiddenSources, isEmpty);

      final visibleSum =
          state.visibleSources.fold<int>(0, (sum, s) => sum + s.unreadCount);
      expect(visibleSum, state.totalUnreadCount);
      expect(visibleSum, 10);
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeInboxStore extends InboxStore {
  _FakeInboxStore(this._initial);
  final InboxState _initial;

  @override
  InboxState build() => _initial;
}

class _FakeHomeListStore extends HomeListStore {
  _FakeHomeListStore(this._initial);
  final HomeListState _initial;

  @override
  HomeListState build() => _initial;
}
