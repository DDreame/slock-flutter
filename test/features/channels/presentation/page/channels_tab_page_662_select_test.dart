// =============================================================================
// #662 — ChannelsTabPage channelManagementStoreProvider .select(isBusy)
//
// Invariant: INV-CHANNELS-MGMT-662-SELECT-1
//   ChannelsTabPage.build() watches channelManagementStoreProvider narrowed
//   to s.isBusy. Mutations to channelId or failure (while activeAction remains
//   null → isBusy stays false) must NOT trigger a rebuild.
//
// Strategy:
// T1: channelId change (isBusy stays false) must NOT notify scaffold.
// T2: failure change (isBusy stays false) must NOT notify scaffold.
// T3: activeAction change (isBusy flips true) DOES notify scaffold.
// T4: dual-path decomposition — isBusy select is independent of
//     channelId/failure mutations.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/channels/application/channel_management_state.dart';
import 'package:slock_app/features/channels/application/channel_management_store.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableChannelManagementStore
    extends AutoDisposeNotifier<ChannelManagementState>
    implements ChannelManagementStore {
  @override
  ChannelManagementState build() => const ChannelManagementState();

  void setChannelIdDirect(String? channelId) {
    state = ChannelManagementState(
      activeAction: state.activeAction,
      channelId: channelId,
      failure: state.failure,
    );
  }

  void setFailureDirect(AppFailure? failure) {
    state = ChannelManagementState(
      activeAction: state.activeAction,
      channelId: state.channelId,
      failure: failure,
    );
  }

  void setActiveActionDirect(ChannelManagementAction? action) {
    state = ChannelManagementState(
      activeAction: action,
      channelId: state.channelId,
      failure: state.failure,
    );
  }

  // Stubs for ChannelManagementStore interface — not needed for this test.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: channelId change (isBusy stays false) must NOT notify scaffold.
  // -------------------------------------------------------------------------
  test(
    'INV-CHANNELS-MGMT-662-SELECT-1: channelId change does NOT notify '
    'isBusy select — scaffold stays stable',
    () async {
      final container = ProviderContainer(
        overrides: [
          channelManagementStoreProvider
              .overrideWith(() => _ControllableChannelManagementStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(channelManagementStoreProvider, (_, __) {});

      // This is the EXACT select expression from channels_tab_page.dart:
      //   ref.watch(channelManagementStoreProvider.select((s) => s.isBusy))
      int scaffoldRebuildCount = 0;
      container.listen(
        channelManagementStoreProvider.select((s) => s.isBusy),
        (_, __) => scaffoldRebuildCount++,
      );

      // Also verify the raw provider DOES fire (to prove the mutation happened).
      int rawNotifyCount = 0;
      container.listen(
        channelManagementStoreProvider,
        (_, __) => rawNotifyCount++,
      );

      final store = container.read(channelManagementStoreProvider.notifier)
          as _ControllableChannelManagementStore;
      store.setChannelIdDirect('ch-123');

      expect(rawNotifyCount, 1,
          reason: 'Raw provider MUST fire to confirm mutation occurred');
      expect(
        scaffoldRebuildCount,
        0,
        reason: 'channelId change with isBusy=false must NOT notify isBusy '
            'select — scaffold stays stable (INV-CHANNELS-MGMT-662-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: failure change (isBusy stays false) must NOT notify scaffold.
  // -------------------------------------------------------------------------
  test(
    'INV-CHANNELS-MGMT-662-SELECT-1: failure change does NOT notify '
    'isBusy select — scaffold stays stable',
    () async {
      final container = ProviderContainer(
        overrides: [
          channelManagementStoreProvider
              .overrideWith(() => _ControllableChannelManagementStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(channelManagementStoreProvider, (_, __) {});

      int scaffoldRebuildCount = 0;
      container.listen(
        channelManagementStoreProvider.select((s) => s.isBusy),
        (_, __) => scaffoldRebuildCount++,
      );

      int rawNotifyCount = 0;
      container.listen(
        channelManagementStoreProvider,
        (_, __) => rawNotifyCount++,
      );

      final store = container.read(channelManagementStoreProvider.notifier)
          as _ControllableChannelManagementStore;
      store.setFailureDirect(const NetworkFailure(message: 'test error'));

      expect(rawNotifyCount, 1,
          reason: 'Raw provider MUST fire to confirm mutation occurred');
      expect(
        scaffoldRebuildCount,
        0,
        reason: 'failure change with isBusy=false must NOT notify isBusy '
            'select — scaffold stays stable (INV-CHANNELS-MGMT-662-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: activeAction change (isBusy flips) DOES notify scaffold.
  // -------------------------------------------------------------------------
  test(
    'INV-CHANNELS-MGMT-662-SELECT-1: activeAction change (isBusy flips) '
    'DOES notify isBusy select',
    () async {
      final container = ProviderContainer(
        overrides: [
          channelManagementStoreProvider
              .overrideWith(() => _ControllableChannelManagementStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(channelManagementStoreProvider, (_, __) {});

      int scaffoldRebuildCount = 0;
      container.listen(
        channelManagementStoreProvider.select((s) => s.isBusy),
        (_, __) => scaffoldRebuildCount++,
      );

      final store = container.read(channelManagementStoreProvider.notifier)
          as _ControllableChannelManagementStore;
      store.setActiveActionDirect(ChannelManagementAction.create);

      expect(
        scaffoldRebuildCount,
        1,
        reason: 'activeAction change that flips isBusy must notify select',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T4: Multiple mutations — only isBusy-affecting ones trigger rebuild.
  // -------------------------------------------------------------------------
  test(
    'INV-CHANNELS-MGMT-662-SELECT-1: compound mutations — only isBusy flip '
    'triggers scaffold rebuild',
    () async {
      final container = ProviderContainer(
        overrides: [
          channelManagementStoreProvider
              .overrideWith(() => _ControllableChannelManagementStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(channelManagementStoreProvider, (_, __) {});

      int scaffoldRebuildCount = 0;
      container.listen(
        channelManagementStoreProvider.select((s) => s.isBusy),
        (_, __) => scaffoldRebuildCount++,
      );

      final store = container.read(channelManagementStoreProvider.notifier)
          as _ControllableChannelManagementStore;

      // 1. channelId change — no rebuild.
      store.setChannelIdDirect('ch-1');
      expect(scaffoldRebuildCount, 0);

      // 2. failure change — no rebuild.
      store.setFailureDirect(const NetworkFailure(message: 'err'));
      expect(scaffoldRebuildCount, 0);

      // 3. activeAction → create (isBusy flips true) — rebuild.
      store.setActiveActionDirect(ChannelManagementAction.create);
      expect(scaffoldRebuildCount, 1);

      // 4. channelId change while isBusy=true — no rebuild (isBusy unchanged).
      store.setChannelIdDirect('ch-2');
      expect(scaffoldRebuildCount, 1);

      // 5. activeAction → null (isBusy flips false) — rebuild.
      store.setActiveActionDirect(null);
      expect(scaffoldRebuildCount, 2);

      keepAlive.close();
    },
  );
}
