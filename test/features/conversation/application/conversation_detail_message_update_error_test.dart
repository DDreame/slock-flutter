// =============================================================================
// #630 — Conversation store unguarded async closure error boundary
//
// Invariant: INV-CONV-MESSAGE-UPDATE-ERROR-1
//   conversation_detail_store.dart L1396-1418:
//   _handleMessageUpdated() fires on every `message:updated` realtime event.
//   The anonymous async closure has NO try/catch. If the storage operation
//   (updateStoredMessageContent) throws a non-AppFailure exception (e.g.
//   FormatException, TypeError from malformed payload), it becomes an
//   unhandled future error that can terminate the isolate.
//
//   Phase B wraps the closure body in try/catch and routes exceptions to
//   crashReporter.captureException.
//
// Strategy:
// T1: When updateStoredMessageContent throws FormatException, crashReporter
//     captures it (skip:true — no try/catch in current impl).
// T2: Normal message:updated still patches state (active — proves existing
//     happy path unaffected by Phase B changes).
//
// Phase A: T1 skip:true, T2 active.
// Phase B: Add try/catch in _handleMessageUpdated, un-skip T1.
// =============================================================================

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _RecordingCrashReporter implements CrashReporter {
  final List<(Object, StackTrace?)> captured = [];

  @override
  Future<void> init() async {}

  @override
  void captureException(Object error,
      {StackTrace? stackTrace, Map<String, dynamic>? extra}) {
    captured.add((error, stackTrace));
  }

  @override
  void captureFlutterError(FlutterErrorDetails details) {}

  @override
  void addBreadcrumb(Breadcrumb breadcrumb) {}

  @override
  void setUser(String? userId, {String? displayName}) {}
}

class _ThrowingConversationRepository implements ConversationRepository {
  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  _ThrowingConversationRepository({required this.snapshot});

  final ConversationDetailSnapshot snapshot;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    return snapshot;
  }

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {
    throw const FormatException('Malformed payload');
  }

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    CancelToken? cancelToken,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async {
    return message;
  }

  @override
  Future<void> editMessage(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {}

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> pinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> unpinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> addReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async {
    return const [];
  }

  @override
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    throw UnimplementedError();
  }
}

class _SuccessConversationRepository implements ConversationRepository {
  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  _SuccessConversationRepository({required this.snapshot});

  final ConversationDetailSnapshot snapshot;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    return snapshot;
  }

  @override
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {
    for (final message in snapshot.messages) {
      if (message.id == messageId) {
        return message.copyWith(content: content);
      }
    }
    return null;
  }

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    CancelToken? cancelToken,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ConversationMessageSummary> persistMessage(
    ConversationDetailTarget target, {
    required ConversationMessageSummary message,
    String? senderId,
  }) async {
    return message;
  }

  @override
  Future<void> editMessage(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {}

  @override
  Future<void> deleteMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> pinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> unpinMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> addReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<void> removeReaction(
    ConversationDetailTarget target, {
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Future<List<ConversationMessageSummary>> loadPinnedMessages(
    ConversationDetailTarget target,
  ) async {
    return const [];
  }

  @override
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {
    throw UnimplementedError();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    ),
  );

  final baseMessages = [
    ConversationMessageSummary(
      id: 'msg-1',
      content: 'Original content',
      createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
      senderType: 'human',
      messageType: 'message',
      seq: 1,
    ),
  ];

  final snapshot = ConversationDetailSnapshot(
    target: target,
    title: '#general',
    messages: baseMessages,
    historyLimited: false,
    hasOlder: false,
  );

  // -------------------------------------------------------------------------
  // T1: Throwing repository → crashReporter captures exception.
  // -------------------------------------------------------------------------
  test(
    'INV-CONV-MESSAGE-UPDATE-ERROR-1: repository throw → crashReporter '
    'captures exception',
    () async {
      final recorder = _RecordingCrashReporter();
      final ingress = RealtimeReductionIngress();

      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(
            _ThrowingConversationRepository(snapshot: snapshot),
          ),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
          crashReporterProvider.overrideWithValue(recorder),
        ],
      );
      final subscription = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await ingress.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();

      // Fire message:updated event that will cause repository to throw.
      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'message:updated',
          scopeKey: RealtimeEventEnvelope.globalScopeKey,
          receivedAt: DateTime(2026, 4, 20),
          seq: 2,
          payload: {
            'id': 'msg-1',
            'channelId': target.conversationId,
            'content': 'Edited content',
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        recorder.captured,
        isNotEmpty,
        reason: 'crashReporter.captureException must be called when '
            'updateStoredMessageContent throws '
            '(INV-CONV-MESSAGE-UPDATE-ERROR-1)',
      );
      expect(recorder.captured.first.$1, isA<FormatException>());

      // State must remain unchanged — no partial corruption.
      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages[0].content, 'Original content');
    },
  );

  // -------------------------------------------------------------------------
  // T2: Normal update still patches state (regression safety).
  // -------------------------------------------------------------------------
  test(
    'INV-CONV-MESSAGE-UPDATE-ERROR-1: normal update still patches state',
    () async {
      final recorder = _RecordingCrashReporter();
      final ingress = RealtimeReductionIngress();

      final container = ProviderContainer(
        overrides: [
          currentConversationDetailTargetProvider.overrideWithValue(target),
          conversationRepositoryProvider.overrideWithValue(
            _SuccessConversationRepository(snapshot: snapshot),
          ),
          realtimeReductionIngressProvider.overrideWithValue(ingress),
          crashReporterProvider.overrideWithValue(recorder),
        ],
      );
      final subscription = container.listen(
        conversationDetailStoreProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await ingress.dispose();
      });

      await container.read(conversationDetailStoreProvider.notifier).load();

      ingress.accept(
        RealtimeEventEnvelope(
          eventType: 'message:updated',
          scopeKey: RealtimeEventEnvelope.globalScopeKey,
          receivedAt: DateTime(2026, 4, 20),
          seq: 2,
          payload: {
            'id': 'msg-1',
            'channelId': target.conversationId,
            'content': 'Edited content',
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(conversationDetailStoreProvider);
      expect(state.messages[0].content, 'Edited content');

      // No crash reporter calls on success path.
      expect(recorder.captured, isEmpty);
    },
  );
}
