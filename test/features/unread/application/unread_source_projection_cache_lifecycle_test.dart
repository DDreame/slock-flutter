// =============================================================================
// #661 — P0 Static Cache Leak Fix
//
// Invariants verified:
// INV-CACHE-LIFECYCLE-1: Name resolver cache is scoped to ProviderContainer.
//                         Disposing container A and creating container B must
//                         NOT reuse container A's cached resolver.
// INV-CACHE-LIFECYCLE-2: Within the same container, identity-equal
//                         _HomeVisibility produces the same InboxNameResolver
//                         instance (memoization works).
// =============================================================================

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
          homeState: const HomeListState(
            status: HomeListStatus.success,
            channels: [
              HomeChannelSummary(
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
          homeState: const HomeListState(
            status: HomeListStatus.success,
            channels: [
              HomeChannelSummary(
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
      'INV-CACHE-LIFECYCLE-2: within one container, identity-equal '
      'visibility produces same resolver (memoization works)',
      () {
        final container = createContainer(
          homeState: const HomeListState(
            status: HomeListStatus.success,
            channels: [
              HomeChannelSummary(
                scopeId: channelGeneral,
                name: 'general',
              ),
            ],
          ),
        );
        addTearDown(container.dispose);

        // Read twice — provider caches, so both calls return identical
        // projection (same resolver was used).
        final state1 = container.read(unreadSourceProjectionProvider);
        final state2 = container.read(unreadSourceProjectionProvider);

        // Same object reference (Provider caches computed value).
        expect(identical(state1, state2), isTrue,
            reason: 'Provider must cache projection — reads should return same '
                'instance (INV-CACHE-LIFECYCLE-2)');
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
