// ---------------------------------------------------------------------------
// #556: ConversationDetail Memory Management — GlobalKey Cleanup + memCacheWidth
//
// Problem:
//   1. `_messageGlobalKeys` map in ConversationDetailPage grows unbounded
//      with every rendered message (including paginated history), never pruned.
//   2. `CachedNetworkImage` for in-chat thumbnails has no `memCacheWidth` —
//      caches full-resolution decoded bitmap for 200px-wide thumbnails.
//   3. Link preview card `CachedNetworkImage` has no `memCacheHeight`.
//   4. Full-screen image viewer must NOT constrain cache dimensions.
//
// Phase A: skip:true invariants locking the memory management contracts.
//          Widget tests pump ConversationDetailPage / LinkPreviewCard with
//          test data and assert presence of cache constraints, key cleanup.
//
// Invariants verified:
// INV-KEY-DISPOSE-1: _messageGlobalKeys map is cleared on dispose
// INV-KEY-REGEN-1:   After dispose+recreate, keys regenerate via putIfAbsent
// INV-MEMCACHE-1:    In-chat image thumbnail CachedNetworkImage has memCacheWidth
// INV-MEMCACHE-2:    Link preview card CachedNetworkImage has memCacheHeight
// INV-FULLSCREEN-NO-CAP: Full-screen viewer does NOT have memCacheWidth/Height
// ---------------------------------------------------------------------------
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/data/conversation_repository_provider.dart';
import 'package:slock_app/features/conversation/data/pending_attachment.dart';
import 'package:slock_app/features/conversation/presentation/page/conversation_detail_page.dart';
import 'package:slock_app/features/conversation/presentation/widgets/file_preview_page.dart';
import 'package:slock_app/features/link_preview/data/link_metadata.dart';
import 'package:slock_app/features/link_preview/presentation/widgets/link_preview_card.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  // -----------------------------------------------------------------------
  // INV-KEY-DISPOSE-1: GlobalKeys map cleared on dispose
  // -----------------------------------------------------------------------
  group('INV-KEY-DISPOSE-1: GlobalKeys cleared on dispose', () {
    testWidgets(
      'GlobalKey currentContext is null after page dispose',
      (tester) async {
        final target = ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'general',
          ),
        );
        final repository = _FakeConversationRepository(
          snapshot: ConversationDetailSnapshot(
            target: target,
            title: '#general',
            messages: [
              ConversationMessageSummary(
                id: 'msg-1',
                content: 'Hello',
                createdAt: DateTime(2026, 5, 1, 10, 0),
                senderType: 'human',
                messageType: 'message',
                seq: 1,
              ),
            ],
            historyLimited: false,
            hasOlder: false,
          ),
        );

        await tester.pumpWidget(
          _buildApp(
            repository: repository,
            child: ConversationDetailPage(target: target),
          ),
        );
        await tester.pumpAndSettle();

        // Extract the GlobalKey from the KeyedSubtree wrapping msg-1.
        // The _getMessageKey callback generates a GlobalKey per message
        // and wraps each message in KeyedSubtree(key: globalKey).
        final subtrees = find.byType(KeyedSubtree).evaluate();
        final msgSubtree = subtrees.where((e) {
          final widget = e.widget as KeyedSubtree;
          return widget.key is GlobalKey;
        }).toList();
        expect(msgSubtree, isNotEmpty,
            reason: 'At least one message should have a GlobalKey');

        final capturedKey = msgSubtree.first.widget.key as GlobalKey;
        expect(capturedKey.currentContext, isNotNull,
            reason: 'Key should be attached while page is mounted');

        // Navigate away — triggers dispose.
        final context = tester.element(find.byType(ConversationDetailPage));
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('gone')),
          ),
        );
        await tester.pumpAndSettle();

        // After dispose + clear, the captured GlobalKey should be
        // detached (currentContext is null). Phase B adds
        // `_messageGlobalKeys.clear()` in dispose().
        expect(capturedKey.currentContext, isNull,
            reason: 'GlobalKey must be detached after page dispose');
      },
      skip:
          true, // Phase A: invariant locked — Phase B adds key cleanup in dispose
    );
  });

  // -----------------------------------------------------------------------
  // INV-KEY-REGEN-1: Keys regenerate after dispose + recreate
  // -----------------------------------------------------------------------
  group('INV-KEY-REGEN-1: key regeneration after dispose', () {
    testWidgets(
      'recreated page generates different GlobalKey instance for same message',
      (tester) async {
        final target = ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'general',
          ),
        );
        final snapshot = ConversationDetailSnapshot(
          target: target,
          title: '#general',
          messages: [
            ConversationMessageSummary(
              id: 'msg-1',
              content: 'Hello',
              createdAt: DateTime(2026, 5, 1, 10, 0),
              senderType: 'human',
              messageType: 'message',
              seq: 1,
            ),
          ],
          historyLimited: false,
          hasOlder: false,
        );
        final repository = _FakeConversationRepository(snapshot: snapshot);

        // First mount.
        await tester.pumpWidget(
          _buildApp(
            repository: repository,
            child: ConversationDetailPage(target: target),
          ),
        );
        await tester.pumpAndSettle();

        // Extract GlobalKey from the first incarnation.
        final firstSubtrees = find.byType(KeyedSubtree).evaluate();
        final firstGlobalKeys = firstSubtrees
            .where((e) => (e.widget as KeyedSubtree).key is GlobalKey)
            .map((e) => (e.widget as KeyedSubtree).key as GlobalKey)
            .toList();
        expect(firstGlobalKeys, isNotEmpty);
        final firstKeyIdentity = firstGlobalKeys.first;

        // Navigate away (dispose).
        final context = tester.element(find.byType(ConversationDetailPage));
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('gone')),
          ),
        );
        await tester.pumpAndSettle();

        // Re-mount with same messages.
        await tester.pumpWidget(
          _buildApp(
            repository: repository,
            child: ConversationDetailPage(target: target),
          ),
        );
        await tester.pumpAndSettle();

        // Extract GlobalKey from the second incarnation.
        final secondSubtrees = find.byType(KeyedSubtree).evaluate();
        final secondGlobalKeys = secondSubtrees
            .where((e) => (e.widget as KeyedSubtree).key is GlobalKey)
            .map((e) => (e.widget as KeyedSubtree).key as GlobalKey)
            .toList();
        expect(secondGlobalKeys, isNotEmpty);
        final secondKeyIdentity = secondGlobalKeys.first;

        // After dispose+clear+recreate, the GlobalKey instance should
        // be a fresh one (different identity), proving putIfAbsent
        // regenerated it from an empty map.
        expect(
          identical(firstKeyIdentity, secondKeyIdentity),
          isFalse,
          reason: 'After dispose+recreate, GlobalKey must be a fresh instance',
        );
      },
      skip:
          true, // Phase A: invariant locked — Phase B adds key cleanup in dispose
    );
  });

  // -----------------------------------------------------------------------
  // INV-MEMCACHE-1: In-chat image thumbnail has memCacheWidth
  // -----------------------------------------------------------------------
  group('INV-MEMCACHE-1: in-chat thumbnail memCacheWidth', () {
    testWidgets(
      'CachedNetworkImage for in-chat image thumbnail includes memCacheWidth',
      (tester) async {
        final target = ConversationDetailTarget.channel(
          const ChannelScopeId(
            serverId: ServerScopeId('server-1'),
            value: 'general',
          ),
        );
        final repository = _FakeConversationRepository(
          snapshot: ConversationDetailSnapshot(
            target: target,
            title: '#general',
            messages: [
              ConversationMessageSummary(
                id: 'msg-img',
                content: '',
                createdAt: DateTime(2026, 5, 1, 10, 0),
                senderType: 'human',
                messageType: 'message',
                seq: 1,
                attachments: const [
                  MessageAttachment(
                    name: 'photo.jpg',
                    type: 'image/jpeg',
                    url: 'https://example.com/photo.jpg',
                    thumbnailUrl: 'https://example.com/photo_thumb.jpg',
                    id: 'att-1',
                  ),
                ],
              ),
            ],
            historyLimited: false,
            hasOlder: false,
          ),
        );

        await tester.pumpWidget(
          _buildApp(
            repository: repository,
            child: ConversationDetailPage(target: target),
          ),
        );
        await tester.pumpAndSettle();

        // Find the CachedNetworkImage used for the inline thumbnail.
        final images = find.byType(CachedNetworkImage);
        expect(images, findsWidgets,
            reason: 'At least one CachedNetworkImage should render');

        // The thumbnail image should have memCacheWidth set to constrain
        // the decoded bitmap size in memory.
        final thumbnailWidget = tester.widgetList<CachedNetworkImage>(images);
        final hasCacheWidth = thumbnailWidget.any(
          (img) => img.memCacheWidth != null && img.memCacheWidth! > 0,
        );
        expect(hasCacheWidth, isTrue,
            reason:
                'In-chat thumbnail must have memCacheWidth to limit memory');
      },
      skip: true, // Phase A: invariant locked — Phase B adds memCacheWidth
    );
  });

  // -----------------------------------------------------------------------
  // INV-MEMCACHE-2: Link preview card CachedNetworkImage has memCacheHeight
  // -----------------------------------------------------------------------
  group('INV-MEMCACHE-2: link preview memCacheHeight', () {
    testWidgets(
      'LinkPreviewCard CachedNetworkImage includes memCacheHeight',
      (tester) async {
        // LinkPreviewCard is a standalone widget — pump directly.
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: LinkPreviewCard(
                metadata: LinkMetadata(
                  url: 'https://example.com/article',
                  title: 'Example Article',
                  description: 'An interesting article.',
                  imageUrl: 'https://example.com/preview.jpg',
                  domain: 'example.com',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the CachedNetworkImage inside the link preview card.
        final images = find.descendant(
          of: find.byKey(const ValueKey('link-preview-card')),
          matching: find.byType(CachedNetworkImage),
        );
        expect(images, findsOneWidget,
            reason: 'Link preview card should render one CachedNetworkImage');

        final img = tester.widget<CachedNetworkImage>(images);
        expect(img.memCacheHeight, isNotNull,
            reason: 'Link preview image must have memCacheHeight');
        expect(img.memCacheHeight, greaterThan(0),
            reason: 'memCacheHeight must be positive');
      },
      skip: true, // Phase A: invariant locked — Phase B adds memCacheHeight
    );
  });

  // -----------------------------------------------------------------------
  // INV-FULLSCREEN-NO-CAP: Full-screen viewer has no cache constraint
  // -----------------------------------------------------------------------
  group('INV-FULLSCREEN-NO-CAP: full-screen viewer unconstrained', () {
    testWidgets(
      'FilePreviewPage CachedNetworkImage does NOT have memCacheWidth or memCacheHeight',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: const FilePreviewPage(
              attachment: MessageAttachment(
                name: 'photo.jpg',
                type: 'image/jpeg',
                url: 'https://example.com/photo_full.jpg',
                id: 'att-1',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the CachedNetworkImage in the full-screen viewer.
        final images = find.byType(CachedNetworkImage);
        expect(images, findsWidgets,
            reason:
                'Full-screen viewer must render at least one CachedNetworkImage');

        for (final element in images.evaluate()) {
          final img = element.widget as CachedNetworkImage;
          expect(img.memCacheWidth, isNull,
              reason: 'Full-screen viewer must NOT constrain memCacheWidth');
          expect(img.memCacheHeight, isNull,
              reason: 'Full-screen viewer must NOT constrain memCacheHeight');
        }
      },
      skip:
          true, // Phase A: invariant locked — Phase B adds memCacheWidth to thumbnails only
    );
  });
}

// -- Helpers -----------------------------------------------------------------

Widget _buildApp({
  required ConversationRepository repository,
  required Widget child,
  SessionState sessionState = const SessionState(),
}) {
  return ProviderScope(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(repository),
      sessionStoreProvider.overrideWith(
        () => _FixedSessionStore(sessionState),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: _testGoRouter(home: child),
      theme: AppTheme.light,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    ),
  );
}

GoRouter _testGoRouter({Widget? home}) => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => home ?? const SizedBox.shrink(),
        ),
        GoRoute(
          path: '/file-preview',
          builder: (_, state) {
            final attachment = state.extra as MessageAttachment;
            return FilePreviewPage(attachment: attachment);
          },
        ),
      ],
    );

class _FixedSessionStore extends SessionStore {
  _FixedSessionStore(this._state);

  final SessionState _state;

  @override
  SessionState build() => _state;
}

class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({required this.snapshot});

  final ConversationDetailSnapshot snapshot;

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
    return 'test-attachment-id';
  }

  @override
  Future<ConversationMessageSummary> sendMessage(
    ConversationDetailTarget target,
    String content, {
    List<String>? attachmentIds,
    String? replyToId,
    CancelToken? cancelToken,
  }) {
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
    return [];
  }

  @override
  Future<void> removeStoredMessage(
    ConversationDetailTarget target, {
    required String messageId,
  }) async {}
}
