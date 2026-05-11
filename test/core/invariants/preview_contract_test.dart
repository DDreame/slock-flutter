import 'package:glados/glados.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/home/application/home_list_state.dart';
import 'package:slock_app/features/home/application/home_list_store.dart';
import 'package:slock_app/features/inbox/application/inbox_store.dart';
import 'package:slock_app/features/inbox/application/message_preview_resolver.dart';
import 'package:slock_app/features/inbox/data/inbox_item.dart';
import 'package:slock_app/features/unread/application/unread_source_projection_store.dart';

import '../../support/support.dart';

/// CT — Preview Contract Invariants (INV-PREVIEW-1/2/3).
///
/// These tests verify that [MessagePreviewResolver] upholds the preview
/// contract across all possible input combinations:
///
/// - **INV-PREVIEW-1**: Result is never empty, null, or `"[No preview]"`
/// - **INV-PREVIEW-2**: Result length <= 200 chars
/// - **INV-PREVIEW-3**: Every MessageType × attachment × state combination
///   produces a valid preview
void main() {
  // ---------------------------------------------------------------------------
  // Custom generators for property-based testing
  // ---------------------------------------------------------------------------

  /// Generator for nullable String content with interesting shapes.
  final contentGenerator = any.simple<String?>(
    generate: (random, size) {
      final kind = random.nextInt(8);
      switch (kind) {
        case 0:
          return null;
        case 1:
          return '';
        case 2:
          return '   '; // whitespace only
        case 3:
          return 'Hello world';
        case 4:
          return 'https://example.com/path?q=1';
        case 5:
          return List.generate(
            size + 1,
            (_) => String.fromCharCode(0x4e00 + random.nextInt(0x100)),
          ).join(); // random CJK text
        case 6:
          return '\u{1F600}\u{1F601}\u{1F602}'; // emoji
        default:
          return List.generate(
            random.nextInt(size + 1) + 1,
            (_) => String.fromCharCode(0x41 + random.nextInt(26)),
          ).join();
      }
    },
    shrink: (input) sync* {
      if (input == null) return;
      if (input.isEmpty) return;
      yield null;
      yield '';
    },
  );

  /// Generator for messageType strings.
  final messageTypeGenerator = any.simple<String?>(
    generate: (random, size) {
      const types = [null, 'message', 'system', 'unknown', 'custom'];
      return types[random.nextInt(types.length)];
    },
    shrink: (input) sync* {
      if (input != null) yield null;
    },
  );

  /// Generator for MessageSendState.
  final sendStateGenerator = any.simple<MessageSendState>(
    generate: (random, size) {
      return MessageSendState.values[random.nextInt(3)];
    },
    shrink: (input) sync* {
      if (input != MessageSendState.sent) yield MessageSendState.sent;
    },
  );

  /// Generator for attachment lists.
  final attachmentsGenerator = any.simple<List<MessageAttachment>?>(
    generate: (random, size) {
      final kind = random.nextInt(7);
      switch (kind) {
        case 0:
          return null;
        case 1:
          return const [];
        case 2:
          return const [
            MessageAttachment(name: 'audio.mp3', type: 'audio/mp3')
          ];
        case 3:
          return const [
            MessageAttachment(name: 'photo.jpg', type: 'image/jpeg')
          ];
        case 4:
          return const [MessageAttachment(name: 'clip.mp4', type: 'video/mp4')];
        case 5:
          return const [
            MessageAttachment(name: 'doc.pdf', type: 'application/pdf')
          ];
        default:
          return const [
            MessageAttachment(name: 'photo.jpg', type: 'image/jpeg'),
            MessageAttachment(name: 'doc.pdf', type: 'application/pdf'),
          ];
      }
    },
    shrink: (input) sync* {
      if (input != null && input.isNotEmpty) {
        yield null;
        yield const [];
      }
    },
  );

  // ---------------------------------------------------------------------------
  // INV-PREVIEW-1: Never empty, null, or "[No preview]"
  // ---------------------------------------------------------------------------

  group('INV-PREVIEW-1: preview is never empty/null/[No preview]', () {
    Glados2(contentGenerator, sendStateGenerator).test(
      'resolve() with random content × sendState never returns empty',
      (content, sendState) {
        final result = MessagePreviewResolver.resolve(
          content: content,
          sendState: sendState,
        );
        expect(result, isNotEmpty);
        expect(result, isNot(equals('[No preview]')));
        expect(result.trim(), isNotEmpty);
      },
    );

    Glados2(messageTypeGenerator, any.bool).test(
      'resolve() with random messageType × isDeleted never returns empty',
      (messageType, isDeleted) {
        final result = MessagePreviewResolver.resolve(
          messageType: messageType,
          isDeleted: isDeleted,
        );
        expect(result, isNotEmpty);
        expect(result, isNot(equals('[No preview]')));
        expect(result.trim(), isNotEmpty);
      },
    );

    Glados(attachmentsGenerator).test(
      'resolve() with random attachments never returns empty',
      (attachments) {
        final result = MessagePreviewResolver.resolve(
          attachments: attachments,
        );
        expect(result, isNotEmpty);
        expect(result, isNot(equals('[No preview]')));
        expect(result.trim(), isNotEmpty);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // INV-PREVIEW-2: length <= 200
  // ---------------------------------------------------------------------------

  group('INV-PREVIEW-2: preview length <= 200', () {
    // The current implementation passes content through as-is without
    // truncation. This means long content exceeds 200 chars. Marking skip
    // per scope rule: "If a test fails, fix the test to match current
    // behavior or mark skip + TODO."
    Glados(contentGenerator).test(
      'resolve() output length <= 200',
      (content) {
        final result = MessagePreviewResolver.resolve(content: content);
        expect(result.length, lessThanOrEqualTo(200));
      },
      skip: 'TODO: Resolver does not truncate content — INV-PREVIEW-2 '
          'requires adding truncation logic to MessagePreviewResolver.',
    );

    // Verify that all non-content label constants satisfy the 200-char limit.
    test('all label constants are <= 200 chars', () {
      expect(
        MessagePreviewResolver.deletedPreview.length,
        lessThanOrEqualTo(200),
      );
      expect(
        MessagePreviewResolver.sendingPreview.length,
        lessThanOrEqualTo(200),
      );
      expect(
        MessagePreviewResolver.failedPreview.length,
        lessThanOrEqualTo(200),
      );
      expect(
        MessagePreviewResolver.systemPreview.length,
        lessThanOrEqualTo(200),
      );
      expect(
        MessagePreviewResolver.linkPreview.length,
        lessThanOrEqualTo(200),
      );
      expect(
        MessagePreviewResolver.voicePreview.length,
        lessThanOrEqualTo(200),
      );
      expect(
        MessagePreviewResolver.imagePreview.length,
        lessThanOrEqualTo(200),
      );
      expect(
        MessagePreviewResolver.videoPreview.length,
        lessThanOrEqualTo(200),
      );
      expect(
        MessagePreviewResolver.fallbackPreview.length,
        lessThanOrEqualTo(200),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // INV-PREVIEW-3: All MessageType values produce valid preview
  // ---------------------------------------------------------------------------

  group('INV-PREVIEW-3: all message types produce valid previews', () {
    const allMessageTypes = [null, 'message', 'system', 'unknown'];
    const allSendStates = MessageSendState.values;

    for (final messageType in allMessageTypes) {
      for (final sendState in allSendStates) {
        for (final isDeleted in [false, true]) {
          final label =
              'type=$messageType, sendState=$sendState, deleted=$isDeleted';
          test('resolve produces valid preview for $label', () {
            final result = MessagePreviewResolver.resolve(
              content: 'test content',
              messageType: messageType,
              isDeleted: isDeleted,
              sendState: sendState,
            );
            expect(result, isNotEmpty);
            expect(result.trim(), isNotEmpty);
            expect(result, isNot(equals('[No preview]')));
          });
        }
      }
    }

    test('null content + null attachments falls through to fallback', () {
      final result = MessagePreviewResolver.resolve();
      expect(result, equals(MessagePreviewResolver.fallbackPreview));
      expect(result, isNotEmpty);
    });

    // Attachment MIME type matrix
    const mimeTypes = [
      'audio/mp3',
      'audio/ogg',
      'image/jpeg',
      'image/png',
      'image/gif',
      'video/mp4',
      'video/quicktime',
      'application/pdf',
      'text/plain',
    ];

    for (final mime in mimeTypes) {
      test('attachment MIME $mime produces non-empty preview', () {
        final result = MessagePreviewResolver.resolve(
          attachments: [MessageAttachment(name: 'file', type: mime)],
        );
        expect(result, isNotEmpty);
        expect(result.trim(), isNotEmpty);
      });
    }
  });

  // ---------------------------------------------------------------------------
  // Explicit edge cases
  // ---------------------------------------------------------------------------

  group('Edge cases', () {
    test('empty content + empty attachment list → fallback', () {
      final result = MessagePreviewResolver.resolve(
        content: '',
        attachments: const [],
      );
      expect(result, equals(MessagePreviewResolver.fallbackPreview));
    });

    test('null content → fallback', () {
      final result = MessagePreviewResolver.resolve(content: null);
      expect(result, equals(MessagePreviewResolver.fallbackPreview));
    });

    test('pure emoji content → returns emoji string', () {
      const emoji = '\u{1F600}\u{1F601}\u{1F602}';
      final result = MessagePreviewResolver.resolve(content: emoji);
      expect(result, equals(emoji));
    });

    // NOTE: No assertion for >200-char content here — that would bless
    // length > 200 as expected behavior, contradicting INV-PREVIEW-2.
    // See the skip+TODO on the INV-PREVIEW-2 property test above.

    test('non-http URL in content → returns content as-is', () {
      final result = MessagePreviewResolver.resolve(
        content: 'ftp://files.example.com/doc.pdf',
      );
      expect(result, equals('ftp://files.example.com/doc.pdf'));
    });

    test('bare HTTP URL → link label', () {
      final result = MessagePreviewResolver.resolve(
        content: 'https://example.com',
      );
      expect(result, equals(MessagePreviewResolver.linkPreview));
    });

    test('mixed text + URL → returns content as-is', () {
      final result = MessagePreviewResolver.resolve(
        content: 'Check this out: https://example.com',
      );
      expect(result, equals('Check this out: https://example.com'));
    });

    test('voice message (audio attachment, no text) → voice label', () {
      final result = MessagePreviewResolver.resolve(
        content: null,
        attachments: const [
          MessageAttachment(name: 'voice.ogg', type: 'audio/ogg'),
        ],
      );
      expect(result, equals(MessagePreviewResolver.voicePreview));
    });

    test('image attachment only → image label', () {
      final result = MessagePreviewResolver.resolve(
        content: null,
        attachments: const [
          MessageAttachment(name: 'photo.jpg', type: 'image/jpeg'),
        ],
      );
      expect(result, equals(MessagePreviewResolver.imagePreview));
    });

    test('video attachment only → video label', () {
      final result = MessagePreviewResolver.resolve(
        content: null,
        attachments: const [
          MessageAttachment(name: 'clip.mp4', type: 'video/mp4'),
        ],
      );
      expect(result, equals(MessagePreviewResolver.videoPreview));
    });

    test('system message → system label (ignores content)', () {
      final result = MessagePreviewResolver.resolve(
        content: 'User joined',
        messageType: 'system',
      );
      expect(result, equals(MessagePreviewResolver.systemPreview));
    });

    test('deleted message → deleted label (ignores content)', () {
      final result = MessagePreviewResolver.resolve(
        content: 'Some content',
        isDeleted: true,
      );
      expect(result, equals(MessagePreviewResolver.deletedPreview));
    });

    test('sending state → sending label (ignores content)', () {
      final result = MessagePreviewResolver.resolve(
        content: 'Message being sent',
        sendState: MessageSendState.sending,
      );
      expect(result, equals(MessagePreviewResolver.sendingPreview));
    });

    test('failed state → failed label (ignores content)', () {
      final result = MessagePreviewResolver.resolve(
        content: 'Message that failed',
        sendState: MessageSendState.failed,
      );
      expect(result, equals(MessagePreviewResolver.failedPreview));
    });

    test('whitespace-only content → fallback', () {
      final result = MessagePreviewResolver.resolve(content: '   \t\n  ');
      expect(result, equals(MessagePreviewResolver.fallbackPreview));
    });

    test('content with leading/trailing whitespace → returns content as-is',
        () {
      final result = MessagePreviewResolver.resolve(content: '  hello  ');
      expect(result, equals('  hello  '));
    });

    test('deleted takes priority over sending state', () {
      final result = MessagePreviewResolver.resolve(
        isDeleted: true,
        sendState: MessageSendState.sending,
      );
      expect(result, equals(MessagePreviewResolver.deletedPreview));
    });

    test('deleted takes priority over system messageType', () {
      final result = MessagePreviewResolver.resolve(
        isDeleted: true,
        messageType: 'system',
      );
      expect(result, equals(MessagePreviewResolver.deletedPreview));
    });

    test('content takes priority over attachments', () {
      final result = MessagePreviewResolver.resolve(
        content: 'Text with attachment',
        attachments: const [
          MessageAttachment(name: 'photo.jpg', type: 'image/jpeg'),
        ],
      );
      expect(result, equals('Text with attachment'));
    });

    test('unknown attachment MIME produces "附件: filename"', () {
      final result = MessagePreviewResolver.resolve(
        attachments: const [
          MessageAttachment(name: 'data.bin', type: 'application/octet-stream'),
        ],
      );
      expect(result, equals('附件: data.bin'));
    });
  });

  // ---------------------------------------------------------------------------
  // resolvePreviewText backward-compat function
  // ---------------------------------------------------------------------------

  group('resolvePreviewText (backward compat)', () {
    test('non-null non-empty string → returns as-is', () {
      expect(resolvePreviewText('hello'), equals('hello'));
    });

    test('null → fallback', () {
      expect(
        resolvePreviewText(null),
        equals(MessagePreviewResolver.fallbackPreview),
      );
    });

    test('empty string → fallback', () {
      expect(
        resolvePreviewText(''),
        equals(MessagePreviewResolver.fallbackPreview),
      );
    });

    test('whitespace-only → fallback', () {
      expect(
        resolvePreviewText('   '),
        equals(MessagePreviewResolver.fallbackPreview),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Integration: Preview invariants through RuntimeAppFixture projection
  // ---------------------------------------------------------------------------

  group('Integration: Home surface preview pipeline', () {
    test('seeded channel/DM previews satisfy INV-PREVIEW-1/3 after load',
        () async {
      final fixture = RuntimeAppFixture();
      fixture.seedHome(
        channels: [
          (ChannelBuilder('ch-text')..withPreview('Hello world')).build(),
          (ChannelBuilder('ch-link')
                ..withPreview(MessagePreviewResolver.linkPreview))
              .build(),
          (ChannelBuilder('ch-no-preview')..withName('empty-ch')).build(),
        ],
        directMessages: [
          (DmBuilder('dm-text')..withPreview('DM content')).build(),
          (DmBuilder('dm-no-preview')..withTitle('empty-dm')).build(),
        ],
      );

      final container = await fixture.boot();
      try {
        final state = container.read(homeListStoreProvider);
        expect(state.status, HomeListStatus.success);

        // resolvePreviewText is the UI safety net called by HomeChannelRow /
        // HomeDirectMessageRow. Verify it never returns empty or [No preview].
        for (final ch in [...state.pinnedChannels, ...state.channels]) {
          final preview = resolvePreviewText(ch.lastMessagePreview);
          expect(preview, isNotEmpty,
              reason: 'channel ${ch.scopeId.value} preview empty');
          expect(preview.trim(), isNotEmpty,
              reason: 'channel ${ch.scopeId.value} preview whitespace-only');
          expect(preview, isNot(equals('[No preview]')),
              reason: 'channel ${ch.scopeId.value}');
        }

        for (final dm in [
          ...state.pinnedDirectMessages,
          ...state.directMessages,
        ]) {
          final preview = resolvePreviewText(dm.lastMessagePreview);
          expect(preview, isNotEmpty,
              reason: 'dm ${dm.scopeId.value} preview empty');
          expect(preview.trim(), isNotEmpty,
              reason: 'dm ${dm.scopeId.value} preview whitespace-only');
          expect(preview, isNot(equals('[No preview]')),
              reason: 'dm ${dm.scopeId.value}');
        }
      } finally {
        await fixture.dispose();
      }
    });
  });

  group('Integration: Inbox projection preview pipeline', () {
    test(
        'all preview variants (text, null, system, deleted, attachment) '
        'satisfy INV-PREVIEW-1/3', () async {
      final fixture = RuntimeAppFixture();

      // Seed home channels so visibility resolves to visible.
      fixture.seedHome(channels: [
        ChannelBuilder('ch-text').build(),
        ChannelBuilder('ch-null').build(),
        ChannelBuilder('ch-system').build(),
        ChannelBuilder('ch-deleted').build(),
        ChannelBuilder('ch-attachment').build(),
      ]);

      fixture.seedInbox([
        (InboxItemBuilder('ch-text')
              ..withUnread(1)
              ..withPreview('Hello world'))
            .build(),
        (InboxItemBuilder('ch-null')..withUnread(1)).build(), // null preview
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-system',
          channelName: 'ch-system',
          unreadCount: 1,
          messageType: 'system',
        ),
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-deleted',
          channelName: 'ch-deleted',
          unreadCount: 1,
          isDeleted: true,
        ),
        const InboxItem(
          kind: InboxItemKind.channel,
          channelId: 'ch-attachment',
          channelName: 'ch-attachment',
          unreadCount: 1,
          attachments: [
            MessageAttachment(name: 'photo.jpg', type: 'image/jpeg'),
          ],
        ),
      ]);

      final container = await fixture.boot();
      try {
        // Inbox is not auto-loaded by the event router; trigger explicitly.
        await container.read(inboxStoreProvider.notifier).load();
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(Duration.zero);
        }

        final projections = container.read(inboxProjectionProvider);
        expect(projections, hasLength(5));

        for (final p in projections) {
          expect(p.previewText, isNotEmpty, reason: '${p.id} preview empty');
          expect(p.previewText.trim(), isNotEmpty,
              reason: '${p.id} preview whitespace-only');
          expect(p.previewText, isNot(equals('[No preview]')), reason: p.id);
        }
      } finally {
        await fixture.dispose();
      }
    });
  });

  group('Integration: Unread source projection preview pipeline', () {
    test('all unread sources satisfy INV-PREVIEW-1/3', () async {
      final fixture = RuntimeAppFixture();

      fixture.seedHome(channels: [
        ChannelBuilder('ch-1').build(),
        ChannelBuilder('ch-2').build(),
      ]);

      fixture.seedInbox([
        (InboxItemBuilder('ch-1')
              ..withUnread(3)
              ..withPreview('New message'))
            .build(),
        (InboxItemBuilder('ch-2')..withUnread(1)).build(), // null preview
      ]);

      final container = await fixture.boot();
      try {
        await container.read(inboxStoreProvider.notifier).load();
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(Duration.zero);
        }

        final state = container.read(unreadSourceProjectionProvider);
        expect(state.isLoaded, isTrue);
        expect(state.sources, hasLength(2));

        for (final source in state.sources) {
          expect(source.previewText, isNotEmpty,
              reason: '${source.id} preview empty');
          expect(source.previewText.trim(), isNotEmpty,
              reason: '${source.id} preview whitespace-only');
          expect(source.previewText, isNot(equals('[No preview]')),
              reason: source.id);
        }
      } finally {
        await fixture.dispose();
      }
    });
  });
}
