// =============================================================================
// #847 — P1 ConversationDetailStore loadOlder/loadNewer Disposed Guards
//        + InboxItemTile RelativeTimeText Leaf
//
// Load-bearing tests:
// 1. loadOlder after dispose → no StateError, state unchanged
// 2. loadNewer after dispose → no StateError, state unchanged
// 3. InboxItemTile renders InboxRelativeTimeText leaf (not inline DateTime.now)
//
// Falsification:
// - Removing `if (_disposed) return;` guards → StateError on ref.read() after
//   dispose (test RED)
// - Reverting InboxRelativeTimeText → InboxItemTile calls DateTime.now() in
//   build (no leaf widget found, test RED)
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/inbox/application/conversation_projection.dart';
import 'package:slock_app/features/inbox/presentation/widgets/inbox_item_tile.dart';
import 'package:slock_app/features/inbox/presentation/widgets/inbox_relative_time_text.dart';
import 'package:slock_app/l10n/app_localizations.dart';

import '../support/support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // Group 1: Disposed guards — loadOlder/loadNewer must bail after dispose
  // ===========================================================================
  group('#847 — ConversationDetailStore disposed guards', () {
    test('loadOlder after dispose does not throw StateError', () async {
      final loadCompleter = Completer<ConversationMessagePage>();
      final repo = _DelayedPaginationRepo(
        olderCompleter: loadCompleter,
      );

      final target = ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'ch-1',
        ),
      );

      final fixture = RuntimeAppFixture(
        extraOverrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
        ],
      );

      await fixture.boot();

      final sub =
          fixture.container.listen(conversationDetailStoreProvider, (_, __) {});
      final store =
          fixture.container.read(conversationDetailStoreProvider.notifier);

      // Set up success state with messages and hasOlder=true so loadOlder
      // actually initiates the request.
      store.state = ConversationDetailState(
        target: target,
        status: ConversationDetailStatus.success,
        messages: [
          ConversationMessageSummary(
            id: 'msg-1',
            content: 'Hello',
            createdAt: DateTime(2026, 5, 1),
            senderType: 'human',
            messageType: 'text',
            seq: 100,
          ),
        ],
        hasOlder: true,
      );

      // Trigger loadOlder — the repo will block on the completer.
      final future = store.loadOlder();

      // Dispose before the completer resolves.
      sub.close();
      fixture.dispose();

      // Now resolve the pending request.
      loadCompleter.complete(const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
      ));

      // Await the future — without the guard, ref.read() throws StateError.
      await future;

      // If we reach here, no StateError was thrown. State remains unchanged
      // (still isLoadingOlder since the guard prevented the copyWith).
      expect(store.state.status, ConversationDetailStatus.success);
    });

    test('loadNewer after dispose does not throw StateError', () async {
      final loadCompleter = Completer<ConversationMessagePage>();
      final repo = _DelayedPaginationRepo(
        newerCompleter: loadCompleter,
      );

      final target = ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'ch-1',
        ),
      );

      final fixture = RuntimeAppFixture(
        extraOverrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
        ],
      );

      await fixture.boot();

      final sub =
          fixture.container.listen(conversationDetailStoreProvider, (_, __) {});
      final store =
          fixture.container.read(conversationDetailStoreProvider.notifier);

      // Set up success state with messages and hasNewer=true.
      store.state = ConversationDetailState(
        target: target,
        status: ConversationDetailStatus.success,
        messages: [
          ConversationMessageSummary(
            id: 'msg-1',
            content: 'Hello',
            createdAt: DateTime(2026, 5, 1),
            senderType: 'human',
            messageType: 'text',
            seq: 100,
          ),
        ],
        hasNewer: true,
      );

      // Trigger loadNewer — the repo will block on the completer.
      final future = store.loadNewer();

      // Dispose before the completer resolves.
      sub.close();
      fixture.dispose();

      // Resolve the pending request.
      loadCompleter.complete(const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
        hasNewer: false,
      ));

      // Await — without the guard this throws StateError.
      await future;

      // No throw means the guard works.
      expect(store.state.status, ConversationDetailStatus.success);
    });

    test('loadOlder with AppFailure after dispose does not throw', () async {
      final loadCompleter = Completer<ConversationMessagePage>();
      final repo = _DelayedPaginationRepo(
        olderCompleter: loadCompleter,
      );

      final target = ConversationDetailTarget.channel(
        const ChannelScopeId(
          serverId: ServerScopeId('server-1'),
          value: 'ch-1',
        ),
      );

      final fixture = RuntimeAppFixture(
        extraOverrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(repo),
        ],
      );

      await fixture.boot();

      final sub =
          fixture.container.listen(conversationDetailStoreProvider, (_, __) {});
      final store =
          fixture.container.read(conversationDetailStoreProvider.notifier);

      store.state = ConversationDetailState(
        target: target,
        status: ConversationDetailStatus.success,
        messages: [
          ConversationMessageSummary(
            id: 'msg-1',
            content: 'Hello',
            createdAt: DateTime(2026, 5, 1),
            senderType: 'human',
            messageType: 'text',
            seq: 100,
          ),
        ],
        hasOlder: true,
      );

      final future = store.loadOlder();

      sub.close();
      fixture.dispose();

      // Complete with an error (AppFailure path).
      loadCompleter.completeError(
        const UnknownFailure(message: 'Network error', causeType: 'test'),
      );

      // Without the guard, ref.read() in catch block throws StateError.
      await future;

      expect(store.state.status, ConversationDetailStatus.success);
    });
  });

  // ===========================================================================
  // Group 2: InboxItemTile uses InboxRelativeTimeText leaf widget
  // ===========================================================================
  group('#847 — InboxItemTile uses InboxRelativeTimeText leaf', () {
    testWidgets('renders InboxRelativeTimeText widget for time display',
        (tester) async {
      final projection = ConversationProjection(
        id: 'conv-1',
        title: 'General',
        previewText: 'Hello world',
        lastActivityAt: DateTime.now().subtract(const Duration(minutes: 5)),
        unreadCount: 1,
        kind: ConversationProjectionKind.channel,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            home: Scaffold(
              body: ListView(
                children: [
                  InboxItemTile(
                    projection: projection,
                    isMentioned: false,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The leaf widget InboxRelativeTimeText must be present in the tree.
      expect(
        find.byType(InboxRelativeTimeText),
        findsOneWidget,
        reason: 'InboxItemTile must use InboxRelativeTimeText leaf widget '
            'instead of inline DateTime.now()',
      );
    });

    testWidgets('does not render InboxRelativeTimeText when no lastActivityAt',
        (tester) async {
      const projection = ConversationProjection(
        id: 'conv-2',
        title: 'Empty',
        previewText: 'No activity',
        lastActivityAt: null,
        unreadCount: 0,
        kind: ConversationProjectionKind.dm,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            home: Scaffold(
              body: ListView(
                children: [
                  InboxItemTile(
                    projection: projection,
                    isMentioned: false,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No time widget when lastActivityAt is null.
      expect(
        find.byType(InboxRelativeTimeText),
        findsNothing,
        reason: 'No InboxRelativeTimeText when lastActivityAt is null',
      );
    });
  });
}

// =============================================================================
// Fakes
// =============================================================================

/// ConversationRepository that delays loadOlderMessages/loadNewerMessages
/// until the corresponding Completer resolves.
class _DelayedPaginationRepo implements ConversationRepository {
  _DelayedPaginationRepo({
    this.olderCompleter,
    this.newerCompleter,
  });

  final Completer<ConversationMessagePage>? olderCompleter;
  final Completer<ConversationMessagePage>? newerCompleter;

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) =>
      olderCompleter?.future ??
      Future.value(const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
      ));

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) =>
      newerCompleter?.future ??
      Future.value(const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
        hasNewer: false,
      ));

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) =>
      Future.value(ConversationDetailSnapshot(
        target: target,
        title: 'Test',
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
