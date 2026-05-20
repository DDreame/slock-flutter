// =============================================================================
// #662 — ChannelsTabPage channelManagementStoreProvider .select(isBusy)
//
// Invariant: INV-CHANNELS-MGMT-662-SELECT-1
//   ChannelsTabPage.build() ref.watch(channelManagementStoreProvider) narrowed
//   to: s.isBusy (derived getter: activeAction != null).
//   Mutations to channelId or failure (while activeAction remains null) must
//   NOT trigger a rebuild.
//
// Strategy:
// T1: channelId change (while isBusy stays false) must NOT fire select.
// T2: failure change (while isBusy stays false) must NOT fire select.
// T3: activeAction change (null→create, isBusy flips true) DOES fire select.
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
  // T1: channelId change must NOT fire isBusy select.
  // -------------------------------------------------------------------------
  test(
    'INV-CHANNELS-MGMT-662-SELECT-1: channelId change does NOT notify '
    'isBusy select',
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

      int selectNotifyCount = 0;
      container.listen(
        channelManagementStoreProvider.select((s) => s.isBusy),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(channelManagementStoreProvider.notifier)
          as _ControllableChannelManagementStore;
      store.setChannelIdDirect('ch-123');

      expect(
        selectNotifyCount,
        0,
        reason: 'channelId change must not notify isBusy select '
            '(INV-CHANNELS-MGMT-662-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: failure change must NOT fire isBusy select.
  // -------------------------------------------------------------------------
  test(
    'INV-CHANNELS-MGMT-662-SELECT-1: failure change does NOT notify '
    'isBusy select',
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

      int selectNotifyCount = 0;
      container.listen(
        channelManagementStoreProvider.select((s) => s.isBusy),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(channelManagementStoreProvider.notifier)
          as _ControllableChannelManagementStore;
      store.setFailureDirect(const NetworkFailure(message: 'test error'));

      expect(
        selectNotifyCount,
        0,
        reason: 'failure change must not notify isBusy select '
            '(INV-CHANNELS-MGMT-662-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: activeAction change (isBusy flips) DOES fire select.
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

      int selectNotifyCount = 0;
      container.listen(
        channelManagementStoreProvider.select((s) => s.isBusy),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(channelManagementStoreProvider.notifier)
          as _ControllableChannelManagementStore;
      store.setActiveActionDirect(ChannelManagementAction.create);

      expect(
        selectNotifyCount,
        1,
        reason: 'activeAction change that flips isBusy must notify select',
      );

      keepAlive.close();
    },
  );
}
