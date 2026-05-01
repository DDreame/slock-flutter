import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/telemetry/diagnostic_log_service.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';

void main() {
  group('DiagnosticBundle', () {
    test('buildBundle captures entries and context', () {
      final collector = DiagnosticsCollector();
      collector.info('test', 'hello');
      collector.warning('net', 'slow');

      final service = DiagnosticLogService(collector: collector);
      final bundle = service.buildBundle(
        context: const DiagnosticContext(
          appVersion: '1.0.0',
          platform: 'android',
          locale: 'en_US',
        ),
      );

      expect(bundle.entries, hasLength(2));
      expect(bundle.context?.appVersion, '1.0.0');
      expect(bundle.context?.platform, 'android');
      expect(bundle.context?.locale, 'en_US');
    });

    test('buildBundle limits entries with maxEntries parameter', () {
      final collector = DiagnosticsCollector();
      for (var i = 0; i < 10; i++) {
        collector.info('test', 'entry $i');
      }

      final service = DiagnosticLogService(collector: collector);
      final bundle = service.buildBundle(maxEntries: 5);

      expect(bundle.entries, hasLength(5));
      // Should take the last 5 (most recent)
      expect(bundle.entries.first.message, 'entry 5');
      expect(bundle.entries.last.message, 'entry 9');
    });

    test('buildBundle without maxEntries includes all entries', () {
      final collector = DiagnosticsCollector();
      for (var i = 0; i < 10; i++) {
        collector.info('test', 'entry $i');
      }

      final service = DiagnosticLogService(collector: collector);
      final bundle = service.buildBundle();
      expect(bundle.entries, hasLength(10));
    });

    test('buildBundle with null context omits context', () {
      final collector = DiagnosticsCollector();
      collector.info('test', 'msg');

      final service = DiagnosticLogService(collector: collector);
      final bundle = service.buildBundle();
      expect(bundle.context, isNull);
    });
  });

  group('formatText', () {
    test('formats bundle as human-readable text', () {
      final collector = DiagnosticsCollector();
      collector.info('net', 'GET /api/users');
      collector.error('crash', 'NullPointerException');

      final service = DiagnosticLogService(collector: collector);
      final bundle = service.buildBundle(
        context: const DiagnosticContext(
          appVersion: '2.0.0',
          platform: 'ios',
        ),
      );

      final text = service.formatText(bundle);

      // Header with context
      expect(text, contains('App Version: 2.0.0'));
      expect(text, contains('Platform: ios'));

      // Entry lines
      expect(text, contains('[INFO]'));
      expect(text, contains('[ERROR]'));
      expect(text, contains('net'));
      expect(text, contains('crash'));
      expect(text, contains('GET /api/users'));
      expect(text, contains('NullPointerException'));
    });

    test('formatText without context omits header', () {
      final collector = DiagnosticsCollector();
      collector.info('test', 'hello');

      final service = DiagnosticLogService(collector: collector);
      final bundle = service.buildBundle();
      final text = service.formatText(bundle);

      expect(text, isNot(contains('App Version:')));
      expect(text, contains('[INFO]'));
    });

    test('formatText includes metadata', () {
      final collector = DiagnosticsCollector();
      collector.info('net', 'request', metadata: {
        'statusCode': 200,
        'method': 'GET',
      });

      final service = DiagnosticLogService(collector: collector);
      final bundle = service.buildBundle();
      final text = service.formatText(bundle);

      expect(text, contains('statusCode'));
      expect(text, contains('200'));
      expect(text, contains('method'));
      expect(text, contains('GET'));
    });
  });

  group('redaction in formatText', () {
    test('does not contain token or password values', () {
      final collector = DiagnosticsCollector();
      collector.info('net', 'auth request', metadata: {
        'token': 'my-secret-token-123',
        'password': 'hunter2',
        'authorization': 'Bearer xyz-abc',
        'cookie': 'session=s3cr3t',
        'secret': 'api-key-456',
      });

      final service = DiagnosticLogService(collector: collector);
      final bundle = service.buildBundle();
      final text = service.formatText(bundle);

      // Redacted values should appear as [REDACTED]
      expect(text, isNot(contains('my-secret-token-123')));
      expect(text, isNot(contains('hunter2')));
      expect(text, isNot(contains('Bearer xyz-abc')));
      expect(text, isNot(contains('s3cr3t')));
      expect(text, isNot(contains('api-key-456')));
      expect(text, contains('[REDACTED]'));
    });

    test('redacts full URLs to path-only', () {
      final collector = DiagnosticsCollector();
      collector.info('net', 'request', metadata: {
        'url': 'https://api.slock.app/v1/servers/123/channels?token=abc',
      });

      final service = DiagnosticLogService(collector: collector);
      final bundle = service.buildBundle();
      final text = service.formatText(bundle);

      // Should not contain the full URL with scheme/host
      expect(text, isNot(contains('https://api.slock.app')));
      // Should contain the path part
      expect(text, contains('/v1/servers/123/channels'));
    });

    test('non-URL values are not path-stripped', () {
      final collector = DiagnosticsCollector();
      collector.info('test', 'hello', metadata: {
        'description': 'simple text value',
      });

      final service = DiagnosticLogService(collector: collector);
      final bundle = service.buildBundle();
      final text = service.formatText(bundle);

      expect(text, contains('simple text value'));
    });

    test('compound sensitive keys are redacted in formatted output', () {
      final collector = DiagnosticsCollector();
      collector.info('net', 'request', metadata: {
        'accessToken': 'bearer-xyz',
        'refresh_token': 'rt-123',
        'apiSecret': 'secret-456',
        'safe_key': 'visible-value',
      });

      final service = DiagnosticLogService(collector: collector);
      final bundle = service.buildBundle();
      final text = service.formatText(bundle);

      expect(text, isNot(contains('bearer-xyz')));
      expect(text, isNot(contains('rt-123')));
      expect(text, isNot(contains('secret-456')));
      expect(text, contains('visible-value'));
    });

    test('body-like metadata keys do not appear in formatted text', () {
      // Body keys are stripped at collector level via _redact.
      // Verify end-to-end: adding entries with body keys results in no body
      // content in formatted output.
      final collector = DiagnosticsCollector();
      collector.info('net', 'POST /api/messages', metadata: {
        'body': '{"content":"secret message body"}',
        'messageBody': 'raw user message content',
        'requestBody': '{"data":"payload"}',
        'responseBody': '{"result":"ok"}',
        'statusCode': 201,
      });

      final service = DiagnosticLogService(collector: collector);
      final bundle = service.buildBundle();
      final text = service.formatText(bundle);

      // Body content must not appear
      expect(text, isNot(contains('secret message body')));
      expect(text, isNot(contains('raw user message content')));
      expect(text, isNot(contains('payload')));
      // Body keys themselves must not appear
      expect(text, isNot(contains('  body:')));
      expect(text, isNot(contains('  messageBody:')));
      expect(text, isNot(contains('  requestBody:')));
      expect(text, isNot(contains('  responseBody:')));
      // Non-body keys should appear
      expect(text, contains('statusCode'));
      expect(text, contains('201'));
    });
  });

  group('copyToClipboard', () {
    test('copies formatted text to clipboard', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      final collector = DiagnosticsCollector();
      collector.info('test', 'clipboard test');

      final service = DiagnosticLogService(collector: collector);
      final bundle = service.buildBundle();

      String? copiedText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map;
          copiedText = args['text'] as String?;
        }
        return null;
      });

      await service.copyToClipboard(bundle);

      expect(copiedText, isNotNull);
      expect(copiedText, contains('clipboard test'));

      // Cleanup
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
  });

  group('DiagnosticContext', () {
    test('DiagnosticContext equality', () {
      const a = DiagnosticContext(
        appVersion: '1.0.0',
        platform: 'android',
        locale: 'en_US',
      );
      const b = DiagnosticContext(
        appVersion: '1.0.0',
        platform: 'android',
        locale: 'en_US',
      );
      expect(a, equals(b));
    });

    test('DiagnosticBundle entries are immutable', () {
      final collector = DiagnosticsCollector();
      collector.info('test', 'msg');

      final service = DiagnosticLogService(collector: collector);
      final bundle = service.buildBundle();

      expect(
        () => bundle.entries.add(DiagnosticsEntry(
          timestamp: DateTime.now(),
          level: DiagnosticsLevel.info,
          tag: 'x',
          message: 'y',
        )),
        throwsUnsupportedError,
      );
    });
  });
}
