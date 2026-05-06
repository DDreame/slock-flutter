import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstraction for image compression before upload.
///
/// Compresses large images to reduce upload time and bandwidth. Falls back
/// to the original file on failure or when the image is already small.
abstract class ImageCompressor {
  /// Returns the file size in bytes.
  Future<int> getFileSize(String path);

  /// Compresses the image at [path] and returns the path to the compressed
  /// file. Throws on failure (caller should fall back to original).
  Future<String> compress(String path, {int quality = 80});

  /// Whether the given MIME type is a compressible image format.
  bool isCompressibleImage(String mimeType);
}

/// Default implementation using dart:io for file size and a no-op
/// compression that returns the original (real compression requires
/// a native plugin like flutter_image_compress).
class DefaultImageCompressor implements ImageCompressor {
  const DefaultImageCompressor();

  /// Threshold above which images will be compressed (5MB).
  static const int compressionThresholdBytes = 5 * 1024 * 1024;

  static const Set<String> _compressibleTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  @override
  Future<int> getFileSize(String path) async {
    final file = File(path);
    return file.length();
  }

  @override
  Future<String> compress(String path, {int quality = 80}) async {
    // TODO: Integrate flutter_image_compress or similar native plugin.
    // For now, returns the original path (no-op compression).
    return path;
  }

  @override
  bool isCompressibleImage(String mimeType) {
    return _compressibleTypes.contains(mimeType);
  }
}

final imageCompressorProvider = Provider<ImageCompressor>((ref) {
  return const DefaultImageCompressor();
});
