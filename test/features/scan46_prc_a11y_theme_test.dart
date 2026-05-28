// =============================================================================
// Scan #46 PR C — Accessibility + Theme load-bearing tests
//
// These tests prove:
// - A1-A7: InkWell/divider wrappers have Semantics nodes with correct properties
// - T1: Inbox count pill uses colors.primaryForeground (not Colors.white)
// - T2-T3: Error count badges use colors.errorForeground (not Colors.white)
// - T4-T5: Search highlight uses colors.warning token (not hardcoded hex)
//
// Reverting any fix (removing Semantics wrapper or re-hardcoding Colors.white)
// causes the corresponding test to go RED.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_attachment_renderers.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_message_list.dart';
import 'package:slock_app/features/home/presentation/page/home_page.dart';
import 'package:slock_app/features/home/presentation/page/unread_list_page.dart';
import 'package:slock_app/features/inbox/application/conversation_projection.dart';
import 'package:slock_app/features/inbox/presentation/widgets/inbox_item_tile.dart';
import 'package:slock_app/features/saved_messages/data/saved_message_item.dart';
import 'package:slock_app/features/saved_messages/presentation/page/saved_messages_page.dart';
import 'package:slock_app/features/search/application/search_state.dart';
import 'package:slock_app/features/search/data/search_repository.dart';
import 'package:slock_app/features/search/presentation/widgets/search_channel_result_item.dart';
import 'package:slock_app/features/search/presentation/widgets/search_contact_result_item.dart';
import 'package:slock_app/features/search/presentation/widgets/search_result_item.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  // ===========================================================================
  // A1: _HtmlAttachmentRow — Semantics(button: true) wraps InkWell
  // ===========================================================================
  group('Scan #46 A11y — _HtmlAttachmentRow', () {
    testWidgets(
      'has Semantics button with label',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(
                body: AttachmentSection(
                  attachments: [
                    MessageAttachment(
                      name: 'report.html',
                      type: 'text/html',
                      url: 'https://example.com/report.html',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final inkWellFinder =
            find.byKey(const ValueKey('html-attachment-report.html'));
        expect(inkWellFinder, findsOneWidget);

        final semanticsNode = tester.getSemantics(inkWellFinder);
        final data = semanticsNode.getSemanticsData();
        expect(
          data.flagsCollection.isButton,
          isTrue,
          reason:
              'Scan #46: _HtmlAttachmentRow must have Semantics(button: true). '
              'Removing the Semantics wrapper → no button flag → RED.',
        );
        expect(data.label, contains('report.html'));

        handle.dispose();
      },
    );
  });

  // ===========================================================================
  // A2: _GenericFileAttachmentRow — Semantics(button) wraps InkWell
  // ===========================================================================
  group('Scan #46 A11y — _GenericFileAttachmentRow', () {
    testWidgets(
      'has Semantics button with label when tappable',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(
                body: AttachmentSection(
                  attachments: [
                    MessageAttachment(
                      name: 'doc.pdf',
                      type: 'application/pdf',
                      url: 'https://example.com/doc.pdf',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final inkWellFinder =
            find.byKey(const ValueKey('file-attachment-doc.pdf'));
        expect(inkWellFinder, findsOneWidget);

        final semanticsNode = tester.getSemantics(inkWellFinder);
        final data = semanticsNode.getSemanticsData();
        expect(
          data.flagsCollection.isButton,
          isTrue,
          reason: 'Scan #46: _GenericFileAttachmentRow must have '
              'Semantics(button: true). Removing wrapper → RED.',
        );
        expect(data.label, contains('doc.pdf'));

        handle.dispose();
      },
    );
  });

  // ===========================================================================
  // A3: SearchResultItem — Semantics(button: true)
  // ===========================================================================
  group('Scan #46 A11y — SearchResultItem', () {
    testWidgets(
      'has Semantics button with sender:content label',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SearchResultItem(
                  result: SearchResultMessage(
                    message: ConversationMessageSummary(
                      id: 'msg-1',
                      content: 'Hello world',
                      createdAt: DateTime(2026, 1, 1),
                      senderType: 'human',
                      messageType: 'text',
                      senderName: 'Bob',
                    ),
                    channelName: 'general',
                    surface: 'channel',
                  ),
                  query: 'hello',
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final inkWellFinder = find.byKey(const ValueKey('search-result-msg-1'));
        expect(inkWellFinder, findsOneWidget);

        final semanticsNode = tester.getSemantics(inkWellFinder);
        final data = semanticsNode.getSemanticsData();
        expect(
          data.flagsCollection.isButton,
          isTrue,
          reason: 'Scan #46: SearchResultItem must have '
              'Semantics(button: true). Removing wrapper → RED.',
        );
        expect(data.label, contains('Bob'));
        expect(data.label, contains('Hello world'));

        handle.dispose();
      },
    );
  });

  // ===========================================================================
  // A4: SearchContactResultItem — Semantics(button: true)
  // ===========================================================================
  group('Scan #46 A11y — SearchContactResultItem', () {
    testWidgets(
      'has Semantics button with display name label',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SearchContactResultItem(
                result: const SearchContactResult(
                  identityId: 'id-1',
                  displayName: 'Alice Smith',
                ),
                query: 'ali',
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final inkWellFinder =
            find.byKey(const ValueKey('search-contact-result-id-1'));
        expect(inkWellFinder, findsOneWidget);

        final semanticsNode = tester.getSemantics(inkWellFinder);
        final data = semanticsNode.getSemanticsData();
        expect(
          data.flagsCollection.isButton,
          isTrue,
          reason: 'Scan #46: SearchContactResultItem must have '
              'Semantics(button: true). Removing wrapper → RED.',
        );
        expect(data.label, contains('Alice Smith'));

        handle.dispose();
      },
    );
  });

  // ===========================================================================
  // A5: SearchChannelResultItem — Semantics(button: true)
  // ===========================================================================
  group('Scan #46 A11y — SearchChannelResultItem', () {
    testWidgets(
      'has Semantics button with channel name label',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SearchChannelResultItem(
                result: const SearchChannelResult(
                  channelId: 'ch-1',
                  channelName: 'engineering',
                  surface: 'channel',
                ),
                query: 'eng',
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final inkWellFinder =
            find.byKey(const ValueKey('search-channel-result-ch-1'));
        expect(inkWellFinder, findsOneWidget);

        final semanticsNode = tester.getSemantics(inkWellFinder);
        final data = semanticsNode.getSemanticsData();
        expect(
          data.flagsCollection.isButton,
          isTrue,
          reason: 'Scan #46: SearchChannelResultItem must have '
              'Semantics(button: true). Removing wrapper → RED.',
        );
        expect(data.label, contains('#engineering'));

        handle.dispose();
      },
    );
  });

  // ===========================================================================
  // A6: _SavedMessageCard — Semantics(button: true)
  // ===========================================================================
  group('Scan #46 A11y — SavedMessageCard', () {
    testWidgets(
      'has Semantics button with sender:content label',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SavedMessageCard(
                  item: SavedMessageItem(
                    message: ConversationMessageSummary(
                      id: 'saved-1',
                      content: 'Important message',
                      createdAt: DateTime(2026, 1, 1),
                      senderType: 'human',
                      messageType: 'text',
                      senderName: 'Carol',
                    ),
                    channelId: 'ch-1',
                    channelName: 'general',
                    surface: 'channel',
                  ),
                  onTap: () {},
                  onUnsave: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final inkWellFinder =
            find.byKey(const ValueKey('saved-message-saved-1'));
        expect(inkWellFinder, findsOneWidget);

        final semanticsNode = tester.getSemantics(inkWellFinder);
        final data = semanticsNode.getSemanticsData();
        expect(
          data.flagsCollection.isButton,
          isTrue,
          reason: 'Scan #46: _SavedMessageCard must have '
              'Semantics(button: true). Removing wrapper → RED.',
        );
        expect(data.label, contains('Carol'));
        expect(data.label, contains('Important message'));

        handle.dispose();
      },
    );
  });

  // ===========================================================================
  // A7: UnreadDivider — Semantics(header: true)
  // ===========================================================================
  group('Scan #46 A11y — UnreadDivider', () {
    testWidgets(
      'has Semantics header=true',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: UnreadDivider(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final dividerFinder = find.byKey(const ValueKey('unread-divider'));
        expect(dividerFinder, findsOneWidget);

        final semanticsNode = tester.getSemantics(dividerFinder);
        final data = semanticsNode.getSemanticsData();
        expect(
          data.flagsCollection.isHeader,
          isTrue,
          reason: 'Scan #46: _UnreadDivider must have '
              'Semantics(header: true). Removing wrapper → RED.',
        );

        handle.dispose();
      },
    );
  });

  // ===========================================================================
  // T1: Inbox count pill — production widget uses primaryForeground
  // ===========================================================================
  group('Scan #46 Theme — InboxItemTile count pill', () {
    testWidgets(
      'dark mode: count text uses primaryForeground (not Colors.white)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.dark,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: InboxItemTile(
                  projection: const ConversationProjection(
                    kind: ConversationProjectionKind.channel,
                    id: 'channel:ch-1',
                    title: 'general',
                    previewText: 'Hello',
                    unreadCount: 5,
                    senderName: 'Alice',
                  ),
                  isMentioned: false,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the count badge text by key (_keyId = projection.id).
        final badgeFinder =
            find.byKey(const ValueKey('inbox-unread-badge-channel:ch-1'));
        expect(badgeFinder, findsOneWidget);

        // Extract the Text widget inside the badge.
        final textFinder = find.descendant(
          of: badgeFinder,
          matching: find.byType(Text),
        );
        expect(textFinder, findsOneWidget);
        final textWidget = tester.widget<Text>(textFinder);
        final textColor = textWidget.style?.color;

        // Must match dark mode primaryForeground, NOT Colors.white.
        expect(
          textColor,
          isNot(equals(const Color(0xFFFFFFFF))),
          reason: 'Scan #46: Inbox count pill text color must not be white '
              'in dark mode. Reverting to Colors.white → RED.',
        );
        expect(
          textColor,
          equals(AppColors.dark.primaryForeground),
          reason: 'Must use colors.primaryForeground token.',
        );
      },
    );
  });

  // ===========================================================================
  // T2: unread_list_page error badge — production widget uses errorForeground
  // ===========================================================================
  group('Scan #46 Theme — UnreadListRow error badge', () {
    testWidgets(
      'dark mode: count text uses errorForeground (not Colors.white)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: UnreadListRow(
                item: ConversationProjection(
                  kind: ConversationProjectionKind.channel,
                  id: 'channel:ch-2',
                  title: 'bugs',
                  previewText: 'Error occurred',
                  unreadCount: 3,
                ),
                colors: AppColors.dark,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The badge has count text '3' — find the Text with '3' inside
        // the count pill (which uses errorForeground).
        final allTexts = tester.widgetList<Text>(find.byType(Text));
        Text? countText;
        for (final t in allTexts) {
          if (t.data == '3' && t.style?.fontSize == 11) {
            countText = t;
            break;
          }
        }
        expect(countText, isNotNull,
            reason: 'Count badge Text("3") should exist');

        final textColor = countText!.style?.color;
        expect(
          textColor,
          isNot(equals(const Color(0xFFFFFFFF))),
          reason: 'Scan #46: UnreadListRow error badge text must not be '
              'white in dark mode. Reverting to Colors.white → RED.',
        );
        expect(
          textColor,
          equals(AppColors.dark.errorForeground),
          reason: 'Must use colors.errorForeground token.',
        );
      },
    );
  });

  // ===========================================================================
  // T3: home_page _UnreadBadge — production widget uses errorForeground
  // ===========================================================================
  group('Scan #46 Theme — HomeUnreadBadge', () {
    testWidgets(
      'dark mode: count text uses errorForeground (not Colors.white)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: HomeUnreadBadge(count: 7),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the Text widget with '7'.
        final textFinder = find.text('7');
        expect(textFinder, findsOneWidget);

        final textWidget = tester.widget<Text>(textFinder);
        final textColor = textWidget.style?.color;

        expect(
          textColor,
          isNot(equals(const Color(0xFFFFFFFF))),
          reason: 'Scan #46: HomeUnreadBadge text must not be white '
              'in dark mode. Reverting to Colors.white → RED.',
        );
        expect(
          textColor,
          equals(AppColors.dark.errorForeground),
          reason: 'Must use colors.errorForeground token.',
        );
      },
    );
  });

  // ===========================================================================
  // T4: SearchContactResultItem — highlight uses warning token in dark mode
  // ===========================================================================
  group('Scan #46 Theme — SearchContactResultItem highlight', () {
    testWidgets(
      'dark mode: highlight color follows theme (not hardcoded hex)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SearchContactResultItem(
                result: const SearchContactResult(
                  identityId: 'id-2',
                  displayName: 'Alice Smith',
                ),
                query: 'ali',
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final richTexts = tester.widgetList<RichText>(find.byType(RichText));
        final highlightColors = <Color>{};
        for (final rt in richTexts) {
          _collectBackgroundColors(rt.text, highlightColors);
        }

        // The old hardcoded value was Color(0x1AF59E0B) — 10% of light amber.
        const oldHardcoded = Color(0x1AF59E0B);
        expect(
          highlightColors.contains(oldHardcoded),
          isFalse,
          reason: 'Scan #46: SearchContactResultItem highlight must NOT use '
              'hardcoded Color(0x1AF59E0B). It should use colors.warning '
              'at 10% which differs in dark mode. Reverting → RED.',
        );

        // Verify it uses the dark-mode warning token at 10% alpha.
        if (highlightColors.isNotEmpty) {
          final darkWarning10 = AppColors.dark.warning.withValues(alpha: 0.1);
          expect(
            highlightColors.contains(darkWarning10),
            isTrue,
            reason: 'Highlight should use dark warning at 10% alpha.',
          );
        }
      },
    );
  });

  // ===========================================================================
  // T5: SearchChannelResultItem — highlight uses warning token in dark mode
  // ===========================================================================
  group('Scan #46 Theme — SearchChannelResultItem highlight', () {
    testWidgets(
      'dark mode: highlight color follows theme (not hardcoded hex)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SearchChannelResultItem(
                result: const SearchChannelResult(
                  channelId: 'ch-1',
                  channelName: 'engineering',
                  surface: 'channel',
                ),
                query: 'eng',
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final richTexts = tester.widgetList<RichText>(find.byType(RichText));
        final highlightColors = <Color>{};
        for (final rt in richTexts) {
          _collectBackgroundColors(rt.text, highlightColors);
        }

        // The old hardcoded value was Color(0x1AF59E0B) — 10% of light amber.
        const oldHardcoded = Color(0x1AF59E0B);
        expect(
          highlightColors.contains(oldHardcoded),
          isFalse,
          reason: 'Scan #46: SearchChannelResultItem highlight must NOT use '
              'hardcoded Color(0x1AF59E0B). It should use colors.warning '
              'at 10% which differs in dark mode. Reverting → RED.',
        );

        // Verify it uses the dark-mode warning token at 10% alpha.
        if (highlightColors.isNotEmpty) {
          final darkWarning10 = AppColors.dark.warning.withValues(alpha: 0.1);
          expect(
            highlightColors.contains(darkWarning10),
            isTrue,
            reason: 'Highlight should use dark warning at 10% alpha.',
          );
        }
      },
    );
  });

  // ===========================================================================
  // Token existence / split proofs (regression guards)
  // ===========================================================================
  group('Scan #46 Theme — Token regression guards', () {
    test('errorForeground token exists with light/dark split', () {
      expect(AppColors.dark.errorForeground, isNotNull);
      expect(AppColors.light.errorForeground, isNotNull);
      expect(
        AppColors.dark.errorForeground != AppColors.light.errorForeground,
        isTrue,
        reason: 'errorForeground must differ between light and dark.',
      );
    });

    test('dark primaryForeground is not white (WCAG AA)', () {
      expect(
        AppColors.dark.primaryForeground,
        isNot(equals(const Color(0xFFFFFFFF))),
        reason: 'Scan #46: dark mode primaryForeground must not be white.',
      );
    });

    test('dark errorForeground is not white (WCAG AA)', () {
      expect(
        AppColors.dark.errorForeground,
        isNot(equals(const Color(0xFFFFFFFF))),
        reason: 'Scan #46: dark mode errorForeground must not be white.',
      );
    });
  });
}

// =============================================================================
// Helpers
// =============================================================================

/// Recursively collect background colors from TextSpan tree.
void _collectBackgroundColors(InlineSpan span, Set<Color> colors) {
  if (span is TextSpan) {
    final bg = span.style?.backgroundColor;
    if (bg != null) colors.add(bg);
    if (span.children != null) {
      for (final child in span.children!) {
        _collectBackgroundColors(child, colors);
      }
    }
  }
}
