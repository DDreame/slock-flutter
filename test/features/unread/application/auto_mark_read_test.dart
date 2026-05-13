// ---------------------------------------------------------------------------
// #497: Auto mark-read on conversation enter — Phase A (test-only)
//
// Invariants verified:
// INV-READ-1: Entering conversation with unread → unreadCount drops to 0
// INV-READ-2: markRead does not block conversation UI loading (async)
// INV-READ-3: markRead API failure → UI does not flicker (optimistic kept)
// INV-READ-4: unreadCount == 0 → no redundant API request
// INV-READ-5: Quick enter/exit (<1s) still triggers markRead
// ---------------------------------------------------------------------------
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  const server1 = ServerScopeId('server-1');
  const channelGeneral = ChannelScopeId(serverId: server1, value: 'ch-general');
  const dmAlice = DirectMessageScopeId(serverId: server1, value: 'dm-alice');

  final channelTarget = ConversationDetailTarget.channel(channelGeneral);
  final dmTarget = ConversationDetailTarget.directMessage(dmAlice);

  /// Creates a provider container with inbox pre-seeded with unread items.
  ProviderContainer createContainer({
    required ConversationRepository conversationRepo,
    required _RecordingInboxRepository inboxRepo,
    List<InboxItem> inboxItems = const [],
    int totalUnreadCount = 0,
  }) {
    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(conversationRepo),
        inboxRepositoryProvider.overrideWithValue(inboxRepo),
        activeServerScopeIdProvider.overrideWithValue(server1),
        homeListStoreProvider.overrideWith(
          () => _FakeHomeListStore(
            const HomeListState(
              status: HomeListStatus.success,
              channels: [
                HomeChannelSummary(
                  scopeId: channelGeneral,
                  name: 'general',
                ),
              ],
              directMessages: [
                HomeDirectMessageSummary(
                  scopeId: dmAlice,
                  title: 'Alice',
                ),
              ],
            ),
          ),
        ),
        sessionStoreProvider.overrideWith(
          () => _FixedSessionStore(const SessionState()),
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

  /// Seeds the InboxStore with items so unread counts are available.
  Future<void> seedInbox(
    ProviderContainer container, {
    required List<InboxItem> items,
    int totalUnreadCount = 0,
  }) async {
    // Load triggers fetchInbox, which returns the preconfigured response.
    await container.read(inboxStoreProvider.notifier).load();
  }

  group('Auto mark-read on conversation enter (#497)', () {
    // -------------------------------------------------------------------
    // INV-READ-1: Entering channel conversation with unread → markRead
    // called, unreadCount drops to 0.
    // -------------------------------------------------------------------
    testWidgets(
      'entering channel with unread auto-marks read on successful load '
      '(INV-READ-1)',
      skip: true, // TDD red — Phase B implementation required
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

        // Seed inbox so unread counts are available.
        await seedInbox(container, items: const []);

        // Verify unread before entering conversation.
        expect(
          container
              .read(unreadSourceProjectionProvider)
              .channelUnreadCount(channelGeneral),
          5,
          reason: 'Channel should have 5 unread before entering conversation',
        );

        // Enter the conversation.
        await pumpConversation(tester,
            container: container, target: channelTarget);
        await tester.pumpAndSettle();

        // After successful load, markRead should have been called.
        expect(
          inboxRepo.markReadChannelIds,
          contains('ch-general'),
          reason: 'markRead should be called after conversation loads',
        );

        // Unread count should drop to 0 (optimistic update).
        expect(
          container
              .read(unreadSourceProjectionProvider)
              .channelUnreadCount(channelGeneral),
          0,
          reason:
              'INV-READ-1: Channel unread should be 0 after entering conversation',
        );
      },
    );

    // -------------------------------------------------------------------
    // INV-READ-1 (DM variant): Entering DM conversation with unread →
    // markRead called, unreadCount drops to 0.
    // -------------------------------------------------------------------
    testWidgets(
      'entering DM with unread auto-marks read on successful load '
      '(INV-READ-1)',
      skip: true, // TDD red — Phase B implementation required
      (tester) async {
        final inboxRepo = _RecordingInboxRepository(
          fetchResponse: const InboxResponse(
            items: [
              InboxItem(
                kind: InboxItemKind.dm,
                channelId: 'dm-alice',
                channelName: 'Alice',
                unreadCount: 3,
              ),
            ],
            totalCount: 1,
            totalUnreadCount: 3,
            hasMore: false,
          ),
        );
        final conversationRepo = _FakeConversationRepository(
          snapshot: ConversationDetailSnapshot(
            target: dmTarget,
            title: 'Alice',
            messages: [
              ConversationMessageSummary(
                id: 'msg-dm-1',
                content: 'Hey',
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
        await seedInbox(container, items: const []);

        // Verify unread before entering.
        expect(
          container.read(unreadSourceProjectionProvider).dmUnreadCount(dmAlice),
          3,
        );

        // Enter the DM conversation.
        await pumpConversation(tester, container: container, target: dmTarget);
        await tester.pumpAndSettle();

        // markRead should have been called for the DM channel.
        expect(
          inboxRepo.markReadChannelIds,
          contains('dm-alice'),
          reason: 'markRead should be called for DM after conversation loads',
        );

        // DM unread should drop to 0.
        expect(
          container.read(unreadSourceProjectionProvider).dmUnreadCount(dmAlice),
          0,
          reason: 'INV-READ-1: DM unread should be 0 after entering',
        );
      },
    );

    // -------------------------------------------------------------------
    // INV-READ-4: unreadCount == 0 → no redundant markRead API request.
    // -------------------------------------------------------------------
    testWidgets(
      'entering conversation with no unread does not call markRead '
      '(INV-READ-4)',
      (tester) async {
        final inboxRepo = _RecordingInboxRepository(
          fetchResponse: const InboxResponse(
            items: [
              InboxItem(
                kind: InboxItemKind.channel,
                channelId: 'ch-general',
                channelName: 'general',
                unreadCount: 0,
              ),
            ],
            totalCount: 1,
            totalUnreadCount: 0,
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
        await seedInbox(container, items: const []);

        // Enter the conversation — unread is already 0.
        await pumpConversation(tester,
            container: container, target: channelTarget);
        await tester.pumpAndSettle();

        // markRead should NOT have been called.
        expect(
          inboxRepo.markReadChannelIds,
          isEmpty,
          reason:
              'INV-READ-4: markRead must not fire when unreadCount is already 0',
        );
      },
    );

    // -------------------------------------------------------------------
    // INV-READ-2: markRead does not block conversation UI load.
    // -------------------------------------------------------------------
    testWidgets(
      'markRead does not block conversation UI — messages render immediately '
      '(INV-READ-2)',
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
          // Simulate slow markRead — never completes within test.
          markReadDelay: const Duration(seconds: 30),
        );
        final conversationRepo = _FakeConversationRepository(
          snapshot: ConversationDetailSnapshot(
            target: channelTarget,
            title: '#general',
            messages: [
              ConversationMessageSummary(
                id: 'msg-1',
                content: 'Non-blocking message',
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
        await seedInbox(container, items: const []);

        await pumpConversation(tester,
            container: container, target: channelTarget);
        // Pump a few frames — don't use pumpAndSettle because markRead
        // never completes in this test.
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Conversation UI should be rendered even though markRead is pending.
        expect(
          find.text('Non-blocking message'),
          findsOneWidget,
          reason:
              'INV-READ-2: Messages must render without waiting for markRead',
        );
      },
    );

    // -------------------------------------------------------------------
    // INV-READ-3: markRead API failure → UI does not flicker.
    // -------------------------------------------------------------------
    testWidgets(
      'markRead API failure does not affect conversation UI '
      '(INV-READ-3)',
      skip: true, // TDD red — Phase B implementation required
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
          markReadFailure:
              const NetworkFailure(message: 'mark-read network error'),
        );
        final conversationRepo = _FakeConversationRepository(
          snapshot: ConversationDetailSnapshot(
            target: channelTarget,
            title: '#general',
            messages: [
              ConversationMessageSummary(
                id: 'msg-1',
                content: 'Stable message',
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
        await seedInbox(container, items: const []);

        await pumpConversation(tester,
            container: container, target: channelTarget);
        await tester.pumpAndSettle();

        // UI should still show conversation content — no error overlay.
        expect(
          find.text('Stable message'),
          findsOneWidget,
          reason: 'INV-READ-3: API failure must not disturb conversation UI',
        );

        // Optimistic unread update should be retained despite API failure.
        expect(
          container
              .read(unreadSourceProjectionProvider)
              .channelUnreadCount(channelGeneral),
          0,
          reason:
              'INV-READ-3: Optimistic unread=0 must survive markRead API failure',
        );
      },
    );

    // -------------------------------------------------------------------
    // INV-READ-5: Quick enter/exit still triggers markRead.
    // -------------------------------------------------------------------
    testWidgets(
      'quick enter and exit still triggers markRead '
      '(INV-READ-5)',
      skip: true, // TDD red — Phase B implementation required
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
                content: 'Quick message',
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
        await seedInbox(container, items: const []);

        // Enter conversation.
        await pumpConversation(tester,
            container: container, target: channelTarget);
        await tester.pumpAndSettle();

        // Immediately replace with a blank page (simulates quick back).
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SizedBox.shrink()),
          ),
        );
        await tester.pumpAndSettle();

        // Even after quick exit, markRead should have been triggered.
        expect(
          inboxRepo.markReadChannelIds,
          contains('ch-general'),
          reason: 'INV-READ-5: markRead must fire even on quick enter/exit',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _RecordingInboxRepository implements InboxRepository {
  _RecordingInboxRepository({
    required this.fetchResponse,
    this.markReadDelay,
    this.markReadFailure,
  });

  final InboxResponse fetchResponse;
  final Duration? markReadDelay;
  final AppFailure? markReadFailure;

  final List<String> markReadChannelIds = [];
  final List<String> markDoneChannelIds = [];
  bool markAllReadCalled = false;

  @override
  Future<InboxResponse> fetchInbox(
    ServerScopeId serverId, {
    InboxFilter filter = InboxFilter.all,
    int limit = 30,
    int offset = 0,
  }) async {
    return fetchResponse;
  }

  @override
  Future<void> markItemRead(
    ServerScopeId serverId, {
    required String channelId,
  }) async {
    markReadChannelIds.add(channelId);
    if (markReadDelay != null) {
      await Future<void>.delayed(markReadDelay!);
    }
    if (markReadFailure != null) throw markReadFailure!;
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
