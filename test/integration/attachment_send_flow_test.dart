import 'dart:async';

// =============================================================================
// B132 Phase 2 — Integration Flow Test: Attachment send
// =============================================================================

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';

import 'b132_phase2_test_support.dart';

void main() {
  late B132FakeFilePicker fakeFilePicker;

  setUp(() {
    fakeFilePicker = B132FakeFilePicker();
    FilePicker.platform = fakeFilePicker;
  });

  testWidgets('pick attachment, preview, send optimistic row, then confirm',
      (tester) async {
    final prefs = await b132Prefs();
    final repository = B132ConversationRepository();
    repository.sendCompleter = Completer<void>();
    final ingress = RealtimeReductionIngress();
    addTearDown(() => ingress.dispose());
    fakeFilePicker.result = FilePickerResult([
      PlatformFile(
        name: 'brief.pdf',
        size: 2048,
        path: '/tmp/brief.pdf',
      ),
    ]);

    final router = GoRouter(
      initialLocation: '/conversation',
      routes: [
        GoRoute(
          path: '/conversation',
          builder: (_, __) => ConversationDetailPage(target: b132ChannelTarget),
        ),
      ],
    );

    await tester.pumpWidget(b132App(
      router: router,
      prefs: prefs,
      conversationRepository: repository,
      realtimeIngress: ingress,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('composer-attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('composer-pending-attachments')),
        findsOneWidget);
    expect(find.text('brief.pdf'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('composer-send')));
    await tester.pump();

    expect(repository.uploadedAttachments.single.name, 'brief.pdf');
    expect(find.byKey(const ValueKey('pending-sending-indicator')),
        findsOneWidget);

    ingress.accept(RealtimeEventEnvelope(
      eventType: 'message:new',
      scopeKey: 'channel:$b132ChannelId',
      seq: 2,
      receivedAt: DateTime(2026, 6, 1, 12, 2),
      payload: {
        'id': 'attachment-realtime-1',
        'channelId': b132ChannelId,
        'content': '',
        'createdAt': DateTime(2026, 6, 1, 12, 2).toIso8601String(),
        'senderId': 'user-1',
        'senderType': 'user',
        'senderName': 'Robin',
        'messageType': 'message',
        'seq': 2,
        'attachments': const [
          {
            'id': 'attachment-1',
            'name': 'brief.pdf',
            'type': 'application/pdf',
            'sizeBytes': 2048,
          },
        ],
      },
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('message-attachment-realtime-1')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('message-attachments')), findsOneWidget);
    expect(find.byKey(const ValueKey('file-attachment-attachment-1')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('pending-sending-indicator')), findsNothing);

    repository.completeSend();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(repository.sentAttachmentIds, ['attachment-1']);
    expect(
        find.byKey(const ValueKey('pending-sending-indicator')), findsNothing);
    expect(find.byKey(const ValueKey('file-attachment-attachment-1')),
        findsWidgets);
  });
}
