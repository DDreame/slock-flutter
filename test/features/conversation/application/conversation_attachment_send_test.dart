import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';

void main() {
  late ProviderContainer container;
  late _FakeConversationRepository fakeRepo;

  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(serverId: ServerScopeId('s1'), value: 'ch1'),
  );

  setUp(() {
    fakeRepo = _FakeConversationRepository();
    container = ProviderContainer(overrides: [
      currentConversationDetailTargetProvider.overrideWithValue(target),
      conversationRepositoryProvider.overrideWithValue(fakeRepo),
      realtimeReductionIngressProvider.overrideWithValue(
        RealtimeReductionIngress(),
      ),
    ]);
  });

  tearDown(() => container.dispose());

  ConversationDetailStore store() =>
      container.read(conversationDetailStoreProvider.notifier);

  ConversationDetailState state() =>
      container.read(conversationDetailStoreProvider);

  Future<void> loadConversation() async {
    fakeRepo.snapshot = ConversationDetailSnapshot(
      target: target,
      title: 'test',
      messages: const [],
      historyLimited: false,
      hasOlder: false,
    );
    await store().load();
  }

  group('pending attachments', () {
    test('addPendingAttachment appends to state', () async {
      await loadConversation();
      const a = PendingAttachment(
        path: '/tmp/test.pdf',
        name: 'test.pdf',
        mimeType: 'application/pdf',
      );
      store().addPendingAttachment(a);
      expect(state().pendingAttachments, [a]);
    });

    test('removePendingAttachment removes by index', () async {
      await loadConversation();
      const a = PendingAttachment(
        path: '/tmp/a.pdf',
        name: 'a.pdf',
        mimeType: 'application/pdf',
      );
      const b = PendingAttachment(
        path: '/tmp/b.png',
        name: 'b.png',
        mimeType: 'image/png',
      );
      store().addPendingAttachment(a);
      store().addPendingAttachment(b);
      store().removePendingAttachment(0);
      expect(state().pendingAttachments, [b]);
    });

    test('removePendingAttachment ignores out-of-range index', () async {
      await loadConversation();
      const a = PendingAttachment(
        path: '/tmp/a.pdf',
        name: 'a.pdf',
        mimeType: 'application/pdf',
      );
      store().addPendingAttachment(a);
      store().removePendingAttachment(5);
      expect(state().pendingAttachments, [a]);
    });
  });

  group('canSend with attachments', () {
    test('canSend is true with only attachments (no text)', () async {
      await loadConversation();
      const a = PendingAttachment(
        path: '/tmp/test.pdf',
        name: 'test.pdf',
        mimeType: 'application/pdf',
      );
      store().addPendingAttachment(a);
      expect(state().canSend, isTrue);
    });

    test('canSend is true with text and attachments', () async {
      await loadConversation();
      store().updateDraft('hello');
      const a = PendingAttachment(
        path: '/tmp/test.pdf',
        name: 'test.pdf',
        mimeType: 'application/pdf',
      );
      store().addPendingAttachment(a);
      expect(state().canSend, isTrue);
    });

    test('canSend is false with no text and no attachments', () async {
      await loadConversation();
      expect(state().canSend, isFalse);
    });
  });

  group('send with attachments', () {
    test('send passes attachments to repository and clears on success',
        () async {
      await loadConversation();
      const a = PendingAttachment(
        path: '/tmp/test.pdf',
        name: 'test.pdf',
        mimeType: 'application/pdf',
      );
      store().addPendingAttachment(a);
      store().updateDraft('with file');
      fakeRepo.sendResult = ConversationMessageSummary(
        id: 'msg-1',
        content: 'with file',
        createdAt: DateTime.now(),
        senderType: 'human',
        messageType: 'message',
        attachments: const [
          MessageAttachment(name: 'test.pdf', type: 'pdf'),
        ],
      );

      await store().send();
      expect(state().pendingAttachments, isEmpty);
      expect(state().draft, isEmpty);
      expect(state().messages, hasLength(1));
      expect(state().messages.first.attachments, isNotNull);
      expect(fakeRepo.uploadedAttachments, [a]);
      expect(fakeRepo.lastSentAttachmentIds, ['att-1']);
    });

    test('attachment-only send works (empty draft)', () async {
      await loadConversation();
      const a = PendingAttachment(
        path: '/tmp/test.pdf',
        name: 'test.pdf',
        mimeType: 'application/pdf',
      );
      store().addPendingAttachment(a);
      fakeRepo.sendResult = ConversationMessageSummary(
        id: 'msg-2',
        content: '',
        createdAt: DateTime.now(),
        senderType: 'human',
        messageType: 'message',
        attachments: const [
          MessageAttachment(name: 'test.pdf', type: 'pdf'),
        ],
      );

      await store().send();
      expect(state().pendingAttachments, isEmpty);
      expect(state().messages, hasLength(1));
      expect(fakeRepo.uploadedAttachments, [a]);
      expect(fakeRepo.lastSentAttachmentIds, ['att-1']);
    });

    test('send failure preserves pending attachments', () async {
      await loadConversation();
      const a = PendingAttachment(
        path: '/tmp/test.pdf',
        name: 'test.pdf',
        mimeType: 'application/pdf',
      );
      store().addPendingAttachment(a);
      store().updateDraft('will fail');
      fakeRepo.shouldFail = true;

      await store().send();
      expect(state().pendingAttachments, [a]);
      expect(state().sendFailure, isNotNull);
    });

    test('partial upload failure sends with successful ids', () async {
      await loadConversation();
      const a = PendingAttachment(
        path: '/tmp/a.pdf',
        name: 'a.pdf',
        mimeType: 'application/pdf',
      );
      const b = PendingAttachment(
        path: '/tmp/b.png',
        name: 'b.png',
        mimeType: 'image/png',
      );
      store().addPendingAttachment(a);
      store().addPendingAttachment(b);
      store().updateDraft('mixed');
      fakeRepo.failUploadIndices = {0};
      fakeRepo.sendResult = ConversationMessageSummary(
        id: 'msg-3',
        content: 'mixed',
        createdAt: DateTime.now(),
        senderType: 'human',
        messageType: 'message',
        attachments: const [
          MessageAttachment(name: 'b.png', type: 'png'),
        ],
      );

      await store().send();
      expect(state().pendingAttachments, [a]);
      expect(state().messages, hasLength(1));
      expect(fakeRepo.uploadedAttachments, [b]);
      expect(fakeRepo.lastSentAttachmentIds, ['att-1']);
    });

    test('all uploads fail with no text aborts send', () async {
      await loadConversation();
      const a = PendingAttachment(
        path: '/tmp/a.pdf',
        name: 'a.pdf',
        mimeType: 'application/pdf',
      );
      store().addPendingAttachment(a);
      fakeRepo.failUploadIndices = {0};

      await store().send();
      expect(state().pendingAttachments, [a]);
      expect(state().sendFailure, isNotNull);
    });
  });
}

class _FakeConversationRepository implements ConversationRepository {
  ConversationDetailSnapshot? snapshot;
  ConversationMessageSummary? sendResult;
  List<String>? lastSentAttachmentIds;
  List<PendingAttachment> uploadedAttachments = [];
  String uploadIdPrefix = 'att';
  bool shouldFail = false;
  bool shouldFailUpload = false;
  Set<int> failUploadIndices = {};
  int _uploadCallIndex = 0;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    return snapshot!;
  }

  @override
  Future<ConversationMessagePage> loadOlderMessages(
    ConversationDetailTarget target, {
    required int beforeSeq,
  }) async {
    return const ConversationMessagePage(
      messages: [],
      historyLimited: false,
      hasOlder: false,
    );
  }

  @override
  Future<ConversationMessagePage> loadNewerMessages(
    ConversationDetailTarget target, {
    required int afterSeq,
  }) async {
    return const ConversationMessagePage(
      messages: [],
      historyLimited: false,
      hasOlder: false,
    );
  }

  @override
  Future<String> uploadAttachment(
    ConversationDetailTarget target,
    PendingAttachment attachment,
  ) async {
    final index = _uploadCallIndex++;
    if (shouldFailUpload || failUploadIndices.contains(index)) {
      throw const UnknownFailure(
        message: 'Upload failed',
        causeType: 'test',
      );
    }
    uploadedAttachments.add(attachment);
    return '$uploadIdPrefix-${uploadedAttachments.length}';
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
  }) async {
    lastSentAttachmentIds = attachmentIds;
    if (shouldFail) {
      throw const UnknownFailure(
        message: 'Test failure',
        causeType: 'test',
      );
    }
    return sendResult!;
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
  Future<ConversationMessageSummary?> updateStoredMessageContent(
    ConversationDetailTarget target, {
    required String messageId,
    required String content,
  }) async {
    return null;
  }
}
