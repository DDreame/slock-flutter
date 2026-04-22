import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/notifications/notification_target.dart';
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/threads/application/current_open_thread_target_provider.dart';
import 'package:slock_app/features/threads/application/thread_route.dart';
import 'package:slock_app/stores/notification/notification_store.dart';

VisibleTarget? conversationTargetToVisibleTarget(
  ConversationDetailTarget? target,
) {
  if (target == null) return null;
  final surface = switch (target.surface) {
    ConversationSurface.channel => NotificationSurface.channel,
    ConversationSurface.directMessage => NotificationSurface.dm,
  };
  return VisibleTarget(
    serverId: target.serverId.value,
    surface: surface,
    channelId: target.conversationId,
  );
}

VisibleTarget? threadTargetToVisibleTarget(ThreadRouteTarget? target) {
  if (target == null) return null;
  return VisibleTarget(
    serverId: target.serverId,
    surface: NotificationSurface.thread,
    channelId: target.parentChannelId,
    threadId: target.parentMessageId,
  );
}

void _syncVisibleTarget(Ref ref) {
  final threadTarget = ref.read(currentOpenThreadTargetProvider);
  final visibleTarget = threadTargetToVisibleTarget(threadTarget) ??
      conversationTargetToVisibleTarget(
        ref.read(currentOpenConversationTargetProvider),
      );
  ref.read(notificationStoreProvider.notifier).setVisibleTarget(visibleTarget);
}

final notificationVisibleTargetBindingProvider = Provider<void>((ref) {
  ref.listen<ConversationDetailTarget?>(
    currentOpenConversationTargetProvider,
    (_, __) => _syncVisibleTarget(ref),
  );
  ref.listen<ThreadRouteTarget?>(
    currentOpenThreadTargetProvider,
    (_, __) => _syncVisibleTarget(ref),
  );
});
