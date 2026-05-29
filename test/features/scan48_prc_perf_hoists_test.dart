// =============================================================================
// Scan #48 PR C — Load-bearing identity tests for performance hoists.
//
// Tests prove:
// 1. ImageGalleryPage: indicator uses hoisted BorderRadius and TextStyle.
// 2. ImageGalleryPage: error text uses hoisted errorTextStyle.
// 3. ChannelRefBuilder: chipBackground is cached (identity across calls).
// 4. TaskRefBuilder: chipBackground is cached (identity across calls).
// 5. ThreadRefBuilder: chipBackground is cached (identity across calls).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/conversation/data/attachment_repository.dart';
import 'package:slock_app/features/conversation/data/attachment_repository_provider.dart'
    show attachmentRepositoryProvider;
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/image_gallery_page.dart';
import 'package:slock_app/features/conversation/presentation/widgets/inline_ref_syntax.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  // ===========================================================================
  // ImageGalleryPage hoists
  // ===========================================================================
  group('ImageGalleryPage performance hoists', () {
    testWidgets(
      'indicator uses hoisted BorderRadius (identity)',
      (tester) async {
        await tester.pumpWidget(_buildGalleryApp(
          images: [_image('img-1', 'a.png'), _image('img-2', 'b.png')],
          initialIndex: 0,
        ));
        await _pumpFrames(tester);

        // Find the indicator container by key.
        final containerFinder =
            find.byKey(const ValueKey('gallery-index-indicator'));
        expect(containerFinder, findsOneWidget);

        final container = tester.widget<Container>(containerFinder);
        final decoration = container.decoration! as BoxDecoration;

        // Identity check: the BorderRadius must be the exact hoisted instance.
        expect(
          identical(
            decoration.borderRadius,
            ImageGalleryPage.indicatorBorderRadius,
          ),
          isTrue,
          reason: 'Reverting hoisted BorderRadius → fresh allocation '
              '→ identity fails → RED',
        );
      },
    );

    testWidgets(
      'indicator text uses hoisted TextStyle (identity)',
      (tester) async {
        await tester.pumpWidget(_buildGalleryApp(
          images: [_image('img-1', 'a.png'), _image('img-2', 'b.png')],
          initialIndex: 0,
        ));
        await _pumpFrames(tester);

        // Find the "1 / 2" text widget.
        final textFinder = find.text('1 / 2');
        expect(textFinder, findsOneWidget);

        final textWidget = tester.widget<Text>(textFinder);

        // Identity check: the TextStyle must be the exact hoisted instance.
        expect(
          identical(textWidget.style, ImageGalleryPage.indicatorTextStyle),
          isTrue,
          reason: 'Reverting hoisted TextStyle → fresh copyWith allocation '
              '→ identity fails → RED',
        );
      },
    );

    testWidgets(
      'error text uses hoisted errorTextStyle (identity)',
      (tester) async {
        // Drive gallery into error/fallback path: attachment with no URLs.
        await tester.pumpWidget(_buildGalleryApp(
          images: [_nullUrlImage('broken.png')],
          initialIndex: 0,
        ));
        await _pumpFrames(tester);

        // Find the error text widget (l10n key: filePreviewImageLoadFailed).
        // Since we can't easily get the exact l10n string, find Text widgets
        // with the hoisted style.
        final textFinder = find.byWidgetPredicate(
          (w) => w is Text && w.style == ImageGalleryPage.errorTextStyle,
        );
        expect(textFinder, findsOneWidget);

        final textWidget = tester.widget<Text>(textFinder);

        // Identity check: the TextStyle must be the exact hoisted instance.
        expect(
          identical(textWidget.style, ImageGalleryPage.errorTextStyle),
          isTrue,
          reason: 'Reverting hoisted errorTextStyle → fresh copyWith '
              '→ identity fails → RED',
        );
      },
    );
  });

  // ===========================================================================
  // Inline ref builder chip background caching
  // ===========================================================================
  group('Inline ref builder chipBackground caching', () {
    testWidgets(
      'ChannelRefBuilder caches chipBackground across builds',
      (tester) async {
        final builder = ChannelRefBuilder(onChannelRefTap: (_) {});
        // Before any build, chipBackground is null.
        expect(builder.chipBackground, isNull);

        await tester.pumpWidget(_buildMarkdownApp('#general'));
        // After rendering, the builder's chipBackground should be set.
        // We need to use a real builder to test. Let's use a more direct
        // approach: build the widget twice and verify identity.
        final builder2 = ChannelRefBuilder(onChannelRefTap: (_) {});

        await tester.pumpWidget(_buildRefChipApp(builder2, 'channel_ref',
            attributes: {'name': 'general'}));
        await tester.pumpAndSettle();

        final bg1 = builder2.chipBackground;
        expect(bg1, isNotNull,
            reason: 'chipBackground must be set after build');

        // Rebuild — chipBackground must be the same instance.
        await tester.pumpWidget(_buildRefChipApp(builder2, 'channel_ref',
            attributes: {'name': 'other'}));
        await tester.pumpAndSettle();

        expect(
          identical(builder2.chipBackground, bg1),
          isTrue,
          reason: 'Reverting _chipBackground caching → new Color per build '
              '→ identity fails → RED',
        );
      },
    );

    testWidgets(
      'TaskRefBuilder caches chipBackground across builds',
      (tester) async {
        final builder = TaskRefBuilder(onTaskRefTap: (_) {});

        await tester.pumpWidget(_buildRefChipApp(builder, 'task_ref',
            attributes: {'number': '42'}));
        await tester.pumpAndSettle();

        final bg1 = builder.chipBackground;
        expect(bg1, isNotNull);

        await tester.pumpWidget(_buildRefChipApp(builder, 'task_ref',
            attributes: {'number': '99'}));
        await tester.pumpAndSettle();

        expect(
          identical(builder.chipBackground, bg1),
          isTrue,
          reason: 'Reverting _chipBackground caching → new Color per build '
              '→ identity fails → RED',
        );
      },
    );

    testWidgets(
      'ThreadRefBuilder caches chipBackground across builds',
      (tester) async {
        final builder = ThreadRefBuilder(onThreadRefTap: (_) {});

        await tester
            .pumpWidget(_buildRefChipApp(builder, 'thread_ref', attributes: {
          'target': 'general',
          'messageId': 'abc123',
          'isDm': 'false',
        }));
        await tester.pumpAndSettle();

        final bg1 = builder.chipBackground;
        expect(bg1, isNotNull);

        await tester
            .pumpWidget(_buildRefChipApp(builder, 'thread_ref', attributes: {
          'target': 'other',
          'messageId': 'def456',
          'isDm': 'false',
        }));
        await tester.pumpAndSettle();

        expect(
          identical(builder.chipBackground, bg1),
          isTrue,
          reason: 'Reverting _chipBackground caching → new Color per build '
              '→ identity fails → RED',
        );
      },
    );
  });
}

// =============================================================================
// Helpers
// =============================================================================

MessageAttachment _image(String id, String name) => MessageAttachment(
      id: id,
      name: name,
      type: 'image/png',
      url: 'https://example.com/$id.png',
      thumbnailUrl: 'https://example.com/$id-thumb.png',
    );

/// Attachment with all URLs null — drives the gallery into error/fallback path.
MessageAttachment _nullUrlImage(String name) => MessageAttachment(
      id: '',
      name: name,
      type: 'image/png',
    );

Future<void> _pumpFrames(WidgetTester tester) async {
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Widget _buildGalleryApp({
  required List<MessageAttachment> images,
  required int initialIndex,
}) {
  return ProviderScope(
    overrides: [
      attachmentRepositoryProvider
          .overrideWithValue(_FakeAttachmentRepository()),
      currentOpenConversationTargetProvider.overrideWith((ref) => null),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: ImageGalleryPage(
        args: ImageGalleryArgs(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    ),
  );
}

/// Builds a minimal app that exercises a MarkdownElementBuilder directly
/// by calling visitElementAfterWithContext.
Widget _buildRefChipApp(
  MarkdownElementBuilder builder,
  String tag, {
  required Map<String, String> attributes,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Builder(builder: (context) {
        final element = md.Element.text(tag, tag);
        attributes.forEach((k, v) => element.attributes[k] = v);
        final widget = builder.visitElementAfterWithContext(
          context,
          element,
          null,
          null,
        );
        return widget ?? const SizedBox.shrink();
      }),
    ),
  );
}

/// Placeholder for markdown rendering — not actually used in chip tests.
Widget _buildMarkdownApp(String text) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Text(text)),
  );
}

// =============================================================================
// Fakes
// =============================================================================

class _FakeAttachmentRepository implements AttachmentRepository {
  @override
  Future<String> getSignedUrl(
    ServerScopeId serverId, {
    required String attachmentId,
  }) async {
    return 'https://signed.example.com/$attachmentId';
  }

  @override
  Future<String> getHtmlPreviewUrl(
    ServerScopeId serverId, {
    required String attachmentId,
  }) async {
    return 'https://preview.example.com/$attachmentId';
  }
}
