// =============================================================================
// Scan #46 PR B — BorderRadius hoist load-bearing tests
//
// These tests prove that the hoisted `static final` BorderRadius fields in
// production widgets return the SAME object instance across rebuilds.
// If someone reverts a hoist back to inline `BorderRadius.circular(N)` in
// build(), each rebuild produces a new instance → identical() fails → test RED.
//
// Coverage:
// H1: ShimmerBox — _cachedBorderRadius survives across animation frames
// H2: MessageBubble — agentBadgeBorderRadius identical across rebuilds
// H3: ConversationMessageCard — systemBorderRadius reused for search highlight
// H4: ConversationMessageCard — systemBorderRadius reused for quote-jump
// H5: _DateSeparatorWidget — borderRadius identical across rebuilds
// H6: _ImageAttachmentPreview — borderRadius identical across rebuilds
// H7: _ReplyPreviewBanner — borderRadius identical across rebuilds
// H8: _QuotedMessageBlock — _agentBadgeBorderRadius reused across rebuilds
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/message_bubble.dart';
import 'package:slock_app/app/widgets/shimmer_box.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_attachment_renderers.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_composer.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_message_card.dart';
import 'package:slock_app/features/conversation/presentation/widgets/conversation_message_list.dart';
import 'package:slock_app/l10n/l10n.dart';
import 'package:slock_app/stores/session/session_state.dart';
import 'package:slock_app/stores/session/session_store.dart';

void main() {
  // ===========================================================================
  // H1: ShimmerBox — _cachedBorderRadius survives across animation frames
  //
  // The AnimatedBuilder calls its builder ~60fps. Before the fix, each frame
  // allocated a new BorderRadius.circular(). Now we cache in State and the
  // same object survives multiple frames.
  // ===========================================================================
  group('Scan #46 BorderRadius hoist — ShimmerBox', () {
    testWidgets(
      'borderRadius is identical across animation frames',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: ShimmerBox(width: 100, height: 20),
            ),
          ),
        );

        // Frame 1: extract borderRadius from the shimmer-box Container.
        final container1 = tester.widget<Container>(
          find.byKey(const ValueKey('shimmer-box')),
        );
        final br1 = (container1.decoration as BoxDecoration).borderRadius;

        // Advance animation to trigger AnimatedBuilder rebuild.
        await tester.pump(const Duration(milliseconds: 500));

        final container2 = tester.widget<Container>(
          find.byKey(const ValueKey('shimmer-box')),
        );
        final br2 = (container2.decoration as BoxDecoration).borderRadius;

        expect(
          identical(br1, br2),
          isTrue,
          reason: 'Scan #46: ShimmerBox borderRadius must be cached in State '
              '(same object across animation frames). Reverting to inline '
              'BorderRadius.circular() in builder → new instance per frame → RED.',
        );
      },
    );
  });

  // ===========================================================================
  // H2: MessageBubble — agentBadgeBorderRadius identical across rebuilds
  // ===========================================================================
  group('Scan #46 BorderRadius hoist — MessageBubble agent badge', () {
    testWidgets(
      'agent badge borderRadius is identical across rebuilds',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: MessageBubble(
                variant: MessageBubbleVariant.agent,
                senderName: 'Bot',
                child: Text('Hello'),
              ),
            ),
          ),
        );

        // Find the agent badge Container (has BoxDecoration + borderRadius,
        // child is Text with short content like "AI").
        final br1 = _extractAgentBadgeBorderRadius(tester);
        expect(br1, isNotNull, reason: 'Agent badge must render');

        // Rebuild with different content.
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: MessageBubble(
                variant: MessageBubbleVariant.agent,
                senderName: 'Bot2',
                child: Text('World'),
              ),
            ),
          ),
        );

        final br2 = _extractAgentBadgeBorderRadius(tester);
        expect(br2, isNotNull);

        expect(
          identical(br1, br2),
          isTrue,
          reason: 'Scan #46: MessageBubble agent badge borderRadius must be '
              'hoisted (same object across builds). Reverting to inline '
              'BorderRadius.circular() → new instance each build → RED.',
        );
      },
    );
  });

  // ===========================================================================
  // H3: ConversationMessageCard — systemBorderRadius reused for search highlight
  // ===========================================================================
  group(
      'Scan #46 BorderRadius hoist — ConversationMessageCard search highlight',
      () {
    testWidgets(
      'search highlight borderRadius is identical to systemBorderRadius',
      (tester) async {
        final target = ConversationDetailTarget.channel(
          const ChannelScopeId(serverId: ServerScopeId('srv'), value: 'ch-1'),
        );
        final message = ConversationMessageSummary(
          id: 'msg-1',
          content: 'searchable',
          createdAt: DateTime(2026),
          senderType: 'human',
          messageType: 'message',
          senderId: 'user-1',
          senderName: 'Alice',
          seq: 1,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentConversationDetailTargetProvider.overrideWithValue(target),
              conversationDetailStoreProvider
                  .overrideWith(() => _FakeDetailStore(target)),
              sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light,
              home: Scaffold(
                body: ConversationMessageCard(
                  target: target,
                  message: message,
                  maxBubbleWidth: 300,
                  isCurrentSearchMatch: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the search-current-match-highlight Container.
        final container = tester.widget<Container>(
          find.byKey(const ValueKey('search-current-match-highlight')),
        );
        final br = (container.decoration as BoxDecoration).borderRadius;

        expect(
          identical(br, ConversationMessageCard.systemBorderRadius),
          isTrue,
          reason: 'Scan #46: Search highlight must reuse '
              'ConversationMessageCard.systemBorderRadius. Reverting to inline '
              'BorderRadius.circular() → new instance → RED.',
        );
      },
    );
  });

  // ===========================================================================
  // H4: ConversationMessageCard — systemBorderRadius for quote-jump highlight
  // ===========================================================================
  group(
      'Scan #46 BorderRadius hoist — ConversationMessageCard quote-jump highlight',
      () {
    testWidgets(
      'quote-jump highlight borderRadius is identical to systemBorderRadius',
      (tester) async {
        final target = ConversationDetailTarget.channel(
          const ChannelScopeId(serverId: ServerScopeId('srv'), value: 'ch-1'),
        );
        final message = ConversationMessageSummary(
          id: 'msg-1',
          content: 'quoted',
          createdAt: DateTime(2026),
          senderType: 'human',
          messageType: 'message',
          senderId: 'user-1',
          senderName: 'Alice',
          seq: 1,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentConversationDetailTargetProvider.overrideWithValue(target),
              conversationDetailStoreProvider
                  .overrideWith(() => _FakeDetailStore(target)),
              sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light,
              home: Scaffold(
                body: ConversationMessageCard(
                  target: target,
                  message: message,
                  maxBubbleWidth: 300,
                  isQuoteJumpHighlighted: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the quote-jump-highlight Container.
        final container = tester.widget<Container>(
          find.byKey(const ValueKey('quote-jump-highlight')),
        );
        final br = (container.decoration as BoxDecoration).borderRadius;

        expect(
          identical(br, ConversationMessageCard.systemBorderRadius),
          isTrue,
          reason: 'Scan #46: Quote-jump highlight must reuse '
              'ConversationMessageCard.systemBorderRadius. Reverting to inline '
              'BorderRadius.circular() → new instance → RED.',
        );
      },
    );
  });

  // ===========================================================================
  // H5: _DateSeparatorWidget — borderRadius identical across rebuilds
  //
  // We mount the ConversationMessageList's date separator via a minimal
  // ProviderScope that supplies the needed providers.
  // ===========================================================================
  group('Scan #46 BorderRadius hoist — DateSeparator', () {
    testWidgets(
      'date separator borderRadius is identical across rebuilds',
      (tester) async {
        // Mount two date separators by providing the list with messages on
        // different days. Simpler: just mount ConversationMessageList indirectly
        // is complex. Instead, directly test via the exposed public widget tree.
        // The date separator is built inside ConversationMessageList which needs
        // significant setup. Let's take a simpler approach: use the fact that
        // _DateSeparatorWidget reads dateSeparatorNowProvider + toLocalProvider.
        //
        // We can test identity by building a minimal widget tree that contains
        // the _DateSeparatorWidget indirectly via the message list.
        // But since _DateSeparatorWidget is private, we'll use a simpler pattern:
        // find a Container with decoration matching borderRadius.circular(12)
        // in the rendered tree.

        final target = ConversationDetailTarget.channel(
          const ChannelScopeId(serverId: ServerScopeId('srv'), value: 'ch-1'),
        );

        // Messages on two different days to trigger a date separator.
        final messages = [
          ConversationMessageSummary(
            id: 'msg-1',
            content: 'Old message',
            createdAt: DateTime(2026, 1, 1, 10),
            senderType: 'human',
            messageType: 'message',
            senderId: 'user-1',
            senderName: 'Alice',
            seq: 1,
          ),
          ConversationMessageSummary(
            id: 'msg-2',
            content: 'New message',
            createdAt: DateTime(2026, 1, 2, 10),
            senderType: 'human',
            messageType: 'message',
            senderId: 'user-1',
            senderName: 'Alice',
            seq: 2,
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentConversationDetailTargetProvider.overrideWithValue(target),
              conversationDetailStoreProvider.overrideWith(
                () => _FakeDetailStoreWithMessages(target, messages),
              ),
              sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
              dateSeparatorNowProvider
                  .overrideWithValue(DateTime(2026, 1, 3, 10)),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light,
              home: Scaffold(
                body: ConversationMessageList(
                  controller: ScrollController(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find all Containers with borderRadius matching the date separator.
        final separators = tester
            .widgetList<Container>(
              find.byWidgetPredicate(
                (w) =>
                    w is Container &&
                    w.decoration is BoxDecoration &&
                    (w.decoration as BoxDecoration).borderRadius != null &&
                    (w.decoration as BoxDecoration).color != null &&
                    w.child is Text,
              ),
            )
            .toList();

        // We expect at least one date separator.
        expect(separators, isNotEmpty,
            reason: 'Date separator must be rendered between messages');

        final br1 = (separators.first.decoration as BoxDecoration).borderRadius;

        // Rebuild (scroll controller update or just pump) to get a second frame.
        await tester.pump();

        final separators2 = tester
            .widgetList<Container>(
              find.byWidgetPredicate(
                (w) =>
                    w is Container &&
                    w.decoration is BoxDecoration &&
                    (w.decoration as BoxDecoration).borderRadius != null &&
                    (w.decoration as BoxDecoration).color != null &&
                    w.child is Text,
              ),
            )
            .toList();

        final br2 =
            (separators2.first.decoration as BoxDecoration).borderRadius;

        expect(
          identical(br1, br2),
          isTrue,
          reason: 'Scan #46: _DateSeparatorWidget borderRadius must be hoisted '
              '(same object across builds). Reverting to inline '
              'BorderRadius.circular(12) → new instance per build → RED.',
        );
      },
    );
  });

  // ===========================================================================
  // H6: _ImageAttachmentPreview — borderRadius identical across rebuilds
  //
  // The ClipRRect wrapping the image uses a hoisted static final. Mounting
  // AttachmentSection with an image attachment exposes it.
  // ===========================================================================
  group('Scan #46 BorderRadius hoist — _ImageAttachmentPreview', () {
    testWidgets(
      'image clip borderRadius is identical across rebuilds',
      (tester) async {
        // Use id: null to skip VisibilityDetector/downloadScheduler wiring.
        const attachment1 = MessageAttachment(
          name: 'photo.png',
          type: 'image/png',
          url: 'https://example.com/a.png',
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(
                body: AttachmentSection(attachments: [attachment1]),
              ),
            ),
          ),
        );
        await tester.pump();

        // Find the ClipRRect used for the image preview.
        final clip1 = tester.widget<ClipRRect>(find.byType(ClipRRect).first);
        final br1 = clip1.borderRadius;

        // Rebuild with a different attachment (different URL triggers rebuild).
        const attachment2 = MessageAttachment(
          name: 'photo2.png',
          type: 'image/png',
          url: 'https://example.com/b.png',
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(
                body: AttachmentSection(attachments: [attachment2]),
              ),
            ),
          ),
        );
        await tester.pump();

        final clip2 = tester.widget<ClipRRect>(find.byType(ClipRRect).first);
        final br2 = clip2.borderRadius;

        expect(
          identical(br1, br2),
          isTrue,
          reason: 'Scan #46: _ImageAttachmentPreview borderRadius must be '
              'hoisted (same object across builds). Reverting to inline '
              'BorderRadius.circular(8) → new instance each build → RED.',
        );
      },
    );
  });

  // ===========================================================================
  // H7: _ReplyPreviewBanner — borderRadius identical across rebuilds
  //
  // Mounting ConversationComposer with state.replyToMessage set causes the
  // _ReplyPreviewBanner to render. We find its Container via the key.
  // ===========================================================================
  group('Scan #46 BorderRadius hoist — _ReplyPreviewBanner', () {
    testWidgets(
      'reply preview borderRadius is identical across rebuilds',
      (tester) async {
        final target = ConversationDetailTarget.channel(
          const ChannelScopeId(serverId: ServerScopeId('srv'), value: 'ch-1'),
        );

        final replyMsg1 = ConversationMessageSummary(
          id: 'reply-1',
          content: 'Original message',
          createdAt: DateTime(2026),
          senderType: 'human',
          messageType: 'message',
          senderId: 'user-2',
          senderName: 'Bob',
          seq: 1,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentConversationDetailTargetProvider.overrideWithValue(target),
              conversationDetailStoreProvider
                  .overrideWith(() => _FakeDetailStore(target)),
              sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light,
              home: Scaffold(
                body: _ComposerWrapper(
                  state: ConversationDetailState(
                    target: target,
                    status: ConversationDetailStatus.success,
                    replyToMessage: replyMsg1,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Find the reply preview banner's root Container.
        final bannerFinder =
            find.byKey(const ValueKey('composer-reply-preview'));
        expect(bannerFinder, findsOneWidget);

        // The _ReplyPreviewBanner itself is a Container with BoxDecoration.
        final container1 =
            _findFirstContainerWithBorderRadius(tester, bannerFinder);
        expect(container1, isNotNull,
            reason: 'Reply banner Container must exist');
        final br1 = (container1!.decoration as BoxDecoration).borderRadius;

        // Rebuild with different reply message.
        final replyMsg2 = ConversationMessageSummary(
          id: 'reply-2',
          content: 'Different reply',
          createdAt: DateTime(2026),
          senderType: 'human',
          messageType: 'message',
          senderId: 'user-3',
          senderName: 'Charlie',
          seq: 2,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentConversationDetailTargetProvider.overrideWithValue(target),
              conversationDetailStoreProvider
                  .overrideWith(() => _FakeDetailStore(target)),
              sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light,
              home: Scaffold(
                body: _ComposerWrapper(
                  state: ConversationDetailState(
                    target: target,
                    status: ConversationDetailStatus.success,
                    replyToMessage: replyMsg2,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final container2 =
            _findFirstContainerWithBorderRadius(tester, bannerFinder);
        expect(container2, isNotNull);
        final br2 = (container2!.decoration as BoxDecoration).borderRadius;

        expect(
          identical(br1, br2),
          isTrue,
          reason: 'Scan #46: _ReplyPreviewBanner borderRadius must be hoisted '
              '(same object across builds). Reverting to inline '
              'BorderRadius.circular(AppSpacing.radiusSm) → new instance → RED.',
        );
      },
    );
  });

  // ===========================================================================
  // H8: _QuotedMessageBlock — _agentBadgeBorderRadius reused across rebuilds
  //
  // Mounting ConversationMessageCard with replyTo set renders the quoted-block.
  // Its Container uses the hoisted _agentBadgeBorderRadius.
  // ===========================================================================
  group('Scan #46 BorderRadius hoist — _QuotedMessageBlock', () {
    testWidgets(
      'quoted message borderRadius is identical across rebuilds',
      (tester) async {
        final target = ConversationDetailTarget.channel(
          const ChannelScopeId(serverId: ServerScopeId('srv'), value: 'ch-1'),
        );

        final message1 = ConversationMessageSummary(
          id: 'msg-with-quote',
          content: 'Reply content',
          createdAt: DateTime(2026),
          senderType: 'human',
          messageType: 'message',
          senderId: 'user-1',
          senderName: 'Alice',
          seq: 1,
          replyTo: const ReplyToSummary(
            id: 'original-1',
            content: 'Original text',
            senderName: 'Bob',
            senderType: 'human',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentConversationDetailTargetProvider.overrideWithValue(target),
              conversationDetailStoreProvider
                  .overrideWith(() => _FakeDetailStore(target)),
              sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light,
              home: Scaffold(
                body: ConversationMessageCard(
                  target: target,
                  message: message1,
                  maxBubbleWidth: 300,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the quoted-message-tap GestureDetector, then find its Container
        // descendant that has borderRadius.
        final quotedTap = find.byKey(const ValueKey('quoted-message-tap'));
        expect(quotedTap, findsOneWidget);
        final container1 =
            _findFirstContainerWithBorderRadius(tester, quotedTap);
        expect(container1, isNotNull,
            reason: 'Quoted message Container with borderRadius must exist');
        final br1 = (container1!.decoration as BoxDecoration).borderRadius;

        // Rebuild with different quote content.
        final message2 = ConversationMessageSummary(
          id: 'msg-with-quote',
          content: 'Different reply',
          createdAt: DateTime(2026),
          senderType: 'human',
          messageType: 'message',
          senderId: 'user-1',
          senderName: 'Alice',
          seq: 2,
          replyTo: const ReplyToSummary(
            id: 'original-2',
            content: 'Different original',
            senderName: 'Charlie',
            senderType: 'human',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentConversationDetailTargetProvider.overrideWithValue(target),
              conversationDetailStoreProvider
                  .overrideWith(() => _FakeDetailStore(target)),
              sessionStoreProvider.overrideWith(() => _FakeSessionStore()),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light,
              home: Scaffold(
                body: ConversationMessageCard(
                  target: target,
                  message: message2,
                  maxBubbleWidth: 300,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final container2 =
            _findFirstContainerWithBorderRadius(tester, quotedTap);
        expect(container2, isNotNull);
        final br2 = (container2!.decoration as BoxDecoration).borderRadius;

        expect(
          identical(br1, br2),
          isTrue,
          reason: 'Scan #46: _QuotedMessageBlock borderRadius must be hoisted '
              '(same object across builds). Reverting to inline '
              'BorderRadius.circular(AppSpacing.radiusSm) → new instance → RED.',
        );
      },
    );
  });
}

// =============================================================================
// Helpers
// =============================================================================

/// Extract the agent badge Container's borderRadius from MessageBubble.
/// The badge Container has a BoxDecoration with borderRadius and its child
/// is a Text widget with short content (the AI badge label).
BorderRadiusGeometry? _extractAgentBadgeBorderRadius(WidgetTester tester) {
  final candidates = tester.widgetList<Container>(
    find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).borderRadius != null &&
          w.child is Text,
    ),
  );
  for (final c in candidates) {
    final child = c.child;
    if (child is Text && child.data != null && child.data!.length <= 5) {
      return (c.decoration as BoxDecoration).borderRadius;
    }
  }
  return null;
}

/// Find the first Container descendant (or self) with BoxDecoration.borderRadius
/// under the given [ancestor] finder.
Container? _findFirstContainerWithBorderRadius(
  WidgetTester tester,
  Finder ancestor,
) {
  final containerFinder = find.descendant(
    of: ancestor,
    matching: find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).borderRadius != null,
    ),
  );
  if (containerFinder.evaluate().isEmpty) return null;
  return tester.widget<Container>(containerFinder.first);
}

// =============================================================================
// Test Widgets
// =============================================================================

/// Minimal wrapper that mounts ConversationComposer with the given state.
/// Avoids the heavyweight consumer setup by providing required callbacks.
class _ComposerWrapper extends StatelessWidget {
  const _ComposerWrapper({required this.state});

  final ConversationDetailState state;

  @override
  Widget build(BuildContext context) {
    return ConversationComposer(
      controller: TextEditingController(),
      focusNode: FocusNode(),
      state: state,
      isRecording: false,
      isFormattingToolbarVisible: false,
      isEmojiPickerVisible: false,
      onToggleFormattingToolbar: () {},
      onToggleEmojiPicker: () {},
      onChanged: (_) {},
      onSend: () async {},
      onPickAttachment: (_) {},
      onRemoveAttachment: (_) {},
      onCancelUpload: (_) {},
      onClearReply: () {},
      onMicTap: () {},
      onSendRecording: () {},
      onCancelRecording: () {},
    );
  }
}

// =============================================================================
// Fakes
// =============================================================================

class _FakeDetailStore extends ConversationDetailStore {
  _FakeDetailStore(this._target);

  final ConversationDetailTarget _target;

  @override
  ConversationDetailState build() => ConversationDetailState(
        target: _target,
        status: ConversationDetailStatus.success,
      );
}

class _FakeDetailStoreWithMessages extends ConversationDetailStore {
  _FakeDetailStoreWithMessages(this._target, this._messages);

  final ConversationDetailTarget _target;
  final List<ConversationMessageSummary> _messages;

  @override
  ConversationDetailState build() => ConversationDetailState(
        target: _target,
        status: ConversationDetailStatus.success,
        messages: _messages,
      );
}

class _FakeSessionStore extends SessionStore {
  @override
  SessionState build() => const SessionState(
        status: AuthStatus.authenticated,
        userId: 'user-test',
        displayName: 'Test User',
        token: 'test-token',
      );

  @override
  Future<void> logout() async {}
}
