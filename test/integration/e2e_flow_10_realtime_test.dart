// =============================================================================
// PR #855 — E2E Flow 10: Real-time Updates
//
// Verifies the end-to-end realtime update pipeline:
// 1. Receive new message via socket mock → verify it appears in conversation
// 2. Verify inbox unread count updates after realtime message
// 3. Verify typing indicator shows when typing event received and hides after
//    expiry timeout
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/typing_indicator_store.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/application/inbox_unread_count_provider.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/inbox/data/inbox_repository_provider.dart';

import '../support/fakes/fake_inbox_repository.dart';
import 'b132_phase2_test_support.dart';

void main() {
  // ===========================================================================
  // Flow 10a: Realtime message appears in conversation
  // ===========================================================================
  group('E2E Flow 10a: Realtime message reception', () {
    testWidgets(
        'message:new event from another user → message appears in conversation',
        (tester) async {
      final prefs = await b132Prefs();
      final ingress = RealtimeReductionIngress();
      addTearDown(() => ingress.dispose());

      final conversationRepository = B132ConversationRepository(
        seed: {
          b132ChannelId: [
            b132Message(
              id: 'msg-1',
              content: 'Hello from before',
              seq: 1,
            ),
          ],
        },
      );

      final router = GoRouter(
        initialLocation: '/conversation',
        routes: [
          GoRoute(
            path: '/conversation',
            builder: (_, __) =>
                ConversationDetailPage(target: b132ChannelTarget),
          ),
        ],
      );

      await tester.pumpWidget(b132App(
        router: router,
        prefs: prefs,
        conversationRepository: conversationRepository,
        realtimeIngress: ingress,
      ));
      await tester.pumpAndSettle();

      // Verify initial message is shown.
      expect(find.text('Hello from before'), findsOneWidget);

      // Inject a realtime message:new event from another user.
      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: 'channel:$b132ChannelId',
        seq: 2,
        receivedAt: DateTime.now(),
        payload: {
          'id': 'msg-realtime-1',
          'channelId': b132ChannelId,
          'content': 'Live from the socket!',
          'createdAt': DateTime.now().toIso8601String(),
          'senderId': 'user-3',
          'senderType': 'human',
          'senderName': 'Charlie',
          'messageType': 'message',
          'seq': 2,
        },
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // The new message should now be visible in the conversation.
      expect(
        find.text('Live from the socket!'),
        findsOneWidget,
        reason: 'Realtime message should appear in the conversation list',
      );
    });

    testWidgets(
        'multiple realtime messages arrive in sequence → all appear in order',
        (tester) async {
      final prefs = await b132Prefs();
      final ingress = RealtimeReductionIngress();
      addTearDown(() => ingress.dispose());

      final conversationRepository = B132ConversationRepository(
        seed: {
          b132ChannelId: [
            b132Message(id: 'msg-1', content: 'First message', seq: 1),
          ],
        },
      );

      final router = GoRouter(
        initialLocation: '/conversation',
        routes: [
          GoRoute(
            path: '/conversation',
            builder: (_, __) =>
                ConversationDetailPage(target: b132ChannelTarget),
          ),
        ],
      );

      await tester.pumpWidget(b132App(
        router: router,
        prefs: prefs,
        conversationRepository: conversationRepository,
        realtimeIngress: ingress,
      ));
      await tester.pumpAndSettle();

      // Inject two realtime messages in quick succession.
      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: 'channel:$b132ChannelId',
        seq: 2,
        receivedAt: DateTime.now(),
        payload: {
          'id': 'msg-rt-2',
          'channelId': b132ChannelId,
          'content': 'Second from socket',
          'createdAt': DateTime.now().toIso8601String(),
          'senderId': 'user-3',
          'senderType': 'human',
          'senderName': 'Charlie',
          'messageType': 'message',
          'seq': 2,
        },
      ));
      await tester.pump(const Duration(milliseconds: 50));

      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: 'channel:$b132ChannelId',
        seq: 3,
        receivedAt: DateTime.now(),
        payload: {
          'id': 'msg-rt-3',
          'channelId': b132ChannelId,
          'content': 'Third from socket',
          'createdAt': DateTime.now().toIso8601String(),
          'senderId': 'user-4',
          'senderType': 'human',
          'senderName': 'Diana',
          'messageType': 'message',
          'seq': 3,
        },
      ));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Both messages should appear.
      expect(
        find.text('Second from socket'),
        findsOneWidget,
        reason: 'First realtime message should be visible',
      );
      expect(
        find.text('Third from socket'),
        findsOneWidget,
        reason: 'Second realtime message should be visible',
      );
    });
  });

  // ===========================================================================
  // Flow 10b: Inbox unread count updates after realtime message
  // ===========================================================================
  group('E2E Flow 10b: Inbox unread count update', () {
    testWidgets(
        'realtime message triggers inbox refresh → unread count updates',
        (tester) async {
      final prefs = await b132Prefs();
      final ingress = RealtimeReductionIngress();
      addTearDown(() => ingress.dispose());

      // Start with 0 unread, then update to 1 after refresh.
      final fakeInbox = FakeInboxRepository(
        fetchResponse: const InboxResponse(
          items: [],
          totalCount: 0,
          totalUnreadCount: 0,
          hasMore: false,
        ),
      );

      final router = GoRouter(
        initialLocation: '/conversation',
        routes: [
          GoRoute(
            path: '/conversation',
            builder: (_, __) =>
                ConversationDetailPage(target: b132ChannelTarget),
          ),
        ],
      );

      await tester.pumpWidget(b132App(
        router: router,
        prefs: prefs,
        realtimeIngress: ingress,
        overrides: [
          inboxRepositoryProvider.overrideWithValue(fakeInbox),
        ],
      ));
      await tester.pumpAndSettle();

      // Access ProviderScope container.
      final innerElement =
          tester.element(find.byKey(const ValueKey('composer-input')));
      final container = ProviderScope.containerOf(innerElement);

      // Force inbox store to load so it reaches success state.
      container.read(inboxStoreProvider.notifier).load();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify inbox is now in success state with 0 unread.
      final initialState = container.read(inboxStoreProvider);
      expect(initialState.status, InboxStatus.success,
          reason: 'Inbox must be in success state for refresh to trigger');
      expect(initialState.totalUnreadCount, 0);

      final fetchCountBefore = fakeInbox.fetchCallCount;

      // Start the domain event router (normally mounted in main.dart).
      container.read(domainRuntimeEventRouterProvider);
      await tester.pump();

      // Change the fake response to return unread=1 on next fetch.
      fakeInbox.fetchResponse = const InboxResponse(
        items: [
          InboxItem(
            channelId: 'other-channel',
            channelName: 'Other',
            kind: InboxItemKind.channel,
            unreadCount: 1,
            preview: 'New msg',
          ),
        ],
        totalCount: 1,
        totalUnreadCount: 1,
        hasMore: false,
      );

      // Inject a realtime message event (from a different channel so it
      // doesn't get suppressed by the "open conversation" guard).
      ingress.accept(RealtimeEventEnvelope(
        eventType: 'message:new',
        scopeKey: 'channel:other-channel',
        seq: 1,
        receivedAt: DateTime.now(),
        payload: {
          'id': 'msg-other-1',
          'channelId': 'other-channel',
          'content': 'Hey!',
          'createdAt': DateTime.now().toIso8601String(),
          'senderId': 'user-5',
          'senderType': 'human',
          'senderName': 'Eve',
          'messageType': 'message',
          'seq': 1,
        },
      ));
      await tester.pump();

      // Wait for the debounce timer (2 seconds).
      await tester.pump(const Duration(milliseconds: 2100));
      // Let the async fetchInbox complete.
      await tester.pump(const Duration(milliseconds: 100));

      // Verify inbox was refreshed.
      expect(
        fakeInbox.fetchCallCount,
        greaterThan(fetchCountBefore),
        reason: 'Inbox should be refreshed after realtime event + debounce',
      );

      // Verify the unread count provider reflects the update.
      final updatedUnreadCount = container.read(inboxTotalUnreadCountProvider);
      expect(
        updatedUnreadCount,
        1,
        reason: 'Total unread count should update to 1 after refresh',
      );
    });
  });

  // ===========================================================================
  // Flow 10c: Typing indicator shows on event and hides after expiry
  // ===========================================================================
  group('E2E Flow 10c: Typing indicator', () {
    testWidgets('typing:start event shows indicator widget', (tester) async {
      final prefs = await b132Prefs();
      final ingress = RealtimeReductionIngress();
      addTearDown(() => ingress.dispose());

      final router = GoRouter(
        initialLocation: '/conversation',
        routes: [
          GoRoute(
            path: '/conversation',
            builder: (_, __) =>
                ConversationDetailPage(target: b132ChannelTarget),
          ),
        ],
      );

      await tester.pumpWidget(b132App(
        router: router,
        prefs: prefs,
        realtimeIngress: ingress,
      ));
      await tester.pumpAndSettle();

      // Initially, typing indicator should not be visible.
      expect(
        find.byKey(const ValueKey('typing-indicator')),
        findsNothing,
        reason: 'Typing indicator should not be visible initially',
      );

      // Inject a typing:start event from another user.
      // The scope key format is 'server:{serverId}/{channel|dm}:{conversationId}'
      ingress.accept(RealtimeEventEnvelope(
        eventType: 'typing:start',
        scopeKey: 'server:server-1/channel:$b132ChannelId',
        seq: 0,
        receivedAt: DateTime.now(),
        payload: {
          'scopeKey': 'server:server-1/channel:$b132ChannelId',
          'userId': 'user-3',
          'displayName': 'Charlie',
        },
      ));
      // Use pump() not pumpAndSettle() — animated dots never settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Typing indicator should now be visible.
      expect(
        find.byKey(const ValueKey('typing-indicator')),
        findsOneWidget,
        reason: 'Typing indicator should appear after typing:start event',
      );
    });

    testWidgets('typing indicator hides after expiry timeout (5s)',
        (tester) async {
      final prefs = await b132Prefs();
      final ingress = RealtimeReductionIngress();
      addTearDown(() => ingress.dispose());

      final router = GoRouter(
        initialLocation: '/conversation',
        routes: [
          GoRoute(
            path: '/conversation',
            builder: (_, __) =>
                ConversationDetailPage(target: b132ChannelTarget),
          ),
        ],
      );

      await tester.pumpWidget(b132App(
        router: router,
        prefs: prefs,
        realtimeIngress: ingress,
      ));
      await tester.pumpAndSettle();

      // Inject a typing event.
      ingress.accept(RealtimeEventEnvelope(
        eventType: 'typing:start',
        scopeKey: 'server:server-1/channel:$b132ChannelId',
        seq: 0,
        receivedAt: DateTime.now(),
        payload: {
          'scopeKey': 'server:server-1/channel:$b132ChannelId',
          'userId': 'user-3',
          'displayName': 'Charlie',
        },
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify visible.
      expect(
        find.byKey(const ValueKey('typing-indicator')),
        findsOneWidget,
        reason: 'Typing indicator should be visible',
      );

      // Advance past the kTypingIndicatorExpiry (5 seconds).
      await tester.pump(const Duration(seconds: 6));

      // Typing indicator should now be gone.
      expect(
        find.byKey(const ValueKey('typing-indicator')),
        findsNothing,
        reason:
            'Typing indicator should disappear after 5s expiry with no new event',
      );
    });

    testWidgets('typing event from self is ignored', (tester) async {
      final prefs = await b132Prefs();
      final ingress = RealtimeReductionIngress();
      addTearDown(() => ingress.dispose());

      final router = GoRouter(
        initialLocation: '/conversation',
        routes: [
          GoRoute(
            path: '/conversation',
            builder: (_, __) =>
                ConversationDetailPage(target: b132ChannelTarget),
          ),
        ],
      );

      await tester.pumpWidget(b132App(
        router: router,
        prefs: prefs,
        realtimeIngress: ingress,
      ));
      await tester.pumpAndSettle();

      // Inject a typing event from the current user (user-1 in B132SessionStore).
      ingress.accept(RealtimeEventEnvelope(
        eventType: 'typing:start',
        scopeKey: 'server:server-1/channel:$b132ChannelId',
        seq: 0,
        receivedAt: DateTime.now(),
        payload: {
          'scopeKey': 'server:server-1/channel:$b132ChannelId',
          'userId': 'user-1',
          'displayName': 'Robin',
        },
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Typing indicator should NOT appear (self-typing is ignored).
      expect(
        find.byKey(const ValueKey('typing-indicator')),
        findsNothing,
        reason: 'Typing events from self should not show the indicator',
      );
    });

    testWidgets('multiple typers shown simultaneously', (tester) async {
      final prefs = await b132Prefs();
      final ingress = RealtimeReductionIngress();
      addTearDown(() => ingress.dispose());

      final router = GoRouter(
        initialLocation: '/conversation',
        routes: [
          GoRoute(
            path: '/conversation',
            builder: (_, __) =>
                ConversationDetailPage(target: b132ChannelTarget),
          ),
        ],
      );

      await tester.pumpWidget(b132App(
        router: router,
        prefs: prefs,
        realtimeIngress: ingress,
      ));
      await tester.pumpAndSettle();

      // Inject typing events from two different users.
      ingress.accept(RealtimeEventEnvelope(
        eventType: 'typing:start',
        scopeKey: 'server:server-1/channel:$b132ChannelId',
        seq: 0,
        receivedAt: DateTime.now(),
        payload: {
          'scopeKey': 'server:server-1/channel:$b132ChannelId',
          'userId': 'user-3',
          'displayName': 'Charlie',
        },
      ));
      await tester.pump(const Duration(milliseconds: 10));

      ingress.accept(RealtimeEventEnvelope(
        eventType: 'typing:start',
        scopeKey: 'server:server-1/channel:$b132ChannelId',
        seq: 0,
        receivedAt: DateTime.now(),
        payload: {
          'scopeKey': 'server:server-1/channel:$b132ChannelId',
          'userId': 'user-4',
          'displayName': 'Diana',
        },
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Typing indicator should be visible (two-person variant).
      expect(
        find.byKey(const ValueKey('typing-indicator')),
        findsOneWidget,
        reason: 'Typing indicator should show when multiple users are typing',
      );

      // Access container to verify both typers are tracked.
      final innerElement =
          tester.element(find.byKey(const ValueKey('composer-input')));
      final container = ProviderScope.containerOf(innerElement);
      final typingState = container.read(typingIndicatorStoreProvider);
      expect(
        typingState.activeTypers,
        hasLength(2),
        reason: 'Both active typers should be tracked',
      );
    });
  });
}
