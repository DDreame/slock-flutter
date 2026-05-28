// =============================================================================
// Interim Cleanup #3 — Load-bearing tests
//
// Proves:
// T1: DurationChip <1h uses colors.primary (not hardcoded Colors.blue).
//     Reverting to Colors.blue → expected color != actual → RED.
// T2: DurationChip >4h uses colors.error (not hardcoded Colors.red).
//     Reverting to Colors.red → expected color != actual → RED.
// T3: _appendDedupedMessage binary search inserts at position 0 correctly.
//     Reverting the binary search (naïve sort) produces same result, but this
//     verifies the boundary case the old sort also handled — regression guard.
// T4: _appendDedupedMessage binary search inserts between adjacent seqs.
//     Stress-tests insert at various positions to prove ordering invariant.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/home/presentation/page/home_page.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository.dart';
import 'package:slock_app/features/saved_messages/data/saved_messages_repository_provider.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  // ===========================================================================
  // Item 1: _DurationChip theme color tests
  // ===========================================================================

  group('DurationChip theme colors', () {
    // -------------------------------------------------------------------------
    // T1: <1h → colors.primary (indigo 0xFF6366F1), NOT Colors.blue (0xFF2196F3)
    // -------------------------------------------------------------------------
    testWidgets(
      'Cleanup3: DurationChip <1h uses colors.primary from theme',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context)!;
                return DurationChip(
                  duration: const Duration(minutes: 30),
                  l10n: l10n,
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the Text widget rendered by DurationChip.
        final textWidget = tester.widget<Text>(
          find.descendant(
            of: find.byType(DurationChip),
            matching: find.byType(Text),
          ),
        );
        final textColor = textWidget.style?.color;
        final expectedColor =
            AppColors.light.primary; // 0xFF6366F1 (NOT Colors.blue)

        expect(
          textColor,
          expectedColor,
          reason: 'Cleanup3: DurationChip <1h must use colors.primary from '
              'the theme extension. Reverting to Colors.blue (0xFF2196F3) '
              'makes this fail → RED.',
        );
      },
    );

    // -------------------------------------------------------------------------
    // T2: >4h → colors.error (red 0xFFEF4444), NOT Colors.red (0xFFF44336)
    // -------------------------------------------------------------------------
    testWidgets(
      'Cleanup3: DurationChip >4h uses colors.error from theme',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context)!;
                return DurationChip(
                  duration: const Duration(hours: 5),
                  l10n: l10n,
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        final textWidget = tester.widget<Text>(
          find.descendant(
            of: find.byType(DurationChip),
            matching: find.byType(Text),
          ),
        );
        final textColor = textWidget.style?.color;
        final expectedColor =
            AppColors.light.error; // 0xFFEF4444 (NOT Colors.red)

        expect(
          textColor,
          expectedColor,
          reason: 'Cleanup3: DurationChip >4h must use colors.error from '
              'the theme extension. Reverting to Colors.red (0xFFF44336) '
              'makes this fail → RED.',
        );
      },
    );
  });

  // ===========================================================================
  // Item 2: _appendDedupedMessage binary search correctness
  // ===========================================================================

  group('_appendDedupedMessage binary search insert', () {
    final target = ConversationDetailTarget.channel(
      const ChannelScopeId(
        serverId: ServerScopeId('server-1'),
        value: 'general',
      ),
    );

    ConversationMessageSummary msg(String id, int seq) =>
        ConversationMessageSummary(
          id: id,
          content: 'msg-$seq',
          createdAt: DateTime.utc(2026, 5, 20),
          senderType: 'human',
          messageType: 'message',
          seq: seq,
        );

    // -------------------------------------------------------------------------
    // T3: Insert at position 0 (seq smaller than all existing)
    // -------------------------------------------------------------------------
    test(
      'Cleanup3: binary search inserts at position 0 when seq < all existing',
      () async {
        final repo = _SimpleRepo(
          snapshot: ConversationDetailSnapshot(
            target: target,
            title: '#general',
            messages: [msg('a', 5), msg('b', 10), msg('c', 15)],
            historyLimited: false,
            hasOlder: false,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            currentConversationDetailTargetProvider.overrideWithValue(target),
            conversationRepositoryProvider.overrideWithValue(repo),
            savedMessagesRepositoryProvider
                .overrideWithValue(_FakeSavedMessagesRepo()),
          ],
        );
        final sub =
            container.listen(conversationDetailStoreProvider, (_, __) {});
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        final notifier =
            container.read(conversationDetailStoreProvider.notifier);
        await notifier.load();
        await Future<void>.value(); // Drain refreshSavedMessageIds microtask.

        final state = container.read(conversationDetailStoreProvider);
        expect(state.messages.map((m) => m.seq).toList(), [5, 10, 15]);

        // Insert message with seq=2 — must go at position 0.
        final result = notifier.appendDedupedMessageForTesting(
          state.messages,
          msg('d', 2),
        );

        expect(
          result.map((m) => m.seq).toList(),
          [2, 5, 10, 15],
          reason: 'Cleanup3: binary search must insert at position 0 when '
              'new seq is smaller than all existing messages.',
        );
      },
    );

    // -------------------------------------------------------------------------
    // T4: Multiple sequential inserts maintain order
    // -------------------------------------------------------------------------
    test(
      'Cleanup3: binary search inserts multiple out-of-order messages correctly',
      () async {
        final repo = _SimpleRepo(
          snapshot: ConversationDetailSnapshot(
            target: target,
            title: '#general',
            messages: [msg('a', 1), msg('b', 5), msg('c', 10), msg('d', 20)],
            historyLimited: false,
            hasOlder: false,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            currentConversationDetailTargetProvider.overrideWithValue(target),
            conversationRepositoryProvider.overrideWithValue(repo),
            savedMessagesRepositoryProvider
                .overrideWithValue(_FakeSavedMessagesRepo()),
          ],
        );
        final sub =
            container.listen(conversationDetailStoreProvider, (_, __) {});
        addTearDown(() {
          sub.close();
          container.dispose();
        });

        final notifier =
            container.read(conversationDetailStoreProvider.notifier);
        await notifier.load();
        await Future<void>.value();

        var messages = container.read(conversationDetailStoreProvider).messages;
        expect(messages.map((m) => m.seq).toList(), [1, 5, 10, 20]);

        // Insert seq=7 (between 5 and 10).
        messages = notifier.appendDedupedMessageForTesting(
          messages,
          msg('e', 7),
        );
        expect(
          messages.map((m) => m.seq).toList(),
          [1, 5, 7, 10, 20],
          reason: 'seq=7 inserted between 5 and 10',
        );

        // Insert seq=3 (between 1 and 5).
        messages = notifier.appendDedupedMessageForTesting(
          messages,
          msg('f', 3),
        );
        expect(
          messages.map((m) => m.seq).toList(),
          [1, 3, 5, 7, 10, 20],
          reason: 'seq=3 inserted between 1 and 5',
        );

        // Insert seq=15 (between 10 and 20).
        messages = notifier.appendDedupedMessageForTesting(
          messages,
          msg('g', 15),
        );
        expect(
          messages.map((m) => m.seq).toList(),
          [1, 3, 5, 7, 10, 15, 20],
          reason: 'seq=15 inserted between 10 and 20',
        );
      },
    );
  });
}

// =============================================================================
// Fakes
// =============================================================================

class _SimpleRepo implements ConversationRepository {
  _SimpleRepo({required this.snapshot});

  final ConversationDetailSnapshot snapshot;

  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async =>
      snapshot;

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
        hasNewer: false,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeSavedMessagesRepo implements SavedMessagesRepository {
  @override
  Future<Set<String>> checkSavedMessages(
    ServerScopeId serverId,
    List<String> messageIds,
  ) async =>
      const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
