// ---------------------------------------------------------------------------
// #541: Mark-read race condition — Phase A (test-only)
//
// Root cause: _handleStateChange fires markRead exactly once on the
// initial -> success transition, guarded by channelUnreadCount > 0.
// But unreadSourceProjectionProvider returns all zeros when InboxStore
// is in initial/failure state.  If the conversation loads before the
// inbox finishes loading (notification deep link, home unread card),
// the one-shot window fires with 0 unread → markRead never called.
//
// Invariants verified:
// INV-RACE-1: Entering conversation with late inbox → markRead fires
//             after inbox projection transitions to loaded
// INV-RACE-2: Deferred markRead fires exactly once (no duplicates)
// ---------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';
import 'package:dio/dio.dart';

void main() {
  const server1 = ServerScopeId('server-1');
  const channelGeneral = ChannelScopeId(serverId: server1, value: 'ch-general');

  final channelTarget = ConversationDetailTarget.channel(channelGeneral);

  /// Creates a provider container. Does NOT seed the inbox — callers
  /// must explicitly call [seedInbox] to simulate inbox loading.
  ProviderContainer createContainer({
    required ConversationRepository conversationRepo,
    required _RecordingInboxRepository inboxRepo,
  }) {
    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(conversationRepo),
        inboxRepositoryProvider.overrideWithValue(inboxRepo),
        activeServerScopeIdProvider.overrideWithValue(server1),
        homeListStoreProvider.overrideWith(
          () => _FakeHomeListStore(
            HomeListState(
              status: HomeListStatus.success,
              channels: [
                const HomeChannelSummary(
                  scopeId: channelGeneral,
                  name: 'general',
                ),
              ],
              directMessages: [],
            ),
          ),
        ),
        sessionStoreProvider.overrideWith(
          () => _FixedSessionStore(const SessionState()),
        ),
        homeNowProvider.overrideWith(
          (ref) => Stream.value(DateTime.now()),
        ),
      ],
    );
    return container;
  }

  /// Pumps ConversationDetailPage inside MaterialApp.router with GoRouter.
  Future<void> pumpConversation(
    WidgetTester tester, {
    required ProviderContainer container,
    required ConversationDetailTarget target,
  }) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => ConversationDetailPage(target: target),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
        ),
      ),
    );
  }

  /// Seeds the InboxStore by triggering load() — the repository's
  /// preconfigured fetchResponse provides the items.
  Future<void> seedInbox(ProviderContainer container) async {
    await container.read(inboxStoreProvider.notifier).load();
  }

  group('Mark-read race condition (#541)', () {
    // -------------------------------------------------------------------
    // INV-RACE-1: Conversation loads before inbox projection is available.
    // markRead must fire once the inbox projection transitions to loaded.
    // -------------------------------------------------------------------
    testWidgets(
      'markRead fires after inbox loads even when conversation loaded first '
      '(INV-RACE-1)',
      (tester) async {
        final inboxRepo = _RecordingInboxRepository(
          fetchResponse: const InboxResponse(
            items: [
              InboxItem(
                kind: InboxItemKind.channel,
                channelId: 'ch-general',
                channelName: 'general',
                unreadCount: 5,
              ),
            ],
            totalCount: 1,
            totalUnreadCount: 5,
            hasMore: false,
          ),
        );
        // Block auto-load from completing so inbox stays in loading state
        // until we explicitly call seedInbox().
        inboxRepo.fetchGate = Completer<void>();
        final conversationRepo = _FakeConversationRepository(
          snapshot: ConversationDetailSnapshot(
            target: channelTarget,
            title: '#general',
            messages: [
              ConversationMessageSummary(
                id: 'msg-1',
                content: 'Hello',
                createdAt: DateTime.parse('2026-05-13T12:00:00Z'),
                senderType: 'human',
                messageType: 'message',
                seq: 1,
              ),
            ],
            historyLimited: false,
            hasOlder: false,
          ),
        );

        final container = createContainer(
          conversationRepo: conversationRepo,
          inboxRepo: inboxRepo,
        );
        addTearDown(container.dispose);

        // DO NOT seed inbox — simulates inbox still loading when user
        // opens a conversation (e.g. via notification deep link).

        // Verify inbox projection is in initial state (all zeros).
        expect(
          container.read(unreadSourceProjectionProvider).isLoaded,
          isFalse,
          reason: 'Inbox projection should not be loaded yet',
        );

        // Enter the conversation — it loads successfully.
        await pumpConversation(
          tester,
          container: container,
          target: channelTarget,
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Conversation rendered, but inbox was not available during the
        // success transition — the one-shot _handleStateChange saw 0 unread.
        expect(
          find.text('Hello'),
          findsOneWidget,
          reason: 'Conversation should render despite inbox not loaded',
        );

        // KEY MID-TEST ASSERTION: markRead must NOT have been called yet.
        // The conversation reached success while inbox was still initial,
        // so the unread projection returned 0 and the > 0 guard skipped.
        expect(
          inboxRepo.markReadChannelIds,
          isEmpty,
          reason: 'markRead must not fire while inbox is still initial '
              '(projection returns 0)',
        );

        // Now simulate inbox finishing its load.
        // Release the fetch gate so auto-load (and seedInbox) can complete.
        inboxRepo.fetchGate!.complete();
        await seedInbox(container);

        // Verify inbox projection is now loaded with unread.
        // The deferred markRead is scheduled for the next frame via
        // addPostFrameCallback, so the loaded state is observable here
        // before the optimistic zeroing kicks in.
        expect(
          container
              .read(unreadSourceProjectionProvider)
              .channelUnreadCount(channelGeneral),
          greaterThan(0),
          reason: 'Inbox should now report unread for ch-general',
        );

        // Pump to let the deferred markRead fire on the next frame.
        await tester.pumpAndSettle();

        // KEY ASSERTION: markRead must have been called despite the
        // conversation loading before the inbox.
        expect(
          inboxRepo.markReadChannelIds,
          contains('ch-general'),
          reason: 'INV-RACE-1: markRead must fire after inbox loads, even when '
              'conversation loaded first',
        );

        // Unread should drop to 0 after markRead.
        expect(
          container
              .read(unreadSourceProjectionProvider)
              .channelUnreadCount(channelGeneral),
          0,
          reason:
              'INV-RACE-1: Unread should be 0 after deferred markRead fires',
        );
      },
    );

    // -------------------------------------------------------------------
    // INV-RACE-2: Deferred markRead fires exactly once — no duplicate
    // calls even when inbox transitions multiple times.
    // -------------------------------------------------------------------
    testWidgets(
      'deferred markRead fires exactly once after inbox loads '
      '(INV-RACE-2)',
      (tester) async {
        final inboxRepo = _RecordingInboxRepository(
          fetchResponse: const InboxResponse(
            items: [
              InboxItem(
                kind: InboxItemKind.channel,
                channelId: 'ch-general',
                channelName: 'general',
                unreadCount: 5,
              ),
            ],
            totalCount: 1,
            totalUnreadCount: 5,
            hasMore: false,
          ),
        );
        final conversationRepo = _FakeConversationRepository(
          snapshot: ConversationDetailSnapshot(
            target: channelTarget,
            title: '#general',
            messages: [
              ConversationMessageSummary(
                id: 'msg-1',
                content: 'Hello',
                createdAt: DateTime.parse('2026-05-13T12:00:00Z'),
                senderType: 'human',
                messageType: 'message',
                seq: 1,
              ),
            ],
            historyLimited: false,
            hasOlder: false,
          ),
        );

        final container = createContainer(
          conversationRepo: conversationRepo,
          inboxRepo: inboxRepo,
        );
        addTearDown(container.dispose);

        // Enter conversation without inbox loaded.
        await pumpConversation(
          tester,
          container: container,
          target: channelTarget,
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Seed inbox — triggers deferred markRead.
        await seedInbox(container);
        await tester.pumpAndSettle();

        // Simulate inbox refresh (e.g. pull-to-refresh or reconnect).
        await container.read(inboxStoreProvider.notifier).refresh();
        await tester.pumpAndSettle();

        // markRead should have been called exactly once — the deferred
        // trigger should not re-fire on subsequent inbox refreshes.
        expect(
          inboxRepo.markReadChannelIds.where((id) => id == 'ch-general').length,
          1,
          reason: 'INV-RACE-2: markRead must fire exactly once, not on every '
              'inbox refresh',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Fakes (duplicated from auto_mark_read_test.dart — private to that file)
// ---------------------------------------------------------------------------

class _RecordingInboxRepository implements InboxRepository {
  _RecordingInboxRepository({required this.fetchResponse});

  final InboxResponse fetchResponse;

  final List<String> markReadChannelIds = [];
  final List<String> markDoneChannelIds = [];
  bool markAllReadCalled = false;

  /// When non-null, fetchInbox waits on this completer before returning.
  /// Used to block auto-load from completing during test setup.
  Completer<void>? fetchGate;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    if (fetchGate != null) {
      await fetchGate!.future;
    }
    return fetchResponse;
  }

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    markReadChannelIds.add(channelId);
  }

  @override
  Future<void> markItemDone(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    markDoneChannelIds.add(channelId);
  }

  @override
  Future<void> markAllRead(ServerScopeId serverId) async {
    markAllReadCalled = true;
  }
}

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({this.snapshot});

  final ConversationDetailSnapshot? snapshot;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    return snapshot ??
        ConversationDetailSnapshot(
          target: target,
          title: 'test',
          messages: const [],
          historyLimited: false,
          hasOlder: false,
        );
  }

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
      );

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
      );

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async =>
      'test-attachment-id';

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    CancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async =>
      message;

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async =>
      null;

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
  ) async =>
      const [];

  @override
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}
}

class _FakeHomeListStore extends HomeListStore {
  _FakeHomeListStore(this._initial);
  final HomeListState _initial;

  @override
  HomeListState build() => _initial;
}

class _FixedSessionStore extends SessionStore {
  _FixedSessionStore(this._state);
  final SessionState _state;

  @override
  SessionState build() => _state;
}
