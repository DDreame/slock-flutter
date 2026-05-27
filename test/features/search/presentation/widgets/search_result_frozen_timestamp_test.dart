// =============================================================================
// #657 — Search Frozen Timestamps
//
// Invariants verified:
// INV-SEARCH-TIME-1: Search result timestamps refresh when homeNowProvider
//                     emits a new DateTime (not frozen at query time).
// INV-SEARCH-TIME-2: Timestamp transitions from "Xm ago" to "Yh ago" as
//                     time advances past the hour boundary.
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';
import 'package:slock_app/features/search/data/search_repository.dart';
import 'package:slock_app/features/search/presentation/widgets/search_result_item.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  // ---------------------------------------------------------------------------
  // INV-SEARCH-TIME-1: Timestamps refresh with homeNowProvider
  // ---------------------------------------------------------------------------
  group('INV-SEARCH-TIME: search result timestamps refresh', () {
    testWidgets(
      'INV-SEARCH-TIME-1: timestamp updates when homeNowProvider emits',
      (tester) async {
        final controller = StreamController<DateTime>();
        addTearDown(controller.close);

        // Message sent at 10:00.
        final messageTime = DateTime(2026, 5, 20, 10, 0);
        final result = SearchResultMessage(
          message: ConversationMessageSummary(
            id: 'msg-1',
            content: 'Hello world',
            createdAt: messageTime,
            senderId: 'user-2',
            senderType: 'human',
            messageType: 'message',
            senderName: 'Alex',
            seq: 1,
          ),
          channelId: 'ch-1',
          channelName: 'general',
          surface: 'channel',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              homeNowProvider.overrideWith((ref) => controller.stream),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SearchResultItem(
                  result: result,
                  query: 'Hello',
                  onTap: () {},
                ),
              ),
            ),
          ),
        );

        // Emit "now" = 10:05 → should display "5m ago".
        controller.add(DateTime(2026, 5, 20, 10, 5));
        await tester.pumpAndSettle();

        expect(
          find.text('5m ago'),
          findsOneWidget,
          reason: 'Timestamp must show "5m ago" when now is 5 min after '
              'message time (INV-SEARCH-TIME-1)',
        );

        // Emit "now" = 10:30 → should display "30m ago".
        controller.add(DateTime(2026, 5, 20, 10, 30));
        await tester.pumpAndSettle();

        expect(
          find.text('30m ago'),
          findsOneWidget,
          reason: 'Timestamp must update to "30m ago" after homeNowProvider '
              'emits a new time (INV-SEARCH-TIME-1)',
        );
      },
    );

    testWidgets(
      'INV-SEARCH-TIME-2: timestamp transitions across hour boundary',
      (tester) async {
        final controller = StreamController<DateTime>();
        addTearDown(controller.close);

        // Message sent at 10:00.
        final messageTime = DateTime(2026, 5, 20, 10, 0);
        final result = SearchResultMessage(
          message: ConversationMessageSummary(
            id: 'msg-2',
            content: 'Test message',
            createdAt: messageTime,
            senderId: 'user-3',
            senderType: 'human',
            messageType: 'message',
            senderName: 'Bob',
            seq: 2,
          ),
          channelId: 'ch-1',
          channelName: 'general',
          surface: 'channel',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              homeNowProvider.overrideWith((ref) => controller.stream),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SearchResultItem(
                  result: result,
                  query: 'Test',
                  onTap: () {},
                ),
              ),
            ),
          ),
        );

        // Emit "now" = 10:45 → should display "45m ago".
        controller.add(DateTime(2026, 5, 20, 10, 45));
        await tester.pumpAndSettle();

        expect(
          find.text('45m ago'),
          findsOneWidget,
          reason: 'Timestamp must show "45m ago" before the hour boundary '
              '(INV-SEARCH-TIME-2)',
        );

        // Emit "now" = 12:00 → should display "2h ago".
        controller.add(DateTime(2026, 5, 20, 12, 0));
        await tester.pumpAndSettle();

        expect(
          find.text('2h ago'),
          findsOneWidget,
          reason: 'Timestamp must transition to "2h ago" after crossing '
              'the hour boundary (INV-SEARCH-TIME-2)',
        );
      },
    );
  });
}
