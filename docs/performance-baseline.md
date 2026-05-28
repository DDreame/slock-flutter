# Performance Baseline

Repeatable performance benchmarks for slock-flutter. These measure app startup,
scroll rendering, and memory usage under synthetic load.

## Running Benchmarks

```bash
# All benchmarks (CI target)
make ci-benchmark

# Individual benchmarks (requires linux desktop: flutter create --platforms=linux .)
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/benchmarks/startup_benchmark_test.dart -d linux --profile
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/benchmarks/scroll_benchmark_test.dart -d linux --profile
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/benchmarks/memory_benchmark_test.dart -d linux --profile
```

Results are written to `build/benchmark_results/` as JSON.

## Metrics

### Startup — `startup_cold`

| Metric | Unit | Description |
|--------|------|-------------|
| `time_to_first_frame_ms` | ms | Time from widget tree initialization to first frame rendered |
| `time_to_settle_ms` | ms | Time from initialization to all animations settled |
| `peak_rss_mb` | MB | Resident set size after startup |

### Scroll — `scroll_home_list`

| Metric | Unit | Description |
|--------|------|-------------|
| `average_fps` | fps | Mean frames per second during fling scrolls |
| `average_frame_build_ms` | ms | Mean frame build duration |
| `worst_frame_build_ms` | ms | Longest single frame build |
| `p99_frame_build_ms` | ms | 99th percentile frame build duration |
| `frame_count` | frames | Total frames measured |
| `missed_frames_16ms` | frames | Frames exceeding 16.67ms budget (60fps target) |
| `peak_rss_mb` | MB | RSS after scroll activity |

### Memory — `memory_navigation`

| Metric | Unit | Description |
|--------|------|-------------|
| `peak_rss_mb` | MB | Highest RSS observed across all checkpoints |
| `rss_after_startup_mb` | MB | RSS after initial render |
| `rss_after_scroll_down_mb` | MB | RSS after scrolling down |
| `rss_after_scroll_up_mb` | MB | RSS after scrolling back up |
| `rss_after_rapid_scroll_mb` | MB | RSS after repeated rapid scrolls |
| `rss_after_idle_2s_mb` | MB | RSS after 2s idle period |

## Benchmark Environment

- **Mode:** Profile (`--profile`) via `flutter drive` — realistic timings without debug overhead
- **Platform:** Linux desktop (headless CI runner, requires `linux/` scaffold)
- **Data:** Synthetic providers (20 channels, 10 DMs, 15 tasks, 50-100 inbox items)
- **Real frame scheduling:** `flutter drive -d linux` executes in a real Dart VM with actual frame callbacks

## CI Integration

Benchmarks run as a non-blocking step in the `verify` job of `flutter-ci.yml`:
- Uses `flutter drive` with `test_driver/integration_test.dart` shim + `-d linux --profile`
- Continues on error (does not fail the build)
- Results uploaded as `benchmark-results` artifact (30-day retention)
- Future: regression gates once stable baselines are established from 3-5 runs

## Architecture

```
integration_test/
  benchmarks/
    benchmark_app.dart          # Minimal app shell with fake providers
    benchmark_reporter.dart     # JSON output to build/benchmark_results/
    startup_benchmark_test.dart # Cold start measurement (first frame)
    scroll_benchmark_test.dart  # List scroll FPS via FrameTiming
    memory_benchmark_test.dart  # RSS tracking across navigation flows
test_driver/
  integration_test.dart         # Standard driver shim for flutter drive
linux/                          # Linux desktop scaffold (CMake)
```

Key design decisions:
- Uses `integration_test` package with `flutter drive` invocation (not legacy `flutter_driver`)
- Profile mode via `--profile` flag for realistic timings
- `IntegrationTestWidgetsFlutterBinding.traceAction()` for timeline capture
- `SchedulerBinding.addTimingsCallback` for real frame timings during scroll
- `ProcessInfo.currentRss` for memory snapshots
- All providers overridden with deterministic fakes — no network dependency
- Each benchmark includes falsifiable assertions (`expect(metric, greaterThan(0))`)
