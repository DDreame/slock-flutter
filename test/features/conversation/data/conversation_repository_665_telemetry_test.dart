// =============================================================================
// #665 — Silent catches → diagnostic telemetry (unit)
//
// Invariant: INV-TELEMETRY-665-1
//   All non-fatal catch blocks in conversation_repository_provider.dart must
//   report to CrashReporter.captureException so local store failures are
//   observable via telemetry.
//
// Strategy (ProviderContainer unit tests):
// T1: loadConversation — local title read failure → telemetry captured.
// T2: loadConversation — local store write failure → telemetry captured.
// T3: loadOlderMessages — local store write failure → telemetry captured.
// T4: loadNewerMessages — local store write failure → telemetry captured.
// T5: sendMessage — local store write failure → telemetry captured.
// =============================================================================

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _RecordingCrashReporter implements CrashReporter {
  final List<Object> capturedErrors = [];

  @override
  void captureException(Object error,
      {StackTrace? stackTrace, Map<String, dynamic>? extra}) {
    capturedErrors.add(error);
  }

  @override
  Future<void> init() async {}
  @override
  void captureFlutterError(FlutterErrorDetails details) {}
  @override
  void addBreadcrumb(Breadcrumb breadcrumb) {}
  @override
  void setUser(String? userId, {String? displayName}) {}
}

/// A local store with configurable per-operation failure behavior.
class _ThrowingLocalStore implements ConversationLocalStore {
  _ThrowingLocalStore({
    this.throwOnRead = false,
    this.throwOnWrite = true,
  });

  final bool throwOnRead;
  final bool throwOnWrite;

  @override
  Future<void> upsertMessages(Iterable<LocalMessageUpsert> entries) async {
    if (throwOnWrite) throw Exception('upsertMessages failed');
  }

  @override
  Future<void> upsertIdentities(Iterable<LocalIdentityUpsert> entries) async {
    if (throwOnWrite) throw Exception('upsertIdentities failed');
  }

  @override
  Future<void> upsertConversationSummaries(
    Iterable<LocalConversationSummaryUpsert> summaries, {
    bool preserveExistingSortIndex = false,
  }) async {
    if (throwOnWrite) throw Exception('upsertConversationSummaries failed');
  }

  @override
  Future<List<LocalConversationSummaryRecord>> listConversationSummaries(
    String serverId, {
    required String surface,
  }) async {
    if (throwOnRead) throw Exception('listConversationSummaries read failed');
    return [];
  }

  @override
  Future<void> touchConversationSummary({
    required String serverId,
    required String conversationId,
    required String lastMessageId,
    required String preview,
    required DateTime activityAt,
  }) async {
    if (throwOnWrite) throw Exception('touchConversationSummary failed');
  }

  @override
  Future<void> removeMessage({
    required String serverId,
    required String conversationId,
    required String messageId,
  }) async {
    if (throwOnWrite) throw Exception('removeMessage failed');
  }

  @override
  Future<LocalStoredMessageRecord?> updateMessageContent({
    required String serverId,
    required String conversationId,
    required String messageId,
    required String content,
  }) async {
    if (throwOnWrite) throw Exception('updateMessageContent failed');
    return null;
  }

  @override
  Future<void> updateConversationPreview({
    required String serverId,
    required String conversationId,
    required String messageId,
    required String preview,
  }) async {
    if (throwOnWrite) throw Exception('updateConversationPreview failed');
  }

  @override
  Future<int> nextSortIndex(String serverId, {required String surface}) async {
    return 0;
  }

  @override
  Future<List<LocalStoredMessageRecord>> listMessages(
    String serverId,
    String conversationId,
  ) async {
    return [];
  }

  @override
  Future<List<LocalStoredMessageRecord>> searchMessages(
    String serverId,
    String query, {
    int limit = 30,
  }) async {
    return [];
  }

  @override
  Future<List<LocalConversationSummaryRecord>> searchConversationSummaries(
    String serverId,
    String query,
  ) async {
    return [];
  }

  @override
  Future<List<LocalIdentityUpsert>> searchIdentities(
    String serverId,
    String query, {
    int limit = 20,
  }) async {
    return [];
  }

  @override
  Future<void> removeConversationSummariesNotIn({
    required String serverId,
    required String surface,
    required Set<String> retainedConversationIds,
  }) async {}
}

class _FakeAppDioClient extends AppDioClient {
  _FakeAppDioClient({required this.responses}) : super(Dio());
  final Map<String, Object?> responses;

  @override
  Future<Response<T>> request<T>(
    String path, {
    required String method,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
  }) async {
    return Response<T>(
      data: responses[path] as T,
      requestOptions: RequestOptions(path: path),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _channelTarget = ChannelScopeId(
  serverId: ServerScopeId('server-1'),
  value: 'ch-1',
);

final _target = ConversationDetailTarget.channel(_channelTarget);

Map<String, Object?> _channelLoadResponses() => {
      '/messages/channel/ch-1': {
        'messages': [
          {
            'id': 'msg-1',
            'content': 'hello',
            'createdAt': '2026-05-20T10:00:00Z',
            'senderType': 'human',
            'messageType': 'message',
            'seq': 1,
          },
        ],
        'historyLimited': false,
      },
      '/channels': [
        {'id': 'ch-1', 'name': 'ch-1'},
      ],
    };

Map<String, Object?> _sendMessageResponses() => {
      ..._channelLoadResponses(),
      '/messages': {
        'id': 'msg-sent-1',
        'content': 'sent content',
        'createdAt': '2026-05-20T10:01:00Z',
        'senderType': 'human',
        'messageType': 'message',
        'seq': 2,
      },
    };

ProviderContainer _createContainer({
  required _FakeAppDioClient appDioClient,
  required ConversationLocalStore localStore,
  required _RecordingCrashReporter crashReporter,
}) {
  return ProviderContainer(
    overrides: [
      appDioClientProvider.overrideWithValue(appDioClient),
      conversationLocalStoreProvider.overrideWithValue(localStore),
      crashReporterProvider.overrideWithValue(crashReporter),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: loadConversation — local title read failure → telemetry captured.
  //     Isolates the read-catch by disabling write throws.
  // -------------------------------------------------------------------------
  test(
    'INV-TELEMETRY-665-1: loadConversation reports local store read failure',
    () async {
      final crashReporter = _RecordingCrashReporter();
      final container = _createContainer(
        appDioClient: _FakeAppDioClient(responses: _channelLoadResponses()),
        localStore: _ThrowingLocalStore(throwOnRead: true, throwOnWrite: false),
        crashReporter: crashReporter,
      );
      addTearDown(container.dispose);

      final repo = container.read(conversationRepositoryProvider);
      final snapshot = await repo.loadConversation(_target);

      // Non-fatal: operation still succeeds.
      expect(snapshot.title, '#ch-1');
      // Exactly 1 error captured — from the read-failure catch site.
      expect(crashReporter.capturedErrors, hasLength(1),
          reason: 'Exactly the read-failure catch must fire');
      expect(
        crashReporter.capturedErrors.first.toString(),
        contains('listConversationSummaries read failed'),
        reason: 'Must capture the read-specific exception',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T2: loadConversation — local store write failure → telemetry captured.
  //     Isolates the write-catch by disabling read throws.
  // -------------------------------------------------------------------------
  test(
    'INV-TELEMETRY-665-1: loadConversation reports local store write failure',
    () async {
      final crashReporter = _RecordingCrashReporter();
      final container = _createContainer(
        appDioClient: _FakeAppDioClient(responses: _channelLoadResponses()),
        localStore: _ThrowingLocalStore(throwOnRead: false, throwOnWrite: true),
        crashReporter: crashReporter,
      );
      addTearDown(container.dispose);

      final repo = container.read(conversationRepositoryProvider);
      final snapshot = await repo.loadConversation(_target);

      // Non-fatal: operation still succeeds.
      expect(snapshot.messages.length, 1);
      // Write catch fires (upsertMessages is first to throw in the write block).
      expect(crashReporter.capturedErrors, hasLength(1),
          reason: 'Exactly the write-failure catch must fire');
      expect(
        crashReporter.capturedErrors.first.toString(),
        contains('upsertMessages failed'),
        reason: 'Must capture the write-specific exception',
      );
    },
  );

  // -------------------------------------------------------------------------
  // T3: loadOlderMessages — local store write failure → telemetry captured.
  // -------------------------------------------------------------------------
  test(
    'INV-TELEMETRY-665-1: loadOlderMessages reports local store write failure',
    () async {
      final crashReporter = _RecordingCrashReporter();
      final container = _createContainer(
        appDioClient: _FakeAppDioClient(responses: _channelLoadResponses()),
        localStore: _ThrowingLocalStore(throwOnRead: false, throwOnWrite: true),
        crashReporter: crashReporter,
      );
      addTearDown(container.dispose);

      final repo = container.read(conversationRepositoryProvider);
      final page = await repo.loadOlderMessages(_target, beforeSeq: 10);

      // Non-fatal: operation still returns results.
      expect(page.messages.length, 1);
      expect(crashReporter.capturedErrors, hasLength(1),
          reason: 'Exactly the write-failure catch must fire');
      expect(
        crashReporter.capturedErrors.first.toString(),
        contains('upsertMessages failed'),
      );
    },
  );

  // -------------------------------------------------------------------------
  // T4: loadNewerMessages — local store write failure → telemetry captured.
  // -------------------------------------------------------------------------
  test(
    'INV-TELEMETRY-665-1: loadNewerMessages reports local store write failure',
    () async {
      final crashReporter = _RecordingCrashReporter();
      final container = _createContainer(
        appDioClient: _FakeAppDioClient(responses: _channelLoadResponses()),
        localStore: _ThrowingLocalStore(throwOnRead: false, throwOnWrite: true),
        crashReporter: crashReporter,
      );
      addTearDown(container.dispose);

      final repo = container.read(conversationRepositoryProvider);
      final page = await repo.loadNewerMessages(_target, afterSeq: 0);

      // Non-fatal: operation still returns results.
      expect(page.messages.length, 1);
      expect(crashReporter.capturedErrors, hasLength(1),
          reason: 'Exactly the write-failure catch must fire');
      expect(
        crashReporter.capturedErrors.first.toString(),
        contains('upsertMessages failed'),
      );
    },
  );

  // -------------------------------------------------------------------------
  // T5: sendMessage — local store write failure → telemetry captured.
  // -------------------------------------------------------------------------
  test(
    'INV-TELEMETRY-665-1: sendMessage reports local store write failure',
    () async {
      final crashReporter = _RecordingCrashReporter();
      final container = _createContainer(
        appDioClient: _FakeAppDioClient(responses: _sendMessageResponses()),
        localStore: _ThrowingLocalStore(throwOnRead: false, throwOnWrite: true),
        crashReporter: crashReporter,
      );
      addTearDown(container.dispose);

      final repo = container.read(conversationRepositoryProvider);
      final message = await repo.sendMessage(_target, 'hello world');

      // Non-fatal: operation still returns the sent message.
      expect(message.id, 'msg-sent-1');
      expect(crashReporter.capturedErrors, hasLength(1),
          reason: 'Exactly the write-failure catch must fire');
      expect(
        crashReporter.capturedErrors.first.toString(),
        contains('upsertMessages failed'),
      );
    },
  );
}
