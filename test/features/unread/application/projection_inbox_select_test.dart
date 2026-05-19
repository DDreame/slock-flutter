// =============================================================================
// #625 — Foundational provider + projection .select() — tree-wide cascade
//
// Invariant: INV-ACTIVE-SERVER-SCOPE-SELECT-1
//   active_server_scope_provider.dart L6 calls
//   ref.watch(serverSelectionStoreProvider).selectedServerId — watches the
//   full ServerSelectionState. While currently single-field, the .select()
//   documents the contract and future-proofs against state expansion.
//
// Invariant: INV-PROJECTION-INBOX-SELECT-1
//   unread_source_projection_store.dart L29 calls
//   ref.watch(inboxStoreProvider) — the full ~9-field state.
//   The provider only consumes status + items. Mutations to filter,
//   isRefreshing, totalUnreadCount, totalCount, hasMore, offset, failure
//   MUST NOT trigger full projection recomputation.
//
//   inboxProjectionProvider at L70 has the same issue.
//
// Strategy:
// T1: activeServerScopeIdProvider .select() correctness proof (active).
// T2: isRefreshing change must NOT fire projection (status, items) select
//     (skip:true).
// T3: filter change must NOT fire projection (status, items) select
//     (skip:true).
// T4: status change DOES fire projection (status, items) select (active).
// T5: items change DOES fire projection (status, items) select (active).
//
// Phase A: T2/T3 skip:true — current impl watches full inboxStoreProvider.
//          T1/T4/T5 active — correctness proof.
//
// Phase B:
// - active_server_scope_provider.dart L6:
//     .select((s) => s.selectedServerId)
// - unread_source_projection_store.dart L29:
//     .select((s) => (status: s.status, items: s.items))
// - unread_source_projection_store.dart L70:
//     .select((s) => (status: s.status, items: s.items))
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/stores/server_selection/server_selection_state.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableServerSelectionStore extends ServerSelectionStore {
  @override
  ServerSelectionState build() => const ServerSelectionState(
        selectedServerId: 'srv-1',
      );

  void setSelectedServerIdDirect(String? id) {
    if (id == null) {
      state = state.copyWith(clearSelectedServerId: true);
    } else {
      state = state.copyWith(selectedServerId: id);
    }
  }
}

class _ControllableInboxStore extends InboxStore {
  @override
  InboxState build() => const InboxState(
        status: InboxStatus.success,
        items: [
          InboxItem(
            channelId: 'ch-1',
            kind: InboxItemKind.channel,
            channelName: 'general',
            unreadCount: 3,
          ),
        ],
      );

  void setIsRefreshingDirect(bool value) {
    state = state.copyWith(isRefreshing: value);
  }

  void setFilterDirect(InboxFilter filter) {
    state = state.copyWith(filter: filter);
  }

  void setStatusDirect(InboxStatus status) {
    state = state.copyWith(status: status);
  }

  void setItemsDirect(List<InboxItem> items) {
    state = state.copyWith(items: items);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // Active server scope — INV-ACTIVE-SERVER-SCOPE-SELECT-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T1: selectedServerId select correctness proof.
  // -------------------------------------------------------------------------
  test(
    'INV-ACTIVE-SERVER-SCOPE-SELECT-1: selectedServerId change DOES notify '
    'selectedServerId select',
    () async {
      final container = ProviderContainer(
        overrides: [
          serverSelectionStoreProvider
              .overrideWith(() => _ControllableServerSelectionStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(serverSelectionStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        serverSelectionStoreProvider.select((s) => s.selectedServerId),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(serverSelectionStoreProvider.notifier)
          as _ControllableServerSelectionStore;
      store.setSelectedServerIdDirect('srv-2');

      expect(
        selectNotifyCount,
        1,
        reason: 'selectedServerId change must notify selectedServerId select',
      );

      keepAlive.close();
    },
  );

  // =========================================================================
  // Projection inbox select — INV-PROJECTION-INBOX-SELECT-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T2: isRefreshing change must NOT fire projection (status, items) select.
  // -------------------------------------------------------------------------
  test(
    'INV-PROJECTION-INBOX-SELECT-1: isRefreshing change does NOT notify '
    '(status, items) select',
    skip: true,
    () async {
      final container = ProviderContainer(
        overrides: [
          inboxStoreProvider.overrideWith(() => _ControllableInboxStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(inboxStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        inboxStoreProvider.select(
          (s) => (status: s.status, items: s.items),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(inboxStoreProvider.notifier)
          as _ControllableInboxStore;
      store.setIsRefreshingDirect(true);

      expect(
        selectNotifyCount,
        0,
        reason: 'isRefreshing change must not notify '
            '(status, items) select '
            '(INV-PROJECTION-INBOX-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: filter change must NOT fire projection (status, items) select.
  // -------------------------------------------------------------------------
  test(
    'INV-PROJECTION-INBOX-SELECT-1: filter change does NOT notify '
    '(status, items) select',
    skip: true,
    () async {
      final container = ProviderContainer(
        overrides: [
          inboxStoreProvider.overrideWith(() => _ControllableInboxStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(inboxStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        inboxStoreProvider.select(
          (s) => (status: s.status, items: s.items),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(inboxStoreProvider.notifier)
          as _ControllableInboxStore;
      store.setFilterDirect(InboxFilter.mentions);

      expect(
        selectNotifyCount,
        0,
        reason: 'filter change must not notify '
            '(status, items) select '
            '(INV-PROJECTION-INBOX-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T4: status change DOES fire projection (status, items) select.
  // -------------------------------------------------------------------------
  test(
    'INV-PROJECTION-INBOX-SELECT-1: status change DOES notify '
    '(status, items) select',
    () async {
      final container = ProviderContainer(
        overrides: [
          inboxStoreProvider.overrideWith(() => _ControllableInboxStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(inboxStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        inboxStoreProvider.select(
          (s) => (status: s.status, items: s.items),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(inboxStoreProvider.notifier)
          as _ControllableInboxStore;
      store.setStatusDirect(InboxStatus.loading);

      expect(
        selectNotifyCount,
        1,
        reason: 'status change must notify (status, items) select',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T5: items change DOES fire projection (status, items) select.
  // -------------------------------------------------------------------------
  test(
    'INV-PROJECTION-INBOX-SELECT-1: items change DOES notify '
    '(status, items) select',
    () async {
      final container = ProviderContainer(
        overrides: [
          inboxStoreProvider.overrideWith(() => _ControllableInboxStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(inboxStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        inboxStoreProvider.select(
          (s) => (status: s.status, items: s.items),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(inboxStoreProvider.notifier)
          as _ControllableInboxStore;
      store.setItemsDirect([
        const InboxItem(
          channelId: 'ch-2',
          kind: InboxItemKind.dm,
          channelName: 'bob',
          unreadCount: 1,
        ),
      ]);

      expect(
        selectNotifyCount,
        1,
        reason: 'items change must notify (status, items) select',
      );

      keepAlive.close();
    },
  );
}
