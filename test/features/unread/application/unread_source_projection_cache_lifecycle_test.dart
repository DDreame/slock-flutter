// =============================================================================
// #661 — P0 Static Cache Leak Fix
//
// Invariants verified:
// INV-CACHE-LIFECYCLE-1: Name resolver cache is scoped to ProviderContainer.
//                         Disposing container A and creating container B must
//                         NOT reuse container A's cached resolver.
// INV-CACHE-LIFECYCLE-2: Within the same container, invoking the resolver
//                         closure with the same identity-equal input returns
//                         the same InboxNameResolver instance (memoization).
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';

void main() {
  const serverId = ServerScopeId('server-1');
  const channelGeneral = ChannelScopeId(
    serverId: serverId,
    value: 'ch-general',
  );

  // ---------------------------------------------------------------
  // Helper: build a container with configurable home state.
  // ---------------------------------------------------------------
  ProviderContainer createContainer({
    required HomeListState homeState,
    InboxState? inboxState,
  }) {
    return ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(serverId),
        inboxStoreProvider.overrideWith(() => _FakeInboxStore(
              inboxState ??
                  const InboxState(
                    status: InboxStatus.success,
                    items: [
                      InboxItem(
                        kind: InboxItemKind.channel,
                        channelId: 'ch-general',
                        // channelName intentionally null — forces resolver
                        // to fall through to channelNames map (from home list).
                        senderName: 'Alice',
                        preview: 'Hello',
                        unreadCount: 1,
                      ),
                    ],
                  ),
            )),
        homeListStoreProvider.overrideWith(() => _FakeHomeListStore(homeState)),
      ],
    );
  }

  group('INV-CACHE-LIFECYCLE: name resolver cache scoped to container', () {
    test(
      'INV-CACHE-LIFECYCLE-1: disposing container clears resolver cache — '
      'new container does not inherit stale state',
      () {
        // Container A: home has channel named "general-v1".
        final containerA = createContainer(
          homeState: HomeListState(
            status: HomeListStatus.success,
            channels: [
              const HomeChannelSummary(
                scopeId: channelGeneral,
                name: 'general-v1',
              ),
            ],
          ),
        );

        final stateA = containerA.read(unreadSourceProjectionProvider);
        expect(stateA.sources.first.title, 'general-v1');

        // Dispose container A — cache must die with it.
        containerA.dispose();

        // Container B: same channel ID but different name "general-v2".
        // If stale cache survived (file-scoped static), the resolver
        // would return "general-v1" from the cached map.
        final containerB = createContainer(
          homeState: HomeListState(
            status: HomeListStatus.success,
            channels: [
              const HomeChannelSummary(
                scopeId: channelGeneral,
                name: 'general-v2',
              ),
            ],
          ),
        );
        addTearDown(containerB.dispose);

        final stateB = containerB.read(unreadSourceProjectionProvider);
        expect(
          stateB.sources.first.title,
          'general-v2',
          reason: 'New container must build fresh resolver — '
              'cache must not survive container disposal '
              '(INV-CACHE-LIFECYCLE-1)',
        );
      },
    );

    test(
      'INV-CACHE-LIFECYCLE-2: same visibility identity → same resolver '
      'instance (closure-level memoization)',
      () {
        final container = createContainer(
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
        addTearDown(container.dispose);

        // Read the resolver closure directly from the cache provider.
        final resolverFn = container.read(nameResolverCacheProvider);

        // Construct a single visibility record and call the closure twice.
        // Identity-equal input must return the same InboxNameResolver.
        const HomeVisibilitySelect vis = (
          status: HomeListStatus.success,
          pinnedChannels: <HomeChannelSummary>[],
          channels: [
            HomeChannelSummary(
              scopeId: channelGeneral,
              name: 'general',
            ),
          ],
          pinnedDirectMessages: <HomeDirectMessageSummary>[],
          directMessages: <HomeDirectMessageSummary>[],
          pinnedAgents: <AgentItem>[],
          agents: <AgentItem>[],
        );

        final resolver1 = resolverFn(vis);
        final resolver2 = resolverFn(vis);

        expect(
          identical(resolver1, resolver2),
          isTrue,
          reason: 'Same identity-equal _HomeVisibility input must return '
              'the same InboxNameResolver instance — proving closure-level '
              'memoization works (INV-CACHE-LIFECYCLE-2)',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Minimal fake stores for provider overrides.
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
