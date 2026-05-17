import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/profile/presentation/widgets/profile_avatar.dart';

// ---------------------------------------------------------------------------
// #538: 消息列表性能修复 — Phase A
//
// Verifies image caching: avatar and thumbnail images use
// CachedNetworkImageProvider instead of bare NetworkImage to prevent
// refetching on scroll-back and tab-switch.
//
// Invariants:
//   INV-PERFFIX-1: ProfileAvatar with avatarUrl uses
//                  CachedNetworkImageProvider (not bare NetworkImage)
//   INV-PERFFIX-2: ProfileAvatar sets maxWidthDiskCache /
//                  maxHeightDiskCache to avoid caching full-res at
//                  avatar sizes
//
// Phase A: All tests skip:true — no cached_network_image package yet,
// ProfileAvatar still uses NetworkImage(avatarUrl!).
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
  // CachedNetworkImageProvider should have maxWidthDiskCache and
  // maxHeightDiskCache set to reasonable avatar-sized values (e.g. 200)
  // to avoid caching full-resolution images at avatar display sizes.
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

      // CachedNetworkImageProvider must be the image type.
      expect(
        circleAvatar.backgroundImage.runtimeType.toString(),
        contains('CachedNetworkImageProvider'),
        reason: 'ProfileAvatar must use CachedNetworkImageProvider '
            '(INV-PERFFIX-2)',
      );

      // Verify that the provider is not using default (unlimited) cache
      // dimensions. The exact assertion depends on the
      // CachedNetworkImageProvider API — Phase B will use
      // maxWidthDiskCache/maxHeightDiskCache parameters.
      //
      // Phase B note: After migrating to CachedNetworkImageProvider,
      // add a concrete assertion like:
      //   final provider = circleAvatar.backgroundImage
      //       as CachedNetworkImageProvider;
      //   expect(provider.maxWidth, lessThanOrEqualTo(200));
      //   expect(provider.maxHeight, lessThanOrEqualTo(200));
    },
  );
}
