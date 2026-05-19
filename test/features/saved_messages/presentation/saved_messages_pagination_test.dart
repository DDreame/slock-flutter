// =============================================================================
// #592 — SavedMessages loadMore Guard
//
// Invariant: INV-PAGING-1
//   At most one loadMore() in-flight at any time.
//
// Strategy:
// T1: Verify that concurrent loadMore() calls do NOT trigger multiple fetches
//     (requires isLoadingMore guard in store state).
// T2: Verify loadMore rejects when already loading (isLoadingMore == true).
// T3: Verify that the store exposes isLoadingMore to enable UI-level guards.
//
// Phase A: tests skip:true — current implementation has no isLoadingMore guard.
//
// Phase B:
// 1. Add `isLoadingMore` boolean to SavedMessagesState
// 2. Set true before fetch, false after (success or error)
// 3. Guard: early return if isLoadingMore is true
// 4. Move pagination trigger from itemBuilder to ScrollController listener
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_state.dart';
import 'package:slock_app/features/saved_messages/application/saved_messages_store.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeSavedMessagesRepository implements SavedMessagesRepository {
  int loadMoreCallCount = 0;
  Completer<SavedMessagesPage>? loadMoreCompleter;

  /// First page of items (returned by initial load).
  final List<SavedMessageItem> initialItems;

  /// Second page of items (returned by loadMore).
  final List<SavedMessageItem> moreItems;

  _FakeSavedMessagesRepository({
    List<SavedMessageItem>? initialItems,
    List<SavedMessageItem>? moreItems,
  })  : initialItems = initialItems ?? _defaultInitialItems(),
        moreItems = moreItems ?? _defaultMoreItems();

  @override
  Future<SavedMessagesPage> listSavedMessages(
    ServerScopeId serverId, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (offset > 0) {
      loadMoreCallCount++;
      if (loadMoreCompleter != null) {
        return loadMoreCompleter!.future;
      }
      return SavedMessagesPage(items: moreItems, hasMore: false);
    }
    return SavedMessagesPage(items: initialItems, hasMore: true);
  }

  @override
  Future<void> saveMessage(ServerScopeId serverId, String messageId) async {}

  @override
  Future<void> unsaveMessage(ServerScopeId serverId, String messageId) async {}

  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) async =>
      const {};
}

List<SavedMessageItem> _defaultInitialItems() {
  return List.generate(
    10,
    (i) => SavedMessageItem(
      message: ConversationMessageSummary(
        id: 'msg-$i',
        content: 'Saved message $i',
        createdAt: DateTime.parse('2026-05-18T10:00:00Z'),
        senderId: 'user-1',
        senderType: 'human',
        messageType: 'message',
        senderName: 'Alice',
        seq: i + 1,
      ),
      channelId: 'ch-general',
      channelName: '#general',
      savedAt: DateTime.parse('2026-05-18T11:00:00Z'),
    ),
  );
}

List<SavedMessageItem> _defaultMoreItems() {
  return List.generate(
    5,
    (i) => SavedMessageItem(
      message: ConversationMessageSummary(
        id: 'msg-${10 + i}',
        content: 'Saved message ${10 + i}',
        createdAt: DateTime.parse('2026-05-18T10:00:00Z'),
        senderId: 'user-1',
        senderType: 'human',
        messageType: 'message',
        senderName: 'Alice',
        seq: 11 + i,
      ),
      channelId: 'ch-general',
      channelName: '#general',
      savedAt: DateTime.parse('2026-05-18T11:00:00Z'),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: Concurrent loadMore() calls should result in exactly 1 fetch.
  //
  // When loadMore() is already in-flight, a second call to loadMore() must
  // be rejected immediately (early return). The repository should only be
  // called once even if loadMore() is invoked multiple times before the
  // first completes.
  //
  // skip:true — requires Phase B isLoadingMore guard.
  // -------------------------------------------------------------------------
  test(
    'INV-PAGING-1: concurrent loadMore() calls result in exactly 1 fetch',
    skip: true,
    () async {
      final repo = _FakeSavedMessagesRepository();
      repo.loadMoreCompleter = Completer<SavedMessagesPage>();

      final container = ProviderContainer(
        overrides: [
          currentSavedMessagesServerIdProvider
              .overrideWithValue(const ServerScopeId('server-1')),
          savedMessagesRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        savedMessagesStoreProvider,
        (_, __) {},
      );

      // Initial load to populate items.
      await container.read(savedMessagesStoreProvider.notifier).load();

      expect(
        container.read(savedMessagesStoreProvider).status,
        SavedMessagesStatus.success,
      );
      expect(container.read(savedMessagesStoreProvider).hasMore, isTrue);

      // Fire 3 concurrent loadMore calls.
      final f1 = container.read(savedMessagesStoreProvider.notifier).loadMore();
      final f2 = container.read(savedMessagesStoreProvider.notifier).loadMore();
      final f3 = container.read(savedMessagesStoreProvider.notifier).loadMore();

      // Complete the first fetch.
      repo.loadMoreCompleter!.complete(
        SavedMessagesPage(items: repo.moreItems, hasMore: false),
      );
      await Future.wait([f1, f2, f3]);

      // Repository should have been called exactly once.
      expect(
        repo.loadMoreCallCount,
        1,
        reason: 'Only 1 fetch must reach the repository despite 3 calls '
            '(INV-PAGING-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T2: loadMore() is a no-op when one is already in-flight.
  //
  // This verifies the guard at the top of loadMore(): if already loading,
  // return immediately without touching the repository.
  //
  // skip:true — requires Phase B isLoadingMore guard.
  // -------------------------------------------------------------------------
  test(
    'INV-PAGING-1: loadMore() is a no-op when one is already in-flight',
    skip: true,
    () async {
      final repo = _FakeSavedMessagesRepository();
      repo.loadMoreCompleter = Completer<SavedMessagesPage>();

      final container = ProviderContainer(
        overrides: [
          currentSavedMessagesServerIdProvider
              .overrideWithValue(const ServerScopeId('server-1')),
          savedMessagesRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        savedMessagesStoreProvider,
        (_, __) {},
      );

      await container.read(savedMessagesStoreProvider.notifier).load();

      // Start first loadMore (will hang on completer).
      container.read(savedMessagesStoreProvider.notifier).loadMore();
      // Allow microtask for the state change.
      await Future<void>.delayed(Duration.zero);

      // Second loadMore should exit immediately (no-op).
      await container.read(savedMessagesStoreProvider.notifier).loadMore();

      // Still only 1 call to the repository.
      expect(
        repo.loadMoreCallCount,
        1,
        reason: 'Second loadMore must not reach repository when '
            'one is already in-flight (INV-PAGING-1)',
      );

      // Clean up.
      repo.loadMoreCompleter!.complete(
        SavedMessagesPage(items: repo.moreItems, hasMore: false),
      );
      await Future<void>.delayed(Duration.zero);

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T3: loadMore error does not permanently block future loads.
  //
  // If loadMore() throws, the guard must reset so the user can retry.
  //
  // skip:true — requires Phase B isLoadingMore field.
  // -------------------------------------------------------------------------
  test(
    'INV-PAGING-1: loadMore error does not permanently block future loads',
    skip: true,
    () async {
      final repo = _FakeSavedMessagesRepository();
      repo.loadMoreCompleter = Completer<SavedMessagesPage>();

      final container = ProviderContainer(
        overrides: [
          currentSavedMessagesServerIdProvider
              .overrideWithValue(const ServerScopeId('server-1')),
          savedMessagesRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        savedMessagesStoreProvider,
        (_, __) {},
      );

      await container.read(savedMessagesStoreProvider.notifier).load();

      // Start loadMore and fail it.
      final future =
          container.read(savedMessagesStoreProvider.notifier).loadMore();
      await Future<void>.delayed(Duration.zero);

      // Fail the loadMore.
      repo.loadMoreCompleter!.completeError(
        const UnknownFailure(message: 'Network error'),
      );
      await future;

      expect(repo.loadMoreCallCount, 1);

      // Reset completer for a retry.
      repo.loadMoreCompleter = null;

      // Retry should succeed (guard must have reset).
      await container.read(savedMessagesStoreProvider.notifier).loadMore();

      expect(
        repo.loadMoreCallCount,
        2,
        reason: 'After error, loadMore guard must reset so retry works '
            '(INV-PAGING-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T4: Current loadMore has no guard (anti-pattern proof).
  //
  // Demonstrates the bug: calling loadMore() multiple times concurrently
  // results in multiple repository fetches. This test passes NOW.
  // -------------------------------------------------------------------------
  test(
    'current loadMore allows concurrent fetches (anti-pattern proof)',
    () async {
      final repo = _FakeSavedMessagesRepository();

      final container = ProviderContainer(
        overrides: [
          currentSavedMessagesServerIdProvider
              .overrideWithValue(const ServerScopeId('server-1')),
          savedMessagesRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(
        savedMessagesStoreProvider,
        (_, __) {},
      );

      await container.read(savedMessagesStoreProvider.notifier).load();

      expect(container.read(savedMessagesStoreProvider).hasMore, isTrue);

      // Fire 3 concurrent loadMore calls (no completer → instant resolve).
      await Future.wait([
        container.read(savedMessagesStoreProvider.notifier).loadMore(),
        container.read(savedMessagesStoreProvider.notifier).loadMore(),
        container.read(savedMessagesStoreProvider.notifier).loadMore(),
      ]);

      // Without a guard, all 3 reach the repository.
      expect(
        repo.loadMoreCallCount,
        greaterThan(1),
        reason: 'Without isLoadingMore guard, concurrent calls all hit the '
            'repository (proving the bug)',
      );

      keepAlive.close();
    },
  );
}
