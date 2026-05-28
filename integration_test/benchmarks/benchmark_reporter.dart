import 'dart:convert';
import 'dart:io';

/// Writes benchmark results to `build/benchmark_results/<name>.json`.
///
/// Each invocation creates or overwrites a single JSON file with:
/// - `benchmarkName`: Identifier for this measurement.
/// - `metrics`: Map of metric name → value + unit.
/// - `timestamp`: ISO 8601 UTC timestamp.
/// - `environment`: Basic system info for reproducibility.
class BenchmarkReporter {
  BenchmarkReporter._();

  /// Writes [metrics] for [benchmarkName] to the standard output directory.
  ///
  /// [metrics] is a map where keys are metric names and values are
  /// [BenchmarkMetric] instances (value + unit).
  static Future<File> report({
    required String benchmarkName,
    required Map<String, BenchmarkMetric> metrics,
  }) async {
    final outputDir = Directory('build/benchmark_results');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final result = <String, dynamic>{
      'benchmarkName': benchmarkName,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'metrics': {
        for (final entry in metrics.entries)
          entry.key: {
            'value': entry.value.value,
            'unit': entry.value.unit,
          },
      },
      'environment': {
        'platform': Platform.operatingSystem,
        'dartVersion': Platform.version.split(' ').first,
        'processors': Platform.numberOfProcessors,
      },
    };

    final file = File('${outputDir.path}/$benchmarkName.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(result),
    );
    return file;
  }
}

/// A single benchmark measurement with its unit.
class BenchmarkMetric {
  const BenchmarkMetric({
    required this.value,
    required this.unit,
  });

  /// The measured value.
  final double value;

  /// Unit of measurement (e.g. 'ms', 'fps', 'MB').
  final String unit;

  @override
  String toString() => '$value $unit';
}
