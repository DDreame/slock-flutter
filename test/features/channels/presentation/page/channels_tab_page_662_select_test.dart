// =============================================================================
// #662 — ChannelsTabPage channelManagementStoreProvider .select(isBusy)
//        (widget-path)
//
// Invariant: INV-CHANNELS-MGMT-662-SELECT-1
//   ChannelsTabPage.build() watches channelManagementStoreProvider narrowed
//   to s.isBusy. Mutations to channelId or failure (while activeAction remains
//   null -> isBusy stays false) must NOT trigger a widget rebuild.
//
// Strategy (widget-path tests using pumpWidget + Consumer rebuild counters):
// T1: channelId change (isBusy stays false) must NOT rebuild scaffold.
// T2: failure change (isBusy stays false) must NOT rebuild scaffold.
// T3: activeAction change (isBusy flips true) DOES rebuild scaffold.
// T4: compound mutations — only isBusy-affecting ones trigger rebuild.
//
// Each test renders a ConsumerWidget via pumpWidget that uses the EXACT
// .select((s) => s.isBusy) expression from the production code, counting
// widget-level rebuilds.
// =============================================================================

import 'package:flutter/material.dart';
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
// Widget-path test harness
//
// Renders a ConsumerWidget that uses the EXACT .select() expression from
// ChannelsTabPage.build():
//   ref.watch(channelManagementStoreProvider.select((s) => s.isBusy))
// ---------------------------------------------------------------------------

class _IsBusySelectConsumer extends ConsumerWidget {
  const _IsBusySelectConsumer({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(channelManagementStoreProvider.select((s) => s.isBusy));
    onBuild();
    return const SizedBox.shrink();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: channelId change (isBusy stays false) must NOT rebuild scaffold.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-CHANNELS-MGMT-662-SELECT-1: channelId change does NOT rebuild '
    'isBusy select widget — scaffold stays stable',
    (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            channelManagementStoreProvider
                .overrideWith(() => _ControllableChannelManagementStore()),
          ],
          child: MaterialApp(
            home: _IsBusySelectConsumer(onBuild: () => buildCount++),
          ),
        ),
      );

      expect(buildCount, 1);

      final element = tester.element(find.byType(_IsBusySelectConsumer));
      final container = ProviderScope.containerOf(element);
      final store = container.read(channelManagementStoreProvider.notifier)
          as _ControllableChannelManagementStore;

      store.setChannelIdDirect('ch-123');
      await tester.pump();

      expect(
        buildCount,
        1,
        reason: 'channelId change with isBusy=false must NOT rebuild widget '
            '(INV-CHANNELS-MGMT-662-SELECT-1)',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T2: failure change (isBusy stays false) must NOT rebuild scaffold.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-CHANNELS-MGMT-662-SELECT-1: failure change does NOT rebuild '
    'isBusy select widget — scaffold stays stable',
    (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            channelManagementStoreProvider
                .overrideWith(() => _ControllableChannelManagementStore()),
          ],
          child: MaterialApp(
            home: _IsBusySelectConsumer(onBuild: () => buildCount++),
          ),
        ),
      );

      expect(buildCount, 1);

      final element = tester.element(find.byType(_IsBusySelectConsumer));
      final container = ProviderScope.containerOf(element);
      final store = container.read(channelManagementStoreProvider.notifier)
          as _ControllableChannelManagementStore;

      store.setFailureDirect(const NetworkFailure(message: 'test error'));
      await tester.pump();

      expect(
        buildCount,
        1,
        reason: 'failure change with isBusy=false must NOT rebuild widget '
            '(INV-CHANNELS-MGMT-662-SELECT-1)',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T3: activeAction change (isBusy flips true) DOES rebuild scaffold.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-CHANNELS-MGMT-662-SELECT-1: activeAction change (isBusy flips) '
    'DOES rebuild isBusy select widget',
    (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            channelManagementStoreProvider
                .overrideWith(() => _ControllableChannelManagementStore()),
          ],
          child: MaterialApp(
            home: _IsBusySelectConsumer(onBuild: () => buildCount++),
          ),
        ),
      );

      expect(buildCount, 1);

      final element = tester.element(find.byType(_IsBusySelectConsumer));
      final container = ProviderScope.containerOf(element);
      final store = container.read(channelManagementStoreProvider.notifier)
          as _ControllableChannelManagementStore;

      store.setActiveActionDirect(ChannelManagementAction.create);
      await tester.pump();

      expect(
        buildCount,
        2,
        reason: 'activeAction change that flips isBusy must rebuild widget',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T4: Multiple mutations — only isBusy-affecting ones trigger rebuild.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-CHANNELS-MGMT-662-SELECT-1: compound mutations — only isBusy flip '
    'triggers widget rebuild',
    (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            channelManagementStoreProvider
                .overrideWith(() => _ControllableChannelManagementStore()),
          ],
          child: MaterialApp(
            home: _IsBusySelectConsumer(onBuild: () => buildCount++),
          ),
        ),
      );

      expect(buildCount, 1);

      final element = tester.element(find.byType(_IsBusySelectConsumer));
      final container = ProviderScope.containerOf(element);
      final store = container.read(channelManagementStoreProvider.notifier)
          as _ControllableChannelManagementStore;

      // 1. channelId change — no rebuild.
      store.setChannelIdDirect('ch-1');
      await tester.pump();
      expect(buildCount, 1);

      // 2. failure change — no rebuild.
      store.setFailureDirect(const NetworkFailure(message: 'err'));
      await tester.pump();
      expect(buildCount, 1);

      // 3. activeAction -> create (isBusy flips true) — rebuild.
      store.setActiveActionDirect(ChannelManagementAction.create);
      await tester.pump();
      expect(buildCount, 2);

      // 4. channelId change while isBusy=true — no rebuild (isBusy unchanged).
      store.setChannelIdDirect('ch-2');
      await tester.pump();
      expect(buildCount, 2);

      // 5. activeAction -> null (isBusy flips false) — rebuild.
      store.setActiveActionDirect(null);
      await tester.pump();
      expect(buildCount, 3);
    },
  );
}
