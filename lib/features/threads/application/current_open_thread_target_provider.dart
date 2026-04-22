import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';

final currentOpenThreadTargetProvider =
    StateProvider<ThreadRouteTarget?>((ref) => null);

final currentOpenThreadRegistrationProvider =
    Provider.autoDispose.family<void, ThreadRouteTarget>((ref, target) {
  var disposed = false;
  final openTargetNotifier = ref.read(currentOpenThreadTargetProvider.notifier);

  Future.microtask(() {
    if (disposed || !openTargetNotifier.mounted) {
      return;
    }
    openTargetNotifier.state = target;
  });

  ref.onDispose(() {
    disposed = true;
    if (!openTargetNotifier.mounted) {
      return;
    }
    if (openTargetNotifier.state == target) {
      openTargetNotifier.state = null;
    }
  });
});
