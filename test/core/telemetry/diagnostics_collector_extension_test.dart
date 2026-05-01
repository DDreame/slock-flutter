import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';

void main() {
  group('DiagnosticsCollector — extended defaults', () {
    test('default maxEntries is 500', () {
      final collector = DiagnosticsCollector();
      expect(collector.maxEntries, 500);
    });

    test('default maxRetentionAge is 24 hours', () {
      final collector = DiagnosticsCollector();
      expect(collector.maxRetentionAge, const Duration(hours: 24));
    });
  });

  group('DiagnosticsCollector — convenience methods', () {
    test('info() creates entry with DiagnosticsLevel.info', () {
      final collector = DiagnosticsCollector();
      collector.info('test', 'hello world');
      expect(collector.entries, hasLength(1));
      final entry = collector.entries.first;
      expect(entry.level, DiagnosticsLevel.info);
      expect(entry.tag, 'test');
      expect(entry.message, 'hello world');
      expect(entry.metadata, isNull);
    });

    test('warning() creates entry with DiagnosticsLevel.warning', () {
      final collector = DiagnosticsCollector();
      collector.warning('net', 'slow response', metadata: {'latencyMs': 3000});
      expect(collector.entries, hasLength(1));
      final entry = collector.entries.first;
      expect(entry.level, DiagnosticsLevel.warning);
      expect(entry.tag, 'net');
      expect(entry.message, 'slow response');
      expect(entry.metadata?['latencyMs'], 3000);
    });

    test('error() creates entry with DiagnosticsLevel.error', () {
      final collector = DiagnosticsCollector();
      collector.error('crash', 'NullPointerException');
      expect(collector.entries, hasLength(1));
      final entry = collector.entries.first;
      expect(entry.level, DiagnosticsLevel.error);
      expect(entry.tag, 'crash');
      expect(entry.message, 'NullPointerException');
    });

    test('convenience methods auto-populate timestamp', () {
      final before = DateTime.now();
      final collector = DiagnosticsCollector();
      collector.info('test', 'msg');
      final after = DateTime.now();

      final entry = collector.entries.first;
      expect(
          entry.timestamp.isAfter(before) || entry.timestamp == before, isTrue);
      expect(
          entry.timestamp.isBefore(after) || entry.timestamp == after, isTrue);
    });

    test('convenience methods pass metadata with redaction', () {
      final collector = DiagnosticsCollector();
      collector.info('net', 'request', metadata: {
        'url': '/api/users',
        'token': 'secret-abc',
      });
      final meta = collector.entries.first.metadata!;
      expect(meta['url'], '/api/users');
      expect(meta['token'], '[REDACTED]');
    });

    test('compound sensitive keys are redacted via substring matching', () {
      final collector = DiagnosticsCollector();
      collector.info('net', 'request', metadata: {
        'accessToken': 'bearer-xyz',
        'refresh_token': 'rt-123',
        'apiSecret': 'secret-456',
        'sessionCookie': 'sess=abc',
        'authorizationHeader': 'Bearer abc',
        'userCredentials': 'cred-789',
        'oldPassword': 'hunter2',
        'safe_key': 'visible',
      });
      final meta = collector.entries.first.metadata!;
      expect(meta['accessToken'], '[REDACTED]');
      expect(meta['refresh_token'], '[REDACTED]');
      expect(meta['apiSecret'], '[REDACTED]');
      expect(meta['sessionCookie'], '[REDACTED]');
      expect(meta['authorizationHeader'], '[REDACTED]');
      expect(meta['userCredentials'], '[REDACTED]');
      expect(meta['oldPassword'], '[REDACTED]');
      expect(meta['safe_key'], 'visible');
    });

    test('body-like metadata keys are stripped entirely', () {
      final collector = DiagnosticsCollector();
      collector.info('net', 'POST /api/messages', metadata: {
        'body': '{"content":"hello world"}',
        'messageBody': 'raw message content',
        'requestBody': '{"data":"value"}',
        'responseBody': '{"result":"ok"}',
        'url': '/api/messages',
        'statusCode': 201,
      });
      final meta = collector.entries.first.metadata!;
      // Body keys should be stripped
      expect(meta.containsKey('body'), isFalse);
      expect(meta.containsKey('messageBody'), isFalse);
      expect(meta.containsKey('requestBody'), isFalse);
      expect(meta.containsKey('responseBody'), isFalse);
      // Non-body keys should remain
      expect(meta['url'], '/api/messages');
      expect(meta['statusCode'], 201);
    });
  });

  group('DiagnosticsCollector — toSnapshot()', () {
    test('toSnapshot returns immutable list', () {
      final collector = DiagnosticsCollector();
      collector.info('test', 'a');
      collector.info('test', 'b');

      final snapshot = collector.toSnapshot();
      expect(snapshot, hasLength(2));
      expect(
        () => snapshot.add(DiagnosticsEntry(
          timestamp: DateTime.now(),
          level: DiagnosticsLevel.info,
          tag: 'x',
          message: 'y',
        )),
        throwsUnsupportedError,
      );
    });

    test('toSnapshot is independent of subsequent mutations', () {
      final collector = DiagnosticsCollector();
      collector.info('test', 'a');
      final snapshot = collector.toSnapshot();

      collector.info('test', 'b');
      collector.info('test', 'c');

      // Snapshot should still have only 1 entry
      expect(snapshot, hasLength(1));
      expect(snapshot.first.message, 'a');
      // Collector should have 3
      expect(collector.entries, hasLength(3));
    });

    test('toSnapshot prunes expired entries', () {
      final collector = DiagnosticsCollector(
        maxRetentionAge: const Duration(minutes: 5),
      );
      collector.add(DiagnosticsEntry(
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        level: DiagnosticsLevel.info,
        tag: 'old',
        message: 'expired',
      ));
      collector.info('new', 'fresh');

      final snapshot = collector.toSnapshot();
      expect(snapshot, hasLength(1));
      expect(snapshot.first.message, 'fresh');
    });
  });
}
