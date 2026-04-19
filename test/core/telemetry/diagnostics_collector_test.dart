import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';

void main() {
  group('DiagnosticsCollector', () {
    test('adds and retrieves entries', () {
      final collector = DiagnosticsCollector();
      final entry = DiagnosticsEntry(
        timestamp: DateTime.now(),
        level: DiagnosticsLevel.info,
        tag: 'test',
        message: 'hello',
      );
      collector.add(entry);
      expect(collector.entries, hasLength(1));
      expect(collector.entries.first.message, 'hello');
    });

    test('respects max entry count', () {
      final collector = DiagnosticsCollector(maxEntries: 3);
      for (var i = 0; i < 5; i++) {
        collector.add(DiagnosticsEntry(
          timestamp: DateTime.now(),
          level: DiagnosticsLevel.info,
          tag: 'test',
          message: 'entry $i',
        ));
      }
      expect(collector.entries, hasLength(3));
      expect(collector.entries.first.message, 'entry 2');
      expect(collector.entries.last.message, 'entry 4');
    });

    test('prunes entries exceeding max retention age', () {
      final collector = DiagnosticsCollector(
        maxRetentionAge: const Duration(minutes: 5),
      );
      final old = DiagnosticsEntry(
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        level: DiagnosticsLevel.info,
        tag: 'old',
        message: 'expired',
      );
      final recent = DiagnosticsEntry(
        timestamp: DateTime.now(),
        level: DiagnosticsLevel.info,
        tag: 'new',
        message: 'fresh',
      );
      collector.add(old);
      collector.add(recent);
      expect(collector.entries, hasLength(1));
      expect(collector.entries.first.message, 'fresh');
    });

    test('prunes expired entries on entries getter', () {
      final collector = DiagnosticsCollector(
        maxRetentionAge: const Duration(minutes: 5),
      );
      final old = DiagnosticsEntry(
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        level: DiagnosticsLevel.warning,
        tag: 'stale',
        message: 'should be pruned',
      );
      collector.add(old);
      // Even though add prunes, accessing entries also prunes
      expect(collector.entries, isEmpty);
    });

    test('redacts sensitive metadata keys', () {
      final collector = DiagnosticsCollector();
      collector.add(DiagnosticsEntry(
        timestamp: DateTime.now(),
        level: DiagnosticsLevel.info,
        tag: 'net',
        message: 'request',
        metadata: {
          'url': '/api/users',
          'token': 'secret-abc',
          'Password': 'hunter2',
          'Authorization': 'Bearer xyz',
          'normal': 'value',
        },
      ));
      final meta = collector.entries.first.metadata!;
      expect(meta['url'], '/api/users');
      expect(meta['token'], '[REDACTED]');
      expect(meta['Password'], '[REDACTED]');
      expect(meta['Authorization'], '[REDACTED]');
      expect(meta['normal'], 'value');
    });

    test('entries without metadata are not redacted', () {
      final collector = DiagnosticsCollector();
      collector.add(DiagnosticsEntry(
        timestamp: DateTime.now(),
        level: DiagnosticsLevel.error,
        tag: 'crash',
        message: 'NullPointerException',
      ));
      expect(collector.entries.first.metadata, isNull);
    });

    test('entries snapshot is unmodifiable', () {
      final collector = DiagnosticsCollector();
      collector.add(DiagnosticsEntry(
        timestamp: DateTime.now(),
        level: DiagnosticsLevel.info,
        tag: 'test',
        message: 'msg',
      ));
      final snapshot = collector.entries;
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

    test('clear empties the buffer', () {
      final collector = DiagnosticsCollector();
      collector.add(DiagnosticsEntry(
        timestamp: DateTime.now(),
        level: DiagnosticsLevel.info,
        tag: 'test',
        message: 'a',
      ));
      expect(collector.entries, hasLength(1));
      collector.clear();
      expect(collector.entries, isEmpty);
    });

    test('combined max entries and max retention age', () {
      final collector = DiagnosticsCollector(
        maxEntries: 3,
        maxRetentionAge: const Duration(minutes: 5),
      );
      // Add 2 old + 3 recent; expect only 3 recent (old pruned by age)
      for (var i = 0; i < 2; i++) {
        collector.add(DiagnosticsEntry(
          timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
          level: DiagnosticsLevel.info,
          tag: 'old',
          message: 'old $i',
        ));
      }
      for (var i = 0; i < 3; i++) {
        collector.add(DiagnosticsEntry(
          timestamp: DateTime.now(),
          level: DiagnosticsLevel.info,
          tag: 'new',
          message: 'new $i',
        ));
      }
      final entries = collector.entries;
      expect(entries, hasLength(3));
      expect(entries.every((e) => e.tag == 'new'), isTrue);
    });
  });
}
