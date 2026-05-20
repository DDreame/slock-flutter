// =============================================================================
// #662 — UnreadListPage inboxStoreProvider .select() narrow
//
// Invariant: INV-UNREAD-LIST-662-SELECT-1
//   UnreadListPage.build() watches inboxStoreProvider narrowed to:
//     (filter: s.filter, hasMore: s.hasMore)
//   Mutations to status, items, totalUnreadCount, totalCount, offset,
//   isRefreshing, or failure must NOT trigger a rebuild through this select.
//
// The page also watches unreadSourceProjectionProvider for the list content,
// ensuring items-level changes flow through the projection (not the scaffold
// select).
//
// Strategy:
// T1: items change must NOT fire (filter, hasMore) select.
// T2: totalUnreadCount change must NOT fire (filter, hasMore) select.
// T3: status change must NOT fire (filter, hasMore) select.
// T4: filter change DOES fire (filter, hasMore) select.
// T5: hasMore change DOES fire (filter, hasMore) select.
// T6: compound mutations — only filter/hasMore changes trigger scaffold.
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

  void setIsRefreshingDirect(bool value) {
    state = state.copyWith(isRefreshing: value);
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
    '(filter, hasMore) select — scaffold stays stable',
    () async {
      final container = ProviderContainer(
        overrides: [
          inboxStoreProvider.overrideWith(() => _ControllableInboxStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(inboxStoreProvider, (_, __) {});

      // This is the EXACT select expression from unread_list_page.dart:
      //   ref.watch(inboxStoreProvider.select(
      //     (s) => (filter: s.filter, hasMore: s.hasMore)))
      int scaffoldRebuildCount = 0;
      container.listen(
        inboxStoreProvider
            .select((s) => (filter: s.filter, hasMore: s.hasMore)),
        (_, __) => scaffoldRebuildCount++,
      );

      // Also verify the raw provider DOES fire.
      int rawNotifyCount = 0;
      container.listen(
        inboxStoreProvider,
        (_, __) => rawNotifyCount++,
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

      expect(rawNotifyCount, 1,
          reason: 'Raw provider MUST fire to confirm mutation occurred');
      expect(
        scaffoldRebuildCount,
        0,
        reason: 'items change must not notify (filter, hasMore) select '
            '— scaffold stays stable (INV-UNREAD-LIST-662-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: totalUnreadCount change must NOT fire (filter, hasMore) select.
  // -------------------------------------------------------------------------
  test(
    'INV-UNREAD-LIST-662-SELECT-1: totalUnreadCount change does NOT notify '
    '(filter, hasMore) select — scaffold stays stable',
    () async {
      final container = ProviderContainer(
        overrides: [
          inboxStoreProvider.overrideWith(() => _ControllableInboxStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(inboxStoreProvider, (_, __) {});

      int scaffoldRebuildCount = 0;
      container.listen(
        inboxStoreProvider
            .select((s) => (filter: s.filter, hasMore: s.hasMore)),
        (_, __) => scaffoldRebuildCount++,
      );

      int rawNotifyCount = 0;
      container.listen(
        inboxStoreProvider,
        (_, __) => rawNotifyCount++,
      );

      final store = container.read(inboxStoreProvider.notifier)
          as _ControllableInboxStore;
      store.setTotalUnreadCountDirect(42);

      expect(rawNotifyCount, 1,
          reason: 'Raw provider MUST fire to confirm mutation occurred');
      expect(
        scaffoldRebuildCount,
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
    '(filter, hasMore) select — scaffold stays stable',
    () async {
      final container = ProviderContainer(
        overrides: [
          inboxStoreProvider.overrideWith(() => _ControllableInboxStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(inboxStoreProvider, (_, __) {});

      int scaffoldRebuildCount = 0;
      container.listen(
        inboxStoreProvider
            .select((s) => (filter: s.filter, hasMore: s.hasMore)),
        (_, __) => scaffoldRebuildCount++,
      );

      int rawNotifyCount = 0;
      container.listen(
        inboxStoreProvider,
        (_, __) => rawNotifyCount++,
      );

      final store = container.read(inboxStoreProvider.notifier)
          as _ControllableInboxStore;
      store.setStatusDirect(InboxStatus.loading);

      expect(rawNotifyCount, 1,
          reason: 'Raw provider MUST fire to confirm mutation occurred');
      expect(
        scaffoldRebuildCount,
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

      int scaffoldRebuildCount = 0;
      container.listen(
        inboxStoreProvider
            .select((s) => (filter: s.filter, hasMore: s.hasMore)),
        (_, __) => scaffoldRebuildCount++,
      );

      final store = container.read(inboxStoreProvider.notifier)
          as _ControllableInboxStore;
      store.setFilterDirect(InboxFilter.unread);

      expect(
        scaffoldRebuildCount,
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

      int scaffoldRebuildCount = 0;
      container.listen(
        inboxStoreProvider
            .select((s) => (filter: s.filter, hasMore: s.hasMore)),
        (_, __) => scaffoldRebuildCount++,
      );

      final store = container.read(inboxStoreProvider.notifier)
          as _ControllableInboxStore;
      store.setHasMoreDirect(true);

      expect(
        scaffoldRebuildCount,
        1,
        reason: 'hasMore change must notify (filter, hasMore) select',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T6: Compound mutations — only filter/hasMore trigger scaffold.
  // -------------------------------------------------------------------------
  test(
    'INV-UNREAD-LIST-662-SELECT-1: compound mutations — only filter/hasMore '
    'changes trigger scaffold rebuild',
    () async {
      final container = ProviderContainer(
        overrides: [
          inboxStoreProvider.overrideWith(() => _ControllableInboxStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(inboxStoreProvider, (_, __) {});

      int scaffoldRebuildCount = 0;
      container.listen(
        inboxStoreProvider
            .select((s) => (filter: s.filter, hasMore: s.hasMore)),
        (_, __) => scaffoldRebuildCount++,
      );

      final store = container.read(inboxStoreProvider.notifier)
          as _ControllableInboxStore;

      // 1. items change — no rebuild.
      store.setItemsDirect([
        InboxItem(
          channelId: 'ch-1',
          kind: InboxItemKind.channel,
          unreadCount: 5,
          lastActivityAt: DateTime(2026, 5, 20),
        ),
      ]);
      expect(scaffoldRebuildCount, 0);

      // 2. status change — no rebuild.
      store.setStatusDirect(InboxStatus.loading);
      expect(scaffoldRebuildCount, 0);

      // 3. totalUnreadCount change — no rebuild.
      store.setTotalUnreadCountDirect(99);
      expect(scaffoldRebuildCount, 0);

      // 4. offset change — no rebuild.
      store.setOffsetDirect(30);
      expect(scaffoldRebuildCount, 0);

      // 5. isRefreshing change — no rebuild.
      store.setIsRefreshingDirect(true);
      expect(scaffoldRebuildCount, 0);

      // 6. filter change — rebuild.
      store.setFilterDirect(InboxFilter.unread);
      expect(scaffoldRebuildCount, 1);

      // 7. hasMore change — rebuild.
      store.setHasMoreDirect(true);
      expect(scaffoldRebuildCount, 2);

      keepAlive.close();
    },
  );
}
