import 'package:flutter/foundation.dart';

/// Describes the type of content received from a share intent.
enum SharedContentType { text, url, image, video, file }

/// A single item of shared content parsed from a platform share intent.
@immutable
class SharedContentItem {
  const SharedContentItem({
    required this.type,
    required this.path,
    this.mimeType,
    this.thumbnail,
  });

  /// The kind of content (text, URL, image, video, file).
  final SharedContentType type;

  /// File path, URL string, or raw text content.
  final String path;

  /// MIME type when available (e.g. `image/jpeg`, `video/mp4`).
  final String? mimeType;

  /// Local path to a video thumbnail, if available.
  final String? thumbnail;

  /// Whether this item represents a file that can be uploaded as an attachment.
  bool get isAttachment =>
      type == SharedContentType.image ||
      type == SharedContentType.video ||
      type == SharedContentType.file;

  /// Whether this item is plain text or a URL.
  bool get isText =>
      type == SharedContentType.text || type == SharedContentType.url;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SharedContentItem &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          path == other.path &&
          mimeType == other.mimeType &&
          thumbnail == other.thumbnail;

  @override
  int get hashCode => Object.hash(type, path, mimeType, thumbnail);
}

/// Aggregated shared content from a single share intent.
///
/// May contain multiple items (e.g. user shares several images at once).
@immutable
class SharedContent {
  const SharedContent({required this.items});

  /// The individual shared items.
  final List<SharedContentItem> items;

  /// Whether this share contains any content.
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  /// All text items (text + URL types).
  List<SharedContentItem> get textItems =>
      items.where((i) => i.isText).toList();

  /// All attachment items (images, videos, files).
  List<SharedContentItem> get attachmentItems =>
      items.where((i) => i.isAttachment).toList();

  /// Convenience: the combined text content for all text items.
  String get combinedText => textItems.map((i) => i.path).join('\n');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SharedContent &&
          runtimeType == other.runtimeType &&
          listEquals(items, other.items);

  @override
  int get hashCode => Object.hashAll(items);
}
