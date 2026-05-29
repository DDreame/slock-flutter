import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/core/realtime/scope_patterns.dart';
import 'package:slock_app/features/agents/application/agents_store.dart';
import 'package:slock_app/features/announcements/application/announcement_store.dart';
import 'package:slock_app/features/announcements/data/announcement.dart';
import 'package:slock_app/features/conversation/application/current_open_conversation_target_provider.dart';
import 'package:slock_app/features/conversation/data/conversation_identity_parser.dart';
import 'package:slock_app/features/conversation/data/conversation_message_parser.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/home/data/home_repository.dart';
import 'package:slock_app/features/home/data/home_repository_provider.dart';
import 'package:slock_app/features/inbox/application/inbox_state.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/application/message_preview_resolver.dart';
import 'package:slock_app/l10n/app_localizations_provider.dart';
import 'package:slock_app/features/servers/application/server_list_state.dart';
import 'package:slock_app/features/servers/application/server_list_store.dart';
import 'package:slock_app/features/tasks/data/task_item.dart';
import 'package:slock_app/features/threads/application/current_open_thread_target_provider.dart';
import 'package:slock_app/features/threads/application/known_thread_channel_ids_provider.dart';
import 'package:slock_app/stores/notification/notification_store.dart';
import 'package:slock_app/stores/server_selection/server_selection_store.dart';
import 'package:slock_app/stores/session/session_store.dart';

// ---------------------------------------------------------------------------
// Event type constants
// ---------------------------------------------------------------------------

const _messageNewEvent = 'message:new';
const _messageUpdatedEvent = 'message:updated';
const _dmNewEvent = 'dm:new';
const _connectEvent = 'connect';
const _channelUpdatedEvent = 'channel:updated';
const _channelMembersUpdatedEvent = 'channel:members-updated';
const _serverMembershipRemovedEvent = 'server:membership-removed';
const _taskCreatedEvent = 'task:created';
const _taskUpdatedEvent = 'task:updated';
const _taskDeletedEvent = 'task:deleted';
const _messageDeletedEvent = 'message:deleted';
const _channelCreatedEvent = 'channel:created';
const _channelDeletedEvent = 'channel:deleted';
const _channelArchivedEvent = 'channel:archived';
const _channelUnarchivedEvent = 'channel:unarchived';
const _agentActivityEvent = 'agent:activity';
const _agentCreatedEvent = 'agent:created';
const _agentDeletedEvent = 'agent:deleted';
const _announcementNewEvent = 'announcement:new';
const _announcementUpdatedEvent = 'announcement:updated';
const _announcementDeletedEvent = 'announcement:deleted';

/// INV-856: Synthetic event emitted after a sync:resume:response batch
/// completes with hasMore=false. Triggers a single coalesced inbox/home
/// refresh instead of per-message debounce resets.
const syncBatchCompleteEvent = 'sync:batch:complete';

/// Maximum number of message events queued before Home reaches success
/// state. Prevents unbounded memory growth.
const _pendingEventQueueLimit = 100;

/// Minimum debounce interval between inbox refreshes triggered
/// by realtime events (milliseconds).
const _inboxRefreshDebounceMs = 2000;

// ---------------------------------------------------------------------------
// Page-scoped relay providers
// ---------------------------------------------------------------------------

/// Signal emitted when a [channel:updated] event is received.
/// Page-level listeners compare [serverId]/[channelId] against their
/// open target and refresh the conversation detail store if matched.
final routedChannelDetailSignalProvider =
    StateProvider<ChannelRouterSignal?>((ref) => null);

/// Signal emitted when a [channel:members-updated] event is received.
/// The channel members page listens and reloads its scoped store.
final routedChannelMembersSignalProvider =
    StateProvider<ChannelRouterSignal?>((ref) => null);

/// Typed task event emitted by the router after payload parsing.
/// The tasks page listens and applies upsert/remove to its scoped store.
final routedTaskEventProvider = StateProvider<TaskRouterEvent?>((ref) => null);

/// Lightweight signal carrying parsed server/channel IDs from a
/// channel-scoped realtime event.
class ChannelRouterSignal {
  const ChannelRouterSignal({this.serverId, this.channelId});

  /// Server ID extracted from event payload or scope key. Null means
  /// the event applies to any server.
  final String? serverId;

  /// Channel ID extracted from event payload or scope key. Null means
  /// the event applies to any channel.
  final String? channelId;
}

/// Pre-parsed task event emitted by the router.
sealed class TaskRouterEvent {
  const TaskRouterEvent();
}

/// One or more tasks were created.
class TasksCreatedRouterEvent extends TaskRouterEvent {
  const TasksCreatedRouterEvent(this.tasks);
  final List<TaskItem> tasks;
}

/// A single task was updated.
class TaskUpdatedRouterEvent extends TaskRouterEvent {
  const TaskUpdatedRouterEvent(this.task);
  final TaskItem task;
}

/// A task was deleted.
class TaskDeletedRouterEvent extends TaskRouterEvent {
  const TaskDeletedRouterEvent(this.taskId);
  final String taskId;
}

// ---------------------------------------------------------------------------
// Router provider
// ---------------------------------------------------------------------------

/// Root-mounted, non-autoDispose provider that routes **all** domain
/// realtime events to the appropriate stores and relay providers.
///
/// This is the single subscription point for [RealtimeReductionIngress].
/// It replaces:
/// - `homeRealtimeUnreadBindingProvider` (message:new/updated/deleted)
/// - `homeRealtimeDmMaterializationBindingProvider` (dm:new)
/// - `inboxRealtimeRefreshBindingProvider` (inbox debounce + lifecycle)
/// - `homeAdminRealtimeBindingProvider` (channel:updated/created/deleted,
///    server:membership-removed)
/// - `homeTasksRealtimeBindingProvider` (task events → home refresh)
/// - `agentsRealtimeBindingProvider` (agent lifecycle)
/// - `channelPageRealtimeBindingProvider` (channel detail refresh relay)
/// - `channelMembersRealtimeBindingProvider` (channel members refresh relay)
/// - `tasksRealtimeBindingProvider` (task detail upsert relay)
final domainRuntimeEventRouterProvider = Provider<void>(
  (ref) {
    final activeServerId = ref.watch(activeServerScopeIdProvider);
    final ingress = ref.watch(realtimeReductionIngressProvider);

    // -----------------------------------------------------------------------
    // Mutable state for message pending queue
    // -----------------------------------------------------------------------
    final pendingMessageQueue = Queue<RealtimeEventEnvelope>();
    var catchUpLoadScheduled = false;

    // -----------------------------------------------------------------------
    // Mutable state for DM materialization buffer
    // -----------------------------------------------------------------------
    final pendingDmBuffer = <_BufferedDmEvent>[];

    // -----------------------------------------------------------------------
    // Mutable state for inbox refresh debounce
    // -----------------------------------------------------------------------
    Timer? inboxDebounceTimer;
    bool syncBatchRefreshPending = false;

    // -----------------------------------------------------------------------
    // Inbox refresh helpers (local to this provider)
    // -----------------------------------------------------------------------
    void scheduleInboxRefresh(String reason, {bool isBatchEvent = false}) {
      // INV-856: During sync batch, defer refresh. A single coalesced
      // refresh fires when syncBatchCompleteEvent arrives.
      if (isBatchEvent) {
        syncBatchRefreshPending = true;
        return;
      }
      // If exiting a batch and a refresh was deferred, fire it now.
      if (syncBatchRefreshPending) {
        syncBatchRefreshPending = false;
      }
      final inboxState = ref.read(inboxStoreProvider);
      if (inboxState.status != InboxStatus.success) return;

      inboxDebounceTimer?.cancel();
      inboxDebounceTimer = Timer(
        const Duration(milliseconds: _inboxRefreshDebounceMs),
        () {
          ref.read(inboxStoreProvider.notifier).refresh(reason: reason);
        },
      );
    }

    void immediateInboxRefresh(String reason) {
      final inboxState = ref.read(inboxStoreProvider);
      if (inboxState.status != InboxStatus.success) return;

      inboxDebounceTimer?.cancel();
      ref.read(inboxStoreProvider.notifier).refresh(reason: reason);
    }

    // -----------------------------------------------------------------------
    // Single ingress subscription
    // -----------------------------------------------------------------------
    final subscription = ingress.acceptedEvents.listen((event) {
      switch (event.eventType) {
        // — Message domain —
        case _messageNewEvent:
          _handleMessageNew(
            ref,
            event,
            pendingQueue: pendingMessageQueue,
            onMissingThreadRow: () {
              if (!catchUpLoadScheduled) {
                catchUpLoadScheduled = true;
                unawaited(
                  ref
                      .read(homeListStoreProvider.notifier)
                      .refresh(reason: 'messageNew')
                      .catchError((_) {}),
                );
              }
            },
          );
          scheduleInboxRefresh('messageNew',
              isBatchEvent: event.isSyncBatchEvent);

        case _messageUpdatedEvent:
          _handleMessageUpdated(ref, event);

        case _messageDeletedEvent:
          _handleMessageDeleted(ref, event);

        // — DM domain —
        case _dmNewEvent:
          _handleDmNew(ref, event, pendingDmBuffer);
          scheduleInboxRefresh('dmNew', isBatchEvent: event.isSyncBatchEvent);

        // — Connect domain —
        case _connectEvent:
          immediateInboxRefresh('reconnect');

        // — Sync batch complete (INV-856) —
        case syncBatchCompleteEvent:
          syncBatchRefreshPending = false;
          immediateInboxRefresh('syncBatchComplete');
          _refreshHomeList(ref, reason: 'syncBatchComplete');

        // — Channel domain —
        case _channelUpdatedEvent:
          if (activeServerId != null && _targetsServer(activeServerId, event)) {
            _refreshHomeList(ref, reason: 'channelUpdated');
          }
          // Relay to channel detail page.
          ref.read(routedChannelDetailSignalProvider.notifier).state =
              ChannelRouterSignal(
            serverId: _extractServerId(event),
            channelId: _extractChannelId(event),
          );

        case _channelMembersUpdatedEvent:
          // Relay to channel members page.
          ref.read(routedChannelMembersSignalProvider.notifier).state =
              ChannelRouterSignal(
            serverId: _extractServerId(event),
            channelId: _extractChannelId(event),
          );

        case _channelCreatedEvent:
          if (activeServerId != null && _targetsServer(activeServerId, event)) {
            _refreshHomeList(ref, reason: 'channelCreated');
          }

        case _channelDeletedEvent:
          if (activeServerId != null && _targetsServer(activeServerId, event)) {
            _refreshHomeList(ref, reason: 'channelDeleted');
          }

        case _channelArchivedEvent:
          if (activeServerId != null && _targetsServer(activeServerId, event)) {
            _refreshHomeList(ref, reason: 'channelArchived');
          }

        case _channelUnarchivedEvent:
          if (activeServerId != null && _targetsServer(activeServerId, event)) {
            _refreshHomeList(ref, reason: 'channelUnarchived');
          }

        // — Server membership domain —
        case _serverMembershipRemovedEvent:
          if (activeServerId != null &&
              _shouldRefreshServerState(activeServerId, event)) {
            unawaited(_handleServerMembershipRemoved(ref, activeServerId));
          }

        // — Task domain —
        case _taskCreatedEvent:
          if (activeServerId != null) {
            _refreshHomeList(ref, reason: 'taskEvent');
          }
          _relayTaskCreated(ref, event);
        case _taskUpdatedEvent:
          if (activeServerId != null) {
            _refreshHomeList(ref, reason: 'taskEvent');
          }
          _relayTaskUpdated(ref, event);
        case _taskDeletedEvent:
          if (activeServerId != null) {
            _refreshHomeList(ref, reason: 'taskEvent');
          }
          _relayTaskDeleted(ref, event);

        // — Agent domain —
        case _agentActivityEvent:
          _handleAgentActivity(ref, event);
        case _agentCreatedEvent:
        case _agentDeletedEvent:
          _handleAgentCreatedOrDeleted(ref);

        // — Announcement domain —
        case _announcementNewEvent:
          _handleAnnouncementNew(ref, event);
        case _announcementUpdatedEvent:
          _handleAnnouncementUpdated(ref, event);
        case _announcementDeletedEvent:
          _handleAnnouncementDeleted(ref, event);
      }
    });

    // -----------------------------------------------------------------------
    // HomeListStore status listener — drain pending queues on success
    // -----------------------------------------------------------------------
    ref.listen<HomeListStatus>(
      homeListStoreProvider.select((s) => s.status),
      (previous, next) {
        if (next == HomeListStatus.success) {
          catchUpLoadScheduled = false;
          if (pendingMessageQueue.isNotEmpty) {
            _drainPendingMessageQueue(ref, pendingMessageQueue);
          }
        }
      },
    );

    ref.listen(
      homeListStoreProvider
          .select((s) => (status: s.status, serverScopeId: s.serverScopeId)),
      (previous, next) {
        if (next.status != HomeListStatus.success ||
            next.serverScopeId == null ||
            pendingDmBuffer.isEmpty) {
          return;
        }
        final toReplay = List<_BufferedDmEvent>.of(pendingDmBuffer);
        pendingDmBuffer.clear();
        for (final buffered in toReplay) {
          if (buffered.serverId != next.serverScopeId) continue;
          unawaited(() async {
            try {
              await _materializeDm(
                ref,
                buffered.serverId,
                buffered.channelId,
                buffered.payload,
              );
            } catch (e, st) {
              ref
                  .read(crashReporterProvider)
                  .captureException(e, stackTrace: st);
            }
          }());
        }
      },
    );

    // -----------------------------------------------------------------------
    // App lifecycle: refresh inbox on resume
    // -----------------------------------------------------------------------
    ref.listen(
      notificationStoreProvider.select((s) => s.lifecycleStatus),
      (previous, next) {
        if (next == AppLifecycleStatus.resumed &&
            previous != AppLifecycleStatus.resumed) {
          immediateInboxRefresh('appResume');
        }
      },
    );

    // -----------------------------------------------------------------------
    // Cleanup
    // -----------------------------------------------------------------------
    ref.onDispose(() {
      inboxDebounceTimer?.cancel();
      unawaited(subscription.cancel());
    });
  },
  dependencies: [
    activeServerScopeIdProvider,
    homeListStoreProvider,
    serverListStoreProvider,
    serverSelectionStoreProvider,
    agentsStoreProvider,
    announcementStoreProvider,
  ],
);

// ---------------------------------------------------------------------------
// Message domain handlers (absorbed from home_realtime_unread_binding)
// ---------------------------------------------------------------------------

void _drainPendingMessageQueue(
  Ref ref,
  Queue<RealtimeEventEnvelope> queue,
) {
  while (queue.isNotEmpty) {
    final event = queue.removeFirst();
    if (event.eventType == _messageNewEvent) {
      _handleMessageNew(ref, event);
    }
  }
}

void _handleMessageNew(
  Ref ref,
  RealtimeEventEnvelope event, {
  Queue<RealtimeEventEnvelope>? pendingQueue,
  void Function()? onMissingThreadRow,
}) {
  final incoming = tryParseConversationIncomingMessage(
    event.payload,
    payloadName: 'message:new',
  );
  if (incoming == null) return;

  final homeState = ref.read(homeListStoreProvider);
  if (homeState.status != HomeListStatus.success ||
      homeState.serverScopeId == null) {
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

  final l10n = ref.read(appLocalizationsProvider);
  final preview = MessagePreviewResolver.resolveFromMessage(
    incoming.message,
    l10n: l10n,
  );

  // BUG-3 fix (#637): If the resolver can only produce the generic fallback
  // (empty content + no attachments + not deleted/system), the WS event
  // lacks meaningful preview data. Do NOT write "New message" — skip the
  // preview update so backfill can fetch the actual content later.
  final isGenericFallback = preview == l10n.previewFallback;

  final notifier = ref.read(homeListStoreProvider.notifier);

  if (matchedChannel != null && matchedDirectMessage == null) {
    if (!isGenericFallback) {
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
    }
    if (!isSelfMessage && !isOpen) {
      // InboxStore refresh (debounced above) propagates the count
      // via unreadSourceProjectionProvider.
    }
    return;
  }
  if (matchedDirectMessage != null && matchedChannel == null) {
    if (!isGenericFallback) {
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
    }
    if (!isSelfMessage && !isOpen) {
      // InboxStore refresh (debounced above) propagates the count
      // via unreadSourceProjectionProvider.
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
      final openThread = ref.read(currentOpenThreadTargetProvider);
      final isThreadOpen = openThread != null &&
          openThread.serverId == homeState.serverScopeId!.value &&
          openThread.threadChannelId == incoming.conversationId;

      final senderName = _extractSenderName(event.payload);
      final updated = notifier.updateThreadInboxItem(
        threadChannelId: incoming.conversationId,
        preview: preview,
        senderName: senderName,
        lastReplyAt: incoming.message.createdAt,
        incrementUnread: !isSelfMessage && !isThreadOpen,
      );
      if (!updated) {
        onMissingThreadRow?.call();
      }
      return;
    }
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
      } catch (e, st) {
        ref.read(crashReporterProvider).captureException(e, stackTrace: st);
      }
    }());
  }
}

String? _extractSenderName(Object? payload) {
  if (payload is Map<String, dynamic>) return payload['senderName'] as String?;
  if (payload is Map) return payload['senderName'] as String?;
  return null;
}

void _handleMessageUpdated(Ref ref, RealtimeEventEnvelope event) {
  final updated = tryParseMessageUpdatedPayload(event.payload);
  if (updated == null) return;

  final homeState = ref.read(homeListStoreProvider);
  if (homeState.status != HomeListStatus.success) return;

  final notifier = ref.read(homeListStoreProvider.notifier);

  final preview = MessagePreviewResolver.resolve(
    l10n: ref.read(appLocalizationsProvider),
    content: updated.content,
  );

  unawaited(ref.read(homeRepositoryProvider).persistConversationPreviewUpdate(
        serverId: homeState.serverScopeId!,
        conversationId: updated.channelId,
        messageId: updated.id,
        preview: preview,
      ));

  notifier.updateChannelPreview(
    conversationId: updated.channelId,
    messageId: updated.id,
    preview: preview,
  );
  notifier.updateDmPreview(
    conversationId: updated.channelId,
    messageId: updated.id,
    preview: preview,
  );
}

/// Handles `message:deleted` at the home level.
///
/// When the deleted message is the current sidebar preview for a channel
/// or DM, the preview is stale — refresh the home list so the server
/// provides the correct last-message preview.
void _handleMessageDeleted(Ref ref, RealtimeEventEnvelope event) {
  final deleted = tryParseMessageDeletedPayload(event.payload);
  if (deleted == null) return;

  final homeState = ref.read(homeListStoreProvider);
  if (homeState.status != HomeListStatus.success) return;

  // Check if deleted message is the current sidebar preview for a
  // channel or DM. If so, refresh to get the correct last-message.
  final isChannelPreview = homeState.channels.any(
        (ch) =>
            ch.scopeId.value == deleted.channelId &&
            ch.lastMessageId == deleted.id,
      ) ||
      homeState.pinnedChannels.any(
        (ch) =>
            ch.scopeId.value == deleted.channelId &&
            ch.lastMessageId == deleted.id,
      );

  final isDmPreview = homeState.directMessages.any(
        (dm) =>
            dm.scopeId.value == deleted.channelId &&
            dm.lastMessageId == deleted.id,
      ) ||
      homeState.pinnedDirectMessages.any(
        (dm) =>
            dm.scopeId.value == deleted.channelId &&
            dm.lastMessageId == deleted.id,
      ) ||
      homeState.hiddenDirectMessages.any(
        (dm) =>
            dm.scopeId.value == deleted.channelId &&
            dm.lastMessageId == deleted.id,
      );

  if (isChannelPreview || isDmPreview) {
    _refreshHomeList(ref, reason: 'messageDeleted');
  }
}

// ---------------------------------------------------------------------------
// DM materialization handlers (absorbed from
// home_realtime_dm_materialization_binding)
// ---------------------------------------------------------------------------

void _handleDmNew(
  Ref ref,
  RealtimeEventEnvelope event,
  List<_BufferedDmEvent> pendingBuffer,
) {
  final payload = event.payload;
  if (payload == null) return;

  final map = payload is Map<String, dynamic>
      ? payload
      : (payload is Map ? Map<String, dynamic>.from(payload) : null);
  if (map == null) return;

  final channelId = readOptionalConversationPayloadString(map['channelId']);
  if (channelId == null) return;

  ref.read(realtimeSocketClientProvider).emit('join:channel', channelId);

  final homeState = ref.read(homeListStoreProvider);
  if (homeState.status != HomeListStatus.success ||
      homeState.serverScopeId == null) {
    final activeServerId = ref.read(activeServerScopeIdProvider);
    if (activeServerId != null) {
      pendingBuffer.add(_BufferedDmEvent(
        serverId: activeServerId,
        channelId: channelId,
        payload: map,
      ));
    }
    return;
  }

  unawaited(() async {
    try {
      await _materializeDm(ref, homeState.serverScopeId!, channelId, map);
    } catch (e, st) {
      ref.read(crashReporterProvider).captureException(e, stackTrace: st);
    }
  }());
}

Future<void> _materializeDm(
  Ref ref,
  ServerScopeId serverId,
  String channelId,
  Map<String, dynamic>? eventMap,
) async {
  final scopeId = DirectMessageScopeId(
    serverId: serverId,
    value: channelId,
  );

  final title = eventMap != null
      ? (resolveDirectMessageTitle(eventMap) ?? channelId)
      : channelId;

  final summary =
      await ref.read(homeRepositoryProvider).persistDirectMessageSummary(
            HomeDirectMessageSummary(scopeId: scopeId, title: title),
          );

  ref.read(homeListStoreProvider.notifier).addDirectMessage(summary);
}

// ---------------------------------------------------------------------------
// Channel / Home helpers
// ---------------------------------------------------------------------------

void _refreshHomeList(Ref ref, {required String reason}) {
  try {
    final state = ref.read(homeListStoreProvider);
    if (state.status == HomeListStatus.loading) return;
    unawaited(ref.read(homeListStoreProvider.notifier).refresh(reason: reason));
  } catch (e, st) {
    ref.read(crashReporterProvider).captureException(e, stackTrace: st);
  }
}

ChannelScopeId? _matchChannelScopeId(
  HomeListState state,
  String conversationId,
) {
  for (final channel in state.pinnedChannels) {
    if (channel.scopeId.value == conversationId) return channel.scopeId;
  }
  for (final channel in state.channels) {
    if (channel.scopeId.value == conversationId) return channel.scopeId;
  }
  return null;
}

DirectMessageScopeId? _matchDirectMessageScopeId(
  HomeListState state,
  String conversationId,
) {
  for (final dm in state.pinnedDirectMessages) {
    if (dm.scopeId.value == conversationId) return dm.scopeId;
  }
  for (final dm in state.directMessages) {
    if (dm.scopeId.value == conversationId) return dm.scopeId;
  }
  for (final dm in state.hiddenDirectMessages) {
    if (dm.scopeId.value == conversationId) return dm.scopeId;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Server membership helpers
// ---------------------------------------------------------------------------

Future<void> _handleServerMembershipRemoved(
  Ref ref,
  ServerScopeId activeServerId,
) async {
  try {
    if (ref.read(serverListStoreProvider).status != ServerListStatus.loading) {
      await ref.read(serverListStoreProvider.notifier).load();
    }
  } catch (e, st) {
    ref.read(crashReporterProvider).captureException(e, stackTrace: st);
    return;
  }

  try {
    final servers = ref.read(serverListStoreProvider).servers;
    if (!servers.any((server) => server.id == activeServerId.value)) {
      await ref.read(serverSelectionStoreProvider.notifier).clearSelection();
    }
  } catch (e, st) {
    ref.read(crashReporterProvider).captureException(e, stackTrace: st);
  }
}

bool _shouldRefreshServerState(
  ServerScopeId activeServerId,
  RealtimeEventEnvelope event,
) {
  final eventServerId = _extractServerId(event);
  return eventServerId == null || eventServerId == activeServerId.value;
}

// ---------------------------------------------------------------------------
// Agent helpers
// ---------------------------------------------------------------------------

void _handleAgentActivity(Ref ref, RealtimeEventEnvelope event) {
  final map = _asMap(event.payload);
  if (map == null) return;
  final agentId = _optionalString(map['agentId']);
  final activity = _optionalString(map['activity']);
  if (agentId == null || activity == null) return;
  final detail = _optionalString(map['detail']);

  try {
    ref.read(agentsStoreProvider.notifier).updateActivity(
          agentId,
          activity,
          detail,
          timestamp: event.receivedAt,
        );
  } on StateError catch (_) {
  } catch (e, s) {
    ref.read(crashReporterProvider).captureException(e, stackTrace: s);
  }
}

void _handleAgentCreatedOrDeleted(Ref ref) {
  try {
    ref.read(agentsStoreProvider.notifier).load();
  } on StateError catch (_) {
  } catch (e, s) {
    ref.read(crashReporterProvider).captureException(e, stackTrace: s);
  }
}

// ---------------------------------------------------------------------------
// Task relay helpers
// ---------------------------------------------------------------------------

void _relayTaskCreated(Ref ref, RealtimeEventEnvelope event) {
  final tasks = _parseTasksFromPayload(event.payload);
  if (tasks.isEmpty) return;
  ref.read(routedTaskEventProvider.notifier).state =
      TasksCreatedRouterEvent(tasks);
}

void _relayTaskUpdated(Ref ref, RealtimeEventEnvelope event) {
  final task = _parseSingleTaskFromPayload(event.payload);
  if (task == null) return;
  ref.read(routedTaskEventProvider.notifier).state =
      TaskUpdatedRouterEvent(task);
}

void _relayTaskDeleted(Ref ref, RealtimeEventEnvelope event) {
  final taskId = _parseTaskIdFromPayload(event.payload);
  if (taskId == null) return;
  ref.read(routedTaskEventProvider.notifier).state =
      TaskDeletedRouterEvent(taskId);
}

// ---------------------------------------------------------------------------
// Task payload parsers (absorbed from tasks_realtime_binding)
// ---------------------------------------------------------------------------

List<TaskItem> _parseTasksFromPayload(Object? payload) {
  final map = _asMap(payload);
  if (map == null) return [];
  final tasks = map['tasks'];
  if (tasks is! List) return [];

  final result = <TaskItem>[];
  for (final item in tasks) {
    final taskMap = _asMap(item);
    if (taskMap == null) continue;
    final parsed = _tryParseTaskItem(taskMap);
    if (parsed != null) result.add(parsed);
  }
  return result;
}

TaskItem? _parseSingleTaskFromPayload(Object? payload) {
  final map = _asMap(payload);
  if (map == null) return null;
  final task = map['task'];
  final taskMap = _asMap(task);
  if (taskMap == null) return null;
  return _tryParseTaskItem(taskMap);
}

String? _parseTaskIdFromPayload(Object? payload) {
  final map = _asMap(payload);
  if (map == null) return null;
  final taskId = map['taskId'];
  return taskId is String && taskId.isNotEmpty ? taskId : null;
}

TaskItem? _tryParseTaskItem(Map<String, dynamic> map) {
  final id = _optionalString(map['id']);
  final title = _optionalString(map['title']);
  final status = _optionalString(map['status']);
  final channelId = _optionalString(map['channelId']);
  if (id == null || title == null || status == null || channelId == null) {
    return null;
  }
  final taskNumber = map['taskNumber'];
  return TaskItem(
    id: id,
    taskNumber: taskNumber is int
        ? taskNumber
        : taskNumber is num
            ? taskNumber.toInt()
            : 0,
    title: title,
    status: status,
    channelId: channelId,
    channelType: _optionalString(map['channelType']) ?? 'channel',
    messageId: _optionalString(map['messageId']),
    isLegacy: map['isLegacy'] == true,
    claimedById: _optionalString(map['claimedById']),
    claimedByName: _optionalString(map['claimedByName']),
    claimedByType: _optionalString(map['claimedByType']),
    claimedAt: _optionalDateTime(map['claimedAt']),
    createdById: _optionalString(map['createdById']) ?? '',
    createdByName: _optionalString(map['createdByName']) ?? '',
    createdByType: _optionalString(map['createdByType']) ?? 'user',
    createdAt: _optionalDateTime(map['createdAt']) ?? DateTime.now(),
    completedAt: _optionalDateTime(map['completedAt']),
  );
}

DateTime? _optionalDateTime(Object? value) {
  final raw = _optionalString(value);
  return raw != null ? DateTime.tryParse(raw) : null;
}

// ---------------------------------------------------------------------------
// Shared parsing helpers
// ---------------------------------------------------------------------------

bool _targetsServer(ServerScopeId serverId, RealtimeEventEnvelope event) {
  final eventServerId = _extractServerId(event);
  return eventServerId == null || eventServerId == serverId.value;
}

String? _extractServerId(RealtimeEventEnvelope event) {
  final payload = _asMap(event.payload);
  final payloadServerId = _optionalString(payload?['serverId']);
  if (payloadServerId != null) return payloadServerId;
  return _serverIdFromScopeKey(event.scopeKey);
}

String? _extractChannelId(RealtimeEventEnvelope event) {
  final payload = _asMap(event.payload);
  final payloadChannelId =
      _optionalString(payload?['channelId']) ?? _optionalString(payload?['id']);
  if (payloadChannelId != null) return payloadChannelId;
  final match = channelScopePattern.firstMatch(event.scopeKey);
  return match?.group(1);
}

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String? _optionalString(Object? value) {
  if (value is String && value.isNotEmpty) return value;
  return null;
}

String? _serverIdFromScopeKey(String scopeKey) {
  final match = serverScopePattern.firstMatch(scopeKey);
  return match?.group(1);
}

// ---------------------------------------------------------------------------
// Internal types
// ---------------------------------------------------------------------------

class _BufferedDmEvent {
  const _BufferedDmEvent({
    required this.serverId,
    required this.channelId,
    required this.payload,
  });

  final ServerScopeId serverId;
  final String channelId;
  final Map<String, dynamic> payload;
}

// ---------------------------------------------------------------------------
// Announcement domain handler
// ---------------------------------------------------------------------------

void _handleAnnouncementNew(Ref ref, RealtimeEventEnvelope event) {
  final map = _asMap(event.payload);
  if (map == null) return;
  final announcement = Announcement.fromMap(map);
  if (announcement == null) return;

  try {
    ref.read(announcementStoreProvider.notifier).addAnnouncement(announcement);
  } on StateError catch (_) {
  } catch (e, s) {
    ref.read(crashReporterProvider).captureException(e, stackTrace: s);
  }
}

void _handleAnnouncementUpdated(Ref ref, RealtimeEventEnvelope event) {
  final map = _asMap(event.payload);
  if (map == null) return;
  final announcement = Announcement.fromMap(map);
  if (announcement == null) return;

  try {
    ref
        .read(announcementStoreProvider.notifier)
        .updateAnnouncement(announcement);
  } on StateError catch (_) {
  } catch (e, s) {
    ref.read(crashReporterProvider).captureException(e, stackTrace: s);
  }
}

void _handleAnnouncementDeleted(Ref ref, RealtimeEventEnvelope event) {
  final map = _asMap(event.payload);
  if (map == null) return;
  final id = map['id'];
  if (id is! String || id.isEmpty) return;

  try {
    ref.read(announcementStoreProvider.notifier).removeAnnouncement(id);
  } on StateError catch (_) {
  } catch (e, s) {
    ref.read(crashReporterProvider).captureException(e, stackTrace: s);
  }
}
