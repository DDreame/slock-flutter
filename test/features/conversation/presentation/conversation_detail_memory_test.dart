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
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });
  // Clean up static test hook after each test to avoid cross-test leaks.
  tearDown(() {
    ConversationDetailPage.debugMessageGlobalKeyCount = null;
    VisibilityDetectorController.instance.updateInterval =
        const Duration(milliseconds: 500);
  });

  // -----------------------------------------------------------------------
  // INV-KEY-DISPOSE-1: GlobalKeys map cleared on dispose
  // -----------------------------------------------------------------------
  group('INV-KEY-DISPOSE-1: GlobalKeys cleared on dispose', () {
    testWidgets(
      'messageGlobalKeyCount drops to zero after page dispose',
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

        // Verify the key map is populated while page is mounted.
        final countFn = ConversationDetailPage.debugMessageGlobalKeyCount;
        expect(countFn, isNotNull,
            reason: 'debugMessageGlobalKeyCount hook must be registered');
        expect(countFn!(), greaterThan(0),
            reason: 'Key map must contain entries while messages are rendered');

        // Navigate away — triggers dispose.
        final context = tester.element(find.byType(ConversationDetailPage));
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('gone')),
          ),
        );
        await tester.pumpAndSettle();

        // After dispose, the hook still exists but returns 0 because
        // _messageGlobalKeys.clear() was called in dispose().
        // This distinguishes "map explicitly cleared" from "hook unavailable".
        final postDisposeFn = ConversationDetailPage.debugMessageGlobalKeyCount;
        expect(postDisposeFn, isNotNull,
            reason: 'Hook must survive dispose to observe cleared map');
        expect(postDisposeFn!(), equals(0),
            reason:
                'Key map must be empty after dispose (proves explicit clear)');
      },
    );
  });

  // -----------------------------------------------------------------------
  // INV-KEY-REGEN-1: Keys regenerate after dispose + recreate
  // -----------------------------------------------------------------------
  group('INV-KEY-REGEN-1: key regeneration after dispose', () {
    testWidgets(
      'key count resets to zero on dispose and repopulates on recreate',
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

        // Capture count from first incarnation.
        final firstCountFn = ConversationDetailPage.debugMessageGlobalKeyCount;
        expect(firstCountFn, isNotNull);
        final firstCount = firstCountFn!();
        expect(firstCount, greaterThan(0),
            reason: 'Key map must be populated after first mount');

        // Navigate away (dispose).
        final context = tester.element(find.byType(ConversationDetailPage));
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('gone')),
          ),
        );
        await tester.pumpAndSettle();

        // After dispose, hook returns 0 (map was cleared).
        final midCountFn = ConversationDetailPage.debugMessageGlobalKeyCount;
        expect(midCountFn, isNotNull, reason: 'Hook must survive dispose');
        expect(midCountFn!(), equals(0),
            reason: 'Key map must be 0 after dispose (proves explicit clear)');

        // Re-mount with same messages.
        await tester.pumpWidget(
          _buildApp(
            repository: repository,
            child: ConversationDetailPage(target: target),
          ),
        );
        await tester.pumpAndSettle();

        // After re-creation, the hook now points to the NEW state's map,
        // which has been repopulated via putIfAbsent.
        final secondCountFn = ConversationDetailPage.debugMessageGlobalKeyCount;
        expect(secondCountFn, isNotNull,
            reason: 'Hook must be re-registered after recreate');
        expect(secondCountFn!(), greaterThan(0),
            reason: 'Key map must be repopulated after recreate');
      },
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
        // Use bounded pump instead of pumpAndSettle — the page has
        // ongoing animations/timers that prevent settle.  The fake
        // repository resolves synchronously so one async gap is enough
        // to render message widgets.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
    );
  });

  // -----------------------------------------------------------------------
  // INV-FULLSCREEN-NO-CAP: Full-screen viewer has no cache constraint
  // -----------------------------------------------------------------------
  group('INV-FULLSCREEN-NO-CAP: full-screen viewer unconstrained', () {
    testWidgets(
      'FilePreviewPage CachedNetworkImage does NOT have memCacheWidth or memCacheHeight',
      (tester) async {
        // FilePreviewPage is a ConsumerStatefulWidget — wrap in ProviderScope.
        // Use a null id so _loadAttachment takes the fast fallback path
        // (sets _signedUrl = att.url without needing attachment repo).
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const FilePreviewPage(
                attachment: MessageAttachment(
                  name: 'photo.jpg',
                  type: 'image/jpeg',
                  url: 'https://example.com/photo_full.jpg',
                ),
              ),
            ),
          ),
        );
        // Bounded pump: async gap for _loadAttachment future + build.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

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
  @override
  Future<List<ConversationMessageSummary>?> loadLocalMessages(
    ConversationDetailTarget target,
  ) async =>
      null;

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
  Future<ConversationMessagePage> loadMessageContext(
    ConversationDetailTarget target, {
    required String messageId,
  }) async =>
      const ConversationMessagePage(
        messages: [],
        historyLimited: false,
        hasOlder: false,
        hasNewer: false,
      );

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
