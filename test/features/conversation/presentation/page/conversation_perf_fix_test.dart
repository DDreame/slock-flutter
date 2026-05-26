import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/link_preview/data/link_metadata.dart';
import 'package:slock_app/features/link_preview/presentation/widgets/link_preview_card.dart';
import 'package:slock_app/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:slock_app/l10n/l10n.dart';

// ---------------------------------------------------------------------------
// #538: 消息列表性能修复 — Phase A
//
// Verifies image caching: avatar and thumbnail images use
// CachedNetworkImageProvider / CachedNetworkImage instead of bare
// NetworkImage / Image.network to prevent refetching on scroll-back
// and tab-switch.
//
// Invariants:
//   INV-PERFFIX-1: ProfileAvatar with avatarUrl uses
//                  CachedNetworkImageProvider (not bare NetworkImage)
//   INV-PERFFIX-2: ProfileAvatar CachedNetworkImageProvider sets
//                  maxWidthDiskCache / maxHeightDiskCache ≤ 200
//   INV-PERFFIX-3: LinkPreviewCard image uses CachedNetworkImage
//                  (not bare Image.network)
//
// Phase A: All tests skip:true — no cached_network_image package yet.
// Phase B: Un-skipped — cached_network_image added and all sites migrated.
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // INV-PERFFIX-1: ProfileAvatar uses CachedNetworkImageProvider.
  //
  // Setup: Render a ProfileAvatar with an avatarUrl. The backgroundImage
  // of the CircleAvatar should be a CachedNetworkImageProvider, not a
  // bare NetworkImage.
  //
  // skip:false — ProfileAvatar now uses CachedNetworkImageProvider.
  // -----------------------------------------------------------------------
  testWidgets(
    'ProfileAvatar uses CachedNetworkImageProvider (INV-PERFFIX-1)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: ProfileAvatar(
                displayName: 'Alice',
                avatarUrl: 'https://example.com/avatar.png',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the CircleAvatar with the profile-avatar-image key.
      final avatarFinder = find.byKey(const ValueKey('profile-avatar-image'));
      expect(avatarFinder, findsOneWidget);

      final circleAvatar = tester.widget<CircleAvatar>(avatarFinder);

      // The backgroundImage should be CachedNetworkImageProvider,
      // not bare NetworkImage.
      expect(
        circleAvatar.backgroundImage.runtimeType.toString(),
        contains('CachedNetworkImageProvider'),
        reason: 'ProfileAvatar must use CachedNetworkImageProvider '
            'for network avatars (INV-PERFFIX-1)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-PERFFIX-2: ProfileAvatar sets disk cache size limits.
  //
  // Setup: Render a ProfileAvatar with an avatarUrl. The
  // CachedNetworkImageProvider must set maxWidthDiskCache and
  // maxHeightDiskCache to ≤ 200 to avoid caching full-resolution
  // images at avatar display sizes.
  //
  // skip:false — ProfileAvatar now uses CachedNetworkImageProvider with
  // maxWidth/maxHeight ≤ 200.
  // -----------------------------------------------------------------------
  testWidgets(
    'ProfileAvatar sets disk cache size limits (INV-PERFFIX-2)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: ProfileAvatar(
                displayName: 'Bob',
                avatarUrl: 'https://example.com/avatar-bob.png',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final avatarFinder = find.byKey(const ValueKey('profile-avatar-image'));
      expect(avatarFinder, findsOneWidget);

      final circleAvatar = tester.widget<CircleAvatar>(avatarFinder);
      final provider = circleAvatar.backgroundImage!;

      // Must be CachedNetworkImageProvider.
      expect(
        provider.runtimeType.toString(),
        contains('CachedNetworkImageProvider'),
        reason: 'ProfileAvatar must use CachedNetworkImageProvider '
            '(INV-PERFFIX-2)',
      );

      // Verify disk cache dimensions are bounded via dynamic access.
      // CachedNetworkImageProvider exposes maxWidth / maxHeight as int?.
      // Phase B must set these ≤ 200 for avatar sizes.
      final dynamic dynamicProvider = provider;
      expect(
        dynamicProvider.maxWidth,
        isNotNull,
        reason: 'CachedNetworkImageProvider must set maxWidth '
            '(INV-PERFFIX-2)',
      );
      expect(
        dynamicProvider.maxHeight,
        isNotNull,
        reason: 'CachedNetworkImageProvider must set maxHeight '
            '(INV-PERFFIX-2)',
      );
      expect(
        dynamicProvider.maxWidth as int,
        lessThanOrEqualTo(200),
        reason: 'maxWidth must be ≤ 200 for avatar sizes '
            '(INV-PERFFIX-2)',
      );
      expect(
        dynamicProvider.maxHeight as int,
        lessThanOrEqualTo(200),
        reason: 'maxHeight must be ≤ 200 for avatar sizes '
            '(INV-PERFFIX-2)',
      );
    },
  );

  // -----------------------------------------------------------------------
  // INV-PERFFIX-3: LinkPreviewCard image uses CachedNetworkImage.
  //
  // Setup: Render a LinkPreviewCard with an imageUrl. The image widget
  // should be a CachedNetworkImage (from cached_network_image package),
  // not a bare Image.network.
  //
  // skip:false — LinkPreviewCard now uses CachedNetworkImage.
  // -----------------------------------------------------------------------
  testWidgets(
    'LinkPreviewCard image uses CachedNetworkImage (INV-PERFFIX-3)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Center(
              child: LinkPreviewCard(
                metadata: LinkMetadata(
                  url: 'https://example.com/article',
                  title: 'Example Article',
                  description: 'An example article for testing.',
                  imageUrl: 'https://example.com/preview.jpg',
                  domain: 'example.com',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The link-preview-image key should exist.
      final imageFinder = find.byKey(const ValueKey('link-preview-image'));
      expect(imageFinder, findsOneWidget);

      // The image widget should NOT be a bare Image (Image.network).
      // Phase B replaces Image.network with CachedNetworkImage.
      final imageWidget = tester.widget(imageFinder);
      expect(
        imageWidget.runtimeType.toString(),
        contains('CachedNetworkImage'),
        reason: 'LinkPreviewCard must use CachedNetworkImage '
            'instead of Image.network (INV-PERFFIX-3)',
      );
    },
  );
}
