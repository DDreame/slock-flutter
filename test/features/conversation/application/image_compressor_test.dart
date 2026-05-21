import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/application/image_compressor.dart';

void main() {
  group('DefaultImageCompressor.deleteCompressedFile', () {
    test('deletes compressed temp file when it differs from original',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('compressor-test-');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final original = File('${tempDir.path}/photo.jpg');
      final compressed = File('${tempDir.path}/photo_compressed.jpg');
      await original.writeAsBytes([1, 2, 3]);
      await compressed.writeAsBytes([4, 5, 6]);

      await const DefaultImageCompressor().deleteCompressedFile(
        originalPath: original.path,
        compressedPath: compressed.path,
      );

      expect(await original.exists(), isTrue);
      expect(await compressed.exists(), isFalse);
    });

    test('does not delete original file when paths match', () async {
      final tempDir = await Directory.systemTemp.createTemp('compressor-test-');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final original = File('${tempDir.path}/photo.jpg');
      await original.writeAsBytes([1, 2, 3]);

      await const DefaultImageCompressor().deleteCompressedFile(
        originalPath: original.path,
        compressedPath: original.path,
      );

      expect(await original.exists(), isTrue);
    });
  });
}
