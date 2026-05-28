// =============================================================================
// Startup Benchmark — Cold Start to First Frame
//
// Measures the time from app widget initialization to first frame rendered
// using Flutter's integration_test binding with traceAction().
//
// Run: flutter drive --driver=test_driver/integration_test.dart \
//        --target=integration_test/benchmarks/startup_benchmark_test.dart \
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
      // Single pump renders the first frame — this is the metric the frozen
      // spec requires ("cold start to first frame").
      await tester.pump();
      stopwatch.stop();
    }, reportKey: 'startup_timeline');

    final firstFrameMs = stopwatch.elapsedMicroseconds / 1000.0;

    // Also measure time to fully settle (animations, async loads).
    final settleStopwatch = Stopwatch()..start();
    await tester.pumpAndSettle(const Duration(seconds: 5));
    settleStopwatch.stop();
    final settleMs =
        firstFrameMs + settleStopwatch.elapsedMicroseconds / 1000.0;

    // Memory snapshot after startup.
    final rssBytes = ProcessInfo.currentRss;
    final rssMb = rssBytes / (1024 * 1024);

    // Assertions — prove measurement logic is load-bearing.
    expect(firstFrameMs, greaterThan(0),
        reason: 'First frame must take measurable time');
    expect(rssMb, greaterThan(0), reason: 'RSS must be non-zero after startup');
    expect(firstFrameMs, lessThan(30000),
        reason: 'First frame should complete within 30s');

    // Report results.
    final file = await BenchmarkReporter.report(
      benchmarkName: 'startup_cold',
      metrics: {
        'time_to_first_frame_ms': BenchmarkMetric(
          value: firstFrameMs,
          unit: 'ms',
        ),
        'time_to_settle_ms': BenchmarkMetric(
          value: settleMs,
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
    print('  time to first frame: ${firstFrameMs.toStringAsFixed(1)} ms');
    // ignore: avoid_print
    print('  time to settle: ${settleMs.toStringAsFixed(1)} ms');
    // ignore: avoid_print
    print('  peak RSS: ${rssMb.toStringAsFixed(1)} MB');

    // Store in binding for driver collection.
    binding.reportData = {
      'startup_cold': {
        'time_to_first_frame_ms': firstFrameMs,
        'time_to_settle_ms': settleMs,
        'peak_rss_mb': rssMb,
      },
    };
  });
}
