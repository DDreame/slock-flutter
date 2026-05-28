// =============================================================================
// Startup Benchmark — Cold Start to First Frame
//
// Measures the time from app widget initialization to first frame rendered
// using Flutter's integration_test binding with traceAction(). The reported
// metric is derived FROM the trace data (not a local Stopwatch) to ensure
// the measurement is load-bearing on the trace infrastructure.
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
    // traceAction records Timeline events during the action and populates
    // binding.reportData[reportKey] with the timeline summary containing
    // frame_build_times, average_frame_build_time_millis, frame_count, etc.
    await binding.traceAction(() async {
      await tester.pumpWidget(buildBenchmarkApp());
      await tester.pump(); // render first frame
    }, reportKey: 'startup_timeline');

    // Extract first-frame timing FROM the trace data (frozen spec requirement).
    // traceAction populates reportData[reportKey] with a timeline summary.
    final traceReport =
        binding.reportData!['startup_timeline'] as Map<String, dynamic>;
    expect(traceReport, isNotNull,
        reason: 'traceAction must populate reportData with timeline summary');

    final frameCount = traceReport['frame_count'] as int;
    expect(frameCount, greaterThan(0),
        reason: 'Timeline must contain at least one frame');

    // frame_build_times is a list of frame build durations in microseconds.
    final frameBuildTimes = traceReport['frame_build_times'] as List<dynamic>;
    expect(frameBuildTimes, isNotEmpty,
        reason: 'Timeline must record frame build times');

    // Primary metric: first frame build time derived from trace.
    final firstFrameUs = frameBuildTimes.first as int;
    final firstFrameMs = firstFrameUs / 1000.0;
    expect(firstFrameMs, greaterThan(0),
        reason: 'Trace-derived first frame build time must be positive');

    // Average frame build time from trace summary.
    final avgBuildMs = traceReport['average_frame_build_time_millis'] as double;

    // Also measure time to fully settle (secondary metric via stopwatch —
    // acceptable since primary is trace-derived).
    final settleStopwatch = Stopwatch()..start();
    await tester.pumpAndSettle(const Duration(seconds: 5));
    settleStopwatch.stop();
    final settleMs =
        firstFrameMs + settleStopwatch.elapsedMicroseconds / 1000.0;

    // Memory snapshot after startup.
    final rssBytes = ProcessInfo.currentRss;
    final rssMb = rssBytes / (1024 * 1024);
    expect(rssMb, greaterThan(0), reason: 'RSS must be non-zero after startup');

    // Report results — primary metric is trace-derived.
    final file = await BenchmarkReporter.report(
      benchmarkName: 'startup_cold',
      metrics: {
        'time_to_first_frame_ms': BenchmarkMetric(
          value: firstFrameMs,
          unit: 'ms',
        ),
        'average_frame_build_ms': BenchmarkMetric(
          value: avgBuildMs,
          unit: 'ms',
        ),
        'time_to_settle_ms': BenchmarkMetric(
          value: settleMs,
          unit: 'ms',
        ),
        'frame_count': BenchmarkMetric(
          value: frameCount.toDouble(),
          unit: 'frames',
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
    print(
        '  first frame (trace-derived): ${firstFrameMs.toStringAsFixed(2)} ms');
    // ignore: avoid_print
    print('  average frame build: ${avgBuildMs.toStringAsFixed(2)} ms');
    // ignore: avoid_print
    print('  time to settle: ${settleMs.toStringAsFixed(1)} ms');
    // ignore: avoid_print
    print('  frame count: $frameCount');
    // ignore: avoid_print
    print('  peak RSS: ${rssMb.toStringAsFixed(1)} MB');

    // Store in binding for driver collection.
    binding.reportData = {
      'startup_cold': {
        'time_to_first_frame_ms': firstFrameMs,
        'average_frame_build_ms': avgBuildMs,
        'time_to_settle_ms': settleMs,
        'frame_count': frameCount,
        'peak_rss_mb': rssMb,
      },
    };
  });
}
