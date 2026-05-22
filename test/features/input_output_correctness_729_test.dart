// =============================================================================
// #729 — Input/Output Correctness (3 items)
//
// A. VoiceRecorderService bare filename fallback
// B. ShareSend empty text alongside attachments
// C. HTTP base URL accepts insecure scheme without warning
// =============================================================================

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
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
    test('start() generates paths in temp directory with unique names',
        () async {
      // We can't actually start recording (no mic in CI), but we can verify
      // the path generation logic by testing generateRecordingPath directly.
      final path1 = await VoiceRecorderService.generateRecordingPath(
        tempDirPath: '/tmp',
      );
      final path2 = await VoiceRecorderService.generateRecordingPath(
        tempDirPath: '/tmp',
      );

      // Paths must be absolute (start with /).
      expect(path1, startsWith('/'), reason: 'Recording path must be absolute');
      expect(path2, startsWith('/'), reason: 'Recording path must be absolute');

      // Paths must be in the temp directory.
      expect(path1, startsWith('/tmp/'),
          reason: 'Recording must be in temp directory');

      // Paths must be unique.
      expect(path1, isNot(equals(path2)),
          reason: 'Consecutive recording paths must be unique');

      // Paths must end with .m4a.
      expect(path1, endsWith('.m4a'));
      expect(path2, endsWith('.m4a'));
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
      // When no text items exist, content should be empty string (trimmed).
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
  });

  // ===========================================================================
  // C. BaseUrlValidator — insecure scheme warning
  // ===========================================================================
  group('#729C — BaseUrlValidator insecure scheme warning', () {
    test('http:// URL returns warning state', () {
      final result =
          BaseUrlValidator.validateApiUrl('http://api.example.com/v1');

      expect(result, isNotNull);
      expect(result!.url, 'http://api.example.com/v1');
      expect(result.isInsecure, isTrue,
          reason: 'http:// scheme must flag isInsecure');
    });

    test('https:// URL returns clean pass (no warning)', () {
      final result =
          BaseUrlValidator.validateApiUrl('https://api.example.com/v1');

      expect(result, isNotNull);
      expect(result!.url, 'https://api.example.com/v1');
      expect(result.isInsecure, isFalse,
          reason: 'https:// scheme must not flag isInsecure');
    });

    test('invalid URL returns null', () {
      final result = BaseUrlValidator.validateApiUrl('ftp://bad.com');

      expect(result, isNull, reason: 'Invalid scheme must return null');
    });

    test('empty input returns empty result (no warning)', () {
      final result = BaseUrlValidator.validateApiUrl('');

      expect(result, isNotNull);
      expect(result!.url, isEmpty);
      expect(result.isInsecure, isFalse);
    });

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
