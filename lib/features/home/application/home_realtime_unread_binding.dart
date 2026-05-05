import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/threads/application/current_open_thread_target_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_identity_parser.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/threads/application/known_thread_channel_ids_provider.dart';
import 'package:slock_app/stores/channel_unread/channel_unread_store.dart';
import 'package:slock_app/stores/session/session_store.dart';

const realtimeMessageCreatedEventType = 'message:new';
const realtimeMessageUpdatedEventType = 'message:updated';
const _attachmentFallbackPreview = '[Attachment]';

/// Maximum number of events queued before Home reaches success
/// state. Prevents unbounded memory growth.
const _pendingEventQueueLimit = 100;

final homeRealtimeUnreadBindingProvider = Provider<void>((ref) {
  final ingress = ref.watch(realtimeReductionIngressProvider);

  /// Bounded queue for events received before HomeListStore is
  /// in success state. Drained once load() completes.
  final pendingQueue = Queue<RealtimeEventEnvelope>();

  final subscription = ingress.acceptedEvents.listen((event) {
    if (event.eventType == realtimeMessageCreatedEventType) {
      _handleMessageNew(ref, event, pendingQueue: pendingQueue);
    } else if (event.eventType == realtimeMessageUpdatedEventType) {
      _handleMessageUpdated(ref, event);
    }
  });

  // Listen for HomeListStore status transitions to drain
  // pending events on success.
  ref.listen<HomeListStatus>(
    homeListStoreProvider.select((s) => s.status),
    (previous, next) {
      if (next == HomeListStatus.success && pendingQueue.isNotEmpty) {
        _drainPendingQueue(ref, pendingQueue);
      }
    },
  );

  ref.onDispose(() {
    unawaited(subscription.cancel());
  });
});

/// Drains queued events that arrived before Home success state.
void _drainPendingQueue(
  Ref ref,
  Queue<RealtimeEventEnvelope> queue,
) {
  while (queue.isNotEmpty) {
    final event = queue.removeFirst();
    if (event.eventType == realtimeMessageCreatedEventType) {
      _handleMessageNew(ref, event);
    }
  }
}

void _handleMessageNew(
  Ref ref,
  RealtimeEventEnvelope event, {
  Queue<RealtimeEventEnvelope>? pendingQueue,
}) {
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
    // Queue the event for replay once home reaches success.
    if (pendingQueue != null && pendingQueue.length < _pendingEventQueueLimit) {
      pendingQueue.add(event);
    }
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
    final knownThreadIds = ref.read(knownThreadChannelIdsProvider);
    final qualifiedId = threadChannelKey(
      homeState.serverScopeId!.value,
      incoming.conversationId,
    );
    if (knownThreadIds.contains(qualifiedId)) {
      // Determine if the thread is currently open via thread target provider.
      final openThread = ref.read(currentOpenThreadTargetProvider);
      final isThreadOpen = openThread != null &&
          openThread.serverId == homeState.serverScopeId!.value &&
          openThread.threadChannelId == incoming.conversationId;

      // Update thread inbox item with new message metadata.
      final senderName = _extractSenderName(event.payload);
      final updated = notifier.updateThreadInboxItem(
        threadChannelId: incoming.conversationId,
        preview: preview,
        senderName: senderName,
        lastReplyAt: incoming.message.createdAt,
        incrementUnread: !isSelfMessage && !isThreadOpen,
      );
      if (!updated) {
        // Thread row not loaded yet — schedule a full reload to pick it up.
        notifier.load();
      }
      return;
    }
    if (isSelfMessage || isOpen) {
      return;
    }
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

/// Extracts sender name from the raw event payload.
String? _extractSenderName(Object? payload) {
  if (payload is Map<String, dynamic>) {
    return payload['senderName'] as String?;
  }
  if (payload is Map) {
    return payload['senderName'] as String?;
  }
  return null;
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
