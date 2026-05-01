import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/telemetry/diagnostic_share_service.dart';

void main() {
  group('DiagnosticShareResult', () {
    test('has success and dismissed values', () {
      expect(DiagnosticShareResult.values, hasLength(2));
      expect(DiagnosticShareResult.success, isNotNull);
      expect(DiagnosticShareResult.dismissed, isNotNull);
    });
  });

  group('DiagnosticShareService — interface contract', () {
    test('defines copyToClipboard, shareText, and saveToFile', () {
      // Verify the interface exists and can be implemented
      final service = _StubShareService();
      expect(service, isA<DiagnosticShareService>());
    });

    test('copyToClipboard returns a result', () async {
      final service = _StubShareService();
      final result = await service.copyToClipboard('test');
      expect(result, DiagnosticShareResult.success);
    });

    test('shareText returns a result', () async {
      final service = _StubShareService();
      final result = await service.shareText('test');
      expect(result, DiagnosticShareResult.success);
    });

    test('saveToFile returns a file path', () async {
      final service = _StubShareService();
      final path = await service.saveToFile('test');
      expect(path, isNotEmpty);
    });
  });
}

class _StubShareService implements DiagnosticShareService {
  @override
  Future<DiagnosticShareResult> copyToClipboard(String text) async {
    return DiagnosticShareResult.success;
  }

  @override
  Future<DiagnosticShareResult> shareText(String text) async {
    return DiagnosticShareResult.success;
  }

  @override
  Future<String> saveToFile(String text, {String? filename}) async {
    return '/stub/path.txt';
  }
}
