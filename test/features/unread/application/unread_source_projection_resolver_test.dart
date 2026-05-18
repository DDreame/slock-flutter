// ignore_for_file: lines_longer_than_80_chars
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
import 'dart:ui';

import 'package:slock_app/l10n/app_localizations.dart';
import 'package:slock_app/l10n/app_localizations_provider.dart';

// ---------------------------------------------------------------------------
// #561 Phase A — _buildNameResolver map construction tests
//
// Verifies that the name resolver (InboxNameResolver) used by
// UnreadSourceProjectionStore is populated correctly from HomeListState.
//
// INV-RESOLVE-1: channelNames populated from pinned + regular channels
// INV-RESOLVE-2: channelNames populated from pinned + regular DMs
// INV-RESOLVE-3: memberNames populated from DM peer IDs
// INV-RESOLVE-4: memberNames populated from agents
// INV-RESOLVE-5: returns empty resolver when status ≠ success
//
// Phase A — all tests skip: true.
// ---------------------------------------------------------------------------

void main() {
  const serverId = ServerScopeId('server-1');

  // Reusable scope IDs.
  const chGeneral = ChannelScopeId(serverId: serverId, value: 'ch-general');
  const chRandom = ChannelScopeId(serverId: serverId, value: 'ch-random');
  const dmAlice = DirectMessageScopeId(serverId: serverId, value: 'dm-alice');
  const dmBob = DirectMessageScopeId(serverId: serverId, value: 'dm-bob');

  ProviderContainer createContainer({
    InboxState? inboxState,
    HomeListState? homeState,
  }) {
    final container = ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(serverId),
        appLocalizationsProvider.overrideWithValue(
          lookupAppLocalizations(const Locale('en')),
        ),
        inboxStoreProvider.overrideWith(
          () => _FakeInboxStore(inboxState ?? const InboxState()),
        ),
        homeListStoreProvider.overrideWith(
          () => _FakeHomeListStore(homeState ?? const HomeListState()),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('_buildNameResolver — map construction', () {
    test(
      'channelNames populated from pinned + regular channels (INV-RESOLVE-1)',
      skip: true,
      () {
        // Setup: HomeListState with pinnedChannels=[general] + channels=[random].
        // Inbox has items referencing both channel IDs with null channelName.
        // Assert: projection resolves display names via local store fallback.
        const homeState = HomeListState(
          status: HomeListStatus.success,
          pinnedChannels: [
            HomeChannelSummary(scopeId: chGeneral, name: 'general'),
          ],
          channels: [
            HomeChannelSummary(scopeId: chRandom, name: 'random'),
          ],
        );

        final inboxState = InboxState(
          status: InboxStatus.success,
          items: [
            _makeInboxItem(
              channelId: 'ch-general',
              kind: InboxItemKind.channel,
            ),
            _makeInboxItem(
              channelId: 'ch-random',
              kind: InboxItemKind.channel,
            ),
          ],
        );

        final container = createContainer(
          homeState: homeState,
          inboxState: inboxState,
        );
        final state = container.read(unreadSourceProjectionProvider);

        // Both channel names should be resolved from local store.
        final generalSource = state.sources.firstWhere(
          (s) => s.channelScopeId?.value == 'ch-general',
        );
        expect(generalSource.title, contains('general'));

        final randomSource = state.sources.firstWhere(
          (s) => s.channelScopeId?.value == 'ch-random',
        );
        expect(randomSource.title, contains('random'));
      },
    );

    test(
      'channelNames populated from pinned + regular DMs (INV-RESOLVE-2)',
      skip: true,
      () {
        // Setup: HomeListState with pinnedDirectMessages=[alice],
        // directMessages=[bob].
        // Inbox has DM items with null channelName.
        // Assert: projection titles resolve from DM titles.
        const homeState = HomeListState(
          status: HomeListStatus.success,
          pinnedDirectMessages: [
            HomeDirectMessageSummary(scopeId: dmAlice, title: 'Alice'),
          ],
          directMessages: [
            HomeDirectMessageSummary(scopeId: dmBob, title: 'Bob'),
          ],
        );

        final inboxState = InboxState(
          status: InboxStatus.success,
          items: [
            _makeInboxItem(channelId: 'dm-alice', kind: InboxItemKind.dm),
            _makeInboxItem(channelId: 'dm-bob', kind: InboxItemKind.dm),
          ],
        );

        final container = createContainer(
          homeState: homeState,
          inboxState: inboxState,
        );
        final state = container.read(unreadSourceProjectionProvider);

        final aliceSource = state.sources.firstWhere(
          (s) => s.dmScopeId?.value == 'dm-alice',
        );
        expect(aliceSource.title, 'Alice');

        final bobSource = state.sources.firstWhere(
          (s) => s.dmScopeId?.value == 'dm-bob',
        );
        expect(bobSource.title, 'Bob');
      },
    );

    test(
      'memberNames populated from DM peer IDs (INV-RESOLVE-3)',
      skip: true,
      () {
        // Setup: DM with peerId='user-alice'. Inbox item has
        // senderId='user-alice' but null senderName.
        // Assert: projection's senderName resolves from DM peer data.
        const homeState = HomeListState(
          status: HomeListStatus.success,
          directMessages: [
            HomeDirectMessageSummary(
              scopeId: dmAlice,
              title: 'Alice',
              peerId: 'user-alice',
            ),
          ],
        );

        final inboxState = InboxState(
          status: InboxStatus.success,
          items: [
            _makeInboxItem(
              channelId: 'dm-alice',
              kind: InboxItemKind.dm,
              senderId: 'user-alice',
            ),
          ],
        );

        final container = createContainer(
          homeState: homeState,
          inboxState: inboxState,
        );
        final state = container.read(unreadSourceProjectionProvider);

        expect(state.sources, isNotEmpty);
        final source = state.sources.first;
        expect(source.senderName, 'Alice');
      },
    );

    test(
      'memberNames populated from agents (INV-RESOLVE-4)',
      skip: true,
      () {
        // Setup: Agent with id='agent-j1', label='J1'.
        // Inbox item has senderId='agent-j1' but null senderName.
        // Assert: projection's senderName resolves from agent data.
        const agent = AgentItem(
          id: 'agent-j1',
          name: 'j1',
          displayName: 'J1',
          model: 'claude',
          runtime: 'node',
          status: 'active',
          activity: 'working',
        );

        const homeState = HomeListState(
          status: HomeListStatus.success,
          agents: [agent],
          channels: [
            HomeChannelSummary(scopeId: chGeneral, name: 'general'),
          ],
        );

        final inboxState = InboxState(
          status: InboxStatus.success,
          items: [
            _makeInboxItem(
              channelId: 'ch-general',
              kind: InboxItemKind.channel,
              senderId: 'agent-j1',
            ),
          ],
        );

        final container = createContainer(
          homeState: homeState,
          inboxState: inboxState,
        );
        final state = container.read(unreadSourceProjectionProvider);

        expect(state.sources, isNotEmpty);
        final source = state.sources.first;
        expect(source.senderName, 'J1');
      },
    );

    test(
      'returns empty resolver when status ≠ success (INV-RESOLVE-5)',
      skip: true,
      () {
        // Setup: HomeListState with status=loading (not success).
        // Inbox has items.
        // Assert: projection names fall back to raw IDs / null.
        const homeState = HomeListState(
          status: HomeListStatus.loading,
          channels: [
            HomeChannelSummary(scopeId: chGeneral, name: 'general'),
          ],
        );

        final inboxState = InboxState(
          status: InboxStatus.success,
          items: [
            _makeInboxItem(
              channelId: 'ch-general',
              kind: InboxItemKind.channel,
            ),
          ],
        );

        final container = createContainer(
          homeState: homeState,
          inboxState: inboxState,
        );
        final state = container.read(unreadSourceProjectionProvider);

        // With loading state, name resolver should not have channel names.
        // The title should fall back to raw channelId or similar.
        if (state.sources.isNotEmpty) {
          final source = state.sources.first;
          // Should NOT resolve to 'general' since home status != success.
          expect(source.title, isNot('general'));
        }
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

InboxItem _makeInboxItem({
  required String channelId,
  required InboxItemKind kind,
  String? senderId,
  String? senderName,
  String? channelName,
}) {
  return InboxItem(
    channelId: channelId,
    kind: kind,
    unreadCount: 1,
    preview: 'hello',
    lastActivityAt: DateTime.parse('2026-05-18T00:00:00Z'),
    senderId: senderId,
    senderName: senderName,
    channelName: channelName,
  );
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
