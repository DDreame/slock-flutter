import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the current time as a stream that refreshes every minute.
/// Consumers rebuild automatically so timestamps / duration chips stay fresh.
///
/// The stream emits immediately (no loading state) then every 60 seconds.
/// Uses an explicit Timer + StreamController with [onCancel] to tear down the
/// timer when the last subscriber (i.e. the widget) unsubscribes. This
/// ensures the timer is cancelled at widget disposal time — before the test
/// framework checks for pending timers.
///
/// Override in tests with `homeNowProvider.overrideWith((ref) => stream)`.
final homeNowProvider = StreamProvider.autoDispose<DateTime>((ref) {
  late final Timer timer;

  final controller = StreamController<DateTime>(
    onCancel: () {
      timer.cancel();
    },
  );

  // Emit immediately so consumers never see AsyncLoading.
  controller.add(DateTime.now());

  timer = Timer.periodic(
    const Duration(minutes: 1),
    (_) {
      if (!controller.isClosed) {
        controller.add(DateTime.now());
      }
    },
  );

  ref.onDispose(() {
    timer.cancel();
    if (!controller.isClosed) {
      controller.close();
    }
  });

  return controller.stream;
});
