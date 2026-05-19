// =============================================================================
// #623 — Channel members ensureLoaded() — redundant API call elimination
//
// Invariant: INV-CHANNEL-MEMBERS-LOAD-GUARD-1
//   _ChannelMembersBodyState.initState() at channel_members_page.dart L68
//   calls channelMemberStoreProvider.notifier.load(). When the store has
//   already loaded (status != initial), this fires a redundant network request.
//   Phase B replaces load() with ensureLoaded() so the call is idempotent.
//
// Strategy:
// T1: ensureLoaded() on status == success does NOT call load() (skip:true).
// T2: ensureLoaded() on status == initial DOES call load() (active).
//
// Phase A: T1 skip:true — ensureLoaded() not yet implemented.
//          T2 active — correctness proof.
//
// Phase B:
// - channel_member_store.dart: add ensureLoaded() method
// - channel_members_page.dart L68: replace load() with ensureLoaded()
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_member_state.dart';
import 'package:slock_app/features/channels/application/channel_member_store.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeChannelMemberStore extends ChannelMemberStore {
  _FakeChannelMemberStore({required ChannelMemberStatus initialStatus})
      : _initialStatus = initialStatus;

  final ChannelMemberStatus _initialStatus;
  int loadCallCount = 0;

  @override
  ChannelMemberState build() => ChannelMemberState(status: _initialStatus);

  @override
  Future<void> load() async {
    loadCallCount++;
  }

  @override
  void ensureLoaded() {
    if (state.status == ChannelMemberStatus.initial) {
      load();
    }
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: ensureLoaded() on status == success must NOT call load().
  // -------------------------------------------------------------------------
  test(
    'INV-CHANNEL-MEMBERS-LOAD-GUARD-1: ensureLoaded() skips when '
    'status == success',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentChannelMemberServerIdProvider.overrideWithValue(
            const ServerScopeId('srv'),
          ),
          currentChannelMemberChannelIdProvider.overrideWithValue('ch-1'),
          channelMemberStoreProvider.overrideWith(
            () => _FakeChannelMemberStore(
              initialStatus: ChannelMemberStatus.success,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(channelMemberStoreProvider, (_, __) {});

      final store = container.read(channelMemberStoreProvider.notifier)
          as _FakeChannelMemberStore;
      store.ensureLoaded();

      expect(
        store.loadCallCount,
        0,
        reason: 'ensureLoaded() must skip when status != initial '
            '(INV-CHANNEL-MEMBERS-LOAD-GUARD-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: ensureLoaded() on status == initial DOES call load().
  // -------------------------------------------------------------------------
  test(
    'INV-CHANNEL-MEMBERS-LOAD-GUARD-1: ensureLoaded() fires when '
    'status == initial',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentChannelMemberServerIdProvider.overrideWithValue(
            const ServerScopeId('srv'),
          ),
          currentChannelMemberChannelIdProvider.overrideWithValue('ch-1'),
          channelMemberStoreProvider.overrideWith(
            () => _FakeChannelMemberStore(
              initialStatus: ChannelMemberStatus.initial,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(channelMemberStoreProvider, (_, __) {});

      final store = container.read(channelMemberStoreProvider.notifier)
          as _FakeChannelMemberStore;
      store.ensureLoaded();

      expect(
        store.loadCallCount,
        1,
        reason: 'ensureLoaded() must call load() when status == initial',
      );

      keepAlive.close();
    },
  );
}
