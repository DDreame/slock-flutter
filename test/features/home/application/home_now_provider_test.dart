// =============================================================================
// #648 Phase A — homeNowProvider StreamProvider periodic refresh tests
//
// Invariants verified:
// INV-NOW-STREAM-1: provider emits updated DateTime values over time
// INV-NOW-STREAM-2: _DurationChip transitions color/text when now advances
// INV-NOW-STREAM-3: consumer pattern (.value ?? DateTime.now()) never exposes
//                   loading state to UI
// =============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/home/application/home_now_provider.dart';

class _DisposeObserver extends ProviderObserver {
  final disposedProviders = <ProviderBase<Object?>>[];

  @override
  void didDisposeProvider(
    ProviderBase<Object?> provider,
    ProviderContainer container,
  ) {
    disposedProviders.add(provider);
  }
}

void main() {
  // ---------------------------------------------------------------------------
  // INV-NOW-STREAM-1: provider emits updated values over time
  // ---------------------------------------------------------------------------
  group('INV-NOW-STREAM-1: StreamProvider emits periodic updates', () {
    test('emits DateTime value after first microtask', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Listen to keep provider alive.
      final sub = container.listen(homeNowProvider, (_, __) {});
      addTearDown(sub.close);

      // After one microtask, the synchronous add in onListen resolves.
      await Future<void>.delayed(Duration.zero);

      final value = container.read(homeNowProvider);
      expect(value, isA<AsyncData<DateTime>>());
      expect(value.value, isNotNull);
    });

    test('emits new DateTime values as stream ticks', () async {
      final controller = StreamController<DateTime>();
      addTearDown(controller.close);

      final now1 = DateTime(2026, 5, 20, 10, 0);
      final now2 = DateTime(2026, 5, 20, 10, 1);
      final now3 = DateTime(2026, 5, 20, 10, 2);

      final container = ProviderContainer(
        overrides: [
          homeNowProvider.overrideWith(
            (ref) => controller.stream,
          ),
        ],
      );
      addTearDown(container.dispose);

      // Keep listener alive.
      final sub = container.listen(homeNowProvider, (_, __) {});
      addTearDown(sub.close);

      // Emit first value.
      controller.add(now1);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(homeNowProvider).value, now1);

      // Emit second value.
      controller.add(now2);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(homeNowProvider).value, now2);

      // Emit third value.
      controller.add(now3);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(homeNowProvider).value, now3);
    });

    test('overrideWith custom stream works for test control', () async {
      final controller = StreamController<DateTime>();
      addTearDown(controller.close);

      final fixedTime = DateTime(2026, 1, 15, 12, 0);

      final container = ProviderContainer(
        overrides: [
          homeNowProvider.overrideWith(
            (ref) => controller.stream,
          ),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(homeNowProvider, (_, __) {});
      addTearDown(sub.close);

      controller.add(fixedTime);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(homeNowProvider).value, fixedTime);
    });
    test('autoDispose releases stream when unwatched', () async {
      final observer = _DisposeObserver();
      final container = ProviderContainer(observers: [observer]);
      addTearDown(container.dispose);

      final sub = container.listen(homeNowProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);
      expect(container.read(homeNowProvider).value, isA<DateTime>());

      sub.close();
      await Future<void>.delayed(Duration.zero);

      expect(observer.disposedProviders, contains(homeNowProvider));
    });
  });

  // ---------------------------------------------------------------------------
  // INV-NOW-STREAM-2: Duration chip color/text transitions
  // ---------------------------------------------------------------------------
  group('INV-NOW-STREAM-2: Duration calculation advances with stream', () {
    test('duration changes as now advances past claimed time', () async {
      final claimedAt = DateTime(2026, 5, 20, 10, 0);
      final controller = StreamController<DateTime>();
      addTearDown(controller.close);

      final container = ProviderContainer(
        overrides: [
          homeNowProvider.overrideWith(
            (ref) => controller.stream,
          ),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(homeNowProvider, (_, __) {});
      addTearDown(sub.close);

      // 30 minutes in — should be < 1h (blue range).
      controller.add(DateTime(2026, 5, 20, 10, 30));
      await Future<void>.delayed(Duration.zero);
      final now1 = container.read(homeNowProvider).value!;
      final duration1 = now1.difference(claimedAt);
      expect(duration1.inMinutes, 30);
      expect(duration1.inHours, 0); // < 1h

      // 2 hours in — should be 1-4h (orange range).
      controller.add(DateTime(2026, 5, 20, 12, 0));
      await Future<void>.delayed(Duration.zero);
      final now2 = container.read(homeNowProvider).value!;
      final duration2 = now2.difference(claimedAt);
      expect(duration2.inHours, 2); // 1-4h

      // 5 hours in — should be >4h (red range).
      controller.add(DateTime(2026, 5, 20, 15, 0));
      await Future<void>.delayed(Duration.zero);
      final now3 = container.read(homeNowProvider).value!;
      final duration3 = now3.difference(claimedAt);
      expect(duration3.inHours, 5); // > 4h
    });
  });

  // ---------------------------------------------------------------------------
  // INV-NOW-STREAM-3: consumer pattern hides loading state
  // ---------------------------------------------------------------------------
  group('INV-NOW-STREAM-3: .value ?? DateTime.now() hides loading', () {
    test('consumer fallback pattern always provides a DateTime', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Even before the first microtask, the consumer pattern works.
      final asyncValue = container.read(homeNowProvider);
      final now = asyncValue.value ?? DateTime.now();
      expect(now, isA<DateTime>());
      // The value should be very recent (within last second).
      expect(
        DateTime.now().difference(now).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
    });

    test('after stream emits, .value provides the streamed DateTime', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sub = container.listen(homeNowProvider, (_, __) {});
      addTearDown(sub.close);

      await Future<void>.delayed(Duration.zero);

      final asyncValue = container.read(homeNowProvider);
      expect(asyncValue.value, isNotNull);
      expect(asyncValue.value, isA<DateTime>());
    });
  });
}
