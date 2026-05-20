// =============================================================================
// #662 — UnreadListPage inboxStoreProvider .select() narrow (widget-path)
//
// Invariant: INV-UNREAD-LIST-662-SELECT-1
//   UnreadListPage.build() watches inboxStoreProvider narrowed to:
//     (filter: s.filter, hasMore: s.hasMore)
//   Mutations to status, items, totalUnreadCount, totalCount, offset,
//   isRefreshing, or failure must NOT trigger a widget rebuild through this
//   select.
//
// Strategy (widget-path tests using pumpWidget + Consumer rebuild counters):
// T1: items change must NOT rebuild (filter, hasMore) select widget.
// T2: totalUnreadCount change must NOT rebuild (filter, hasMore) select widget.
// T3: status change must NOT rebuild (filter, hasMore) select widget.
// T4: filter change DOES rebuild (filter, hasMore) select widget.
// T5: hasMore change DOES rebuild (filter, hasMore) select widget.
// T6: compound mutations — only filter/hasMore changes trigger rebuild.
//
// Each test renders a ConsumerWidget via pumpWidget that uses the EXACT
// .select((s) => (filter: s.filter, hasMore: s.hasMore)) expression from
// the production code, counting widget-level rebuilds.
// =============================================================================

import 'package:flutter/material.dart';
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
// Widget-path test harness
//
// Renders a ConsumerWidget that uses the EXACT .select() expression from
// UnreadListPage.build():
//   ref.watch(inboxStoreProvider.select(
//     (s) => (filter: s.filter, hasMore: s.hasMore)))
// ---------------------------------------------------------------------------

class _FilterHasMoreSelectConsumer extends ConsumerWidget {
  const _FilterHasMoreSelectConsumer({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(
      inboxStoreProvider.select((s) => (filter: s.filter, hasMore: s.hasMore)),
    );
    onBuild();
    return const SizedBox.shrink();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: items change must NOT rebuild (filter, hasMore) select widget.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-UNREAD-LIST-662-SELECT-1: items change does NOT rebuild '
    '(filter, hasMore) select widget — scaffold stays stable',
    (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inboxStoreProvider.overrideWith(() => _ControllableInboxStore()),
          ],
          child: MaterialApp(
            home: _FilterHasMoreSelectConsumer(onBuild: () => buildCount++),
          ),
        ),
      );

      expect(buildCount, 1);

      final element = tester.element(find.byType(_FilterHasMoreSelectConsumer));
      final container = ProviderScope.containerOf(element);
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
      await tester.pump();

      expect(
        buildCount,
        1,
        reason: 'items change must not rebuild (filter, hasMore) select '
            'widget — scaffold stays stable (INV-UNREAD-LIST-662-SELECT-1)',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T2: totalUnreadCount change must NOT rebuild (filter, hasMore) select
  //     widget.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-UNREAD-LIST-662-SELECT-1: totalUnreadCount change does NOT rebuild '
    '(filter, hasMore) select widget — scaffold stays stable',
    (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inboxStoreProvider.overrideWith(() => _ControllableInboxStore()),
          ],
          child: MaterialApp(
            home: _FilterHasMoreSelectConsumer(onBuild: () => buildCount++),
          ),
        ),
      );

      expect(buildCount, 1);

      final element = tester.element(find.byType(_FilterHasMoreSelectConsumer));
      final container = ProviderScope.containerOf(element);
      final store = container.read(inboxStoreProvider.notifier)
          as _ControllableInboxStore;

      store.setTotalUnreadCountDirect(42);
      await tester.pump();

      expect(
        buildCount,
        1,
        reason: 'totalUnreadCount change must not rebuild (filter, hasMore) '
            'select widget (INV-UNREAD-LIST-662-SELECT-1)',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T3: status change must NOT rebuild (filter, hasMore) select widget.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-UNREAD-LIST-662-SELECT-1: status change does NOT rebuild '
    '(filter, hasMore) select widget — scaffold stays stable',
    (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inboxStoreProvider.overrideWith(() => _ControllableInboxStore()),
          ],
          child: MaterialApp(
            home: _FilterHasMoreSelectConsumer(onBuild: () => buildCount++),
          ),
        ),
      );

      expect(buildCount, 1);

      final element = tester.element(find.byType(_FilterHasMoreSelectConsumer));
      final container = ProviderScope.containerOf(element);
      final store = container.read(inboxStoreProvider.notifier)
          as _ControllableInboxStore;

      store.setStatusDirect(InboxStatus.loading);
      await tester.pump();

      expect(
        buildCount,
        1,
        reason: 'status change must not rebuild (filter, hasMore) select '
            'widget (INV-UNREAD-LIST-662-SELECT-1)',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T4: filter change DOES rebuild (filter, hasMore) select widget.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-UNREAD-LIST-662-SELECT-1: filter change DOES rebuild '
    '(filter, hasMore) select widget',
    (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inboxStoreProvider.overrideWith(() => _ControllableInboxStore()),
          ],
          child: MaterialApp(
            home: _FilterHasMoreSelectConsumer(onBuild: () => buildCount++),
          ),
        ),
      );

      expect(buildCount, 1);

      final element = tester.element(find.byType(_FilterHasMoreSelectConsumer));
      final container = ProviderScope.containerOf(element);
      final store = container.read(inboxStoreProvider.notifier)
          as _ControllableInboxStore;

      store.setFilterDirect(InboxFilter.unread);
      await tester.pump();

      expect(
        buildCount,
        2,
        reason: 'filter change must rebuild (filter, hasMore) select widget',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T5: hasMore change DOES rebuild (filter, hasMore) select widget.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-UNREAD-LIST-662-SELECT-1: hasMore change DOES rebuild '
    '(filter, hasMore) select widget',
    (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inboxStoreProvider.overrideWith(() => _ControllableInboxStore()),
          ],
          child: MaterialApp(
            home: _FilterHasMoreSelectConsumer(onBuild: () => buildCount++),
          ),
        ),
      );

      expect(buildCount, 1);

      final element = tester.element(find.byType(_FilterHasMoreSelectConsumer));
      final container = ProviderScope.containerOf(element);
      final store = container.read(inboxStoreProvider.notifier)
          as _ControllableInboxStore;

      store.setHasMoreDirect(true);
      await tester.pump();

      expect(
        buildCount,
        2,
        reason: 'hasMore change must rebuild (filter, hasMore) select widget',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T6: Compound mutations — only filter/hasMore trigger scaffold.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-UNREAD-LIST-662-SELECT-1: compound mutations — only filter/hasMore '
    'changes trigger widget rebuild',
    (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inboxStoreProvider.overrideWith(() => _ControllableInboxStore()),
          ],
          child: MaterialApp(
            home: _FilterHasMoreSelectConsumer(onBuild: () => buildCount++),
          ),
        ),
      );

      expect(buildCount, 1);

      final element = tester.element(find.byType(_FilterHasMoreSelectConsumer));
      final container = ProviderScope.containerOf(element);
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
      await tester.pump();
      expect(buildCount, 1);

      // 2. status change — no rebuild.
      store.setStatusDirect(InboxStatus.loading);
      await tester.pump();
      expect(buildCount, 1);

      // 3. totalUnreadCount change — no rebuild.
      store.setTotalUnreadCountDirect(99);
      await tester.pump();
      expect(buildCount, 1);

      // 4. offset change — no rebuild.
      store.setOffsetDirect(30);
      await tester.pump();
      expect(buildCount, 1);

      // 5. isRefreshing change — no rebuild.
      store.setIsRefreshingDirect(true);
      await tester.pump();
      expect(buildCount, 1);

      // 6. filter change — rebuild.
      store.setFilterDirect(InboxFilter.unread);
      await tester.pump();
      expect(buildCount, 2);

      // 7. hasMore change — rebuild.
      store.setHasMoreDirect(true);
      await tester.pump();
      expect(buildCount, 3);
    },
  );
}
