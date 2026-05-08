import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/share/application/share_send_service.dart';
import 'package:slock_app/features/share/data/shared_content.dart';
import 'package:slock_app/features/share/presentation/page/share_target_picker_page.dart';

void main() {
  final testServerId = ServerScopeId.fromRouteParam('test-server');

  late _MockConversationRepository mockRepo;
  late ShareSendService service;

  setUp(() {
    mockRepo = _MockConversationRepository();
    service = ShareSendService(repository: mockRepo);
  });

  group('ShareSendService', () {
    test('sends text-only content without uploading', () async {
      const content = SharedContent(items: [
        SharedContentItem(type: SharedContentType.text, path: 'Hello world'),
      ]);
      final target = ShareTarget.channel(
        ChannelScopeId(serverId: testServerId, value: 'ch-1'),
        'general',
      );

      await service.send(target: target, content: content);

      expect(mockRepo.uploadCalls, isEmpty);
      expect(mockRepo.sendCalls, hasLength(1));
      expect(mockRepo.sendCalls[0].content, 'Hello world');
      expect(mockRepo.sendCalls[0].attachmentIds, isNull);
    });

    test('sends URL content as text', () async {
      const content = SharedContent(items: [
        SharedContentItem(
          type: SharedContentType.url,
          path: 'https://example.com',
        ),
      ]);
      final target = ShareTarget.directMessage(
        DirectMessageScopeId(serverId: testServerId, value: 'dm-1'),
        'Alice',
      );

      await service.send(target: target, content: content);

      expect(mockRepo.uploadCalls, isEmpty);
      expect(mockRepo.sendCalls[0].content, 'https://example.com');
    });

    test('uploads attachments and sends with attachment IDs', () async {
      mockRepo.uploadResults = ['att-1', 'att-2'];
      const content = SharedContent(items: [
        SharedContentItem(
          type: SharedContentType.image,
          path: '/tmp/photo.jpg',
          mimeType: 'image/jpeg',
        ),
        SharedContentItem(
          type: SharedContentType.file,
          path: '/tmp/doc.pdf',
          mimeType: 'application/pdf',
        ),
      ]);
      final target = ShareTarget.channel(
        ChannelScopeId(serverId: testServerId, value: 'ch-1'),
        'general',
      );

      await service.send(target: target, content: content);

      expect(mockRepo.uploadCalls, hasLength(2));
      expect(mockRepo.uploadCalls[0].path, '/tmp/photo.jpg');
      expect(mockRepo.uploadCalls[1].path, '/tmp/doc.pdf');
      expect(mockRepo.sendCalls, hasLength(1));
      expect(mockRepo.sendCalls[0].attachmentIds, ['att-1', 'att-2']);
      expect(mockRepo.sendCalls[0].content, '');
    });

    test('sends combined text with attachments', () async {
      mockRepo.uploadResults = ['att-1'];
      const content = SharedContent(items: [
        SharedContentItem(
          type: SharedContentType.text,
          path: 'Check this out',
        ),
        SharedContentItem(
          type: SharedContentType.image,
          path: '/tmp/photo.jpg',
          mimeType: 'image/jpeg',
        ),
      ]);
      final target = ShareTarget.channel(
        ChannelScopeId(serverId: testServerId, value: 'ch-1'),
        'general',
      );

      await service.send(target: target, content: content);

      expect(mockRepo.uploadCalls, hasLength(1));
      expect(mockRepo.sendCalls[0].content, 'Check this out');
      expect(mockRepo.sendCalls[0].attachmentIds, ['att-1']);
    });

    test('builds channel ConversationDetailTarget', () async {
      const content = SharedContent(items: [
        SharedContentItem(type: SharedContentType.text, path: 'Hi'),
      ]);
      final target = ShareTarget.channel(
        ChannelScopeId(serverId: testServerId, value: 'ch-1'),
        'general',
      );

      await service.send(target: target, content: content);

      final sentTarget = mockRepo.sendCalls[0].target;
      expect(sentTarget.surface, ConversationSurface.channel);
      expect(sentTarget.conversationId, 'ch-1');
    });

    test('builds DM ConversationDetailTarget', () async {
      const content = SharedContent(items: [
        SharedContentItem(type: SharedContentType.text, path: 'Hi'),
      ]);
      final target = ShareTarget.directMessage(
        DirectMessageScopeId(serverId: testServerId, value: 'dm-1'),
        'Alice',
      );

      await service.send(target: target, content: content);

      final sentTarget = mockRepo.sendCalls[0].target;
      expect(sentTarget.surface, ConversationSurface.directMessage);
      expect(sentTarget.conversationId, 'dm-1');
    });

    test('extracts filename from path for attachment name', () async {
      mockRepo.uploadResults = ['att-1'];
      const content = SharedContent(items: [
        SharedContentItem(
          type: SharedContentType.image,
          path: '/storage/emulated/0/DCIM/Camera/IMG_20240101.jpg',
          mimeType: 'image/jpeg',
        ),
      ]);
      final target = ShareTarget.channel(
        ChannelScopeId(serverId: testServerId, value: 'ch-1'),
        'general',
      );

      await service.send(target: target, content: content);

      expect(mockRepo.uploadCalls[0].name, 'IMG_20240101.jpg');
    });

    test('uses fallback mimeType when not provided', () async {
      mockRepo.uploadResults = ['att-1'];
      const content = SharedContent(items: [
        SharedContentItem(
          type: SharedContentType.file,
          path: '/tmp/unknown',
        ),
      ]);
      final target = ShareTarget.channel(
        ChannelScopeId(serverId: testServerId, value: 'ch-1'),
        'general',
      );

      await service.send(target: target, content: content);

      expect(
        mockRepo.uploadCalls[0].mimeType,
        'application/octet-stream',
      );
    });

    test('propagates upload failure without sending message', () async {
      mockRepo.shouldFailUpload = true;
      const content = SharedContent(items: [
        SharedContentItem(
          type: SharedContentType.image,
          path: '/tmp/photo.jpg',
          mimeType: 'image/jpeg',
        ),
      ]);
      final target = ShareTarget.channel(
        ChannelScopeId(serverId: testServerId, value: 'ch-1'),
        'general',
      );

      expect(
        () => service.send(target: target, content: content),
        throwsA(isA<Exception>()),
      );
      // Message should NOT be sent when upload fails.
      expect(mockRepo.sendCalls, isEmpty);
    });

    test('propagates sendMessage failure', () async {
      mockRepo.shouldFailSend = true;
      const content = SharedContent(items: [
        SharedContentItem(type: SharedContentType.text, path: 'Hello'),
      ]);
      final target = ShareTarget.channel(
        ChannelScopeId(serverId: testServerId, value: 'ch-1'),
        'general',
      );

      expect(
        () => service.send(target: target, content: content),
        throwsA(isA<Exception>()),
      );
    });
  });
}

class _SendCall {
  _SendCall({
    required this.target,
    required this.content,
    this.attachmentIds,
  });
  final ConversationDetailTarget target;
  final String content;
  final List<String>? attachmentIds;
}

class _UploadCall {
  _UploadCall({
    required this.path,
    required this.name,
    required this.mimeType,
  });
  final String path;
  final String name;
  final String mimeType;
}

class _MockConversationRepository implements ConversationRepository {
  List<String> uploadResults = [];
  int _uploadIndex = 0;
  final List<_UploadCall> uploadCalls = [];
  final List<_SendCall> sendCalls = [];
  bool shouldFailUpload = false;
  bool shouldFailSend = false;

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    if (shouldFailUpload) throw Exception('Upload failed');
    uploadCalls.add(_UploadCall(
      path: attachment.path,
      name: attachment.name,
      mimeType: attachment.mimeType,
    ));
    return uploadResults[_uploadIndex++];
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
  }) async {
    if (shouldFailSend) throw Exception('Send failed');
    sendCalls.add(_SendCall(
      target: target,
      content: content,
      attachmentIds: attachmentIds,
    ));
    return ConversationMessageSummary(
      id: 'msg-1',
      content: content,
      createdAt: DateTime(2024),
      senderType: 'human',
      messageType: 'message',
    );
  }

  // -- Unused stubs --
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
