// ---------------------------------------------------------------------------
// #549: Hero Animations — Image→FilePreview, Avatar→Profile
//
// Problem: 0 Hero widgets in lib/. Two strong candidates for shared-element
// transitions: image thumbnail → FilePreviewPage, and avatar → ProfilePage.
// Both routes use builder: with no transition currently.
//
// Phase A: skip:true invariants locking the Hero widget placement contract.
//          A test-local _HeroTags seam defines expected Hero tags.
//          Test wrappers mirror the real production widget tree nesting at
//          the intended Hero insertion points. Phase B adds Hero widgets
//          to the production code and un-skips.
//
// Invariants verified:
// INV-HERO-IMAGE-1: _ImageAttachmentPreview widget tree contains a Hero
//                   widget with tag matching attachment ID
// INV-HERO-IMAGE-2: FilePreviewPage widget tree contains a Hero widget
//                   with the same tag as the thumbnail
// INV-HERO-AVATAR-1: MemberListItem avatar contains a Hero widget with
//                    tag matching user ID
// INV-HERO-AVATAR-2: Profile page header contains a Hero widget with
//                    the same tag
// ---------------------------------------------------------------------------
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/profile/presentation/widgets/profile_avatar.dart';

// ---------------------------------------------------------------------------
// Test-local seam: defines the Hero tag convention and widget wrappers that
// Phase B will implement in the production widgets.
//
// Phase B: add Hero widgets to _ImageAttachmentPreview, FilePreviewPage,
//          MemberListItem, and ProfilePage using the tag conventions below.
//          Replace the test-local wrappers with pumped production widgets.
// ---------------------------------------------------------------------------

/// Hero tag conventions for shared-element transitions.
///
/// Phase B: these constants move to a shared location (e.g.
/// lib/core/hero/hero_tags.dart) so both source and destination
/// widgets reference the same tag.
class _HeroTags {
  /// Tag for image attachment hero: 'image-hero-{attachmentId}'.
  static String imageAttachment(String attachmentId) =>
      'image-hero-$attachmentId';

  /// Tag for avatar hero: 'avatar-hero-{userId}'.
  static String avatar(String userId) => 'avatar-hero-$userId';
}

/// Test-local wrapper mirroring the real _ImageAttachmentPreview tree:
///   GestureDetector → Column → ClipRRect → ConstrainedBox → [Hero →] image
///
/// Phase B: _ImageAttachmentPreview.build() wraps its CachedNetworkImage
/// child in a Hero widget with tag = _HeroTags.imageAttachment(attachment.id).
class _TestableImageThumbnailHero extends StatelessWidget {
  const _TestableImageThumbnailHero({required this.attachmentId});
  final String attachmentId;

  @override
  Widget build(BuildContext context) {
    // Mirrors: _ImageAttachmentPreview.build()
    return GestureDetector(
      key: ValueKey('image-preview-$attachmentId'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 280),
              // Phase B inserts Hero here, wrapping CachedNetworkImage.
              child: Hero(
                tag: _HeroTags.imageAttachment(attachmentId),
                child: CachedNetworkImage(
                  imageUrl: 'https://example.com/$attachmentId.jpg',
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Test-local wrapper mirroring the real FilePreviewPage._buildImageBody tree:
///   GestureDetector → [Hero →] InteractiveViewer → image
///
/// Phase B: FilePreviewPage._buildImageBody() wraps its InteractiveViewer
/// (or the CachedNetworkImage within) in a Hero widget with the same tag.
class _TestableFilePreviewHero extends StatelessWidget {
  const _TestableFilePreviewHero({required this.attachmentId});
  final String attachmentId;

  @override
  Widget build(BuildContext context) {
    // Mirrors: FilePreviewPage._buildImageBody()
    return GestureDetector(
      key: const ValueKey('media-viewer-dismiss-area'),
      // Phase B inserts Hero here, wrapping InteractiveViewer.
      child: Hero(
        tag: _HeroTags.imageAttachment(attachmentId),
        child: InteractiveViewer(
          key: const ValueKey('image-viewer-interactive'),
          child: CachedNetworkImage(
            imageUrl: 'https://example.com/$attachmentId.jpg',
            width: 400,
            height: 400,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

/// Test-local wrapper mirroring the real MemberListItem avatar tree:
///   ListTile.leading → PresenceAvatar/StatusGlowRing → [Hero →] ProfileAvatar
///
/// Phase B: MemberListItem.build() wraps ProfileAvatar in a Hero widget
/// with tag = _HeroTags.avatar(member.id).
class _TestableAvatarHero extends StatelessWidget {
  const _TestableAvatarHero({
    required this.userId,
    required this.displayName,
  });
  final String userId;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    // Mirrors: MemberListItem.build() leading widget.
    // In production: PresenceAvatar/StatusGlowRing wraps ProfileAvatar.
    // Phase B inserts Hero between the presence wrapper and ProfileAvatar.
    return Hero(
      tag: _HeroTags.avatar(userId),
      child: ProfileAvatar(
        displayName: displayName,
        radius: 20,
      ),
    );
  }
}

/// Test-local wrapper mirroring the real ProfilePage._ProfileSuccessBody tree:
///   SingleChildScrollView → Center → Column → [Hero →] ProfileAvatar
///
/// Phase B: _ProfileSuccessBody wraps ProfileAvatar in a Hero widget
/// with tag = _HeroTags.avatar(profile.id).
class _TestableProfileAvatarHero extends StatelessWidget {
  const _TestableProfileAvatarHero({
    required this.userId,
    required this.displayName,
  });
  final String userId;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    // Mirrors: _ProfileSuccessBody.build() layout.
    return SingleChildScrollView(
      key: const ValueKey('profile-success'),
      child: Center(
        child: Column(
          children: [
            // Phase B inserts Hero here, wrapping ProfileAvatar.
            Hero(
              tag: _HeroTags.avatar(userId),
              child: ProfileAvatar(
                displayName: displayName,
                radius: 40,
              ),
            ),
            Text(
              displayName,
              key: const ValueKey('profile-display-name'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  // -----------------------------------------------------------------------
  // INV-HERO-IMAGE-1: Image thumbnail contains a Hero widget
  // -----------------------------------------------------------------------
  group('INV-HERO-IMAGE-1: image thumbnail Hero widget', () {
    testWidgets(
      'image attachment preview contains Hero with tag matching '
      'attachment ID',
      skip: true,
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: _TestableImageThumbnailHero(attachmentId: 'att-123'),
            ),
          ),
        );

        // A Hero widget must exist in the tree.
        final heroFinder = find.byType(Hero);
        expect(heroFinder, findsOneWidget);

        // The Hero tag must match the attachment ID convention.
        final hero = tester.widget<Hero>(heroFinder);
        expect(hero.tag, _HeroTags.imageAttachment('att-123'));
        expect(hero.tag, 'image-hero-att-123');

        // The Hero wraps CachedNetworkImage.
        expect(
          find.descendant(
            of: heroFinder,
            matching: find.byType(CachedNetworkImage),
          ),
          findsOneWidget,
        );
      },
    );

    test(
      'Hero tag is unique per attachment ID',
      skip: true,
      () {
        expect(
          _HeroTags.imageAttachment('att-1'),
          isNot(_HeroTags.imageAttachment('att-2')),
        );
        expect(_HeroTags.imageAttachment('att-1'), 'image-hero-att-1');
        expect(_HeroTags.imageAttachment('att-2'), 'image-hero-att-2');
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-HERO-IMAGE-2: FilePreviewPage contains matching Hero widget
  // -----------------------------------------------------------------------
  group('INV-HERO-IMAGE-2: file preview page Hero widget', () {
    testWidgets(
      'file preview page contains Hero wrapping InteractiveViewer with '
      'same tag as thumbnail',
      skip: true,
      (tester) async {
        const attachmentId = 'att-456';
        final thumbnailTag = _HeroTags.imageAttachment(attachmentId);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: _TestableFilePreviewHero(attachmentId: attachmentId),
            ),
          ),
        );

        final heroFinder = find.byType(Hero);
        expect(heroFinder, findsOneWidget);

        final hero = tester.widget<Hero>(heroFinder);
        expect(hero.tag, thumbnailTag);

        // Hero wraps InteractiveViewer (the zoom/pan container).
        expect(
          find.descendant(
            of: heroFinder,
            matching: find.byType(InteractiveViewer),
          ),
          findsOneWidget,
        );
      },
    );

    test(
      'thumbnail and preview share the same Hero tag for a given attachment',
      skip: true,
      () {
        const attachmentId = 'shared-att';
        // Both source (thumbnail) and destination (preview) must use the
        // same tag for the Hero transition to animate.
        final thumbnailTag = _HeroTags.imageAttachment(attachmentId);
        final previewTag = _HeroTags.imageAttachment(attachmentId);
        expect(thumbnailTag, previewTag);
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-HERO-AVATAR-1: MemberListItem avatar contains a Hero widget
  // -----------------------------------------------------------------------
  group('INV-HERO-AVATAR-1: member list avatar Hero widget', () {
    testWidgets(
      'member list item avatar contains Hero wrapping ProfileAvatar with '
      'tag matching user ID',
      skip: true,
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: _TestableAvatarHero(
                userId: 'user-abc',
                displayName: 'Alice',
              ),
            ),
          ),
        );

        final heroFinder = find.byType(Hero);
        expect(heroFinder, findsOneWidget);

        final hero = tester.widget<Hero>(heroFinder);
        expect(hero.tag, _HeroTags.avatar('user-abc'));
        expect(hero.tag, 'avatar-hero-user-abc');

        // Hero wraps ProfileAvatar.
        expect(
          find.descendant(
            of: heroFinder,
            matching: find.byType(ProfileAvatar),
          ),
          findsOneWidget,
        );
      },
    );

    test(
      'Hero tag is unique per user ID',
      skip: true,
      () {
        expect(
          _HeroTags.avatar('user-1'),
          isNot(_HeroTags.avatar('user-2')),
        );
        expect(_HeroTags.avatar('user-1'), 'avatar-hero-user-1');
        expect(_HeroTags.avatar('user-2'), 'avatar-hero-user-2');
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-HERO-AVATAR-2: Profile page header contains matching Hero widget
  // -----------------------------------------------------------------------
  group('INV-HERO-AVATAR-2: profile page avatar Hero widget', () {
    testWidgets(
      'profile page header contains Hero wrapping ProfileAvatar with '
      'same tag as member avatar',
      skip: true,
      (tester) async {
        const userId = 'user-xyz';
        final memberTag = _HeroTags.avatar(userId);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: _TestableProfileAvatarHero(
                userId: userId,
                displayName: 'Bob',
              ),
            ),
          ),
        );

        final heroFinder = find.byType(Hero);
        expect(heroFinder, findsOneWidget);

        final hero = tester.widget<Hero>(heroFinder);
        expect(hero.tag, memberTag);

        // Hero wraps ProfileAvatar with larger radius (40 for profile).
        final avatar = tester.widget<ProfileAvatar>(
          find.descendant(
            of: heroFinder,
            matching: find.byType(ProfileAvatar),
          ),
        );
        expect(avatar.radius, 40);
      },
    );

    test(
      'member avatar and profile avatar share the same Hero tag for a '
      'given user',
      skip: true,
      () {
        const userId = 'shared-user';
        // Both source (member list) and destination (profile) must use
        // the same tag for the Hero transition to animate.
        final memberTag = _HeroTags.avatar(userId);
        final profileTag = _HeroTags.avatar(userId);
        expect(memberTag, profileTag);
      },
    );
  });
}
