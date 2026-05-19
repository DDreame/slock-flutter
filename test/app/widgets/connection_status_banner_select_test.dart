// =============================================================================
// #611 — realtimeServiceProvider .select() — connection_status_banner
//
// Invariant: INV-REALTIME-SELECT-1
//   ConnectionStatusBanner must only rebuild when `status` changes, not on
//   other RealtimeConnectionState mutations (lastAnyEventAt, lastHeartbeatAt,
//   reconnectAttempts, etc.).
//
// Strategy:
// T1: lastAnyEventAt change must NOT fire status-select (skip:true).
// T2: lastHeartbeatAt change must NOT fire status-select (skip:true).
// T3: status change DOES fire status-select (active).
//
// Phase A: T1/T2 skip:true — current impl uses broad ref.watch.
//          T3 active — correctness proof.
//
// Phase B:
// Replace ref.watch(realtimeServiceProvider) at connection_status_banner.dart
// L18 with ref.watch(realtimeServiceProvider.select((s) => s.status)).
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableRealtimeService extends RealtimeService {
  @override
  RealtimeConnectionState build() => const RealtimeConnectionState(
        status: RealtimeConnectionStatus.connected,
      );

  void setLastAnyEventAtDirect(DateTime time) {
    state = state.copyWith(lastAnyEventAt: time);
  }

  void setLastHeartbeatAtDirect(DateTime time) {
    state = state.copyWith(lastHeartbeatAt: time);
  }

  void setStatusDirect(RealtimeConnectionStatus status) {
    state = state.copyWith(status: status);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: lastAnyEventAt change must NOT fire status-select.
  // -------------------------------------------------------------------------
  test(
    'INV-REALTIME-SELECT-1: lastAnyEventAt change does NOT notify '
    'status select',
    () async {
      final container = ProviderContainer(
        overrides: [
          realtimeServiceProvider
              .overrideWith(() => _ControllableRealtimeService()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(realtimeServiceProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        realtimeServiceProvider.select((s) => s.status),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(realtimeServiceProvider.notifier)
          as _ControllableRealtimeService;
      store.setLastAnyEventAtDirect(DateTime(2026, 5, 19, 10, 0, 0));

      expect(
        selectNotifyCount,
        0,
        reason: 'lastAnyEventAt change must not notify status select '
            '(INV-REALTIME-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: lastHeartbeatAt change must NOT fire status-select.
  // -------------------------------------------------------------------------
  test(
    'INV-REALTIME-SELECT-1: lastHeartbeatAt change does NOT notify '
    'status select',
    () async {
      final container = ProviderContainer(
        overrides: [
          realtimeServiceProvider
              .overrideWith(() => _ControllableRealtimeService()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(realtimeServiceProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        realtimeServiceProvider.select((s) => s.status),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(realtimeServiceProvider.notifier)
          as _ControllableRealtimeService;
      store.setLastHeartbeatAtDirect(DateTime(2026, 5, 19, 10, 0, 0));

      expect(
        selectNotifyCount,
        0,
        reason: 'lastHeartbeatAt change must not notify status select '
            '(INV-REALTIME-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: status change DOES fire status-select.
  // -------------------------------------------------------------------------
  test(
    'INV-REALTIME-SELECT-1: status change DOES notify status select',
    () async {
      final container = ProviderContainer(
        overrides: [
          realtimeServiceProvider
              .overrideWith(() => _ControllableRealtimeService()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(realtimeServiceProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        realtimeServiceProvider.select((s) => s.status),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(realtimeServiceProvider.notifier)
          as _ControllableRealtimeService;
      store.setStatusDirect(RealtimeConnectionStatus.disconnected);

      expect(
        selectNotifyCount,
        1,
        reason: 'status change must notify status select',
      );

      keepAlive.close();
    },
  );
}
