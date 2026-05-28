// =============================================================================
// #853 — BorderRadius.circular() Hoist (5 widgets) + AgentsStore.load() Epoch
//
// Load-bearing tests:
// 1. MessageBubble: system variant uses hoisted systemBorderRadius
//    (reverting to inline allocation → identical() check fails)
// 2. ConversationMessageCard: system variant uses hoisted systemBorderRadius
//    (reverting to inline allocation → identical() check fails)
// 3. ConversationMessageCard: task badge uses hoisted taskBadgeBorderRadius
//    (reverting to inline allocation → identical() check fails)
// 4. ReactionRow: chip uses hoisted chipBorderRadius
//    (reverting to inline allocation → identical() check fails)
// 5. AgentsStore: concurrent load() discards stale response via epoch
//    (removing epoch guard → stale data leaks through)
// =============================================================================

// ignore_for_file: lines_longer_than_80_chars
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/message_bubble.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/agents/application/agents_state.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/agents/data/agent_item.dart';
import 'package:slock_app/features/agents/data/agents_repository.dart';
import 'package:slock_app/features/agents/data/agents_repository_provider.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_message_card.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_reactions.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  // ===========================================================================
  // Group 1: BorderRadius hoisting — MessageBubble
  // ===========================================================================
  group('#853 — MessageBubble BorderRadius hoist', () {
    test('systemBorderRadius is correctly configured', () {
      // The static field must be a BorderRadius with all corners set to
      // BubbleTokens.radiusLarge.
      final br = MessageBubble.systemBorderRadius;
      expect(br.topLeft, const Radius.circular(BubbleTokens.radiusLarge));
      expect(br.topRight, const Radius.circular(BubbleTokens.radiusLarge));
      expect(br.bottomLeft, const Radius.circular(BubbleTokens.radiusLarge));
      expect(br.bottomRight, const Radius.circular(BubbleTokens.radiusLarge));
    });

    test('systemBorderRadius is identity-stable (same instance across reads)',
        () {
      // Proves it's a static field, not a per-call factory.
      expect(
        identical(
            MessageBubble.systemBorderRadius, MessageBubble.systemBorderRadius),
        isTrue,
        reason: 'Reverting to inline BorderRadius.circular() → '
            'getter would produce new instance each call.',
      );
    });

    testWidgets('system variant build path uses hoisted systemBorderRadius',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: MessageBubble(
              variant: MessageBubbleVariant.system,
              child: Text('system msg'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the Container with key 'message-bubble-container'.
      final container = tester.widget<Container>(
        find.byKey(const ValueKey('message-bubble-container')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(
        identical(decoration.borderRadius, MessageBubble.systemBorderRadius),
        isTrue,
        reason: 'Reverting switch arm to inline BorderRadius.circular() → '
            'not identical to the static field (fails identity check).',
      );
    });
  });

  // ===========================================================================
  // Group 2: BorderRadius hoisting — ConversationMessageCard system + badge
  // ===========================================================================
  group('#853 — ConversationMessageCard BorderRadius hoists', () {
    test('systemBorderRadius is correctly configured', () {
      final br = ConversationMessageCard.systemBorderRadius;
      expect(br.topLeft, const Radius.circular(BubbleTokens.radiusLarge));
      expect(br.topRight, const Radius.circular(BubbleTokens.radiusLarge));
      expect(br.bottomLeft, const Radius.circular(BubbleTokens.radiusLarge));
      expect(br.bottomRight, const Radius.circular(BubbleTokens.radiusLarge));
    });

    test('systemBorderRadius is identity-stable', () {
      expect(
        identical(ConversationMessageCard.systemBorderRadius,
            ConversationMessageCard.systemBorderRadius),
        isTrue,
        reason: 'Reverting to inline → new instance each call.',
      );
    });

    testWidgets('system variant build path uses hoisted systemBorderRadius',
        (tester) async {
      final target = ConversationDetailTarget.channel(
        const ChannelScopeId(serverId: ServerScopeId('srv'), value: 'ch-1'),
      );
      // System message → _ConversationMessageVisualKind.system path.
      final message = ConversationMessageSummary(
        id: 'msg-sys',
        content: 'User joined',
        createdAt: DateTime(2026),
        senderType: 'system',
        messageType: 'system',
        senderId: 'system',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentConversationDetailTargetProvider.overrideWithValue(target),
            conversationDetailStoreProvider
                .overrideWith(() => _FakeDetailStore(target)),
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            home: Scaffold(
              body: ConversationMessageCard(
                target: target,
                message: message,
                maxBubbleWidth: 300,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The system message Container uses borderRadius from the hoisted field.
      final container = tester.widget<Container>(
        find.byKey(const ValueKey('message-msg-sys')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(
        identical(decoration.borderRadius,
            ConversationMessageCard.systemBorderRadius),
        isTrue,
        reason: 'Reverting switch arm to inline BorderRadius.circular() → '
            'not identical to the static field.',
      );
    });

    testWidgets('task badge uses hoisted taskBadgeBorderRadius',
        (tester) async {
      final target = ConversationDetailTarget.channel(
        const ChannelScopeId(serverId: ServerScopeId('srv'), value: 'ch-1'),
      );
      // Message with a linked task → _MessageLinkedTaskBadge will render.
      final message = ConversationMessageSummary(
        id: 'msg-1',
        content: 'Hello',
        createdAt: DateTime(2026),
        senderType: 'human',
        messageType: 'message',
        senderId: 'user-1',
        linkedTask: const ConversationLinkedTaskSummary(
          id: 'task-1',
          taskNumber: 42,
          status: 'todo',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentConversationDetailTargetProvider.overrideWithValue(target),
            conversationDetailStoreProvider
                .overrideWith(() => _FakeDetailStore(target)),
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            home: Scaffold(
              body: ConversationMessageCard(
                target: target,
                message: message,
                maxBubbleWidth: 300,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the task badge container by key.
      final container = tester.widget<Container>(
        find.byKey(const ValueKey('message-linked-task-task-1')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(
        identical(decoration.borderRadius,
            ConversationMessageCard.taskBadgeBorderRadius),
        isTrue,
        reason: 'Reverting to inline BorderRadius.circular(999) → '
            'not identical (fails identity check).',
      );
    });
  });

  // ===========================================================================
  // Group 4: BorderRadius hoisting — ReactionRow chip
  // ===========================================================================
  group('#853 — ReactionRow chip BorderRadius hoist', () {
    testWidgets('reaction chip uses hoisted chipBorderRadius', (tester) async {
      final target = ConversationDetailTarget.channel(
        const ChannelScopeId(serverId: ServerScopeId('srv'), value: 'ch-1'),
      );
      // Message with reactions → _ReactionChip will render.
      final message = ConversationMessageSummary(
        id: 'msg-1',
        content: 'Hello',
        createdAt: DateTime(2026),
        senderType: 'human',
        messageType: 'message',
        senderId: 'user-1',
        reactions: const [
          MessageReaction(emoji: '👍', count: 2, userIds: ['user-test']),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentConversationDetailTargetProvider.overrideWithValue(target),
            conversationDetailStoreProvider
                .overrideWith(() => _FakeDetailStore(target)),
            sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            home: Scaffold(
              body: ConversationMessageCard(
                target: target,
                message: message,
                maxBubbleWidth: 300,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the reaction chip container — it uses the hoisted borderRadius
      // in both InkWell and BoxDecoration.
      final inkWell = tester.widget<InkWell>(
        find.descendant(
          of: find.byKey(const ValueKey('reaction-👍')),
          matching: find.byType(InkWell),
        ),
      );
      expect(
        identical(inkWell.borderRadius, ReactionRow.chipBorderRadius),
        isTrue,
        reason: 'Reverting _ReactionChip InkWell to inline '
            'BorderRadius.circular() → not identical.',
      );

      // Also verify the Container decoration uses the same instance.
      final containerFinder = find.descendant(
        of: find.byKey(const ValueKey('reaction-👍')),
        matching: find.byType(Container),
      );
      final container = tester.widget<Container>(containerFinder.last);
      final decoration = container.decoration as BoxDecoration;
      expect(
        identical(decoration.borderRadius, ReactionRow.chipBorderRadius),
        isTrue,
        reason: 'Reverting _ReactionChip Container to inline '
            'BorderRadius.circular() → not identical.',
      );
    });
  });

  // ===========================================================================
  // Group 5: AgentsStore epoch guard
  // ===========================================================================
  group('#853 — AgentsStore.load() epoch guard', () {
    late _DelayableAgentsRepository fakeRepo;
    late ProviderContainer container;
    late ProviderSubscription<AgentsState> sub;

    setUp(() {
      fakeRepo = _DelayableAgentsRepository();
      container = ProviderContainer(
        overrides: [
          agentsRepositoryProvider.overrideWithValue(fakeRepo),
          agentsMachinesLoaderProvider.overrideWithValue(() async => const []),
        ],
      );
      sub = container.listen(agentsStoreProvider, (_, __) {});
    });

    tearDown(() {
      sub.close();
      container.dispose();
    });

    AgentsStore store() => container.read(agentsStoreProvider.notifier);
    AgentsState state() => container.read(agentsStoreProvider);

    test('concurrent load() discards first response (stale epoch)', () async {
      // First load will be slow (delayed).
      final slowCompleter = Completer<List<AgentItem>>();
      fakeRepo.listCompleter = slowCompleter;

      // Start first load — it will hang on the Completer.
      final firstLoad = store().load();

      // While first is in-flight, start second load (immediate).
      fakeRepo.listCompleter = null;
      fakeRepo.listResult = [
        const AgentItem(
          id: 'agent-2',
          name: 'Fresh',
          model: 'sonnet',
          runtime: 'claude',
          status: 'active',
          activity: 'online',
        ),
      ];
      final secondLoad = store().load();

      // Complete the second load first.
      await secondLoad;
      expect(state().status, AgentsStatus.success);
      expect(state().items.single.name, 'Fresh');

      // Now complete the first (slow) load with stale data.
      slowCompleter.complete([
        const AgentItem(
          id: 'agent-1',
          name: 'Stale',
          model: 'sonnet',
          runtime: 'claude',
          status: 'active',
          activity: 'online',
        ),
      ]);
      await firstLoad;

      // State must still show the FRESH data — epoch guard discards stale.
      expect(state().items.single.name, 'Fresh',
          reason: 'Removing epoch guard → stale "Stale" data leaks through, '
              'overwriting the newer "Fresh" response.');
    });

    test('single load() without concurrency applies normally', () async {
      fakeRepo.listResult = [
        const AgentItem(
          id: 'agent-1',
          name: 'Solo',
          model: 'sonnet',
          runtime: 'claude',
          status: 'active',
          activity: 'online',
        ),
      ];

      await store().load();
      expect(state().status, AgentsStatus.success);
      expect(state().items.single.name, 'Solo');
    });
  });
}

// =============================================================================
// Fakes
// =============================================================================

class _FakeDetailStore extends ConversationDetailStore {
  _FakeDetailStore(this._target);

  final ConversationDetailTarget _target;

  @override
  ConversationDetailState build() => ConversationDetailState(
        target: _target,
        status: ConversationDetailStatus.success,
      );
}

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-test',
        displayName: 'Test User',
        token: 'test-token',
      );

  @override
  Future<void> logout() async {}
}

/// Repository that supports delayed listAgents via Completer.
class _DelayableAgentsRepository
    implements AgentsRepository, AgentsMutationRepository {
  List<AgentItem>? listResult;
  Completer<List<AgentItem>>? listCompleter;

  @override
  Future<List<AgentItem>> listAgents() async {
    if (listCompleter != null) return listCompleter!.future;
    return listResult ?? [];
  }

  @override
  Future<AgentItem> createAgent(AgentMutationInput input) async =>
      throw UnimplementedError();

  @override
  Future<AgentItem> updateAgent(
          String agentId, AgentMutationInput input) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteAgent(String agentId) async => throw UnimplementedError();

  @override
  Future<void> startAgent(String agentId) async => throw UnimplementedError();

  @override
  Future<void> stopAgent(String agentId) async => throw UnimplementedError();

  @override
  Future<void> resetAgent(String agentId, {required String mode}) async =>
      throw UnimplementedError();

  @override
  Future<List<AgentActivityLogEntry>> getActivityLog(
    String agentId, {
    int limit = 50,
  }) async =>
      [];
}
