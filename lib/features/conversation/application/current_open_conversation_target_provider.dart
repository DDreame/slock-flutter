import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';

final currentOpenConversationTargetProvider =
    StateProvider<ConversationDetailTarget?>((ref) => null);

final currentOpenConversationRegistrationProvider =
    Provider.autoDispose.family<void, ConversationDetailTarget>((ref, target) {
  var disposed = false;
  final realtimeSocketClient = ref.read(realtimeSocketClientProvider);
  final openTargetNotifier = ref.read(
    currentOpenConversationTargetProvider.notifier,
  );

  Future.microtask(() {
    if (disposed || !openTargetNotifier.mounted) {
      return;
    }
    openTargetNotifier.state = target;
  });

  ref.onDispose(() {
    disposed = true;
    realtimeSocketClient.emit('leave:channel', target.conversationId);
    if (!openTargetNotifier.mounted) {
      return;
    }
    if (openTargetNotifier.state == target) {
      openTargetNotifier.state = null;
    }
  });
});
