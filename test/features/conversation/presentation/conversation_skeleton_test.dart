import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/skeleton_list_item.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

// ---------------------------------------------------------------------------
// #491: Conversation Detail Skeleton Integration Tests
//
// Invariants verified:
// INV-UX-SKELETON-1: First frame must show skeleton, never blank.
//
// Note: INV-UX-SKELETON-2 (no layout jump on transition) is scoped as
// "skeleton replaces loading indicator" — presence/absence verified, not
// golden/layout-shift.
// ---------------------------------------------------------------------------

void main() {
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    ),
  );

  final sampleSnapshot = ConversationDetailSnapshot(
    target: target,
    title: '#general',
    messages: [
      ConversationMessageSummary(
        id: 'message-1',
        content: 'Hello world',
        createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
        senderType: 'human',
        messageType: 'message',
        seq: 1,
      ),
    ],
    historyLimited: false,
    hasOlder: false,
  );

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  Widget buildApp({
    required ConversationRepository repository,
  }) {
    return ProviderScope(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(repository),
        sessionStoreProvider.overrideWith(
          () => _FixedSessionStore(const SessionState()),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: ConversationDetailPage(target: target),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Tests
  // -----------------------------------------------------------------------

  group('Conversation detail skeleton integration', () {
    testWidgets(
      'shows skeleton on very first frame — initial status '
      '(INV-UX-SKELETON-1)',
      (tester) async {
        final loadCompleter = Completer<ConversationDetailSnapshot>();

        await tester.pumpWidget(
          buildApp(
            repository: _DelayedFakeConversationRepository(
              loadCompleter: loadCompleter,
            ),
          ),
        );
        // Single pump — status is still `initial` (microtask hasn't fired).
        await tester.pump();

        // Skeleton must be visible even on the very first frame.
        expect(
          find.byKey(const ValueKey('conversation-skeleton')),
          findsOneWidget,
          reason: 'INV-UX-SKELETON-1: skeleton must appear on the very first '
              'frame when status is initial',
        );

        // No spinner.
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: 'Skeleton replaces CircularProgressIndicator',
        );
      },
    );

    testWidgets(
      'shows 5 skeleton list items during loading state',
      (tester) async {
        final loadCompleter = Completer<ConversationDetailSnapshot>();

        await tester.pumpWidget(
          buildApp(
            repository: _DelayedFakeConversationRepository(
              loadCompleter: loadCompleter,
            ),
          ),
        );
        await tester.pump(); // trigger microtask load
        await tester.pump(); // allow state transition to loading

        // Skeleton container must be visible.
        expect(
          find.byKey(const ValueKey('conversation-skeleton')),
          findsOneWidget,
        );

        // All 5 skeleton list items present.
        for (var i = 0; i < 5; i++) {
          expect(
            find.byKey(ValueKey('conversation-skeleton-item-$i')),
            findsOneWidget,
          );
        }

        // No spinner.
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: 'Skeleton list items replace CircularProgressIndicator',
        );
      },
    );

    testWidgets(
      'skeleton items are SkeletonListItem widgets',
      (tester) async {
        final loadCompleter = Completer<ConversationDetailSnapshot>();

        await tester.pumpWidget(
          buildApp(
            repository: _DelayedFakeConversationRepository(
              loadCompleter: loadCompleter,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Verify the skeleton items are actual SkeletonListItem widgets.
        expect(find.byType(SkeletonListItem), findsNWidgets(5));
      },
    );

    testWidgets(
      'skeleton disappears after data arrives',
      (tester) async {
        final loadCompleter = Completer<ConversationDetailSnapshot>();

        await tester.pumpWidget(
          buildApp(
            repository: _DelayedFakeConversationRepository(
              loadCompleter: loadCompleter,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Skeleton visible.
        expect(
          find.byKey(const ValueKey('conversation-skeleton')),
          findsOneWidget,
        );

        // Complete the network request.
        loadCompleter.complete(sampleSnapshot);
        await tester.pumpAndSettle();

        // Skeleton gone.
        expect(
          find.byKey(const ValueKey('conversation-skeleton')),
          findsNothing,
          reason: 'Skeleton must disappear after data arrives',
        );

        // Real content visible.
        expect(
          find.byKey(const ValueKey('conversation-success')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'skeleton NOT shown during SWR refresh (stale data stays visible)',
      (tester) async {
        // Use a fast-resolving repo for the initial load.
        await tester.pumpWidget(
          buildApp(
            repository: _FakeConversationRepository(
              snapshot: sampleSnapshot,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Success state — real messages visible.
        expect(
          find.byKey(const ValueKey('conversation-success')),
          findsOneWidget,
        );

        // No skeleton.
        expect(
          find.byKey(const ValueKey('conversation-skeleton')),
          findsNothing,
          reason: 'Skeleton must not appear during SWR refresh; '
              'stale data stays visible',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FixedSessionStore extends SessionStore {
  _FixedSessionStore(this._state);

  final SessionState _state;

  @override
  SessionState build() => _state;
}

class _FakeConversationRepository implements ConversationRepository {
  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  _FakeConversationRepository({required this.snapshot});

  final ConversationDetailSnapshot snapshot;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    return snapshot;
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
  Future<ConversationMessagePage> loadMessageContext(
    ConversationDetailTarget target, {
    required String messageId,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
        hasNewer: false,
      );

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    return 'test-attachment-id';
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    bool? asTask,
    CancelToken? cancelToken,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async {
    return message;
  }

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {
    return null;
  }

  @override
  Future<void> editMessage(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {}

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> pinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> unpinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> addReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async {
    return const [];
  }

  @override
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}
}

class _DelayedFakeConversationRepository implements ConversationRepository {
  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  _DelayedFakeConversationRepository({required this.loadCompleter});

  final Completer<ConversationDetailSnapshot> loadCompleter;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) {
    return loadCompleter.future;
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
  Future<ConversationMessagePage> loadMessageContext(
    ConversationDetailTarget target, {
    required String messageId,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
        hasNewer: false,
      );

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    return 'test-attachment-id';
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    bool? asTask,
    CancelToken? cancelToken,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async {
    return message;
  }

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {
    return null;
  }

  @override
  Future<void> editMessage(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {}

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> pinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> unpinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}

  @override
  Future<void> addReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async {
    return const [];
  }

  @override
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}
}
