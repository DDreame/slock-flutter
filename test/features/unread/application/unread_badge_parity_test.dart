import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/application/inbox_unread_count_provider.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';

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
  const serverId = ServerScopeId('server-1');

  ProviderContainer createContainer({
    required List<InboxItem> inboxItems,
    required HomeListState homeState,
    int? totalUnreadCount,
  }) {
    // Compute total if not provided — matches real API behavior
    final total = totalUnreadCount ??
        inboxItems.fold<int>(0, (sum, item) => sum + item.unreadCount);

    final container = ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(serverId),
        inboxStoreProvider.overrideWith(
          () => _FakeInboxStore(InboxState(
            status: InboxStatus.success,
            items: inboxItems,
            totalUnreadCount: total,
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
    test(
        'badge providers match projection totals with mixed visible/hidden sources',
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

      // Read actual badge providers (what AppShell tabs display)
      final channelBadge = container.read(inboxChannelUnreadTotalProvider);
      final dmBadge = container.read(inboxDmUnreadTotalProvider);
      final totalBadge = container.read(inboxTotalUnreadCountProvider);

      // Read projection (what list pages display)
      final projection = container.read(unreadSourceProjectionProvider);
      final visibleSum = projection.visibleSources
          .fold<int>(0, (sum, s) => sum + s.unreadCount);
      final hiddenSum = projection.hiddenSources
          .fold<int>(0, (sum, s) => sum + s.unreadCount);

      // Badge providers must equal projection sub-totals
      expect(
        channelBadge,
        projection.channelUnreadTotal,
        reason:
            'Channels tab badge must equal projection channelUnreadTotal (8)',
      );
      expect(channelBadge, 8); // 5 + 3 (both visible and hidden)

      expect(
        dmBadge,
        projection.dmUnreadTotal,
        reason: 'DMs tab badge must equal projection dmUnreadTotal (2)',
      );
      expect(dmBadge, 2);

      expect(
        totalBadge,
        projection.totalUnreadCount,
        reason: 'Total badge must equal projection totalUnreadCount (11)',
      );
      expect(totalBadge, 11);

      // Algebraic invariant: total == visible + hidden
      expect(
        projection.totalUnreadCount,
        visibleSum + hiddenSum,
        reason: 'totalUnreadCount must equal visible + hidden sums',
      );

      // Visible: ch-general (5) + dm-alice (2) = 7
      expect(visibleSum, 7);

      // Hidden: ch-hidden (3) + thread-1 (1) = 4
      expect(hiddenSum, 4);
    });

    test(
        'all visible channels: channel badge equals visible channel source sum',
        () {
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

      final channelBadge = container.read(inboxChannelUnreadTotalProvider);
      final projection = container.read(unreadSourceProjectionProvider);

      // All channels visible → badge == visible sum == total
      expect(projection.visibleSources.length, 2);
      expect(projection.hiddenSources, isEmpty);

      final visibleSum = projection.visibleSources
          .fold<int>(0, (sum, s) => sum + s.unreadCount);
      expect(channelBadge, visibleSum,
          reason: 'When all channels visible, badge equals visible sum');
      expect(channelBadge, projection.channelUnreadTotal);
      expect(channelBadge, 30);
    });

    test(
        'hidden channels: channel badge includes hidden but visible list does not',
        () {
      final container = createContainer(
        inboxItems: const [
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-visible',
            channelName: 'visible',
            unreadCount: 5,
          ),
          InboxItem(
            kind: InboxItemKind.channel,
            channelId: 'ch-hidden',
            channelName: 'hidden',
            unreadCount: 3,
          ),
        ],
        homeState: const HomeListState(
          status: HomeListStatus.success,
          channels: [
            HomeChannelSummary(
              scopeId: ChannelScopeId(serverId: serverId, value: 'ch-visible'),
              name: 'visible',
            ),
          ],
        ),
      );

      final channelBadge = container.read(inboxChannelUnreadTotalProvider);
      final projection = container.read(unreadSourceProjectionProvider);

      // Badge counts ALL channels (visible + hidden)
      expect(channelBadge, 8, reason: 'Badge includes hidden channels');
      expect(channelBadge, projection.channelUnreadTotal);

      // But visible list only shows the visible channel
      final visibleChannelSum = projection.visibleSources
          .fold<int>(0, (sum, s) => sum + s.unreadCount);
      expect(visibleChannelSum, 5,
          reason: 'Visible list excludes hidden channels');

      // Hidden source accounts for the difference
      expect(projection.hiddenSources.length, 1);
      expect(projection.hiddenSources.first.unreadCount, 3);

      // Parity: badge == visible + hidden for channels
      expect(channelBadge, visibleChannelSum + 3);
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

      final channelBadge = container.read(inboxChannelUnreadTotalProvider);
      final projection = container.read(unreadSourceProjectionProvider);

      // Badge counts all channels
      expect(channelBadge, 10);
      expect(channelBadge, projection.channelUnreadTotal);

      // Pinned channel is visible
      expect(projection.visibleSources.length, 1);
      expect(projection.visibleSources.first.unreadCount, 7);

      // Unpinned is hidden
      expect(projection.hiddenSources.length, 1);
      expect(projection.hiddenSources.first.unreadCount, 3);

      // Invariant holds
      expect(projection.totalUnreadCount, 10);
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

      final channelBadge = container.read(inboxChannelUnreadTotalProvider);
      final dmBadge = container.read(inboxDmUnreadTotalProvider);
      final totalBadge = container.read(inboxTotalUnreadCountProvider);
      final projection = container.read(unreadSourceProjectionProvider);

      // All non-thread sources should be visible optimistically
      expect(projection.visibleSources.length, 2);
      expect(projection.hiddenSources, isEmpty);

      // Badge providers must match projection
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
