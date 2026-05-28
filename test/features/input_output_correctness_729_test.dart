// =============================================================================
// #729 — Input/Output Correctness (3 items)
//
// A. VoiceRecorderService bare filename fallback
// B. ShareSend empty text alongside attachments
// C. HTTP base URL accepts insecure scheme without warning
// =============================================================================

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/settings/data/base_url_validator.dart';
import 'package:slock_app/features/share/application/share_send_service.dart';
import 'package:slock_app/features/share/data/shared_content.dart';
import 'package:slock_app/features/share/presentation/page/share_target_picker_page.dart';
import 'package:slock_app/features/voice/data/voice_recorder_service.dart';

void main() {
  // ===========================================================================
  // A. VoiceRecorderService — unique temp path generation
  // ===========================================================================
  group('#729A — VoiceRecorderService path uniqueness', () {
    test('generateRecordingPath produces unique absolute paths', () async {
      final path1 = await VoiceRecorderService.generateRecordingPath(
        tempDirPath: '/tmp',
      );
      final path2 = await VoiceRecorderService.generateRecordingPath(
        tempDirPath: '/tmp',
      );

      expect(path1, startsWith('/'), reason: 'Recording path must be absolute');
      expect(path2, startsWith('/'), reason: 'Recording path must be absolute');
      expect(path1, startsWith('/tmp/'),
          reason: 'Recording must be in temp directory');
      expect(path1, isNot(equals(path2)),
          reason: 'Consecutive recording paths must be unique');
      expect(path1, endsWith('.m4a'));
      expect(path2, endsWith('.m4a'));
    });

    test('start() production path uses unique absolute temp path', () async {
      // Exercise the real start() method with an injectable recorder seam
      // so that reverting the path generation inside start() would break
      // this test.
      final recorder = _NoOpAudioRecorder();
      final service = VoiceRecorderService(
        recorder: recorder,
        tempDirPathOverride: '/tmp/voice_test',
      );

      await service.start();
      final firstPath = service.filePath;

      // Verify start() assigned a proper absolute path to filePath.
      expect(firstPath, isNotNull);
      expect(firstPath!, startsWith('/tmp/voice_test/'),
          reason: 'start() must generate path in temp directory');
      expect(firstPath, endsWith('.m4a'));

      // The recorder itself received the same path.
      expect(recorder.lastStartPath, firstPath);

      // A second start (after stop) produces a different path.
      await service.stop();
      await service.start();
      final secondPath = service.filePath!;
      expect(secondPath, startsWith('/tmp/voice_test/'));
      expect(secondPath, isNot(equals(firstPath)),
          reason: 'Each recording must have a unique path');

      service.dispose();
    });
  });

  // ===========================================================================
  // B. ShareSend — empty text omitted from API call
  // ===========================================================================
  group('#729B — ShareSend empty text handling', () {
    test('send with only attachments passes empty content to repo', () async {
      final repo = _TrackingConversationRepository();
      final service = ShareSendService(repository: repo);

      await service.send(
        target: ShareTarget.channel(
          const ChannelScopeId(serverId: ServerScopeId('srv-1'), value: 'ch-1'),
          'Test Channel',
        ),
        content: const SharedContent(items: [
          SharedContentItem(
            type: SharedContentType.image,
            path: '/tmp/photo.jpg',
            mimeType: 'image/jpeg',
          ),
        ]),
      );

      expect(repo.sendMessageCalls, hasLength(1));
      final call = repo.sendMessageCalls.first;
      expect(call.content, isEmpty,
          reason: 'Empty/whitespace-only text must be passed as empty string');
    });

    test('send with whitespace-only text trims to empty', () async {
      final repo = _TrackingConversationRepository();
      final service = ShareSendService(repository: repo);

      await service.send(
        target: ShareTarget.channel(
          const ChannelScopeId(serverId: ServerScopeId('srv-1'), value: 'ch-1'),
          'Test Channel',
        ),
        content: const SharedContent(items: [
          SharedContentItem(
            type: SharedContentType.text,
            path: '   \n  ',
          ),
          SharedContentItem(
            type: SharedContentType.image,
            path: '/tmp/photo.jpg',
            mimeType: 'image/jpeg',
          ),
        ]),
      );

      expect(repo.sendMessageCalls, hasLength(1));
      final call = repo.sendMessageCalls.first;
      expect(call.content, isEmpty,
          reason:
              'Whitespace-only text must be trimmed to empty before sending');
    });

    test('send with actual text preserves content', () async {
      final repo = _TrackingConversationRepository();
      final service = ShareSendService(repository: repo);

      await service.send(
        target: ShareTarget.channel(
          const ChannelScopeId(serverId: ServerScopeId('srv-1'), value: 'ch-1'),
          'Test Channel',
        ),
        content: const SharedContent(items: [
          SharedContentItem(
            type: SharedContentType.text,
            path: 'Hello world',
          ),
          SharedContentItem(
            type: SharedContentType.image,
            path: '/tmp/photo.jpg',
            mimeType: 'image/jpeg',
          ),
        ]),
      );

      expect(repo.sendMessageCalls, hasLength(1));
      final call = repo.sendMessageCalls.first;
      expect(call.content, 'Hello world',
          reason: 'Non-empty text must be preserved');
    });

    test(
        'production API repo omits content field from JSON when content is empty',
        () async {
      // Exercise the real _ApiConversationRepository.sendMessage() JSON
      // serialization path — proves reverting the content-omission logic
      // would break this test.
      final interceptor = _CapturingInterceptor();
      final dio = Dio()..interceptors.add(interceptor);
      final appDioClient = AppDioClient(dio);

      final container = ProviderContainer(
        overrides: [
          appDioClientProvider.overrideWithValue(appDioClient),
          conversationLocalStoreProvider
              .overrideWithValue(_NoOpConversationLocalStore()),
          crashReporterProvider.overrideWithValue(NoOpCrashReporter()),
        ],
      );
      addTearDown(container.dispose);

      final repo = container.read(conversationRepositoryProvider);

      // Send with empty content (attachment-only scenario).
      await repo.sendMessage(
        ConversationDetailTarget.channel(
          const ChannelScopeId(serverId: ServerScopeId('srv-1'), value: 'ch-1'),
        ),
        '', // empty content
        attachmentIds: ['att-1'],
      );

      // Verify the outgoing JSON payload does not contain 'content' key.
      expect(interceptor.capturedData, isNotNull);
      expect(interceptor.capturedData!, isNot(contains('content')),
          reason:
              'Empty content must be omitted from API payload to prevent blank text lines');
      expect(interceptor.capturedData!['channelId'], 'ch-1');
      expect(interceptor.capturedData!['attachmentIds'], ['att-1']);
    });

    test('production API repo includes content field when non-empty', () async {
      final interceptor = _CapturingInterceptor();
      final dio = Dio()..interceptors.add(interceptor);
      final appDioClient = AppDioClient(dio);

      final container = ProviderContainer(
        overrides: [
          appDioClientProvider.overrideWithValue(appDioClient),
          conversationLocalStoreProvider
              .overrideWithValue(_NoOpConversationLocalStore()),
          crashReporterProvider.overrideWithValue(NoOpCrashReporter()),
        ],
      );
      addTearDown(container.dispose);

      final repo = container.read(conversationRepositoryProvider);

      await repo.sendMessage(
        ConversationDetailTarget.channel(
          const ChannelScopeId(serverId: ServerScopeId('srv-1'), value: 'ch-1'),
        ),
        'Hello world',
        attachmentIds: ['att-1'],
      );

      expect(interceptor.capturedData, isNotNull);
      expect(interceptor.capturedData!['content'], 'Hello world',
          reason: 'Non-empty content must be present in API payload');
    });
  });

  // ===========================================================================
  // C. BaseUrlValidator — normalizeApiUrl backward compat
  //
  // NOTE: validateApiUrl and UrlValidationResult removed in #849 (dead code).
  // Only normalizeApiUrl remains in production.
  // ===========================================================================
  group('#729C — BaseUrlValidator normalizeApiUrl', () {
    test('normalizeApiUrl still works unchanged for backward compat', () {
      expect(
        BaseUrlValidator.normalizeApiUrl('https://api.example.com/'),
        'https://api.example.com',
      );
      expect(BaseUrlValidator.normalizeApiUrl('not-a-url'), isNull);
    });
  });
}

// =============================================================================
// Test Doubles
// =============================================================================

/// AudioRecorder that records calls without using platform channels.
class _NoOpAudioRecorder extends AudioRecorder {
  String? lastStartPath;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    lastStartPath = path;
  }

  @override
  Future<String?> stop() async {
    final path = lastStartPath;
    lastStartPath = null;
    return path;
  }

  @override
  Future<Amplitude> getAmplitude() async {
    return Amplitude(current: -40, max: 0);
  }

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> dispose() async {}
}

class _SendMessageCall {
  const _SendMessageCall({
    required this.target,
    required this.content,
    this.attachmentIds,
  });

  final ConversationDetailTarget target;
  final String content;
  final List<String>? attachmentIds;
}

class _TrackingConversationRepository implements ConversationRepository {
  final List<_SendMessageCall> sendMessageCalls = [];
  int uploadCount = 0;

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    uploadCount++;
    return 'att-$uploadCount';
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    CancelToken? cancelToken,
  }) async {
    sendMessageCalls.add(_SendMessageCall(
      target: target,
      content: content,
      attachmentIds: attachmentIds,
    ));
    return ConversationMessageSummary(
      id: 'msg-1',
      content: content,
      createdAt: DateTime(2026),
      senderType: 'human',
      messageType: 'message',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Dio interceptor that captures POST /messages request data and returns
/// a fake valid response to exercise the real serialization path.
class _CapturingInterceptor extends Interceptor {
  Map<String, dynamic>? capturedData;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path == '/messages' && options.method == 'POST') {
      capturedData = options.data as Map<String, dynamic>?;
    }
    // Return a fake response matching the expected message format.
    handler.resolve(Response(
      requestOptions: options,
      statusCode: 200,
      data: <String, dynamic>{
        'id': 'msg-fake-1',
        'content': '',
        'createdAt': '2026-01-01T00:00:00Z',
        'senderType': 'human',
        'messageType': 'message',
      },
    ));
  }
}

/// Minimal ConversationLocalStore that does nothing (for API-layer tests).
class _NoOpConversationLocalStore implements ConversationLocalStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<dynamic>.value(null);
}
