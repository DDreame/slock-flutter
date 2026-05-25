// =============================================================================
// #798 — Concurrent Reaction Rollback Isolation
//
// Root cause: addReaction/removeReaction capture the entire reactions list as
// previousReactions. If two emojis are toggled concurrently and one fails,
// its rollback restores the FULL snapshot — undoing the other emoji's
// optimistic update that occurred after the snapshot was taken.
//
// Fix: Per-emoji snapshot isolation. Each toggle captures/restores only its
// own emoji's MessageReaction, leaving other emojis untouched on rollback.
//
// Invariants verified:
//   INV-798-1: Toggle A fails while B succeeds → only A rolls back, B remains
//   INV-798-2: Both A and B fail → both roll back independently
//   INV-798-3: Both A and B succeed → both applied
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    ),
  );

  ConversationDetailSnapshot baseSnapshot() {
    return ConversationDetailSnapshot(
      target: target,
      title: '#general',
      messages: [
        ConversationMessageSummary(
          id: 'msg-1',
          content: 'Hello',
          createdAt: DateTime.parse('2026-05-20T10:00:00Z'),
          senderType: 'human',
          senderId: 'user-1',
          messageType: 'message',
          seq: 1,
          reactions: const [],
        ),
      ],
      historyLimited: false,
      hasOlder: false,
    );
  }

  group('#798 — Concurrent reaction rollback isolation', () {
    // -------------------------------------------------------------------------
    // INV-798-1: A fails, B succeeds → only A rolls back
    // -------------------------------------------------------------------------
    test(
      'toggle A fails while B succeeds → only A rolls back, B remains '
      '(INV-798-1)',
      () async {
        final completerA = Completer<void>();
        final completerB = Completer<void>();
        final repo = _PerEmojiDelayedRepository(
          snapshot: baseSnapshot(),
          emojiCompleters: {'👍': completerA, '❤️': completerB},
        );

        final container = ProviderContainer(overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          sessionStoreProvider
              .overrideWith(() => _FakeSessionStore(userId: 'user-1')),
        ]);
        addTearDown(container.dispose);

        final sub =
            container.listen(conversationDetailStoreProvider, (_, __) {});
        addTearDown(sub.close);

        await container.read(conversationDetailStoreProvider.notifier).load();

        // Toggle emoji A (👍) — will block on completerA.
        final futureA = container
            .read(conversationDetailStoreProvider.notifier)
            .addReaction('msg-1', '👍');

        // Toggle emoji B (❤️) — will block on completerB.
        final futureB = container
            .read(conversationDetailStoreProvider.notifier)
            .addReaction('msg-1', '❤️');

        // Both should be optimistically applied.
        final stateAfterBoth = container.read(conversationDetailStoreProvider);
        final reactionsAfterBoth = stateAfterBoth.messages.first.reactions;
        expect(reactionsAfterBoth.length, 2);
        expect(reactionsAfterBoth.any((r) => r.emoji == '👍'), isTrue);
        expect(reactionsAfterBoth.any((r) => r.emoji == '❤️'), isTrue);

        // B succeeds.
        completerB.complete();
        await futureB;

        // A fails → should roll back only 👍, leaving ❤️ intact.
        completerA.completeError(
          const ServerFailure(message: 'Forbidden', statusCode: 403),
        );
        // addReaction rethrows, so catch the error.
        await futureA.catchError((_) {});

        final finalState = container.read(conversationDetailStoreProvider);
        final finalReactions = finalState.messages.first.reactions;

        // 👍 should be rolled back (removed).
        expect(finalReactions.any((r) => r.emoji == '👍'), isFalse,
            reason: 'A (👍) should be rolled back after failure');
        // ❤️ should remain.
        expect(finalReactions.any((r) => r.emoji == '❤️'), isTrue,
            reason: 'B (❤️) should remain after A fails');
      },
    );

    // -------------------------------------------------------------------------
    // INV-798-2: Both A and B fail → both roll back independently
    // -------------------------------------------------------------------------
    test(
      'both A and B fail → both roll back independently (INV-798-2)',
      () async {
        final completerA = Completer<void>();
        final completerB = Completer<void>();
        final repo = _PerEmojiDelayedRepository(
          snapshot: baseSnapshot(),
          emojiCompleters: {'👍': completerA, '❤️': completerB},
        );

        final container = ProviderContainer(overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          sessionStoreProvider
              .overrideWith(() => _FakeSessionStore(userId: 'user-1')),
        ]);
        addTearDown(container.dispose);

        final sub =
            container.listen(conversationDetailStoreProvider, (_, __) {});
        addTearDown(sub.close);

        await container.read(conversationDetailStoreProvider.notifier).load();

        final futureA = container
            .read(conversationDetailStoreProvider.notifier)
            .addReaction('msg-1', '👍');
        final futureB = container
            .read(conversationDetailStoreProvider.notifier)
            .addReaction('msg-1', '❤️');

        // Both optimistically applied.
        expect(
          container
              .read(conversationDetailStoreProvider)
              .messages
              .first
              .reactions
              .length,
          2,
        );

        // Both fail.
        completerA.completeError(
          const ServerFailure(message: 'Error', statusCode: 500),
        );
        completerB.completeError(
          const ServerFailure(message: 'Error', statusCode: 500),
        );

        await futureA.catchError((_) {});
        await futureB.catchError((_) {});

        final finalReactions = container
            .read(conversationDetailStoreProvider)
            .messages
            .first
            .reactions;

        // Both should be rolled back — reactions empty again.
        expect(finalReactions, isEmpty,
            reason: 'Both reactions should be rolled back independently');
      },
    );

    // -------------------------------------------------------------------------
    // INV-798-3: Both succeed → both applied
    // -------------------------------------------------------------------------
    test(
      'both A and B succeed → both applied (INV-798-3)',
      () async {
        final completerA = Completer<void>();
        final completerB = Completer<void>();
        final repo = _PerEmojiDelayedRepository(
          snapshot: baseSnapshot(),
          emojiCompleters: {'👍': completerA, '❤️': completerB},
        );

        final container = ProviderContainer(overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
          sessionStoreProvider
              .overrideWith(() => _FakeSessionStore(userId: 'user-1')),
        ]);
        addTearDown(container.dispose);

        final sub =
            container.listen(conversationDetailStoreProvider, (_, __) {});
        addTearDown(sub.close);

        await container.read(conversationDetailStoreProvider.notifier).load();

        final futureA = container
            .read(conversationDetailStoreProvider.notifier)
            .addReaction('msg-1', '👍');
        final futureB = container
            .read(conversationDetailStoreProvider.notifier)
            .addReaction('msg-1', '❤️');

        // Both succeed.
        completerA.complete();
        completerB.complete();

        await futureA;
        await futureB;

        final finalReactions = container
            .read(conversationDetailStoreProvider)
            .messages
            .first
            .reactions;

        expect(finalReactions.length, 2);
        expect(finalReactions.any((r) => r.emoji == '👍'), isTrue);
        expect(finalReactions.any((r) => r.emoji == '❤️'), isTrue);
      },
    );
  });
}

// =============================================================================
// Fakes
// =============================================================================

class _FakeSessionStore extends SessionStore {
  _FakeSessionStore({this.userId});

  final String? userId;

  @override
  SessionState build() => SessionState(
        status: AuthStatus.authenticated,
        userId: userId,
      );
}

/// Repository that uses per-emoji completers for addReaction/removeReaction.
/// Allows controlling timing of concurrent reaction operations independently.
class _PerEmojiDelayedRepository implements ConversationRepository {
  _PerEmojiDelayedRepository({
    required this.snapshot,
    required this.emojiCompleters,
  });

  final ConversationDetailSnapshot snapshot;
  final Map<String, Completer<void>> emojiCompleters;

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
    final completer = emojiCompleters[emoji];
    if (completer != null) {
      await completer.future;
    }
  }

  @override
  Future<void> removeReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {
    final completer = emojiCompleters[emoji];
    if (completer != null) {
      await completer.future;
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
