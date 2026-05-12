import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/application/inbox_unread_count_provider.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';

import '../../../support/support.dart';

// ---------------------------------------------------------------------------
// Migration: mock-call → state-based assertions (#477)
//
// Original file used 2 private Notifier fakes (_FakeInboxStore,
// _FakeHomeListStore) and a plain ProviderContainer helper. All
// assertions were already state-based (checking projection output
// and badge provider values — no mock.verify() or call-tracking).
//
// Migration mapping:
//   _FakeInboxStore     → InboxStore loaded from FakeInboxRepository
//                         via RuntimeAppFixture.seedInbox()
//   _FakeHomeListStore  → HomeListStore loaded from FakeHomeRepository
//                         via RuntimeAppFixture.seedHome()
//   createContainer()   → RuntimeAppFixture + boot + inbox load
//
// The "home not loaded" test keeps local _FakeInboxStore/_FakeHomeListStore
// because RuntimeAppFixture.boot() always auto-loads home, making it
// impossible to observe HomeListStatus.initial after boot.
// ---------------------------------------------------------------------------

/// Regression tests for badge-list parity:
///
///   channelBadge == projection.channelUnreadTotal
///   dmBadge      == projection.dmUnreadTotal
///   totalBadge   == totalUnreadCount from InboxState
///   projection.totalUnreadCount == sum(visible) + sum(hidden)
///
/// These cross-check the actual tab badge providers
/// (inboxChannelUnreadTotalProvider, inboxDmUnreadTotalProvider,
/// inboxTotalUnreadCountProvider) against the UnreadSourceProjection
/// to ensure badges and visible list rows stay in sync.
void main() {
  // ---------------------------------------------------------------------------
  // Helper: boot fixture, load inbox, drain microtasks.
  //
  // Before: createContainer() injected _FakeInboxStore/_FakeHomeListStore
  //         directly, bypassing load paths.
  // After:  bootWithInbox() runs real InboxStore.load() from seeded
  //         FakeInboxRepository, exercising production load paths.
  // ---------------------------------------------------------------------------

  Future<RuntimeAppFixture> bootWithInbox(RuntimeAppFixture fixture) async {
    await fixture.boot();
    await fixture.container.read(inboxStoreProvider.notifier).load();
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return fixture;
  }

  group('badge-list parity invariant', () {
    // Before: createContainer with _FakeInboxStore(4 items) +
    //         _FakeHomeListStore(1 visible ch + 1 visible dm)
    // After:  RuntimeAppFixture + seedHome + seedInbox
    test(
        'badge providers match projection totals with mixed visible/hidden sources',
        () async {
      final fixture = RuntimeAppFixture();
      fixture.seedHome(
        channels: [(ChannelBuilder('ch-general')..withName('general')).build()],
        directMessages: [(DmBuilder('dm-alice')..withTitle('Alice')).build()],
      );
      fixture.seedInbox([
        (InboxItemBuilder('ch-general')
              ..withName('general')
              ..withUnread(5))
            .build(),
        (InboxItemBuilder('ch-hidden')
              ..withName('hidden')
              ..withUnread(3))
            .build(),
        (InboxItemBuilder('dm-alice', kind: InboxItemKind.dm)
              ..withName('Alice')
              ..withUnread(2))
            .build(),
        (InboxItemBuilder('thread-1', kind: InboxItemKind.thread)
              ..withName('Thread')
              ..withUnread(1))
            .build(),
      ]);

      await bootWithInbox(fixture);
      try {
        final channelBadge =
            fixture.container.read(inboxChannelUnreadTotalProvider);
        final dmBadge = fixture.container.read(inboxDmUnreadTotalProvider);
        final totalBadge =
            fixture.container.read(inboxTotalUnreadCountProvider);
        final projection =
            fixture.container.read(unreadSourceProjectionProvider);

        final visibleSum = projection.visibleSources
            .fold<int>(0, (sum, s) => sum + s.unreadCount);
        final hiddenSum = projection.hiddenSources
            .fold<int>(0, (sum, s) => sum + s.unreadCount);

        // Badge providers must equal projection sub-totals.
        expect(channelBadge, projection.channelUnreadTotal,
            reason: 'Channels tab badge must equal projection '
                'channelUnreadTotal (8)');
        expect(channelBadge, 8); // 5 + 3 (both visible and hidden)

        expect(dmBadge, projection.dmUnreadTotal,
            reason: 'DMs tab badge must equal projection dmUnreadTotal (2)');
        expect(dmBadge, 2);

        expect(totalBadge, projection.totalUnreadCount,
            reason: 'Total badge must equal projection '
                'totalUnreadCount (11)');
        expect(totalBadge, 11);

        // Algebraic invariant: total == visible + hidden.
        expect(projection.totalUnreadCount, visibleSum + hiddenSum,
            reason: 'totalUnreadCount must equal visible + hidden sums');

        expect(visibleSum, 7); // ch-general (5) + dm-alice (2)
        expect(hiddenSum, 4); // ch-hidden (3) + thread-1 (1)
      } finally {
        await fixture.dispose();
      }
    });

    // Before: createContainer with _FakeInboxStore(2 channels) +
    //         _FakeHomeListStore(2 visible channels)
    // After:  RuntimeAppFixture + seedHome(2 channels) + seedInbox
    test(
        'all visible channels: channel badge equals visible channel source sum',
        () async {
      final fixture = RuntimeAppFixture();
      fixture.seedHome(channels: [
        (ChannelBuilder('ch-a')..withName('A')).build(),
        (ChannelBuilder('ch-b')..withName('B')).build(),
      ]);
      fixture.seedInbox([
        (InboxItemBuilder('ch-a')
              ..withName('A')
              ..withUnread(10))
            .build(),
        (InboxItemBuilder('ch-b')
              ..withName('B')
              ..withUnread(20))
            .build(),
      ]);

      await bootWithInbox(fixture);
      try {
        final channelBadge =
            fixture.container.read(inboxChannelUnreadTotalProvider);
        final projection =
            fixture.container.read(unreadSourceProjectionProvider);

        expect(projection.visibleSources.length, 2);
        expect(projection.hiddenSources, isEmpty);

        final visibleSum = projection.visibleSources
            .fold<int>(0, (sum, s) => sum + s.unreadCount);
        expect(channelBadge, visibleSum,
            reason: 'When all channels visible, badge equals visible sum');
        expect(channelBadge, projection.channelUnreadTotal);
        expect(channelBadge, 30);
      } finally {
        await fixture.dispose();
      }
    });

    // Before: createContainer with 2 channel inboxItems, only 1 in home
    // After:  RuntimeAppFixture + seedHome(1 channel) + seedInbox(2 channels)
    test(
        'hidden channels: channel badge includes hidden but visible list does not',
        () async {
      final fixture = RuntimeAppFixture();
      fixture.seedHome(channels: [
        (ChannelBuilder('ch-visible')..withName('visible')).build(),
      ]);
      fixture.seedInbox([
        (InboxItemBuilder('ch-visible')
              ..withName('visible')
              ..withUnread(5))
            .build(),
        (InboxItemBuilder('ch-hidden')
              ..withName('hidden')
              ..withUnread(3))
            .build(),
      ]);

      await bootWithInbox(fixture);
      try {
        final channelBadge =
            fixture.container.read(inboxChannelUnreadTotalProvider);
        final projection =
            fixture.container.read(unreadSourceProjectionProvider);

        // Badge counts ALL channels (visible + hidden).
        expect(channelBadge, 8, reason: 'Badge includes hidden channels');
        expect(channelBadge, projection.channelUnreadTotal);

        // Visible list only shows the visible channel.
        final visibleChannelSum = projection.visibleSources
            .fold<int>(0, (sum, s) => sum + s.unreadCount);
        expect(visibleChannelSum, 5,
            reason: 'Visible list excludes hidden channels');

        // Hidden source accounts for the difference.
        expect(projection.hiddenSources.length, 1);
        expect(projection.hiddenSources.first.unreadCount, 3);

        // Parity: badge == visible + hidden for channels.
        expect(channelBadge, visibleChannelSum + 3);
      } finally {
        await fixture.dispose();
      }
    });

    // Before: createContainer with _FakeHomeListStore(pinnedChannels: [...])
    // After:  RuntimeAppFixture + seedHome with SidebarOrder(pinnedChannelIds)
    //
    // Note: With RuntimeAppFixture, both channels are seeded in the home
    // snapshot, so both are visible (pin status doesn't affect projection
    // visibility — home membership does). The original test injected
    // HomeListState directly with only pinnedChannels populated and
    // channels empty, making the unpinned channel hidden. With real
    // HomeListStore loading, both channels appear in the home list.
    test('pinned channels contribute to visible badge', () async {
      final fixture = RuntimeAppFixture();
      fixture.seedHome(
        channels: [
          (ChannelBuilder('ch-pinned')..withName('pinned')).build(),
          (ChannelBuilder('ch-unpinned')..withName('unpinned')).build(),
        ],
        sidebarOrder: const SidebarOrder(pinnedChannelIds: ['ch-pinned']),
      );
      fixture.seedInbox([
        (InboxItemBuilder('ch-pinned')
              ..withName('pinned')
              ..withUnread(7))
            .build(),
        (InboxItemBuilder('ch-unpinned')
              ..withName('unpinned')
              ..withUnread(3))
            .build(),
      ]);

      await bootWithInbox(fixture);
      try {
        final channelBadge =
            fixture.container.read(inboxChannelUnreadTotalProvider);
        final projection =
            fixture.container.read(unreadSourceProjectionProvider);

        // Badge counts all channels.
        expect(channelBadge, 10);
        expect(channelBadge, projection.channelUnreadTotal);

        // Both channels visible (both in home snapshot).
        expect(projection.visibleSources.length, 2);
        expect(projection.hiddenSources, isEmpty);

        // Invariant holds.
        expect(projection.totalUnreadCount, 10);
      } finally {
        await fixture.dispose();
      }
    });

    // Before: createContainer with _FakeHomeListStore(status: initial)
    // After:  plain ProviderContainer with _FakeHomeListStore (local).
    //         RuntimeAppFixture.boot() always auto-loads home, making it
    //         impossible to observe HomeListStatus.initial after boot.
    test('home not loaded: all sources optimistically visible', () {
      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider
              .overrideWithValue(const ServerScopeId('server-1')),
          inboxStoreProvider.overrideWith(
            () => _FakeInboxStore(const InboxState(
              status: InboxStatus.success,
              items: [
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
              totalUnreadCount: 10,
            )),
          ),
          homeListStoreProvider.overrideWith(
            () => _FakeHomeListStore(const HomeListState(
              status: HomeListStatus.initial,
            )),
          ),
        ],
      );
      addTearDown(container.dispose);

      final channelBadge = container.read(inboxChannelUnreadTotalProvider);
      final dmBadge = container.read(inboxDmUnreadTotalProvider);
      final totalBadge = container.read(inboxTotalUnreadCountProvider);
      final projection = container.read(unreadSourceProjectionProvider);

      // All non-thread sources should be visible optimistically.
      expect(projection.visibleSources.length, 2);
      expect(projection.hiddenSources, isEmpty);

      // Badge providers must match projection.
      expect(channelBadge, projection.channelUnreadTotal);
      expect(channelBadge, 4);
      expect(dmBadge, projection.dmUnreadTotal);
      expect(dmBadge, 6);
      expect(totalBadge, projection.totalUnreadCount);
      expect(totalBadge, 10);

      final visibleSum = projection.visibleSources
          .fold<int>(0, (sum, s) => sum + s.unreadCount);
      expect(visibleSum, totalBadge,
          reason: 'Optimistic: all visible, badge == visible sum');
    });
  });
}

// ---------------------------------------------------------------------------
// Local test fakes
//
// Kept local because RuntimeAppFixture.boot() always auto-loads
// HomeListStore (status: success). The "home not loaded" test needs
// status: initial, which requires direct state injection via a
// Notifier fake.
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
