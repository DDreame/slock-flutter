import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the current time as a stream that refreshes every minute.
/// Consumers rebuild automatically so timestamps / duration chips stay fresh.
///
/// The stream emits immediately (no loading state) then every 60 seconds.
/// Override in tests with `homeNowProvider.overrideWith((ref) => stream)`.
final homeNowProvider = StreamProvider<DateTime>((ref) {
  late final StreamController<DateTime> controller;
  Timer? timer;

  controller = StreamController<DateTime>(
    onListen: () {
      // Emit immediately so consumers never see AsyncLoading.
      controller.add(DateTime.now());
      // Then refresh every minute.
      timer = Timer.periodic(const Duration(minutes: 1), (_) {
        controller.add(DateTime.now());
      });
    },
    onCancel: () {
      timer?.cancel();
      controller.close();
    },
  );

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});
