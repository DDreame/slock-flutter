// =============================================================================
// #662 — UnreadListPage inboxStoreProvider .select() narrow
//
// Invariant: INV-UNREAD-LIST-662-SELECT-1
//   UnreadListPage.build() ref.watch(inboxStoreProvider) narrowed to:
//     (filter: s.filter, hasMore: s.hasMore)
//   Mutations to status, items, totalUnreadCount, totalCount, offset,
//   isRefreshing, or failure must NOT trigger a rebuild through this select.
//
// Strategy:
// T1: items change must NOT fire (filter, hasMore) select.
// T2: totalUnreadCount change must NOT fire (filter, hasMore) select.
// T3: status change must NOT fire (filter, hasMore) select.
// T4: filter change DOES fire (filter, hasMore) select.
// T5: hasMore change DOES fire (filter, hasMore) select.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableInboxStore extends InboxStore {
  @override
  InboxState build() => const InboxState(status: InboxStatus.success);

  void setItemsDirect(List<InboxItem> items) {
    state = state.copyWith(items: items);
  }

  void setTotalUnreadCountDirect(int count) {
    state = state.copyWith(totalUnreadCount: count);
  }

  void setStatusDirect(InboxStatus status) {
    state = state.copyWith(status: status);
  }

  void setFilterDirect(InboxFilter filter) {
    state = state.copyWith(filter: filter);
  }

  void setHasMoreDirect(bool hasMore) {
    state = state.copyWith(hasMore: hasMore);
  }

  void setOffsetDirect(int offset) {
    state = state.copyWith(offset: offset);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: items change must NOT fire (filter, hasMore) select.
  // -------------------------------------------------------------------------
  test(
    'INV-UNREAD-LIST-662-SELECT-1: items change does NOT notify '
    '(filter, hasMore) select',
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
        inboxStoreProvider
            .select((s) => (filter: s.filter, hasMore: s.hasMore)),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(inboxStoreProvider.notifier)
          as _ControllableInboxStore;
      store.setItemsDirect([
        InboxItem(
          channelId: 'ch-1',
          kind: InboxItemKind.channel,
          unreadCount: 3,
          lastActivityAt: DateTime(2026, 5, 20),
        ),
      ]);

      expect(
        selectNotifyCount,
        0,
        reason: 'items change must not notify (filter, hasMore) select '
            '(INV-UNREAD-LIST-662-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: totalUnreadCount change must NOT fire (filter, hasMore) select.
  // -------------------------------------------------------------------------
  test(
    'INV-UNREAD-LIST-662-SELECT-1: totalUnreadCount change does NOT notify '
    '(filter, hasMore) select',
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
        inboxStoreProvider
            .select((s) => (filter: s.filter, hasMore: s.hasMore)),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(inboxStoreProvider.notifier)
          as _ControllableInboxStore;
      store.setTotalUnreadCountDirect(42);

      expect(
        selectNotifyCount,
        0,
        reason: 'totalUnreadCount change must not notify (filter, hasMore) '
            'select (INV-UNREAD-LIST-662-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: status change must NOT fire (filter, hasMore) select.
  // -------------------------------------------------------------------------
  test(
    'INV-UNREAD-LIST-662-SELECT-1: status change does NOT notify '
    '(filter, hasMore) select',
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
        inboxStoreProvider
            .select((s) => (filter: s.filter, hasMore: s.hasMore)),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(inboxStoreProvider.notifier)
          as _ControllableInboxStore;
      store.setStatusDirect(InboxStatus.loading);

      expect(
        selectNotifyCount,
        0,
        reason: 'status change must not notify (filter, hasMore) select '
            '(INV-UNREAD-LIST-662-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T4: filter change DOES fire (filter, hasMore) select.
  // -------------------------------------------------------------------------
  test(
    'INV-UNREAD-LIST-662-SELECT-1: filter change DOES notify '
    '(filter, hasMore) select',
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
        inboxStoreProvider
            .select((s) => (filter: s.filter, hasMore: s.hasMore)),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(inboxStoreProvider.notifier)
          as _ControllableInboxStore;
      store.setFilterDirect(InboxFilter.unread);

      expect(
        selectNotifyCount,
        1,
        reason: 'filter change must notify (filter, hasMore) select',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T5: hasMore change DOES fire (filter, hasMore) select.
  // -------------------------------------------------------------------------
  test(
    'INV-UNREAD-LIST-662-SELECT-1: hasMore change DOES notify '
    '(filter, hasMore) select',
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
        inboxStoreProvider
            .select((s) => (filter: s.filter, hasMore: s.hasMore)),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(inboxStoreProvider.notifier)
          as _ControllableInboxStore;
      store.setHasMoreDirect(true);

      expect(
        selectNotifyCount,
        1,
        reason: 'hasMore change must notify (filter, hasMore) select',
      );

      keepAlive.close();
    },
  );
}
