import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

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

  /// Deletes a compressed temporary image after upload completion.
  ///
  /// No-ops when [compressedPath] is the original file path.
  Future<void> deleteCompressedFile({
    required String originalPath,
    required String compressedPath,
  });

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

    final dimensions = await _readImageDimensions(path);
    final minWidth =
        dimensions == null ? 1920 : dimensions.width.clamp(1, 1920).toInt();
    final minHeight =
        dimensions == null ? 1920 : dimensions.height.clamp(1, 1920).toInt();

    final result = await FlutterImageCompress.compressAndGetFile(
      path,
      outputPath,
      quality: quality,
      minWidth: minWidth,
      minHeight: minHeight,
    );
    if (result == null) {
      throw Exception('Compression returned null');
    }
    return result.path;
  }

  Future<({int width, int height})?> _readImageDimensions(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final pngDimensions = _readPngDimensions(bytes);
      if (pngDimensions != null) {
        return pngDimensions;
      }
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final dimensions = (width: image.width, height: image.height);
      image.dispose();
      return dimensions;
    } catch (_) {
      return null;
    }
  }

  ({int width, int height})? _readPngDimensions(List<int> bytes) {
    const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (bytes.length < 24) return null;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return null;
    }
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    return (width: data.getUint32(16), height: data.getUint32(20));
  }

  @override
  Future<void> deleteCompressedFile({
    required String originalPath,
    required String compressedPath,
  }) async {
    if (compressedPath == originalPath) return;

    final file = File(compressedPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  bool isCompressibleImage(String mimeType) {
    return _compressibleTypes.contains(mimeType);
  }
}

final imageCompressorProvider = Provider<ImageCompressor>((ref) {
  return const DefaultImageCompressor();
});
