import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/l10n/app_localizations.dart';

void main() {
  final target = ConversationDetailTarget.channel(
    const ChannelScopeId(
      serverId: ServerScopeId('server-1'),
      value: 'general',
    ),
  );

  late _FakeFilePicker fakeFilePicker;

  setUp(() {
    fakeFilePicker = _FakeFilePicker();
    FilePicker.platform = fakeFilePicker;
  });

  Widget buildApp(_FakeConversationRepository repository) {
    return ProviderScope(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ConversationDetailPage(target: target),
      ),
    );
  }

  testWidgets('composer shows attach button', (tester) async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ),
    );
    await tester.pumpWidget(buildApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('composer-attach')), findsOneWidget);
  });

  testWidgets('rejects oversized picked file with snackbar', (tester) async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ),
    );
    fakeFilePicker.result = FilePickerResult([
      PlatformFile(
        name: 'huge.zip',
        size: 51 * 1024 * 1024,
        path: '/tmp/huge.zip',
      ),
    ]);

    await tester.pumpWidget(buildApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('composer-attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('File'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey('attachment-size-error-snackbar')),
      findsOneWidget,
    );
    expect(find.text('File too large. Maximum size: 50 MB'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('composer-pending-attachments')),
      findsNothing,
    );
  });

  testWidgets('rejects oversized gallery media with snackbar', (tester) async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ),
    );
    fakeFilePicker.result = FilePickerResult([
      PlatformFile(
        name: 'huge.mp4',
        size: 51 * 1024 * 1024,
        path: '/tmp/huge.mp4',
      ),
    ]);

    await tester.pumpWidget(buildApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('composer-attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Photo & Video'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey('attachment-size-error-snackbar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('composer-pending-attachments')),
      findsNothing,
    );
  });

  testWidgets('rejects oversized camera capture with snackbar', (tester) async {
    final originalImagePicker = ImagePickerPlatform.instance;
    final fakeImagePicker = _FakeImagePickerPlatform();
    ImagePickerPlatform.instance = fakeImagePicker;
    addTearDown(() {
      ImagePickerPlatform.instance = originalImagePicker;
    });

    fakeImagePicker.result = XFile.fromData(
      Uint8List(0),
      name: 'huge-camera.jpg',
      path: '/tmp/huge-camera.jpg',
      length: 51 * 1024 * 1024,
    );

    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ),
    );

    await tester.pumpWidget(buildApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('composer-attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Camera'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey('attachment-size-error-snackbar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('composer-pending-attachments')),
      findsNothing,
    );
  });

  testWidgets('picking a file shows pending chip in composer', (tester) async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ),
    );
    fakeFilePicker.result = FilePickerResult([
      PlatformFile(name: 'doc.pdf', size: 2048, path: '/tmp/doc.pdf'),
    ]);

    await tester.pumpWidget(buildApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('composer-attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('composer-pending-attachments')),
      findsOneWidget,
    );
    expect(find.text('doc.pdf'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pending-attachment-0')),
      findsOneWidget,
    );
  });

  testWidgets('tapping delete on pending chip removes it', (tester) async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ),
    );

    await tester.pumpWidget(buildApp(repository));
    await tester.pumpAndSettle();

    fakeFilePicker.result = FilePickerResult([
      PlatformFile(name: 'a.pdf', size: 100, path: '/tmp/a.pdf'),
    ]);
    await tester.tap(find.byKey(const ValueKey('composer-attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();

    fakeFilePicker.result = FilePickerResult([
      PlatformFile(name: 'b.png', size: 200, path: '/tmp/b.png'),
    ]);
    await tester.tap(find.byKey(const ValueKey('composer-attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();

    expect(find.text('a.pdf'), findsOneWidget);
    expect(find.text('b.png'), findsOneWidget);

    await tester.tap(find.descendant(
      of: find.byKey(const ValueKey('pending-attachment-0')),
      matching: find.byIcon(Icons.cancel),
    ));
    await tester.pumpAndSettle();

    expect(find.text('a.pdf'), findsNothing);
    expect(find.text('b.png'), findsOneWidget);
  });

  testWidgets('send clears pending attachment chips', (tester) async {
    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ),
      sentMessage: ConversationMessageSummary(
        id: 'msg-1',
        content: '',
        createdAt: DateTime.parse('2026-04-19T15:00:00Z'),
        senderType: 'human',
        messageType: 'message',
        attachments: const [
          MessageAttachment(name: 'test.pdf', type: 'pdf'),
        ],
      ),
    );

    await tester.pumpWidget(buildApp(repository));
    await tester.pumpAndSettle();

    fakeFilePicker.result = FilePickerResult([
      PlatformFile(name: 'test.pdf', size: 1024, path: '/tmp/test.pdf'),
    ]);
    await tester.tap(find.byKey(const ValueKey('composer-attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('composer-pending-attachments')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('composer-send')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('composer-pending-attachments')),
      findsNothing,
    );
    expect(repository.uploadedAttachments, hasLength(1));
    expect(repository.lastSentAttachmentIds, ['upload-1']);
  });

  testWidgets('camera unavailable shows error snackbar', (tester) async {
    // Mock the image_picker method channel to throw PlatformException
    // simulating camera unavailable / permission denied.
    const channel = MethodChannel('plugins.flutter.io/image_picker');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(
        code: 'camera_access_denied',
        message: 'Camera access denied',
      );
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final repository = _FakeConversationRepository(
      snapshot: ConversationDetailSnapshot(
        target: target,
        title: '#general',
        messages: const [],
        historyLimited: false,
        hasOlder: false,
      ),
    );

    await tester.pumpWidget(buildApp(repository));
    await tester.pumpAndSettle();

    // Tap attach button to show bottom sheet
    await tester.tap(find.byKey(const ValueKey('composer-attach')));
    await tester.pumpAndSettle();

    // Tap "Camera" — will throw PlatformException from mocked channel,
    // which exercises the try-catch error path.
    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();

    // Snackbar should be displayed with the error message
    expect(
      find.byKey(const ValueKey('camera-error-snackbar')),
      findsOneWidget,
    );
    expect(find.text('Camera unavailable. Please check permissions.'),
        findsOneWidget);

    // No attachment should have been added
    expect(
      find.byKey(const ValueKey('composer-pending-attachments')),
      findsNothing,
    );
  });
}

class _FakeFilePicker extends FilePicker {
  FilePickerResult? result;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    return result;
  }
}

class _FakeConversationRepository implements ConversationRepository {
  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

  _FakeConversationRepository({
    required this.snapshot,
    this.sentMessage,
  });

  final ConversationDetailSnapshot snapshot;
  final ConversationMessageSummary? sentMessage;
  List<PendingAttachment> uploadedAttachments = [];
  List<String>? lastSentAttachmentIds;

  @override
  Future<ConversationDetailSnapshot> loadConversation(
    ConversationDetailTarget target,
  ) async {
    return snapshot;
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
    PendingAttachment attachment, {
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    uploadedAttachments.add(attachment);
    return 'upload-${uploadedAttachments.length}';
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    CancelToken? cancelToken,
  }) async {
    lastSentAttachmentIds = attachmentIds;
    return sentMessage!;
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

class _FakeImagePickerPlatform extends ImagePickerPlatform {
  XFile? result;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    return result;
  }
}
