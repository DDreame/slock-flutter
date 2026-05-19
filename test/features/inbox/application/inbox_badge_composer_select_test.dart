// =============================================================================
// #622 — Inbox badge providers + composer settings .select()
//
// Invariant: INV-INBOX-BADGE-SELECT-1
//   inboxTotalUnreadCountProvider at inbox_unread_count_provider.dart L10
//   calls ref.watch(inboxStoreProvider) — the full ~9-field state.
//   The provider only consumes status + totalUnreadCount. Mutations to
//   filter, isRefreshing, failure, offset, hasMore MUST NOT recompute badges.
//
// Invariant: INV-INBOX-CHANNEL-BADGE-SELECT-1
//   inboxChannelUnreadTotalProvider at L20 calls ref.watch(inboxStoreProvider).
//   Only consumes status + items. Same exclusion applies.
//
// Invariant: INV-INBOX-DM-BADGE-SELECT-1
//   inboxDmUnreadTotalProvider at L36 calls ref.watch(inboxStoreProvider).
//   Only consumes status + items. Same exclusion applies.
//
// Invariant: INV-COMPOSER-SETTINGS-SELECT-1
//   conversation_detail_page.dart L528 calls
//   ref.watch(composerSettingsStoreProvider).enterToSend — watches full state.
//   Only enterToSend is consumed. Future settings additions must NOT trigger
//   scaffold rebuild.
//
// Strategy:
// T1: filter change must NOT fire total unread badge select (skip:true).
// T2: isRefreshing change must NOT fire total unread badge select (skip:true).
// T3: totalUnreadCount change DOES fire total unread badge select (active).
// T4: filter change must NOT fire channel badge select (skip:true).
// T5: items change DOES fire channel badge select (active).
// T6: composerSettings enterToSend select proof (active — only 1 field now).
//
// Phase A: T1/T2/T4 skip:true — current impl watches full state.
//          T3/T5/T6 active — correctness proof.
//
// Phase B:
// - inboxTotalUnreadCountProvider: .select((s) => (status, totalUnreadCount))
// - inboxChannelUnreadTotalProvider: .select((s) => (status, items))
// - inboxDmUnreadTotalProvider: .select((s) => (status, items))
// - conversation_detail_page.dart L528: .select((s) => s.enterToSend)
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/stores/composer/composer_settings_store.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableInboxStore extends InboxStore {
  @override
  InboxState build() => const InboxState(
        status: InboxStatus.success,
        totalUnreadCount: 5,
        items: [
          InboxItem(
            channelId: 'ch-1',
            kind: InboxItemKind.channel,
            channelName: 'general',
            unreadCount: 3,
          ),
          InboxItem(
            channelId: 'dm-1',
            kind: InboxItemKind.dm,
            channelName: 'alice',
            unreadCount: 2,
          ),
        ],
      );

  void setFilterDirect(InboxFilter filter) {
    state = state.copyWith(filter: filter);
  }

  void setIsRefreshingDirect(bool value) {
    state = state.copyWith(isRefreshing: value);
  }

  void setTotalUnreadCountDirect(int count) {
    state = state.copyWith(totalUnreadCount: count);
  }

  void setItemsDirect(List<InboxItem> items) {
    state = state.copyWith(items: items);
  }
}

class _ControllableComposerSettingsStore extends ComposerSettingsStore {
  @override
  ComposerSettingsState build() => const ComposerSettingsState();

  void setEnterToSendDirect(bool value) {
    state = state.copyWith(enterToSend: value);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // Inbox total unread badge — INV-INBOX-BADGE-SELECT-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T1: filter change must NOT fire total unread badge select.
  // -------------------------------------------------------------------------
  test(
    'INV-INBOX-BADGE-SELECT-1: filter change does NOT notify '
    '(status, totalUnreadCount) select',
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
          (s) => (status: s.status, totalUnreadCount: s.totalUnreadCount),
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
            '(status, totalUnreadCount) select '
            '(INV-INBOX-BADGE-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: isRefreshing change must NOT fire total unread badge select.
  // -------------------------------------------------------------------------
  test(
    'INV-INBOX-BADGE-SELECT-1: isRefreshing change does NOT notify '
    '(status, totalUnreadCount) select',
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
          (s) => (status: s.status, totalUnreadCount: s.totalUnreadCount),
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
            '(status, totalUnreadCount) select '
            '(INV-INBOX-BADGE-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: totalUnreadCount change DOES fire total unread badge select.
  // -------------------------------------------------------------------------
  test(
    'INV-INBOX-BADGE-SELECT-1: totalUnreadCount change DOES notify '
    '(status, totalUnreadCount) select',
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
          (s) => (status: s.status, totalUnreadCount: s.totalUnreadCount),
        ),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(inboxStoreProvider.notifier)
          as _ControllableInboxStore;
      store.setTotalUnreadCountDirect(10);

      expect(
        selectNotifyCount,
        1,
        reason: 'totalUnreadCount change must notify '
            '(status, totalUnreadCount) select',
      );

      keepAlive.close();
    },
  );

  // =========================================================================
  // Inbox channel badge — INV-INBOX-CHANNEL-BADGE-SELECT-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T4: filter change must NOT fire channel badge select.
  // -------------------------------------------------------------------------
  test(
    'INV-INBOX-CHANNEL-BADGE-SELECT-1: filter change does NOT notify '
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
      store.setFilterDirect(InboxFilter.mentions);

      expect(
        selectNotifyCount,
        0,
        reason: 'filter change must not notify '
            '(status, items) select '
            '(INV-INBOX-CHANNEL-BADGE-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T5: items change DOES fire channel badge select.
  // -------------------------------------------------------------------------
  test(
    'INV-INBOX-CHANNEL-BADGE-SELECT-1: items change DOES notify '
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
          channelId: 'ch-1',
          kind: InboxItemKind.channel,
          channelName: 'general',
          unreadCount: 7,
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

  // =========================================================================
  // Composer settings — INV-COMPOSER-SETTINGS-SELECT-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T6: enterToSend select correctness proof.
  // -------------------------------------------------------------------------
  test(
    'INV-COMPOSER-SETTINGS-SELECT-1: enterToSend change DOES notify '
    'enterToSend select',
    () async {
      final container = ProviderContainer(
        overrides: [
          composerSettingsStoreProvider
              .overrideWith(() => _ControllableComposerSettingsStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(composerSettingsStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        composerSettingsStoreProvider.select((s) => s.enterToSend),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(composerSettingsStoreProvider.notifier)
          as _ControllableComposerSettingsStore;
      store.setEnterToSendDirect(true);

      expect(
        selectNotifyCount,
        1,
        reason: 'enterToSend change must notify enterToSend select',
      );

      keepAlive.close();
    },
  );
}
