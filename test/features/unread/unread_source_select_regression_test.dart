// =============================================================================
// #795 — Unread source projection .select() regression
//
// Invariants verified:
//
// INV-SELECT-UNREAD-HOME: home_page.dart watches
//   unreadSourceProjectionProvider.select((s) => (sources: s.sources, isLoaded: s.isLoaded))
//   Changes to channelUnreadCounts / dmUnreadCounts maps must NOT trigger
//   the (sources, isLoaded) selector.
//
// INV-SELECT-UNREAD-LIST: unread_list_page.dart watches the same selector.
//   Same constraint applies.
//
// Strategy (mirrors tab_sort_unread_select_test.dart):
//   Negative tests: Use StateProvider<UnreadSourceProjectionState> intermediary,
//   override unreadSourceProjectionProvider, attach container.listen() with the
//   production .select() pattern. Mutate only maps → assert 0 notifications.
//
//   Positive tests: Use StateProvider.select() directly (same Riverpod select
//   mechanism) proving the record selector fires on sources/isLoaded change.
//   (Provider.overrideWith doesn't propagate positive cases — see T7/T8 in
//   tab_sort_unread_select_test.dart which are also skip:true for this reason.)
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/inbox/application/conversation_projection.dart';
import 'package:slock_app/features/unread/application/unread_source_projection.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Shared test data
  // ---------------------------------------------------------------------------
  const channelScopeId = ChannelScopeId(
    serverId: ServerScopeId('server-1'),
    value: 'general',
  );
  const dmScopeId = DirectMessageScopeId(
    serverId: ServerScopeId('server-1'),
    value: 'dm-1',
  );

  final baseSource = UnreadSourceProjection(
    kind: ConversationProjectionKind.channel,
    id: 'channel:general',
    title: '#general',
    previewText: 'Hello',
    unreadCount: 3,
    visibility: UnreadSourceVisibility.visible,
  );

  final baseState = UnreadSourceProjectionState(
    sources: [baseSource],
    channelUnreadCounts: {channelScopeId: 3},
    dmUnreadCounts: {dmScopeId: 1},
    isLoaded: true,
  );

  // ===========================================================================
  // NEGATIVE TESTS: Map changes must NOT fire (sources, isLoaded) selector
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // INV-SELECT-UNREAD-HOME: channelUnreadCounts change does NOT fire selector
  // ---------------------------------------------------------------------------
  test(
    'INV-SELECT-UNREAD-HOME: channelUnreadCounts change does NOT fire '
    '(sources, isLoaded) selector',
    () {
      final stateProvider = StateProvider<UnreadSourceProjectionState>((ref) {
        return baseState;
      });

      final container = ProviderContainer(
        overrides: [
          unreadSourceProjectionProvider.overrideWith(
            (ref) => ref.watch(stateProvider),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Keep alive + prime the selector.
      final keepAlive =
          container.listen(unreadSourceProjectionProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        unreadSourceProjectionProvider.select(
          (s) => (sources: s.sources, isLoaded: s.isLoaded),
        ),
        (_, __) => selectNotifyCount++,
      );

      // Mutate only channelUnreadCounts — sources and isLoaded stay identical.
      container.read(stateProvider.notifier).state = UnreadSourceProjectionState(
        sources: baseState.sources,
        channelUnreadCounts: {channelScopeId: 99},
        dmUnreadCounts: baseState.dmUnreadCounts,
        isLoaded: true,
      );

      expect(
        selectNotifyCount,
        0,
        reason: 'channelUnreadCounts change must not notify (sources, isLoaded) '
            'selector (INV-SELECT-UNREAD-HOME)',
      );

      keepAlive.close();
    },
  );

  // ---------------------------------------------------------------------------
  // INV-SELECT-UNREAD-LIST: dmUnreadCounts change does NOT fire selector
  // ---------------------------------------------------------------------------
  test(
    'INV-SELECT-UNREAD-LIST: dmUnreadCounts change does NOT fire '
    '(sources, isLoaded) selector',
    () {
      final stateProvider = StateProvider<UnreadSourceProjectionState>((ref) {
        return baseState;
      });

      final container = ProviderContainer(
        overrides: [
          unreadSourceProjectionProvider.overrideWith(
            (ref) => ref.watch(stateProvider),
          ),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(unreadSourceProjectionProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        unreadSourceProjectionProvider.select(
          (s) => (sources: s.sources, isLoaded: s.isLoaded),
        ),
        (_, __) => selectNotifyCount++,
      );

      // Mutate only dmUnreadCounts — sources and isLoaded stay identical.
      container.read(stateProvider.notifier).state = UnreadSourceProjectionState(
        sources: baseState.sources,
        channelUnreadCounts: baseState.channelUnreadCounts,
        dmUnreadCounts: {dmScopeId: 77},
        isLoaded: true,
      );

      expect(
        selectNotifyCount,
        0,
        reason: 'dmUnreadCounts change must not notify (sources, isLoaded) '
            'selector (INV-SELECT-UNREAD-LIST)',
      );

      keepAlive.close();
    },
  );

  // ---------------------------------------------------------------------------
  // Combined: both maps change, sources/isLoaded same → 0 notifications
  // ---------------------------------------------------------------------------
  test(
    'both channelUnreadCounts + dmUnreadCounts changing does NOT fire '
    '(sources, isLoaded) selector when sources/isLoaded are unchanged',
    () {
      final stateProvider = StateProvider<UnreadSourceProjectionState>((ref) {
        return baseState;
      });

      final container = ProviderContainer(
        overrides: [
          unreadSourceProjectionProvider.overrideWith(
            (ref) => ref.watch(stateProvider),
          ),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(unreadSourceProjectionProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        unreadSourceProjectionProvider.select(
          (s) => (sources: s.sources, isLoaded: s.isLoaded),
        ),
        (_, __) => selectNotifyCount++,
      );

      // Mutate both maps simultaneously — sources and isLoaded unchanged.
      container.read(stateProvider.notifier).state = UnreadSourceProjectionState(
        sources: baseState.sources,
        channelUnreadCounts: {channelScopeId: 50},
        dmUnreadCounts: {dmScopeId: 25},
        isLoaded: true,
      );

      expect(
        selectNotifyCount,
        0,
        reason: 'simultaneous map changes must not notify (sources, isLoaded) '
            'selector when sources and isLoaded are unchanged',
      );

      keepAlive.close();
    },
  );

  // ===========================================================================
  // POSITIVE TESTS: sources/isLoaded changes MUST fire the selector
  //
  // Uses StateProvider.select() directly — same Riverpod select mechanism as
  // production code. The Provider.overrideWith indirection doesn't propagate
  // positive notifications (known limitation — see T7/T8 skip:true in
  // tab_sort_unread_select_test.dart).
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // sources list change DOES fire (sources, isLoaded) selector
  // ---------------------------------------------------------------------------
  test(
    'sources list change DOES fire (sources, isLoaded) selector',
    () {
      final stateProvider = StateProvider<UnreadSourceProjectionState>((ref) {
        return baseState;
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      int selectNotifyCount = 0;
      container.listen(
        stateProvider.select(
          (s) => (sources: s.sources, isLoaded: s.isLoaded),
        ),
        (_, __) => selectNotifyCount++,
      );

      // Add a new source — list reference changes.
      final newSource = UnreadSourceProjection(
        kind: ConversationProjectionKind.dm,
        id: 'dm:dm-1',
        title: 'Alice',
        previewText: 'New message',
        unreadCount: 2,
        visibility: UnreadSourceVisibility.visible,
      );
      container.read(stateProvider.notifier).state = UnreadSourceProjectionState(
        sources: [...baseState.sources, newSource],
        channelUnreadCounts: baseState.channelUnreadCounts,
        dmUnreadCounts: baseState.dmUnreadCounts,
        isLoaded: true,
      );

      expect(
        selectNotifyCount,
        1,
        reason: 'sources list change must notify (sources, isLoaded) selector',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // isLoaded change DOES fire (sources, isLoaded) selector
  // ---------------------------------------------------------------------------
  test(
    'isLoaded change DOES fire (sources, isLoaded) selector',
    () {
      final initialState = UnreadSourceProjectionState(
        sources: baseState.sources,
        channelUnreadCounts: baseState.channelUnreadCounts,
        dmUnreadCounts: baseState.dmUnreadCounts,
        isLoaded: false,
      );

      final stateProvider = StateProvider<UnreadSourceProjectionState>((ref) {
        return initialState;
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      int selectNotifyCount = 0;
      container.listen(
        stateProvider.select(
          (s) => (sources: s.sources, isLoaded: s.isLoaded),
        ),
        (_, __) => selectNotifyCount++,
      );

      // Flip isLoaded to true — same sources and maps.
      container.read(stateProvider.notifier).state = UnreadSourceProjectionState(
        sources: initialState.sources,
        channelUnreadCounts: initialState.channelUnreadCounts,
        dmUnreadCounts: initialState.dmUnreadCounts,
        isLoaded: true,
      );

      expect(
        selectNotifyCount,
        1,
        reason: 'isLoaded change must notify (sources, isLoaded) selector',
      );
    },
  );
}
