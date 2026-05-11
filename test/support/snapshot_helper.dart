import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Deterministic JSON snapshot helper for golden-file testing of
/// projection state.
///
/// Unlike `matchesGoldenFile` (which is pixel-based), this compares
/// structured JSON. It produces readable diffs on mismatch.
///
/// ## Usage
/// ```dart
/// final state = container.read(someProjectionProvider);
/// final json = stateToSnapshot(state);
///
/// // First run: creates the golden file
/// // Subsequent runs: compares against it
/// await expectMatchesGoldenJson(
///   json,
///   goldenPath: 'test/goldens/some_projection.json',
/// );
/// ```
class SnapshotHelper {
  const SnapshotHelper._();

  /// Serialize a value to deterministic JSON (sorted keys, stable ordering).
  ///
  /// Supports Map, List, and primitive types. Lists are preserved in order.
  /// Maps are sorted by key.
  static String toJson(Object? value) {
    final normalized = _normalize(value);
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(normalized);
  }

  /// Compare a snapshot string against a golden file at [goldenPath].
  ///
  /// - If the golden file does not exist, it is created (test passes).
  /// - If `autoUpdate` is true or the `UPDATE_GOLDENS` env var is set,
  ///   the file is overwritten and the test passes.
  /// - Otherwise, a line-by-line diff is produced on mismatch.
  static Future<void> expectMatchesGolden(
    Object? actualValue, {
    required String goldenPath,
    bool autoUpdate = false,
  }) async {
    final actualJson = toJson(actualValue);
    final goldenFile = File(goldenPath);

    final shouldUpdate =
        autoUpdate || Platform.environment.containsKey('UPDATE_GOLDENS');

    if (!goldenFile.existsSync() || shouldUpdate) {
      goldenFile.parent.createSync(recursive: true);
      goldenFile.writeAsStringSync('$actualJson\n');
      // Don't fail — this is a generation run.
      return;
    }

    final expectedJson = goldenFile.readAsStringSync().trimRight();

    if (actualJson == expectedJson) return;

    // Build a human-readable diff
    final diff = _buildDiff(expectedJson, actualJson);
    fail(
      'Snapshot mismatch for $goldenPath.\n'
      'Run with UPDATE_GOLDENS=1 to regenerate.\n\n'
      '$diff',
    );
  }

  /// Normalize a value for deterministic JSON serialization.
  /// Maps are sorted by key. Lists preserve order.
  static Object? _normalize(Object? value) {
    if (value is Map) {
      final sorted = Map<String, Object?>.fromEntries(
        value.entries
            .map((e) => MapEntry(e.key.toString(), _normalize(e.value)))
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key)),
      );
      return sorted;
    }
    if (value is List) {
      return value.map(_normalize).toList();
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    // Primitives: String, num, bool, null
    return value;
  }

  static String _buildDiff(String expected, String actual) {
    final expectedLines = expected.split('\n');
    final actualLines = actual.split('\n');
    final buffer = StringBuffer();

    final maxLen = expectedLines.length > actualLines.length
        ? expectedLines.length
        : actualLines.length;

    for (var i = 0; i < maxLen; i++) {
      final exp = i < expectedLines.length ? expectedLines[i] : '<missing>';
      final act = i < actualLines.length ? actualLines[i] : '<missing>';
      if (exp != act) {
        buffer.writeln('  Line ${i + 1}:');
        buffer.writeln('    - $exp');
        buffer.writeln('    + $act');
      }
    }

    return buffer.toString();
  }
}

/// Convenience function — delegates to [SnapshotHelper.toJson].
String snapshotToJson(Object? value) => SnapshotHelper.toJson(value);

/// Convenience function — delegates to [SnapshotHelper.expectMatchesGolden].
Future<void> expectMatchesGoldenJson(
  Object? actualValue, {
  required String goldenPath,
  bool autoUpdate = false,
}) =>
    SnapshotHelper.expectMatchesGolden(
      actualValue,
      goldenPath: goldenPath,
      autoUpdate: autoUpdate,
    );
