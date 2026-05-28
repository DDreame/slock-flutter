// =============================================================================
// Startup Benchmark — Cold Start to First Frame
//
// Measures the time from app widget initialization to first frame rendered
// using Flutter's integration_test binding with traceAction().
//
// Run: flutter test integration_test/benchmarks/startup_benchmark_test.dart \
//        -d linux --profile
//
// Output: build/benchmark_results/startup_cold.json
// =============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'benchmark_app.dart';
import 'benchmark_reporter.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('startup_cold — app launch to first frame', (tester) async {
    // Measure cold startup: build widget tree → first frame rendered.
    final stopwatch = Stopwatch();

    await binding.traceAction(() async {
      stopwatch.start();
      await tester.pumpWidget(buildBenchmarkApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));
      stopwatch.stop();
    }, reportKey: 'startup_timeline');

    final startupTimeMs = stopwatch.elapsedMicroseconds / 1000.0;

    // Memory snapshot after startup.
    final rssBytes = ProcessInfo.currentRss;
    final rssMb = rssBytes / (1024 * 1024);

    // Report results.
    final file = await BenchmarkReporter.report(
      benchmarkName: 'startup_cold',
      metrics: {
        'time_to_settle_ms': BenchmarkMetric(
          value: startupTimeMs,
          unit: 'ms',
        ),
        'peak_rss_mb': BenchmarkMetric(
          value: rssMb,
          unit: 'MB',
        ),
      },
    );

    // Print for CI artifact collection.
    // ignore: avoid_print
    print('Benchmark result: ${file.path}');
    // ignore: avoid_print
    print('  startup time to settle: ${startupTimeMs.toStringAsFixed(1)} ms');
    // ignore: avoid_print
    print('  peak RSS: ${rssMb.toStringAsFixed(1)} MB');

    // Store in binding for CI report collection.
    binding.reportData = {
      'startup_cold': {
        'time_to_settle_ms': startupTimeMs,
        'peak_rss_mb': rssMb,
      },
    };
  });
}
