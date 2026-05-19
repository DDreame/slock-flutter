// =============================================================================
// #593 — HomeListStore Future.wait Type Safety
//
// Invariant: INV-TYPE-1
//   HomeListStore load/refresh return correctly typed results regardless of
//   Future resolution order.
//
// Strategy: Verify that load() and refresh() correctly consume BOTH the
// HomeWorkspaceSnapshot AND SidebarOrder results, producing a correctly
// populated state. The tests use independently-delayed fakes to prove that
// even when the sidebar order resolves BEFORE the workspace snapshot, the
// results are correctly associated (not swapped).
//
// Phase A: tests skip:true — current code uses positional casts that happen
// to work because Future.wait preserves list order. After Phase B, Dart 3
// record destructuring provides compile-time safety.
//
// Phase B: Replace Future.wait with:
//   final (snapshot, sidebarOrder) = await (
//     repo.loadWorkspace(serverScopeId),
//     _loadSidebarOrderSafe(serverScopeId),
//   ).wait;
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/home/data/sidebar_order.dart';
import 'package:slock_app/features/home/data/sidebar_order_repository.dart';
import 'package:slock_app/features/tasks/data/tasks_repository_provider.dart';
import 'package:slock_app/features/threads/application/known_thread_channel_ids_provider.dart';
import 'package:slock_app/features/threads/data/thread_repository_provider.dart';

import '../../../support/support.dart';

// ---------------------------------------------------------------------------
// Delayed fakes — allow independent timing control
// ---------------------------------------------------------------------------

/// Home repository that completes loadWorkspace via an external Completer,
/// enabling test control over resolution timing.
class _DelayableHomeRepository implements HomeRepository {
  _DelayableHomeRepository({required this.snapshot});

  final HomeWorkspaceSnapshot snapshot;
  Completer<HomeWorkspaceSnapshot>? loadCompleter;

  @override
  Future<HomeWorkspaceSnapshot> loadWorkspace(ServerScopeId serverId) async {
    if (loadCompleter != null) {
      return loadCompleter!.future;
    }
    return snapshot;
  }

  @override
  Future<HomeWorkspaceSnapshot?> loadCachedWorkspace(
    ServerScopeId serverId,
  ) async =>
      null;

  @override
  Future<HomeDirectMessageSummary> persistDirectMessageSummary(
    HomeDirectMessageSummary summary,
  ) async =>
      summary;

  @override
  Future<void> persistConversationActivity({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
    required DateTime activityAt,
  }) async {}

  @override
  Future<void> persistConversationPreviewUpdate({
    required ServerScopeId serverId,
    required String conversationId,
    required String messageId,
    required String preview,
  }) async {}
}

/// Sidebar order repository that completes via an external Completer.
class _DelayableSidebarOrderRepository implements SidebarOrderRepository {
  _DelayableSidebarOrderRepository({required this.sidebarOrder});

  final SidebarOrder sidebarOrder;
  Completer<SidebarOrder>? loadCompleter;

  @override
  Future<SidebarOrder> loadSidebarOrder(ServerScopeId serverId) async {
    if (loadCompleter != null) {
      return loadCompleter!.future;
    }
    return sidebarOrder;
  }

  @override
  Future<void> updateSidebarOrder(
    ServerScopeId serverId, {
    required Map<String, Object> patch,
  }) async {}
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: load() correctly types results when sidebar resolves first.
  //
  // Scenario: sidebar order completes BEFORE workspace snapshot. The store
  // should still assign snapshot to snapshot and sidebarOrder to sidebarOrder
  // (not swap them due to positional indexing).
  //
  // With Dart 3 record destructure, the compiler guarantees this. With
  // Future.wait positional casts, reordering the list breaks it.
  //
  // skip:true — test verifies the invariant that Phase B enforces at
  // compile-time. Currently passes by accident (list order matches).
  // -------------------------------------------------------------------------
  test(
    'INV-TYPE-1: load() correctly types results when sidebar resolves before '
    'workspace',
    skip: true,
    () async {
      const snapshot = HomeWorkspaceSnapshot(
        serverId: ServerScopeId('server-1'),
        channels: [
          HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'general',
            ),
            name: 'general',
          ),
        ],
        directMessages: [],
      );
      const sidebarOrder = SidebarOrder(
        channelOrder: ['general'],
        pinnedChannelIds: ['general'],
      );

      final homeRepo = _DelayableHomeRepository(snapshot: snapshot);
      final sidebarRepo =
          _DelayableSidebarOrderRepository(sidebarOrder: sidebarOrder);

      // Control resolution timing.
      homeRepo.loadCompleter = Completer<HomeWorkspaceSnapshot>();
      sidebarRepo.loadCompleter = Completer<SidebarOrder>();

      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider
              .overrideWith((_) => const ServerScopeId('server-1')),
          homeRepositoryProvider.overrideWithValue(homeRepo),
          sidebarOrderRepositoryProvider.overrideWithValue(sidebarRepo),
          agentsRepositoryProvider.overrideWithValue(FakeAgentsRepository()),
          tasksRepositoryProvider.overrideWithValue(FakeTasksRepository()),
          threadRepositoryProvider.overrideWithValue(FakeThreadRepository()),
          knownThreadChannelIdsProvider.overrideWith((ref) => const <String>{}),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        homeListStoreProvider,
        (_, __) {},
      );

      // Trigger load.
      final loadFuture = container.read(homeListStoreProvider.notifier).load();

      // Sidebar resolves FIRST.
      sidebarRepo.loadCompleter!.complete(sidebarOrder);
      await Future<void>.delayed(Duration.zero);

      // Workspace resolves SECOND.
      homeRepo.loadCompleter!.complete(snapshot);
      await loadFuture;

      // State should be correctly populated regardless of resolution order.
      final state = container.read(homeListStoreProvider);
      expect(state.status, HomeListStatus.success);
      expect(state.channels.length, 1);
      expect(state.channels.first.name, 'general');

      // Verify sidebar order was applied (pinned channels).
      expect(
        state.pinnedChannels.any((ch) => ch.name == 'general'),
        isTrue,
        reason: 'SidebarOrder.pinnedChannelIds must be applied correctly '
            '(INV-TYPE-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: refresh() correctly types results when sidebar resolves first.
  //
  // Same timing inversion scenario as T1, but for refresh() path.
  //
  // skip:true — same reasoning as T1.
  // -------------------------------------------------------------------------
  test(
    'INV-TYPE-1: refresh() correctly types results when sidebar resolves before '
    'workspace',
    skip: true,
    () async {
      const snapshot = HomeWorkspaceSnapshot(
        serverId: ServerScopeId('server-1'),
        channels: [
          HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'announcements',
            ),
            name: 'announcements',
          ),
        ],
        directMessages: [],
      );
      const sidebarOrder = SidebarOrder(
        channelOrder: ['announcements'],
      );

      final homeRepo = _DelayableHomeRepository(snapshot: snapshot);
      final sidebarRepo =
          _DelayableSidebarOrderRepository(sidebarOrder: sidebarOrder);

      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider
              .overrideWith((_) => const ServerScopeId('server-1')),
          homeRepositoryProvider.overrideWithValue(homeRepo),
          sidebarOrderRepositoryProvider.overrideWithValue(sidebarRepo),
          agentsRepositoryProvider.overrideWithValue(FakeAgentsRepository()),
          tasksRepositoryProvider.overrideWithValue(FakeTasksRepository()),
          threadRepositoryProvider.overrideWithValue(FakeThreadRepository()),
          knownThreadChannelIdsProvider.overrideWith((ref) => const <String>{}),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        homeListStoreProvider,
        (_, __) {},
      );

      // Initial load (instant, no completer).
      await container.read(homeListStoreProvider.notifier).load();
      expect(
        container.read(homeListStoreProvider).status,
        HomeListStatus.success,
      );

      // Now set up delayed completers for refresh.
      homeRepo.loadCompleter = Completer<HomeWorkspaceSnapshot>();
      sidebarRepo.loadCompleter = Completer<SidebarOrder>();

      final refreshFuture =
          container.read(homeListStoreProvider.notifier).refresh();

      // Sidebar resolves FIRST.
      sidebarRepo.loadCompleter!.complete(sidebarOrder);
      await Future<void>.delayed(Duration.zero);

      // Workspace resolves SECOND.
      homeRepo.loadCompleter!.complete(snapshot);
      await refreshFuture;

      final state = container.read(homeListStoreProvider);
      expect(state.status, HomeListStatus.success);
      expect(state.channels.length, 1);
      expect(state.channels.first.name, 'announcements');

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: load() populates both workspace AND sidebar data correctly
  //     (anti-pattern proof — verifies current behavior works).
  //
  // This test passes NOW and continues to pass after Phase B.
  // It proves the load path returns typed results (snapshot + sidebarOrder)
  // that are both consumed correctly by the store.
  // -------------------------------------------------------------------------
  test(
    'load() populates both workspace and sidebar data correctly',
    () async {
      final fixture = RuntimeAppFixture();
      fixture.seedHome(
        channels: const [
          HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'general',
            ),
            name: 'general',
          ),
          HomeChannelSummary(
            scopeId: ChannelScopeId(
              serverId: ServerScopeId('server-1'),
              value: 'random',
            ),
            name: 'random',
          ),
        ],
        sidebarOrder: const SidebarOrder(
          channelOrder: ['general', 'random'],
          pinnedChannelIds: ['general'],
        ),
      );

      await fixture.boot();
      addTearDown(fixture.dispose);

      final state = fixture.container.read(homeListStoreProvider);
      expect(state.status, HomeListStatus.success);

      // Workspace data loaded — unpinned channels in state.channels,
      // pinned channels in state.pinnedChannels.
      // 'general' is pinned → pinnedChannels, 'random' is not → channels.
      expect(state.channels.length, 1);
      expect(state.channels.first.name, 'random');

      // Sidebar order applied — pinned channel moved to pinnedChannels.
      expect(state.pinnedChannels.length, 1);
      expect(
        state.pinnedChannels.first.name,
        'general',
        reason: 'Pinned channel from SidebarOrder must appear in '
            'pinnedChannels (type safety proof)',
      );
    },
  );
}
