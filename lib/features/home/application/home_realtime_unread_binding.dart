import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_identity_parser.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';
import 'package:slock_app/stores/session/session_store.dart';

const realtimeMessageCreatedEventType = 'message:new';
const realtimeMessageUpdatedEventType = 'message:updated';
const _attachmentFallbackPreview = '[Attachment]';

final homeRealtimeUnreadBindingProvider = Provider<void>((ref) {
  final ingress = ref.watch(realtimeReductionIngressProvider);
  final subscription = ingress.acceptedEvents.listen((event) {
    if (event.eventType == realtimeMessageCreatedEventType) {
      _handleMessageNew(ref, event);
    } else if (event.eventType == realtimeMessageUpdatedEventType) {
      _handleMessageUpdated(ref, event);
    }
  });

  ref.onDispose(() {
    unawaited(subscription.cancel());
  });
});

void _handleMessageNew(Ref ref, RealtimeEventEnvelope event) {
  final incoming = tryParseConversationIncomingMessage(
    event.payload,
    payloadName: 'message:new',
  );
  if (incoming == null) {
    return;
  }

  final homeState = ref.read(homeListStoreProvider);
  if (homeState.status != HomeListStatus.success ||
      homeState.serverScopeId == null) {
    return;
  }

  final currentUserId = ref.read(sessionStoreProvider).userId;
  final isSelfMessage =
      currentUserId != null && incoming.senderId == currentUserId;

  final openTarget = ref.read(currentOpenConversationTargetProvider);
  final isOpen = openTarget != null &&
      openTarget.serverId == homeState.serverScopeId &&
      openTarget.conversationId == incoming.conversationId;

  final matchedChannel =
      _matchChannelScopeId(homeState, incoming.conversationId);
  final matchedDirectMessage =
      _matchDirectMessageScopeId(homeState, incoming.conversationId);

  final preview = incoming.message.content.isNotEmpty
      ? incoming.message.content
      : (incoming.message.attachments?.isNotEmpty == true)
          ? _attachmentFallbackPreview
          : incoming.message.content;

  final notifier = ref.read(homeListStoreProvider.notifier);

  if (matchedChannel != null && matchedDirectMessage == null) {
    unawaited(ref.read(homeRepositoryProvider).persistConversationActivity(
          serverId: homeState.serverScopeId!,
          conversationId: incoming.conversationId,
          messageId: incoming.message.id,
          preview: preview,
          activityAt: incoming.message.createdAt,
        ));
    notifier.updateChannelLastMessage(
      conversationId: incoming.conversationId,
      messageId: incoming.message.id,
      preview: preview,
      activityAt: incoming.message.createdAt,
    );
    if (!isSelfMessage && !isOpen) {
      ref
          .read(channelUnreadStoreProvider.notifier)
          .incrementChannelUnread(matchedChannel);
    }
    return;
  }
  if (matchedDirectMessage != null && matchedChannel == null) {
    unawaited(ref.read(homeRepositoryProvider).persistConversationActivity(
          serverId: homeState.serverScopeId!,
          conversationId: incoming.conversationId,
          messageId: incoming.message.id,
          preview: preview,
          activityAt: incoming.message.createdAt,
        ));
    notifier.updateDmLastMessage(
      conversationId: incoming.conversationId,
      messageId: incoming.message.id,
      preview: preview,
      activityAt: incoming.message.createdAt,
    );
    if (!isSelfMessage && !isOpen) {
      ref
          .read(channelUnreadStoreProvider.notifier)
          .incrementDmUnread(matchedDirectMessage);
    }
    return;
  }

  if (matchedChannel == null && matchedDirectMessage == null) {
    if (isSelfMessage || isOpen) return;
    final newScopeId = DirectMessageScopeId(
      serverId: homeState.serverScopeId!,
      value: incoming.conversationId,
    );
    final title =
        resolveDirectMessageTitle(event.payload) ?? incoming.conversationId;
    unawaited(() async {
      try {
        final summary =
            await ref.read(homeRepositoryProvider).persistDirectMessageSummary(
                  HomeDirectMessageSummary(
                    scopeId: newScopeId,
                    title: title,
                    lastMessageId: incoming.message.id,
                    lastMessagePreview: preview,
                    lastActivityAt: incoming.message.createdAt,
                  ),
                );
        notifier.addDirectMessage(summary);
        ref
            .read(channelUnreadStoreProvider.notifier)
            .incrementDmUnread(newScopeId);
      } catch (e, st) {
        ref.read(crashReporterProvider).captureException(e, stackTrace: st);
      }
    }());
  }
}

void _handleMessageUpdated(Ref ref, RealtimeEventEnvelope event) {
  final updated = tryParseMessageUpdatedPayload(event.payload);
  if (updated == null) {
    return;
  }

  final homeState = ref.read(homeListStoreProvider);
  if (homeState.status != HomeListStatus.success) {
    return;
  }

  final notifier = ref.read(homeListStoreProvider.notifier);

  unawaited(ref.read(homeRepositoryProvider).persistConversationPreviewUpdate(
        serverId: homeState.serverScopeId!,
        conversationId: updated.channelId,
        messageId: updated.id,
        preview: updated.content,
      ));

  notifier.updateChannelPreview(
    conversationId: updated.channelId,
    messageId: updated.id,
    preview: updated.content,
  );
  notifier.updateDmPreview(
    conversationId: updated.channelId,
    messageId: updated.id,
    preview: updated.content,
  );
}

ChannelScopeId? _matchChannelScopeId(
    HomeListState state, String conversationId) {
  for (final channel in state.pinnedChannels) {
    if (channel.scopeId.value == conversationId) {
      return channel.scopeId;
    }
  }
  for (final channel in state.channels) {
    if (channel.scopeId.value == conversationId) {
      return channel.scopeId;
    }
  }
  return null;
}

DirectMessageScopeId? _matchDirectMessageScopeId(
  HomeListState state,
  String conversationId,
) {
  for (final directMessage in state.pinnedDirectMessages) {
    if (directMessage.scopeId.value == conversationId) {
      return directMessage.scopeId;
    }
  }
  for (final directMessage in state.directMessages) {
    if (directMessage.scopeId.value == conversationId) {
      return directMessage.scopeId;
    }
  }
  for (final directMessage in state.hiddenDirectMessages) {
    if (directMessage.scopeId.value == conversationId) {
      return directMessage.scopeId;
    }
  }
  return null;
}
