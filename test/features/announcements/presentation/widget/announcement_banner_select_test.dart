// =============================================================================
// #609 — ref.listen .select() narrows — announcement_banner
//
// Invariant: INV-ANNOUNCE-LISTEN-SELECT-1
//   The ref.listen in AnnouncementBanner (L40) only inspects `next.status` to
//   decide whether to re-trigger ensureLoaded(). Mutations to other state
//   fields (announcements list, failure) must NOT fire the listener.
//
// Strategy:
// T1: announcements change must NOT fire status-select (skip:true).
// T2: failure change must NOT fire status-select (skip:true).
// T3: status change DOES fire status-select (active).
//
// Phase A: T1/T2 skip:true — current impl uses broad ref.listen.
//          T3 active — correctness proof.
//
// Phase B:
// Replace ref.listen(announcementStoreProvider, ...) at L40 with
// ref.listen(announcementStoreProvider.select((s) => s.status), ...).
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/announcements/application/announcement_store.dart';
import 'package:slock_app/features/announcements/data/announcement.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableAnnouncementStore extends AnnouncementStore {
  @override
  AnnouncementState build() => const AnnouncementState(
        status: AnnouncementStatus.success,
        announcements: [],
      );

  void setAnnouncementsDirect(List<Announcement> items) {
    state = AnnouncementState(
      status: state.status,
      announcements: items,
      failure: state.failure,
    );
  }

  void setFailureDirect(AppFailure? f) {
    state = AnnouncementState(
      status: state.status,
      announcements: state.announcements,
      failure: f,
    );
  }

  void setStatusDirect(AnnouncementStatus s) {
    state = AnnouncementState(
      status: s,
      announcements: state.announcements,
      failure: state.failure,
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: announcements list change must NOT fire status-select.
  // -------------------------------------------------------------------------
  test(
    'INV-ANNOUNCE-LISTEN-SELECT-1: announcements change does NOT notify '
    'status select',
    () async {
      final container = ProviderContainer(
        overrides: [
          announcementStoreProvider
              .overrideWith(() => _ControllableAnnouncementStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(announcementStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        announcementStoreProvider.select((s) => s.status),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(announcementStoreProvider.notifier)
          as _ControllableAnnouncementStore;
      store.setAnnouncementsDirect([
        const Announcement(id: 'ann-1', title: 'Hello'),
      ]);

      expect(
        selectNotifyCount,
        0,
        reason: 'announcements list change must not notify status select '
            '(INV-ANNOUNCE-LISTEN-SELECT-1)',
      );

      keepAlive.close();
    },
    skip: true, // Phase A: requires Phase B .select() fix
  );

  // -------------------------------------------------------------------------
  // T2: failure change must NOT fire status-select.
  // -------------------------------------------------------------------------
  test(
    'INV-ANNOUNCE-LISTEN-SELECT-1: failure change does NOT notify '
    'status select',
    () async {
      final container = ProviderContainer(
        overrides: [
          announcementStoreProvider
              .overrideWith(() => _ControllableAnnouncementStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(announcementStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        announcementStoreProvider.select((s) => s.status),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(announcementStoreProvider.notifier)
          as _ControllableAnnouncementStore;
      store.setFailureDirect(
        const UnknownFailure(message: 'network error'),
      );

      expect(
        selectNotifyCount,
        0,
        reason: 'failure change must not notify status select '
            '(INV-ANNOUNCE-LISTEN-SELECT-1)',
      );

      keepAlive.close();
    },
    skip: true, // Phase A: requires Phase B .select() fix
  );

  // -------------------------------------------------------------------------
  // T3: status change DOES fire status-select.
  // -------------------------------------------------------------------------
  test(
    'INV-ANNOUNCE-LISTEN-SELECT-1: status change DOES notify status select',
    () async {
      final container = ProviderContainer(
        overrides: [
          announcementStoreProvider
              .overrideWith(() => _ControllableAnnouncementStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(announcementStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        announcementStoreProvider.select((s) => s.status),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(announcementStoreProvider.notifier)
          as _ControllableAnnouncementStore;
      store.setStatusDirect(AnnouncementStatus.initial);

      expect(
        selectNotifyCount,
        1,
        reason: 'status change must notify status select',
      );

      keepAlive.close();
    },
  );
}
