// =============================================================================
// #785 — P1 Reactions Disposal Guard + P2 AnnouncementStore Stale Server Write
//
// Verifies:
// A. Disposing conversation store during a reaction error does NOT throw
//    StateError from ref.read() — the _disposed guard bails before rollback.
// B. Server switch during announcement load discards stale response — the
//    post-await server ID check prevents cross-server contamination.
//
// Load-bearing proof:
//   Reverting `if ((this as ConversationDetailStore)._disposed) return;` in
//   conversation_detail_store_reactions.dart causes test A to fail with
//   StateError from ref.read on disposed container.
//   Reverting the server ID check in announcement_store.dart causes test B
//   to fail (stale announcements written to wrong server's state).
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/announcements/application/announcement_store.dart';
import 'package:slock_app/features/announcements/application/dismissed_announcement_ids.dart';
import 'package:slock_app/features/announcements/data/announcement.dart';
import 'package:slock_app/features/announcements/data/announcement_repository.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  group('#785 — P1 Reactions disposal guard', () {
    final target = ConversationDetailTarget.channel(
      const ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'general',
      ),
    );

    ConversationDetailSnapshot singleMessageSnapshot() {
      return ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: [
          ConversationMessageSummary(
            id: 'message-1',
            content: 'Hello',
            createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
            senderType: 'human',
            senderId: 'user-1',
            messageType: 'message',
            seq: 1,
            reactions: const [
              MessageReaction(emoji: '👍', count: 1, userIds: ['user-1']),
            ],
          ),
        ],
        historyLimited: false,
        hasOlder: false,
      );
    }

    test('addReaction: dispose during API error does not throw StateError',
        () async {
      final reactionCompleter = Completer<void>();
      final repo = _DelayedReactionRepository(
        snapshot: singleMessageSnapshot(),
        addReactionCompleter: reactionCompleter,
      );

      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          sessionStoreProvider
              .overrideWith(() => _FakeSessionStore(userId: 'user-1')),
        ],
      );

      // Keep provider alive long enough to start the reaction.
      final sub = container.listen(conversationDetailStoreProvider, (_, __) {});
      await container.read(conversationDetailStoreProvider.notifier).load();

      // Start addReaction — will await the completer.
      final addFuture = container
          .read(conversationDetailStoreProvider.notifier)
          .addReaction('message-1', '❤️');

      // Dispose BEFORE the completer resolves — simulates navigation away.
      sub.close();
      container.dispose();

      // Complete with an AppFailure — without the _disposed guard this would
      // trigger ref.read() on a disposed container → StateError.
      reactionCompleter.completeError(
        const ServerFailure(message: 'Forbidden', statusCode: 403),
      );

      // loadFuture should complete without StateError.
      // The AppFailure is swallowed because _disposed returns early.
      await addFuture;
    });

    test('removeReaction: dispose during API error does not throw StateError',
        () async {
      final reactionCompleter = Completer<void>();
      final repo = _DelayedReactionRepository(
        snapshot: singleMessageSnapshot(),
        removeReactionCompleter: reactionCompleter,
      );

      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          sessionStoreProvider
              .overrideWith(() => _FakeSessionStore(userId: 'user-1')),
        ],
      );

      final sub = container.listen(conversationDetailStoreProvider, (_, __) {});
      await container.read(conversationDetailStoreProvider.notifier).load();

      final removeFuture = container
          .read(conversationDetailStoreProvider.notifier)
          .removeReaction('message-1', '👍');

      sub.close();
      container.dispose();

      reactionCompleter.completeError(
        const ServerFailure(message: 'Forbidden', statusCode: 403),
      );

      await removeFuture;
    });
  });

  group('#785 — P2 AnnouncementStore stale server write', () {
    test('server switch during load discards stale response', () async {
      final loadCompleter = Completer<List<Announcement>>();
      final repo = _DelayedAnnouncementRepository(
        getActiveCompleter: loadCompleter,
      );

      // Use a StateProvider to simulate server switch.
      final serverState =
          StateProvider<ServerScopeId?>((ref) => const ServerScopeId('srv-A'));

      final container = ProviderContainer(
        overrides: [
          activeServerScopeIdProvider
              .overrideWith((ref) => ref.watch(serverState)),
          announcementRepositoryProvider.overrideWithValue(repo),
          dismissedAnnouncementIdsProvider.overrideWith(
            () => _FakeDismissedIds(),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Keep provider alive with an active listener — ensures the notifier
      // stays live through the server switch so the in-flight load() can
      // still write to state (which the guard must prevent).
      final sub = container.listen(announcementStoreProvider, (_, __) {});

      final store = container.read(announcementStoreProvider.notifier);
      final loadFuture = store.load();

      // Switch server WHILE load is in flight.
      container.read(serverState.notifier).state = const ServerScopeId('srv-B');
      await Future<void>.delayed(Duration.zero);

      // Complete with server A's announcements — should be discarded.
      loadCompleter.complete([
        const Announcement(id: 'ann-1', title: 'Server A announcement'),
      ]);
      await loadFuture;

      final state = container.read(announcementStoreProvider);
      // Must NOT contain server A's announcements.
      expect(state.announcements, isEmpty,
          reason: '#785: stale server response must be discarded');
      // State should still be loading (since load for server B hasn't run).
      expect(state.status, isNot(AnnouncementStatus.success),
          reason: '#785: stale write must not set success');

      sub.close();
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeSessionStore extends SessionStore {
  _FakeSessionStore({this.userId});

  final String? userId;

  @override
  SessionState build() => SessionState(
        status: AuthStatus.authenticated,
        userId: userId,
      );
}

class _DelayedReactionRepository implements ConversationRepository {
  _DelayedReactionRepository({
    required this.snapshot,
    this.addReactionCompleter,
    this.removeReactionCompleter,
  });

  final ConversationDetailSnapshot snapshot;
  final Completer<void>? addReactionCompleter;
  final Completer<void>? removeReactionCompleter;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    return snapshot;
  }

  @override
  Future<void> addReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {
    if (addReactionCompleter != null) {
      await addReactionCompleter!.future;
    }
  }

  @override
  Future<void> removeReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {
    if (removeReactionCompleter != null) {
      await removeReactionCompleter!.future;
    }
  }

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async {
    return const ConversationMessagePage(
      messages: [],
      historyLimited: false,
      hasOlder: false,
    );
  }

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async {
    return const ConversationMessagePage(
      messages: [],
      historyLimited: false,
      hasOlder: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedAnnouncementRepository implements AnnouncementRepository {
  _DelayedAnnouncementRepository({required this.getActiveCompleter});

  final Completer<List<Announcement>> getActiveCompleter;

  @override
  Future<List<Announcement>> getActive(ServerScopeId serverId) =>
      getActiveCompleter.future;

  @override
  Future<void> dismiss(ServerScopeId serverId,
      {required String announcementId}) async {}
}

class _FakeDismissedIds extends DismissedAnnouncementIds {
  @override
  Set<String> build() => const {};
}
