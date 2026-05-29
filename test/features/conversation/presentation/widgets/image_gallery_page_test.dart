// =============================================================================
// B124 PR 2 — Multi-image gallery tests.
//
// Tests prove:
// 1. PageView renders multiple images and starts at initialIndex.
// 2. Index indicator (1/N) shown for multi-image, not for single image.
// 3. Swiping changes page and updates index indicator.
// 4. Swipe-to-dismiss gesture area exists (gallery-dismiss-area).
// 5. Hero wraps only the initial page image.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/conversation/data/attachment_repository.dart';
import 'package:slock_app/features/conversation/data/attachment_repository_provider.dart'
    show attachmentRepositoryProvider;
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/image_gallery_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  group('ImageGalleryPage', () {
    testWidgets('renders PageView at initialIndex with index indicator',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(
          images: [_image('img-1', 'a.png'), _image('img-2', 'b.png')],
          initialIndex: 0,
        ),
      );
      await _pumpFrames(tester);

      // PageView must exist.
      expect(
        find.byKey(const ValueKey('gallery-page-view')),
        findsOneWidget,
        reason: 'Removing PageView → RED',
      );

      // Index indicator must show "1 / 2".
      expect(
        find.text('1 / 2'),
        findsOneWidget,
        reason: 'Removing index indicator → RED',
      );

      // The index indicator container must have the correct key.
      expect(
        find.byKey(const ValueKey('gallery-index-indicator')),
        findsOneWidget,
        reason: 'Removing indicator key → RED',
      );
    });

    testWidgets('starts at initialIndex=1 and shows correct indicator',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(
          images: [
            _image('img-1', 'a.png'),
            _image('img-2', 'b.png'),
            _image('img-3', 'c.png'),
          ],
          initialIndex: 1,
        ),
      );
      await _pumpFrames(tester);

      // Should show "2 / 3" since initialIndex=1.
      expect(
        find.text('2 / 3'),
        findsOneWidget,
        reason: 'Gallery must start at initialIndex',
      );
    });

    testWidgets('no index indicator for single image', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          images: [_image('img-1', 'solo.png')],
          initialIndex: 0,
        ),
      );
      await _pumpFrames(tester);

      // No indicator when only 1 image.
      expect(
        find.byKey(const ValueKey('gallery-index-indicator')),
        findsNothing,
        reason: 'Single image must not show index indicator',
      );
    });

    testWidgets('swipe-to-dismiss area exists', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          images: [_image('img-1', 'a.png'), _image('img-2', 'b.png')],
          initialIndex: 0,
        ),
      );
      await _pumpFrames(tester);

      expect(
        find.byKey(const ValueKey('gallery-dismiss-area')),
        findsOneWidget,
        reason: 'Removing swipe-to-dismiss GestureDetector → RED',
      );
    });

    testWidgets('Hero wraps only the initial page', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          images: [_image('img-1', 'a.png'), _image('img-2', 'b.png')],
          initialIndex: 0,
        ),
      );
      await _pumpFrames(tester);

      // Hero should exist for initial page (img-1).
      final heroFinder = find.byType(Hero);
      expect(heroFinder, findsOneWidget,
          reason: 'Hero must wrap only the initially visible page');
    });

    testWidgets('swiping to next page updates index indicator', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          images: [_image('img-1', 'a.png'), _image('img-2', 'b.png')],
          initialIndex: 0,
        ),
      );
      await _pumpFrames(tester);

      // Initially shows "1 / 2".
      expect(find.text('1 / 2'), findsOneWidget);

      // Fling left to go to next page (velocity triggers PageView paging).
      await tester.fling(
        find.byKey(const ValueKey('gallery-page-view')),
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();

      // Now should show "2 / 2".
      expect(
        find.text('2 / 2'),
        findsOneWidget,
        reason: 'Swiping to next page must update index indicator',
      );
    });

    testWidgets('app bar shows current image name', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          images: [
            _image('img-1', 'photo_a.png'),
            _image('img-2', 'photo_b.png')
          ],
          initialIndex: 0,
        ),
      );
      await _pumpFrames(tester);

      // App bar shows the current image's filename.
      expect(find.text('photo_a.png'), findsOneWidget);
    });

    testWidgets('out-of-range initialIndex is clamped without crash',
        (tester) async {
      // initialIndex=99 is beyond array bounds — should clamp to last.
      await tester.pumpWidget(
        _buildApp(
          images: [_image('img-1', 'a.png'), _image('img-2', 'b.png')],
          initialIndex: 99,
        ),
      );
      await _pumpFrames(tester);

      // Should not crash and should clamp to last image (index 1 → "2 / 2").
      expect(
        find.text('2 / 2'),
        findsOneWidget,
        reason: 'Out-of-range index must be clamped to last image',
      );
      expect(
        find.byKey(const ValueKey('image-gallery-page')),
        findsOneWidget,
        reason: 'Gallery must render without crash on out-of-range index',
      );
    });

    testWidgets('negative initialIndex is clamped to 0', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          images: [_image('img-1', 'a.png'), _image('img-2', 'b.png')],
          initialIndex: -5,
        ),
      );
      await _pumpFrames(tester);

      // Should clamp to 0 → "1 / 2".
      expect(
        find.text('1 / 2'),
        findsOneWidget,
        reason: 'Negative index must be clamped to 0',
      );
    });
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

/// Pump enough frames for post-frame callbacks without waiting for network
/// images (CachedNetworkImage never completes in test environment).
Future<void> _pumpFrames(WidgetTester tester) async {
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Widget _buildApp({
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
