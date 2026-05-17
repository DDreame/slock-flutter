/// Hero tag conventions for shared-element transitions.
///
/// Both source and destination widgets must reference the same tag
/// for Flutter's Hero animation to animate between them.
class HeroTags {
  HeroTags._();

  /// Tag for image attachment hero: `'image-hero-{attachmentId}'`.
  ///
  /// Source: `_ImageAttachmentPreview` (conversation detail page).
  /// Destination: `FilePreviewPage._buildImageBody()`.
  static String imageAttachment(String attachmentId) =>
      'image-hero-$attachmentId';

  /// Tag for avatar hero: `'avatar-hero-{userId}'`.
  ///
  /// Source: `MemberListItem` avatar.
  /// Destination: `_ProfileSuccessBody` avatar.
  static String avatar(String userId) => 'avatar-hero-$userId';
}
