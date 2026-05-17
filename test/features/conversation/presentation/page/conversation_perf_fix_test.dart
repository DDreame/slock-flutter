import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/link_preview/data/link_metadata.dart';
import 'package:slock_app/features/link_preview/presentation/widgets/link_preview_card.dart';
import 'package:slock_app/features/profile/presentation/widgets/profile_avatar.dart';

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
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // INV-PERFFIX-1: ProfileAvatar uses CachedNetworkImageProvider.
  //
  // Setup: Render a ProfileAvatar with an avatarUrl. The backgroundImage
  // of the CircleAvatar should be a CachedNetworkImageProvider, not a
  // bare NetworkImage.
  //
  // skip:true — ProfileAvatar still uses NetworkImage(avatarUrl!).
  // -----------------------------------------------------------------------
  testWidgets(
    'ProfileAvatar uses CachedNetworkImageProvider (INV-PERFFIX-1)',
    skip: true,
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
  // skip:true — ProfileAvatar still uses NetworkImage(avatarUrl!).
  // -----------------------------------------------------------------------
  testWidgets(
    'ProfileAvatar sets disk cache size limits (INV-PERFFIX-2)',
    skip: true,
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

      // Cast and verify disk cache dimensions are set.
      // CachedNetworkImageProvider exposes maxWidth / maxHeight.
      // Phase B implementation must set these ≤ 200 for avatar sizes.
      //
      // NOTE: The concrete cast depends on the cached_network_image
      // API. Phase B will import the package and use:
      //   final cnip = provider as CachedNetworkImageProvider;
      //   expect(cnip.maxWidth, lessThanOrEqualTo(200));
      //   expect(cnip.maxHeight, lessThanOrEqualTo(200));
      //
      // For now, verify the provider is not a bare NetworkImage
      // (which has no cache size concept).
      expect(
        provider,
        isNot(isA<NetworkImage>()),
        reason: 'ProfileAvatar must NOT use bare NetworkImage — '
            'CachedNetworkImageProvider with size limits required '
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
  // skip:true — LinkPreviewCard still uses Image.network().
  // -----------------------------------------------------------------------
  testWidgets(
    'LinkPreviewCard image uses CachedNetworkImage (INV-PERFFIX-3)',
    skip: true,
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
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
