import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/notifications/notification_target.dart';
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
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

final notificationVisibleTargetBindingProvider = Provider<void>((ref) {
  ref.listen<ConversationDetailTarget?>(
    currentOpenConversationTargetProvider,
    (previous, next) {
      ref
          .read(notificationStoreProvider.notifier)
          .setVisibleTarget(conversationTargetToVisibleTarget(next));
    },
  );
});
