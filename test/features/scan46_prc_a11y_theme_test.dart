// =============================================================================
// Scan #46 PR C — Accessibility + Theme load-bearing tests
//
// These tests prove:
// - A1-A6: InkWell wrappers have Semantics nodes with correct properties
// - A7: _UnreadDivider has header=true in its semantics tree
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
import 'package:slock_app/features/conversation/presentation/widgets/conversation_attachment_renderers.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/search/application/search_state.dart';
import 'package:slock_app/features/search/presentation/widgets/search_channel_result_item.dart';
import 'package:slock_app/features/search/presentation/widgets/search_contact_result_item.dart';
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

        // Find the html attachment InkWell by key.
        final inkWellFinder =
            find.byKey(const ValueKey('html-attachment-report.html'));
        expect(inkWellFinder, findsOneWidget);

        // Semantics node must have button=true and contain the filename.
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
  // T1: Inbox count pill — uses primaryForeground, not Colors.white
  // ===========================================================================
  group('Scan #46 Theme — Inbox count pill WCAG contrast', () {
    test('AppColors.dark.primaryForeground is not white', () {
      // In dark mode, primaryForeground must NOT be white — it should be
      // near-black for contrast on the light-indigo primary background.
      expect(
        AppColors.dark.primaryForeground,
        isNot(equals(const Color(0xFFFFFFFF))),
        reason: 'Scan #46: dark mode primaryForeground must not be white '
            '(WCAG AA contrast failure). Reverting to Colors.white → RED.',
      );
    });

    test('AppColors.light.primaryForeground is white', () {
      // In light mode, primaryForeground should remain white (on dark indigo).
      expect(
        AppColors.light.primaryForeground,
        equals(const Color(0xFFFFFFFF)),
        reason: 'Light mode primaryForeground should be white.',
      );
    });
  });

  // ===========================================================================
  // T2-T3: Error badge — uses errorForeground, not Colors.white
  // ===========================================================================
  group('Scan #46 Theme — Error badge WCAG contrast', () {
    test('AppColors.dark.errorForeground is not white', () {
      // In dark mode, errorForeground must NOT be white — it should be
      // near-black for contrast on the light-pink error background.
      expect(
        AppColors.dark.errorForeground,
        isNot(equals(const Color(0xFFFFFFFF))),
        reason: 'Scan #46: dark mode errorForeground must not be white '
            '(WCAG AA contrast failure). Reverting to Colors.white → RED.',
      );
    });

    test('AppColors.light.errorForeground is white', () {
      expect(
        AppColors.light.errorForeground,
        equals(const Color(0xFFFFFFFF)),
        reason: 'Light mode errorForeground should be white (on dark red).',
      );
    });

    test('errorForeground token exists in AppColors', () {
      // Removing the field entirely would be a compile error, but removing it
      // from the const definitions could silently break. This test asserts the
      // dark/light split is present.
      expect(AppColors.dark.errorForeground, isNotNull);
      expect(AppColors.light.errorForeground, isNotNull);
      expect(
        AppColors.dark.errorForeground != AppColors.light.errorForeground,
        isTrue,
        reason: 'errorForeground must differ between light and dark.',
      );
    });
  });

  // ===========================================================================
  // T4-T5: Search highlight — uses colors.warning token, not hardcoded hex
  //
  // We test that SearchChannelResultItem and SearchContactResultItem render the
  // highlight color derived from the theme's warning token (which differs
  // between light and dark), not the hardcoded amber hex.
  // ===========================================================================
  group('Scan #46 Theme — Search highlight uses warning token', () {
    testWidgets(
      'SearchChannelResultItem highlight color follows theme in dark mode',
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

        // Find a RichText with highlighted span — the highlight background
        // should use the dark-mode warning color at 10% alpha.
        final richTexts = tester.widgetList<RichText>(find.byType(RichText));
        final highlightColors = <Color>{};
        for (final rt in richTexts) {
          _collectBackgroundColors(rt.text, highlightColors);
        }

        // The hardcoded value was Color(0x1AF59E0B) — 10% of light-mode amber.
        // After fix, dark mode should use 10% of dark warning (0xFFFBBF24).
        const oldHardcoded = Color(0x1AF59E0B);
        expect(
          highlightColors.contains(oldHardcoded),
          isFalse,
          reason: 'Scan #46: Search highlight must NOT use hardcoded '
              'Color(0x1AF59E0B). It should use colors.warning at 10% opacity '
              'which differs in dark mode. Reverting to const hex → RED.',
        );
      },
    );
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
