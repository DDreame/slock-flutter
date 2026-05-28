# Performance Baseline

Repeatable performance benchmarks for slock-flutter. These measure app startup,
scroll rendering, and memory usage under synthetic load.

## Running Benchmarks

```bash
# All benchmarks (CI target)
make ci-benchmark

# Individual benchmarks
flutter test integration_test/benchmarks/startup_benchmark_test.dart -d linux --profile
flutter test integration_test/benchmarks/scroll_benchmark_test.dart -d linux --profile
flutter test integration_test/benchmarks/memory_benchmark_test.dart -d linux --profile
```

Results are written to `build/benchmark_results/` as JSON.

## Metrics

### Startup — `startup_cold`

| Metric | Unit | Description |
|--------|------|-------------|
| `time_to_settle_ms` | ms | Time from widget tree initialization to first frame settled |
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

- **Mode:** Profile (`--profile`) — realistic timings without debug overhead
- **Platform:** Headless Linux desktop (CI runner)
- **Data:** Synthetic providers (20 channels, 10 DMs, 15 tasks, 50-100 inbox items)
- **No GPU raster:** Frame build time only; rasterization is device-dependent

## CI Integration

Benchmarks run as a non-blocking step in the `verify` job of `flutter-ci.yml`:
- Continues on error (does not fail the build)
- Results uploaded as `benchmark-results` artifact (30-day retention)
- Future: regression gates once stable baselines are established from 3-5 runs

## Architecture

```
integration_test/
  benchmarks/
    benchmark_app.dart          # Minimal app shell with fake providers
    benchmark_reporter.dart     # JSON output to build/benchmark_results/
    startup_benchmark_test.dart # Cold start measurement
    scroll_benchmark_test.dart  # List scroll FPS via FrameTiming
    memory_benchmark_test.dart  # RSS tracking across navigation flows
```

Key design decisions:
- Uses `integration_test` package (not legacy `flutter_driver`)
- `IntegrationTestWidgetsFlutterBinding.traceAction()` for timeline capture
- `SchedulerBinding.addTimingsCallback` for real frame timings during scroll
- `ProcessInfo.currentRss` for memory snapshots
- All providers overridden with deterministic fakes — no network dependency
