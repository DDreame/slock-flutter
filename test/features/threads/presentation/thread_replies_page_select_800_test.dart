// =============================================================================
// #800 P2-4 — ThreadRepliesPage .select() rebuild isolation
//
// Invariant: INV-THREAD-REPLIES-800-SELECT-1
//   _ThreadRepliesScreen scaffold only rebuilds on (status, conversationTarget,
//   failure, isFollowing, isFollowingInFlight, isDoneInFlight, routeTarget).
//   Changes to replyCount, participantIds, lastReplyAt must NOT trigger rebuild.
//
// Strategy: Consumer widget using the EXACT .select() from production,
// with rebuild counter.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/threads/application/thread_replies_state.dart';
import 'package:slock_app/features/threads/application/thread_replies_store.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';

// ---------------------------------------------------------------------------
// Controllable store for direct state manipulation
// ---------------------------------------------------------------------------

class _ControllableThreadRepliesStore extends ThreadRepliesStore {
  @override
  ThreadRepliesState build() {
    return ThreadRepliesState(
      routeTarget: const ThreadRouteTarget(
        serverId: 'server-1',
        parentChannelId: 'ch-1',
        parentMessageId: 'msg-1',
        isFollowed: false,
      ),
      status: ThreadRepliesStatus.success,
      resolvedThreadChannelId: 'thread-ch-1',
      replyCount: 5,
      participantIds: const ['user-1', 'user-2'],
      lastReplyAt: DateTime(2026, 5, 20),
    );
  }

  void setReplyCountDirect(int count) {
    state = state.copyWith(replyCount: count);
  }

  void setParticipantIdsDirect(List<String> ids) {
    state = state.copyWith(participantIds: ids);
  }

  void setLastReplyAtDirect(DateTime time) {
    state = state.copyWith(lastReplyAt: time);
  }

  void setIsFollowingInFlightDirect(bool value) {
    state = state.copyWith(isFollowingInFlight: value);
  }

  void setStatusDirect(ThreadRepliesStatus status) {
    state = state.copyWith(status: status);
  }
}

// ---------------------------------------------------------------------------
// Consumer using EXACT .select() from production thread_replies_page.dart
// ---------------------------------------------------------------------------

class _ThreadRepliesSelectConsumer extends ConsumerWidget {
  const _ThreadRepliesSelectConsumer({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(
      threadRepliesStoreProvider.select((s) => (
            status: s.status,
            conversationTarget: s.conversationTarget,
            failure: s.failure,
            isFollowing: s.isFollowing,
            isFollowingInFlight: s.isFollowingInFlight,
            isDoneInFlight: s.isDoneInFlight,
            storeRouteTarget: s.routeTarget,
          )),
    );
    onBuild();
    return const SizedBox.shrink();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const routeTarget = ThreadRouteTarget(
    serverId: 'server-1',
    parentChannelId: 'ch-1',
    parentMessageId: 'msg-1',
    isFollowed: false,
  );

  // -------------------------------------------------------------------------
  // T1: replyCount change must NOT rebuild scaffold.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-THREAD-REPLIES-800-SELECT-1: replyCount change does NOT rebuild',
    (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentThreadRouteTargetProvider.overrideWithValue(routeTarget),
            threadRepliesStoreProvider
                .overrideWith(() => _ControllableThreadRepliesStore()),
          ],
          child: MaterialApp(
            home: _ThreadRepliesSelectConsumer(onBuild: () => buildCount++),
          ),
        ),
      );

      expect(buildCount, 1);

      final element = tester.element(find.byType(_ThreadRepliesSelectConsumer));
      final container = ProviderScope.containerOf(element);
      final store = container.read(threadRepliesStoreProvider.notifier)
          as _ControllableThreadRepliesStore;

      store.setReplyCountDirect(10);
      await tester.pump();

      expect(buildCount, 1,
          reason: 'replyCount is excluded from .select() — no rebuild');
    },
  );

  // -------------------------------------------------------------------------
  // T2: participantIds change must NOT rebuild scaffold.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-THREAD-REPLIES-800-SELECT-1: participantIds change does NOT rebuild',
    (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentThreadRouteTargetProvider.overrideWithValue(routeTarget),
            threadRepliesStoreProvider
                .overrideWith(() => _ControllableThreadRepliesStore()),
          ],
          child: MaterialApp(
            home: _ThreadRepliesSelectConsumer(onBuild: () => buildCount++),
          ),
        ),
      );

      expect(buildCount, 1);

      final element = tester.element(find.byType(_ThreadRepliesSelectConsumer));
      final container = ProviderScope.containerOf(element);
      final store = container.read(threadRepliesStoreProvider.notifier)
          as _ControllableThreadRepliesStore;

      store.setParticipantIdsDirect(['user-1', 'user-2', 'user-3']);
      await tester.pump();

      expect(buildCount, 1,
          reason: 'participantIds is excluded from .select() — no rebuild');
    },
  );

  // -------------------------------------------------------------------------
  // T3: lastReplyAt change must NOT rebuild scaffold.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-THREAD-REPLIES-800-SELECT-1: lastReplyAt change does NOT rebuild',
    (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentThreadRouteTargetProvider.overrideWithValue(routeTarget),
            threadRepliesStoreProvider
                .overrideWith(() => _ControllableThreadRepliesStore()),
          ],
          child: MaterialApp(
            home: _ThreadRepliesSelectConsumer(onBuild: () => buildCount++),
          ),
        ),
      );

      expect(buildCount, 1);

      final element = tester.element(find.byType(_ThreadRepliesSelectConsumer));
      final container = ProviderScope.containerOf(element);
      final store = container.read(threadRepliesStoreProvider.notifier)
          as _ControllableThreadRepliesStore;

      store.setLastReplyAtDirect(DateTime(2026, 5, 25));
      await tester.pump();

      expect(buildCount, 1,
          reason: 'lastReplyAt is excluded from .select() — no rebuild');
    },
  );

  // -------------------------------------------------------------------------
  // T4: isFollowingInFlight change DOES rebuild (included in select).
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-THREAD-REPLIES-800-SELECT-1: isFollowingInFlight change DOES rebuild',
    (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentThreadRouteTargetProvider.overrideWithValue(routeTarget),
            threadRepliesStoreProvider
                .overrideWith(() => _ControllableThreadRepliesStore()),
          ],
          child: MaterialApp(
            home: _ThreadRepliesSelectConsumer(onBuild: () => buildCount++),
          ),
        ),
      );

      expect(buildCount, 1);

      final element = tester.element(find.byType(_ThreadRepliesSelectConsumer));
      final container = ProviderScope.containerOf(element);
      final store = container.read(threadRepliesStoreProvider.notifier)
          as _ControllableThreadRepliesStore;

      store.setIsFollowingInFlightDirect(true);
      await tester.pump();

      expect(buildCount, 2,
          reason: 'isFollowingInFlight is in .select() — must rebuild');
    },
  );
}
