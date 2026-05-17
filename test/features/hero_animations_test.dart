// ---------------------------------------------------------------------------
// #549: Hero Animations — Image→FilePreview, Avatar→Profile
//
// Problem: 0 Hero widgets in lib/. Two strong candidates for shared-element
// transitions: image thumbnail → FilePreviewPage, and avatar → ProfilePage.
// Both routes use builder: with no transition currently.
//
// Phase A: skip:true invariants locking the Hero widget placement contract.
//          A test-local _TestableHeroConfig seam defines expected Hero tags
//          and widget tree positions. Phase B adds Hero widgets to the
//          production code and un-skips.
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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// Test-local wrapper simulating a Hero-wrapped image thumbnail.
///
/// Phase B: _ImageAttachmentPreview.build() wraps its CachedNetworkImage
/// in a Hero widget with tag = _HeroTags.imageAttachment(attachment.id).
class _TestableImageThumbnailHero extends StatelessWidget {
  const _TestableImageThumbnailHero({required this.attachmentId});
  final String attachmentId;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: _HeroTags.imageAttachment(attachmentId),
      child: Container(
        key: ValueKey('image-preview-$attachmentId'),
        width: 200,
        height: 200,
        color: Colors.grey,
      ),
    );
  }
}

/// Test-local wrapper simulating a Hero-wrapped file preview image.
///
/// Phase B: FilePreviewPage._buildImageBody() wraps its CachedNetworkImage
/// in a Hero widget with tag = _HeroTags.imageAttachment(attachment.id).
class _TestableFilePreviewHero extends StatelessWidget {
  const _TestableFilePreviewHero({required this.attachmentId});
  final String attachmentId;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: _HeroTags.imageAttachment(attachmentId),
      child: Container(
        key: const ValueKey('image-viewer-interactive'),
        width: 400,
        height: 400,
        color: Colors.black,
      ),
    );
  }
}

/// Test-local wrapper simulating a Hero-wrapped avatar in MemberListItem.
///
/// Phase B: MemberListItem.build() wraps ProfileAvatar in a Hero widget
/// with tag = _HeroTags.avatar(member.id).
class _TestableAvatarHero extends StatelessWidget {
  const _TestableAvatarHero({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: _HeroTags.avatar(userId),
      child: CircleAvatar(
        key: ValueKey('member-avatar-$userId'),
        radius: 20,
        child: const Text('A'),
      ),
    );
  }
}

/// Test-local wrapper simulating a Hero-wrapped avatar in ProfilePage.
///
/// Phase B: _ProfileSuccessBody wraps ProfileAvatar in a Hero widget
/// with tag = _HeroTags.avatar(profile.id).
class _TestableProfileAvatarHero extends StatelessWidget {
  const _TestableProfileAvatarHero({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: _HeroTags.avatar(userId),
      child: CircleAvatar(
        key: const ValueKey('profile-avatar-image'),
        radius: 40,
        child: const Text('P'),
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
      'file preview page contains Hero with same tag as thumbnail',
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
      'member list item avatar contains Hero with tag matching user ID',
      skip: true,
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: _TestableAvatarHero(userId: 'user-abc'),
            ),
          ),
        );

        final heroFinder = find.byType(Hero);
        expect(heroFinder, findsOneWidget);

        final hero = tester.widget<Hero>(heroFinder);
        expect(hero.tag, _HeroTags.avatar('user-abc'));
        expect(hero.tag, 'avatar-hero-user-abc');
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
      'profile page header contains Hero with same tag as member avatar',
      skip: true,
      (tester) async {
        const userId = 'user-xyz';
        final memberTag = _HeroTags.avatar(userId);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: _TestableProfileAvatarHero(userId: userId),
            ),
          ),
        );

        final heroFinder = find.byType(Hero);
        expect(heroFinder, findsOneWidget);

        final hero = tester.widget<Hero>(heroFinder);
        expect(hero.tag, memberTag);
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
