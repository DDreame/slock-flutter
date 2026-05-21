import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the current time as a stream that refreshes every minute.
/// Consumers rebuild automatically so timestamps / duration chips stay fresh.
///
/// The stream emits immediately (no loading state) then every 60 seconds.
/// Override in tests with `homeNowProvider.overrideWith((ref) => stream)`.
final homeNowProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  // Emit immediately so consumers never see AsyncLoading after the first
  // microtask, then refresh every minute. autoDispose cancels the stream
  // subscription (and the periodic timer) when no widgets are watching.
  yield DateTime.now();
  yield* Stream.periodic(
    const Duration(minutes: 1),
    (_) => DateTime.now(),
  );
});
