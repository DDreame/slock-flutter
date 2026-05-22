import 'dart:io';
import 'dart:typed_data' as typed_data;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/application/image_compressor.dart';

/// Tests that the real [DefaultImageCompressor] invokes the platform
/// compression library with correct parameters. Uses a fake platform
/// implementation to capture calls without needing real native compression.
void main() {
  late _FakeCompressPlatform fakePlatform;
  late FlutterImageCompressPlatform originalPlatform;

  setUp(() {
    originalPlatform = FlutterImageCompressPlatform.instance;
    fakePlatform = _FakeCompressPlatform();
    FlutterImageCompressPlatform.instance = fakePlatform;
  });

  tearDown(() {
    FlutterImageCompressPlatform.instance = originalPlatform;
  });

  group('DefaultImageCompressor', () {
    test('compressionThresholdBytes is 5MB', () {
      expect(DefaultImageCompressor.compressionThresholdBytes, 5 * 1024 * 1024);
    });

    test('isCompressibleImage returns true for jpeg/png/webp', () {
      const compressor = DefaultImageCompressor();
      expect(compressor.isCompressibleImage('image/jpeg'), isTrue);
      expect(compressor.isCompressibleImage('image/png'), isTrue);
      expect(compressor.isCompressibleImage('image/webp'), isTrue);
      expect(compressor.isCompressibleImage('image/gif'), isFalse);
      expect(compressor.isCompressibleImage('application/pdf'), isFalse);
    });

    test('getFileSize returns actual file byte length', () async {
      const compressor = DefaultImageCompressor();
      final tempFile = File('${Directory.systemTemp.path}/compressor_test.tmp');
      tempFile.writeAsBytesSync(List.filled(1234, 0));
      addTearDown(() => tempFile.deleteSync());

      final size = await compressor.getFileSize(tempFile.path);
      expect(size, 1234);
    });

    test(
        'compress calls FlutterImageCompress.compressAndGetFile with correct params',
        () async {
      const compressor = DefaultImageCompressor();

      // Create a real temp file (required: platform checks existsSync)
      final tempDir = Directory.systemTemp.createTempSync('img_compress_');
      final inputFile = File('${tempDir.path}/photo.jpg');
      inputFile.writeAsBytesSync(List.filled(100, 0xFF));
      addTearDown(() => tempDir.deleteSync(recursive: true));

      // Configure fake platform to return a specific path
      final expectedOutput = '${tempDir.path}/photo_compressed.jpg';
      fakePlatform.compressAndGetFileResult = XFile(expectedOutput);

      final result = await compressor.compress(inputFile.path, quality: 80);

      // Verify the returned path matches what the platform returned
      expect(result, expectedOutput);

      // Verify compressAndGetFile was called exactly once
      expect(fakePlatform.compressAndGetFileCalls, hasLength(1));

      // Verify correct parameters were passed
      final call = fakePlatform.compressAndGetFileCalls.first;
      expect(call.sourcePath, inputFile.path);
      expect(call.targetPath, '${tempDir.path}/photo_compressed.jpg');
      expect(call.quality, 80);
      expect(call.minWidth, 1920);
      expect(call.minHeight, 1920);
    });

    test('compress does not upscale tiny images (#722)', () async {
      const compressor = DefaultImageCompressor();

      final tempDir = Directory.systemTemp.createTempSync('img_compress_');
      final inputFile = File('${tempDir.path}/tiny.png');
      inputFile.writeAsBytesSync(_png1x1());
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final expectedOutput = '${tempDir.path}/tiny_compressed.png';
      fakePlatform.compressAndGetFileResult = XFile(expectedOutput);

      await compressor.compress(inputFile.path);

      final call = fakePlatform.compressAndGetFileCalls.first;
      expect(call.minWidth, 1);
      expect(call.minHeight, 1);
    });

    test('compress throws when platform returns null', () async {
      const compressor = DefaultImageCompressor();

      final tempDir = Directory.systemTemp.createTempSync('img_compress_');
      final inputFile = File('${tempDir.path}/photo.jpg');
      inputFile.writeAsBytesSync(List.filled(100, 0xFF));
      addTearDown(() => tempDir.deleteSync(recursive: true));

      fakePlatform.compressAndGetFileResult = null;

      expect(
        () => compressor.compress(inputFile.path),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Compression returned null'),
        )),
      );
    });

    test('compress generates correct output path from input', () async {
      const compressor = DefaultImageCompressor();

      final tempDir = Directory.systemTemp.createTempSync('img_compress_');
      final inputFile = File('${tempDir.path}/vacation-photo.png');
      inputFile.writeAsBytesSync(List.filled(50, 0xAA));
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final expectedOutput = '${tempDir.path}/vacation-photo_compressed.png';
      fakePlatform.compressAndGetFileResult = XFile(expectedOutput);

      await compressor.compress(inputFile.path);

      final call = fakePlatform.compressAndGetFileCalls.first;
      expect(call.targetPath, expectedOutput);
    });
  });
}

List<int> _png1x1() => const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1F,
      0x15,
      0xC4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9C,
      0x63,
      0x00,
      0x01,
      0x00,
      0x00,
      0x05,
      0x00,
      0x01,
      0x0D,
      0x0A,
      0x2D,
      0xB4,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82,
    ];

// ---------------------------------------------------------------------------
// Fake platform implementation
// ---------------------------------------------------------------------------

class _CompressAndGetFileCall {
  _CompressAndGetFileCall({
    required this.sourcePath,
    required this.targetPath,
    required this.quality,
    required this.minWidth,
    required this.minHeight,
  });
  final String sourcePath;
  final String targetPath;
  final int quality;
  final int minWidth;
  final int minHeight;
}

class _FakeCompressPlatform extends FlutterImageCompressPlatform {
  XFile? compressAndGetFileResult;
  final List<_CompressAndGetFileCall> compressAndGetFileCalls = [];

  @override
  Future<XFile?> compressAndGetFile(
    String path,
    String targetPath, {
    int minWidth = 1920,
    int minHeight = 1080,
    int inSampleSize = 1,
    int quality = 95,
    int rotate = 0,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
    int numberOfRetries = 5,
  }) async {
    compressAndGetFileCalls.add(_CompressAndGetFileCall(
      sourcePath: path,
      targetPath: targetPath,
      quality: quality,
      minWidth: minWidth,
      minHeight: minHeight,
    ));
    return compressAndGetFileResult;
  }

  @override
  Future<typed_data.Uint8List?> compressAssetImage(
    String assetName, {
    int minWidth = 1920,
    int minHeight = 1080,
    int quality = 95,
    int rotate = 0,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
  }) async =>
      null;

  @override
  Future<typed_data.Uint8List?> compressWithFile(
    String path, {
    int minWidth = 1920,
    int minHeight = 1080,
    int inSampleSize = 1,
    int quality = 95,
    int rotate = 0,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
    int numberOfRetries = 5,
  }) async =>
      null;

  @override
  Future<typed_data.Uint8List> compressWithList(
    typed_data.Uint8List image, {
    int minWidth = 1920,
    int minHeight = 1080,
    int quality = 95,
    int rotate = 0,
    int inSampleSize = 1,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
  }) async =>
      typed_data.Uint8List(0);

  @override
  void ignoreCheckSupportPlatform(bool bool) {}

  @override
  Future<void> showNativeLog(bool value) async {}

  @override
  FlutterImageCompressValidator get validator => throw UnimplementedError();
}
