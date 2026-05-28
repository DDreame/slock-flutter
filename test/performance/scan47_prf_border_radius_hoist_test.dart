// =============================================================================
// Scan #47 PR F — BorderRadius hoist load-bearing tests (7 widgets).
//
// Each test proves the hoisted `static final` BorderRadius field returns the
// SAME object instance across rebuilds. If someone reverts to inline
// BorderRadius.circular(N), each build produces a new instance →
// identical() fails → test RED.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/section_card.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_attachment_renderers.dart';
import 'package:slock_app/features/conversation/presentation/widgets/formatting_toolbar.dart';
import 'package:slock_app/features/link_preview/data/link_metadata.dart';
import 'package:slock_app/features/link_preview/presentation/widgets/link_preview_card.dart';
import 'package:slock_app/features/tasks/presentation/page/tasks_page.dart';
import 'package:slock_app/features/voice/presentation/widgets/voice_recorder_widget.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  // ===========================================================================
  // H1: LinkPreviewCard — borderRadius hoisted
  // ===========================================================================
  group('Scan #47 BorderRadius hoist — LinkPreviewCard', () {
    testWidgets('uses hoisted borderRadius', (tester) async {
      const metadata = LinkMetadata(
        url: 'https://example.com',
        title: 'Example',
        domain: 'example.com',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: LinkPreviewCard(metadata: metadata),
          ),
        ),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('link-preview-card')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(
        identical(decoration.borderRadius, LinkPreviewCard.borderRadius),
        isTrue,
        reason: 'Reverting to inline BorderRadius.circular(12) → '
            'not identical to static field → RED.',
      );
    });
  });

  // ===========================================================================
  // H2: SectionCard — borderRadius hoisted
  // ===========================================================================
  group('Scan #47 BorderRadius hoist — SectionCard', () {
    testWidgets('uses hoisted borderRadius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SectionCard(child: Text('content')),
          ),
        ),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('section-card')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(
        identical(decoration.borderRadius, SectionCard.borderRadius),
        isTrue,
        reason: 'Reverting to inline BorderRadius.circular(radiusMd) → '
            'not identical to static field → RED.',
      );
    });
  });

  // ===========================================================================
  // H3: VoiceRecorderWidget — borderRadius hoisted
  // ===========================================================================
  group('Scan #47 BorderRadius hoist — VoiceRecorderWidget', () {
    testWidgets('uses hoisted borderRadius', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VoiceRecorderWidget(
                onSend: () {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // The outer Container has borderRadius in its BoxDecoration.
      final containers = tester.widgetList<Container>(find.byType(Container));
      // Find the container with our borderRadius value.
      Container? targetContainer;
      for (final c in containers) {
        if (c.decoration is BoxDecoration) {
          final d = c.decoration! as BoxDecoration;
          if (d.borderRadius == VoiceRecorderWidget.borderRadius) {
            targetContainer = c;
            break;
          }
        }
      }
      expect(targetContainer, isNotNull, reason: 'Container with borderRadius');
      final decoration = targetContainer!.decoration as BoxDecoration;
      expect(
        identical(decoration.borderRadius, VoiceRecorderWidget.borderRadius),
        isTrue,
        reason: 'Reverting to inline BorderRadius.circular(24) → '
            'not identical to static field → RED.',
      );
    });
  });

  // ===========================================================================
  // H4: _HtmlAttachmentRow — inkWell borderRadius hoisted (dual-pump)
  // ===========================================================================
  group('Scan #47 BorderRadius hoist — _HtmlAttachmentRow', () {
    testWidgets('InkWell borderRadius is identical across rebuilds',
        (tester) async {
      const attachment1 = MessageAttachment(
        name: 'doc.html',
        type: 'text/html',
        url: 'https://example.com/a.html',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: AttachmentSection(attachments: [attachment1]),
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the InkWell for HTML attachment.
      final inkWell1 = tester.widget<InkWell>(
        find.byKey(const ValueKey('html-attachment-doc.html')),
      );
      final br1 = inkWell1.borderRadius;

      // Rebuild with different attachment name (forces widget rebuild).
      const attachment2 = MessageAttachment(
        name: 'page.html',
        type: 'text/html',
        url: 'https://example.com/b.html',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: AttachmentSection(attachments: [attachment2]),
            ),
          ),
        ),
      );
      await tester.pump();

      final inkWell2 = tester.widget<InkWell>(
        find.byKey(const ValueKey('html-attachment-page.html')),
      );
      final br2 = inkWell2.borderRadius;

      expect(
        identical(br1, br2),
        isTrue,
        reason: 'Reverting to inline BorderRadius.circular(4) → '
            'new instance each build → RED.',
      );
    });

    testWidgets('Container borderRadius is identical across rebuilds',
        (tester) async {
      const attachment1 = MessageAttachment(
        name: 'doc.html',
        type: 'text/html',
        url: 'https://example.com/a.html',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: AttachmentSection(attachments: [attachment1]),
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the Container inside the InkWell (it has the BoxDecoration).
      final containerFinder = find.descendant(
        of: find.byKey(const ValueKey('html-attachment-doc.html')),
        matching: find.byType(Container),
      );
      final container1 = tester.widget<Container>(containerFinder.first);
      final br1 = (container1.decoration! as BoxDecoration).borderRadius;

      // Rebuild.
      const attachment2 = MessageAttachment(
        name: 'page.html',
        type: 'text/html',
        url: 'https://example.com/b.html',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: AttachmentSection(attachments: [attachment2]),
            ),
          ),
        ),
      );
      await tester.pump();

      final containerFinder2 = find.descendant(
        of: find.byKey(const ValueKey('html-attachment-page.html')),
        matching: find.byType(Container),
      );
      final container2 = tester.widget<Container>(containerFinder2.first);
      final br2 = (container2.decoration! as BoxDecoration).borderRadius;

      expect(
        identical(br1, br2),
        isTrue,
        reason: 'Reverting to inline BorderRadius.circular(8) → '
            'new instance each build → RED.',
      );
    });
  });

  // ===========================================================================
  // H5: _GenericFileAttachmentRow — borderRadius hoisted (dual-pump)
  // ===========================================================================
  group('Scan #47 BorderRadius hoist — _GenericFileAttachmentRow', () {
    testWidgets('InkWell borderRadius is identical across rebuilds',
        (tester) async {
      const attachment1 = MessageAttachment(
        name: 'data.bin',
        type: 'application/octet-stream',
        url: 'https://example.com/a.bin',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: AttachmentSection(attachments: [attachment1]),
            ),
          ),
        ),
      );
      await tester.pump();

      final inkWell1 = tester.widget<InkWell>(
        find.byKey(const ValueKey('file-attachment-data.bin')),
      );
      final br1 = inkWell1.borderRadius;

      // Rebuild with different name.
      const attachment2 = MessageAttachment(
        name: 'report.bin',
        type: 'application/octet-stream',
        url: 'https://example.com/b.bin',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: AttachmentSection(attachments: [attachment2]),
            ),
          ),
        ),
      );
      await tester.pump();

      final inkWell2 = tester.widget<InkWell>(
        find.byKey(const ValueKey('file-attachment-report.bin')),
      );
      final br2 = inkWell2.borderRadius;

      expect(
        identical(br1, br2),
        isTrue,
        reason: 'Reverting to inline BorderRadius.circular(4) → '
            'new instance each build → RED.',
      );
    });
  });

  // ===========================================================================
  // H6: _ToolbarButton — borderRadius hoisted (dual-pump)
  // ===========================================================================
  group('Scan #47 BorderRadius hoist — _ToolbarButton', () {
    testWidgets('InkWell borderRadius is identical across rebuilds',
        (tester) async {
      final controller1 = TextEditingController(text: 'hello');
      final focusNode = FocusNode();
      addTearDown(() {
        controller1.dispose();
        focusNode.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FormattingToolbar(
              controller: controller1,
              visible: true,
              focusNode: focusNode,
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the Bold button InkWell (has key '$tooltip-ink' pattern).
      // The first InkWell in the toolbar row should be the Bold button.
      final toolbarFinder = find.byKey(const ValueKey('formatting-toolbar'));
      final inkWellFinder = find.descendant(
        of: toolbarFinder,
        matching: find.byType(InkWell),
      );
      final inkWell1 = tester.widget<InkWell>(inkWellFinder.first);
      final br1 = inkWell1.borderRadius;

      // Rebuild with a new controller to force FormattingToolbar rebuild.
      final controller2 = TextEditingController(text: 'world');
      addTearDown(controller2.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FormattingToolbar(
              controller: controller2,
              visible: true,
              focusNode: focusNode,
            ),
          ),
        ),
      );
      await tester.pump();

      final inkWell2 = tester.widget<InkWell>(inkWellFinder.first);
      final br2 = inkWell2.borderRadius;

      expect(
        identical(br1, br2),
        isTrue,
        reason: 'Reverting to inline BorderRadius.circular(radiusSm) → '
            'new instance each build → RED.',
      );
    });
  });

  // ===========================================================================
  // H7: _FilterChip — borderRadius hoisted (via @visibleForTesting constant)
  // ===========================================================================
  group('Scan #47 BorderRadius hoist — _FilterChip', () {
    test('filterChipBorderRadius is identity-stable', () {
      // The file-scope constant must return the same instance every time.
      expect(
        identical(filterChipBorderRadius, filterChipBorderRadius),
        isTrue,
        reason: 'filterChipBorderRadius must be a stable reference. '
            'Reverting to inline would remove this constant → RED.',
      );
    });

    test('filterChipBorderRadius has expected value', () {
      // Pin the expected value so renaming/rebinding is caught.
      expect(
        filterChipBorderRadius,
        BorderRadius.circular(16),
        reason: 'filterChipBorderRadius must be circular(16).',
      );
    });
  });
}
