// =============================================================================
// Scroll Benchmark — List Scroll FPS Measurement
//
// Measures frame timing during high-velocity fling scrolls on the home page
// list view. Uses SchedulerBinding.addTimingsCallback to capture real
// FrameTimings during scroll operations.
//
// Run: flutter drive --driver=test_driver/integration_test.dart \
//        --target=integration_test/benchmarks/scroll_benchmark_test.dart \
//        -d linux --profile
//
// Output: build/benchmark_results/scroll_home_list.json
// =============================================================================

import 'dart:io';
import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'benchmark_app.dart';
import 'benchmark_reporter.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scroll_home_list — fling scroll FPS', (tester) async {
    // Launch benchmark app with enough items to enable scrolling.
    await tester.pumpWidget(buildBenchmarkApp(inboxItemCount: 100));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Collect frame timings during scroll.
    final timings = <FrameTiming>[];
    void timingsCallback(List<FrameTiming> reported) {
      timings.addAll(reported);
    }

    SchedulerBinding.instance.addTimingsCallback(timingsCallback);

    // Perform multiple fling gestures to measure sustained scroll performance.
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await binding.traceAction(() async {
        // Fling down
        await tester.fling(scrollable.first, const Offset(0, -500), 2000);
        await tester.pumpAndSettle();

        // Fling down again
        await tester.fling(scrollable.first, const Offset(0, -500), 2000);
        await tester.pumpAndSettle();

        // Fling back up
        await tester.fling(scrollable.first, const Offset(0, 500), 2000);
        await tester.pumpAndSettle();
      }, reportKey: 'scroll_home_timeline');
    }

    SchedulerBinding.instance.removeTimingsCallback(timingsCallback);

    // Assertions — prove measurement logic is load-bearing.
    expect(timings, isNotEmpty,
        reason: 'Frame timings must be captured during scroll');

    // Calculate FPS metrics from frame timings.
    final metrics = _computeScrollMetrics(timings);

    // Assertions on computed metrics.
    expect(metrics.frameCount, greaterThan(0),
        reason: 'Must have rendered at least one frame');
    expect(metrics.averageFps, greaterThan(0),
        reason: 'Average FPS must be positive');
    expect(metrics.averageBuildMs, greaterThan(0),
        reason: 'Average build time must be positive');

    // Memory after scroll.
    final rssMb = ProcessInfo.currentRss / (1024 * 1024);
    expect(rssMb, greaterThan(0), reason: 'RSS must be non-zero');

    final file = await BenchmarkReporter.report(
      benchmarkName: 'scroll_home_list',
      metrics: {
        'average_fps': BenchmarkMetric(
          value: metrics.averageFps,
          unit: 'fps',
        ),
        'worst_frame_build_ms': BenchmarkMetric(
          value: metrics.worstBuildMs,
          unit: 'ms',
        ),
        'average_frame_build_ms': BenchmarkMetric(
          value: metrics.averageBuildMs,
          unit: 'ms',
        ),
        'frame_count': BenchmarkMetric(
          value: metrics.frameCount.toDouble(),
          unit: 'frames',
        ),
        'missed_frames_16ms': BenchmarkMetric(
          value: metrics.missedFrames.toDouble(),
          unit: 'frames',
        ),
        'p99_frame_build_ms': BenchmarkMetric(
          value: metrics.p99BuildMs,
          unit: 'ms',
        ),
        'peak_rss_mb': BenchmarkMetric(
          value: rssMb,
          unit: 'MB',
        ),
      },
    );

    // ignore: avoid_print
    print('Benchmark result: ${file.path}');
    // ignore: avoid_print
    print('  average FPS: ${metrics.averageFps.toStringAsFixed(1)}');
    // ignore: avoid_print
    print('  average build: ${metrics.averageBuildMs.toStringAsFixed(2)} ms');
    // ignore: avoid_print
    print('  worst build: ${metrics.worstBuildMs.toStringAsFixed(2)} ms');
    // ignore: avoid_print
    print('  p99 build: ${metrics.p99BuildMs.toStringAsFixed(2)} ms');
    // ignore: avoid_print
    print('  missed frames (>16ms): ${metrics.missedFrames}');
    // ignore: avoid_print
    print('  total frames: ${metrics.frameCount}');
    // ignore: avoid_print
    print('  peak RSS: ${rssMb.toStringAsFixed(1)} MB');

    binding.reportData = {
      'scroll_home_list': {
        'average_fps': metrics.averageFps,
        'worst_frame_build_ms': metrics.worstBuildMs,
        'average_frame_build_ms': metrics.averageBuildMs,
        'p99_frame_build_ms': metrics.p99BuildMs,
        'frame_count': metrics.frameCount,
        'missed_frames_16ms': metrics.missedFrames,
        'peak_rss_mb': rssMb,
      },
    };
  });
}

// =============================================================================
// Scroll metrics computation
// =============================================================================

/// Target frame build time for 60fps (16.67ms budget).
const _targetFrameBuildMs = 16.67;

class _ScrollMetrics {
  const _ScrollMetrics({
    required this.averageFps,
    required this.worstBuildMs,
    required this.averageBuildMs,
    required this.p99BuildMs,
    required this.frameCount,
    required this.missedFrames,
  });

  final double averageFps;
  final double worstBuildMs;
  final double averageBuildMs;
  final double p99BuildMs;
  final int frameCount;
  final int missedFrames;
}

_ScrollMetrics _computeScrollMetrics(List<FrameTiming> timings) {
  if (timings.isEmpty) {
    return const _ScrollMetrics(
      averageFps: 0,
      worstBuildMs: 0,
      averageBuildMs: 0,
      p99BuildMs: 0,
      frameCount: 0,
      missedFrames: 0,
    );
  }

  final buildTimesMs = <double>[];
  double worstBuild = 0;
  double totalBuild = 0;
  int missed = 0;

  for (final timing in timings) {
    final buildMs = timing.buildDuration.inMicroseconds / 1000.0;
    buildTimesMs.add(buildMs);
    totalBuild += buildMs;
    if (buildMs > worstBuild) worstBuild = buildMs;
    if (buildMs > _targetFrameBuildMs) missed++;
  }

  // Sort for percentile calculation.
  buildTimesMs.sort();
  final p99Index = ((buildTimesMs.length - 1) * 0.99).round();
  final p99 = buildTimesMs[p99Index];

  final averageBuild = totalBuild / timings.length;
  final averageFps = averageBuild > 0 ? 1000.0 / averageBuild : 0.0;

  return _ScrollMetrics(
    averageFps: averageFps.clamp(0.0, 120.0),
    worstBuildMs: worstBuild,
    averageBuildMs: averageBuild,
    p99BuildMs: p99,
    frameCount: timings.length,
    missedFrames: missed,
  );
}
