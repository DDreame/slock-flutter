import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the current time as a stream that refreshes every minute.
/// Consumers rebuild automatically so timestamps / duration chips stay fresh.
///
/// The stream emits immediately (no loading state) then every 60 seconds.
/// Uses non-autoDispose so the timer lifecycle is synchronous with
/// [ProviderScope] disposal — ensures the timer is cancelled during widget
/// tree teardown (before the test framework checks for pending timers).
///
/// Cost of non-autoDispose: one lightweight 60s timer persists when the user
/// navigates away from time-displaying screens. Negligible for a
/// `DateTime.now()` return value.
///
/// Override in tests with `homeNowProvider.overrideWith((ref) => stream)`.
final homeNowProvider = StreamProvider<DateTime>((ref) {
  final controller = StreamController<DateTime>();

  // Emit immediately so consumers never see AsyncLoading.
  controller.add(DateTime.now());

  final timer = Timer.periodic(
    const Duration(minutes: 1),
    (_) {
      if (!controller.isClosed) {
        controller.add(DateTime.now());
      }
    },
  );

  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });

  return controller.stream;
});
