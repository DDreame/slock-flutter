// =============================================================================
// Memory Benchmark — Peak RSS Across Main Navigation Flows
//
// Navigates through the app's primary flows and captures peak RSS at each
// checkpoint to establish a memory baseline.
//
// Run: flutter test integration_test/benchmarks/memory_benchmark_test.dart \
//        -d linux --profile
//
// Output: build/benchmark_results/memory_navigation.json
// =============================================================================

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'benchmark_app.dart';
import 'benchmark_reporter.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('memory_navigation — RSS across app flows', (tester) async {
    // Track RSS at each navigation checkpoint.
    final checkpoints = <String, double>{};

    double captureRssMb(String label) {
      final mb = ProcessInfo.currentRss / (1024 * 1024);
      checkpoints[label] = mb;
      return mb;
    }

    // 1. App launch
    await tester.pumpWidget(buildBenchmarkApp(inboxItemCount: 100));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    captureRssMb('after_startup');

    // 2. Scroll down (loads more items into view)
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await tester.fling(scrollable.first, const Offset(0, -800), 3000);
      await tester.pumpAndSettle();
    }
    captureRssMb('after_scroll_down');

    // 3. Scroll back up
    if (scrollable.evaluate().isNotEmpty) {
      await tester.fling(scrollable.first, const Offset(0, 800), 3000);
      await tester.pumpAndSettle();
    }
    captureRssMb('after_scroll_up');

    // 4. Rapid scrolling (stress test memory under churn)
    for (var i = 0; i < 5; i++) {
      if (scrollable.evaluate().isNotEmpty) {
        await tester.fling(
          scrollable.first,
          Offset(0, i.isEven ? -400 : 400),
          2000,
        );
        await tester.pumpAndSettle();
      }
    }
    captureRssMb('after_rapid_scroll');

    // 5. Idle for a moment (simulate background)
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    captureRssMb('after_idle_2s');

    // Compute peak RSS.
    final peakRss = checkpoints.values.reduce(
      (a, b) => a > b ? a : b,
    );

    // Report results.
    final metrics = <String, BenchmarkMetric>{
      'peak_rss_mb': BenchmarkMetric(value: peakRss, unit: 'MB'),
    };
    for (final entry in checkpoints.entries) {
      metrics['rss_${entry.key}_mb'] = BenchmarkMetric(
        value: entry.value,
        unit: 'MB',
      );
    }

    final file = await BenchmarkReporter.report(
      benchmarkName: 'memory_navigation',
      metrics: metrics,
    );

    // ignore: avoid_print
    print('Benchmark result: ${file.path}');
    for (final entry in checkpoints.entries) {
      // ignore: avoid_print
      print('  ${entry.key}: ${entry.value.toStringAsFixed(1)} MB');
    }
    // ignore: avoid_print
    print('  peak RSS: ${peakRss.toStringAsFixed(1)} MB');

    binding.reportData = {
      'memory_navigation': {
        'peak_rss_mb': peakRss,
        ...checkpoints,
      },
    };
  });
}
