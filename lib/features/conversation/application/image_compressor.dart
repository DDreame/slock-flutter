import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

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

/// Default implementation using flutter_image_compress for real compression.
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
    final dir = p.dirname(path);
    final ext = p.extension(path);
    final baseName = p.basenameWithoutExtension(path);
    final outputPath = p.join(dir, '${baseName}_compressed$ext');

    final result = await FlutterImageCompress.compressAndGetFile(
      path,
      outputPath,
      quality: quality,
      minWidth: 1920,
      minHeight: 1920,
    );
    if (result == null) {
      throw Exception('Compression returned null');
    }
    return result.path;
  }

  @override
  bool isCompressibleImage(String mimeType) {
    return _compressibleTypes.contains(mimeType);
  }
}

final imageCompressorProvider = Provider<ImageCompressor>((ref) {
  return const DefaultImageCompressor();
});
