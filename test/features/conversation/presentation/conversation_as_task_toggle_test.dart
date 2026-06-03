import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    ),
  );

  Widget buildApp(_FakeConversationRepository repository) {
    return ProviderScope(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ConversationDetailPage(target: target),
      ),
    );
  }

  testWidgets('task toggle button appears and toggles state', (tester) async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ),
    );
    await tester.pumpWidget(buildApp(repository));
    await tester.pumpAndSettle();

    // Overflow button should exist
    final overflowFinder = find.byKey(const ValueKey('composer-overflow-btn'));
    expect(overflowFinder, findsOneWidget);

    // Initially the overflow button is inactive (task not enabled)
    final containerBefore = tester.widget<Container>(overflowFinder);
    final decorationBefore = containerBefore.decoration as BoxDecoration;
    final inactiveColor = decorationBefore.color;

    // Open overflow menu and tap task toggle
    await tester.tap(overflowFinder);
    await tester.pumpAndSettle();
    final taskItemFinder = find.byKey(const ValueKey('overflow-task'));
    expect(taskItemFinder, findsOneWidget);
    await tester.tap(taskItemFinder);
    await tester.pumpAndSettle();

    // After tap, overflow button should be highlighted (active state)
    final containerAfter = tester.widget<Container>(overflowFinder);
    final decorationAfter = containerAfter.decoration as BoxDecoration;
    expect(decorationAfter.color, isNot(inactiveColor));
  });

  testWidgets('send with asTask=true passes flag and resets toggle',
      (tester) async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ),
    );
    await tester.pumpWidget(buildApp(repository));
    await tester.pumpAndSettle();

    // Type a message
    final inputFinder = find.byKey(const ValueKey('composer-input'));
    await tester.enterText(inputFinder, 'Create a new task');
    await tester.pump();

    // Enable task toggle via overflow menu
    final overflowFinder = find.byKey(const ValueKey('composer-overflow-btn'));
    await tester.tap(overflowFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('overflow-task')));
    await tester.pumpAndSettle();

    // Tap send
    final sendFinder = find.byKey(const ValueKey('composer-send'));
    await tester.tap(sendFinder);
    await tester.pumpAndSettle();

    // Verify asTask was passed as true
    expect(repository.sentAsTaskFlags, [true]);

    // Toggle should reset to off after successful send — overflow button
    // should return to inactive color (surfaceAlt).
    final containerAfterSend = tester.widget<Container>(overflowFinder);
    final decorationAfterSend = containerAfterSend.decoration as BoxDecoration;
    // surfaceAlt is #F5F5F5 in light theme — just verify it's not primary
    expect(
        decorationAfterSend.color, isNot(AppTheme.light.colorScheme.primary));
  });

  testWidgets('send without asTask toggle passes null', (tester) async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ),
    );
    await tester.pumpWidget(buildApp(repository));
    await tester.pumpAndSettle();

    // Type a message without toggling task
    final inputFinder = find.byKey(const ValueKey('composer-input'));
    await tester.enterText(inputFinder, 'Regular message');
    await tester.pump();

    // Tap send
    final sendFinder = find.byKey(const ValueKey('composer-send'));
    await tester.tap(sendFinder);
    await tester.pumpAndSettle();

    // Verify asTask was null (not included)
    expect(repository.sentAsTaskFlags, [null]);
  });
}

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({this.snapshot});

  final ConversationDetailSnapshot? snapshot;
  final List<String> sentContents = [];
  final List<bool?> sentAsTaskFlags = [];

  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async =>
      snapshot ??
      ConversationDetailSnapshot(
        target: target,
        title: 'test',
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      );

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
  }) async =>
      'fake-attachment-id';

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    bool? asTask,
    String? clientId,
    CancelToken? cancelToken,
  }) async {
    sentContents.add(content);
    sentAsTaskFlags.add(asTask);
    return ConversationMessageSummary(
      id: 'msg-${sentContents.length}',
      content: content,
      senderId: 'user-1',
      senderName: 'Test User',
      createdAt: DateTime.now(),
      senderType: 'user',
      messageType: 'message',
      seq: sentContents.length,
    );
  }

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
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async =>
      const [];

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
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}
}
