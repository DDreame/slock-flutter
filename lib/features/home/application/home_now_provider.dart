import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the current time as a stream that refreshes every minute.
/// Consumers rebuild automatically so timestamps / duration chips stay fresh.
///
/// The stream emits immediately (no loading state) then every 60 seconds.
/// Uses an explicit Timer + StreamController so that [ref.onDispose] can
/// cancel the timer deterministically — avoids "Timer is still pending"
/// assertions in Flutter widget tests.
///
/// Override in tests with `homeNowProvider.overrideWith((ref) => stream)`.
final homeNowProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final controller = StreamController<DateTime>();

  // Emit immediately so consumers never see AsyncLoading.
  controller.add(DateTime.now());

  final timer = Timer.periodic(
    const Duration(minutes: 1),
    (_) => controller.add(DateTime.now()),
  );

  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });

  return controller.stream;
});
