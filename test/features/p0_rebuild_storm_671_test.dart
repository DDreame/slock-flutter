// =============================================================================
// #671 — P0 linkPreview rebuild storm + typing indicator .select()
//
// Fix 1 Invariant: INV-SELECT-671-LINKPREVIEW
//   MessageContentWidget watches linkPreviewCacheProvider via
//   .select((cache) => cache[_detectedUrl]) so that resolving URL-B does
//   NOT cause the widget displaying URL-A to rebuild.
//
// Fix 2 Invariant: INV-SELECT-671-TYPING
//   TypingIndicatorWidget watches typingIndicatorStoreProvider via
//   .select((s) => s.displayText) so that mutations to the store that
//   don't change displayText (e.g. timer refresh of same typer) don't
//   cause a rebuild.
//
// Both groups render REAL production widgets and use
// @visibleForTesting static debugBuildCount on the production widgets
// to detect actual rebuilds at the widget boundary.
// =============================================================================

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/conversation/application/typing_indicator_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/message_content_widget.dart';
import 'package:slock_app/features/conversation/presentation/widgets/typing_indicator_widget.dart';
import 'package:slock_app/features/link_preview/application/link_preview_store.dart';
import 'package:slock_app/features/link_preview/data/link_metadata.dart';
import 'package:slock_app/features/link_preview/data/link_preview_service.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// LinkPreviewService that never makes real HTTP calls.
/// Returns null metadata (no OG tags) for any URL so the widget shows
/// the fallback link chip rather than a full preview card.
class _NoOpLinkPreviewService extends LinkPreviewService {
  _NoOpLinkPreviewService() : super(dio: Dio());

  @override
  Future<LinkMetadata?> fetchMetadata(String url) async => null;
}

/// Controllable TypingIndicatorStore for production widget tests.
///
/// Overrides addTyper/removeTyper/clearAll to perform state-only mutations
/// WITHOUT allocating real Timer objects. This avoids "Timer is still pending"
/// failures in the test harness.
class _ControllableTypingIndicatorStore extends TypingIndicatorStore {
  @override
  TypingIndicatorState build() {
    ref.onDispose(() {});
    return const TypingIndicatorState();
  }

  @override
  void addTyper({
    required String userId,
    required String displayName,
    Duration expiry = kTypingIndicatorExpiry,
  }) {
    // State-only mutation — no real Timer allocation.
    final existing = state.activeTypers;
    final updated = existing.where((t) => t.userId != userId).toList()
      ..add(ActiveTyper(userId: userId, displayName: displayName));
    state = state.copyWith(activeTypers: updated);
  }

  @override
  void removeTyper(String userId) {
    // State-only mutation — no timer interaction.
    final updated =
        state.activeTypers.where((t) => t.userId != userId).toList();
    if (updated.length != state.activeTypers.length) {
      state = state.copyWith(activeTypers: updated);
    }
  }

  @override
  void clearAll() {
    state = const TypingIndicatorState();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ---------------------------------------------------------------------------
  // Fix 1: linkPreviewCache .select() — production widget rebuild isolation
  // ---------------------------------------------------------------------------
  group('Fix 1: MessageContentWidget rebuild isolation (production widget)',
      () {
    late ProviderContainer container;

    setUp(() {
      MessageContentWidget.debugBuildCount = 0;
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets(
      'INV-SELECT-671-LINKPREVIEW: resolving URL-B does NOT rebuild '
      'MessageContentWidget watching URL-A',
      (tester) async {
        const urlA = 'https://example.com/page-a';
        const urlB = 'https://example.com/page-b';

        container = ProviderContainer(
          overrides: [
            linkPreviewServiceProvider
                .overrideWithValue(_NoOpLinkPreviewService()),
          ],
        );

        // Pre-seed cache with URL-A resolved so the widget renders preview.
        final notifier = container.read(linkPreviewCacheProvider.notifier);
        notifier.state = {
          urlA: const AsyncValue.data(
            LinkMetadata(
              url: urlA,
              title: 'Page A Title',
              domain: 'example.com',
            ),
          ),
        };

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: MessageContentWidget(
                  message: ConversationMessageSummary(
                    id: 'msg-1',
                    content: 'Check out $urlA for details',
                    createdAt: DateTime(2026, 5, 21),
                    senderType: 'human',
                    messageType: 'text',
                  ),
                ),
              ),
            ),
          ),
        );

        // Let initState microtask fire (fetch attempt — no-op service).
        await tester.pump();

        // Verify the widget is rendering with the preview data.
        expect(find.text('Page A Title'), findsOneWidget);

        // Sanity check: counter incremented during initial builds.
        expect(MessageContentWidget.debugBuildCount, greaterThan(0),
            reason: 'Widget must have built at least once');

        // Record build count after initial render.
        final countAfterInitial = MessageContentWidget.debugBuildCount;

        // Resolve URL-B (irrelevant to this widget).
        notifier.state = {
          ...notifier.state,
          urlB: const AsyncValue.data(
            LinkMetadata(
              url: urlB,
              title: 'Page B Title',
              domain: 'example.com',
            ),
          ),
        };
        await tester.pump();

        // MessageContentWidget MUST NOT have rebuilt.
        expect(
          MessageContentWidget.debugBuildCount,
          countAfterInitial,
          reason: 'Resolving an unrelated URL must not rebuild '
              'MessageContentWidget when using .select()',
        );

        // Now update URL-A — this SHOULD trigger a rebuild.
        notifier.state = {
          ...notifier.state,
          urlA: const AsyncValue.data(
            LinkMetadata(
              url: urlA,
              title: 'Updated Page A',
              domain: 'example.com',
            ),
          ),
        };
        await tester.pump();

        expect(
          MessageContentWidget.debugBuildCount,
          countAfterInitial + 1,
          reason: 'Updating the watched URL must trigger exactly one rebuild',
        );
        expect(find.text('Updated Page A'), findsOneWidget);
      },
    );

    testWidgets(
      'INV-SELECT-671-LINKPREVIEW: transitioning own URL from loading to data '
      'rebuilds MessageContentWidget',
      (tester) async {
        const urlA = 'https://example.com/page-a';

        container = ProviderContainer(
          overrides: [
            linkPreviewServiceProvider
                .overrideWithValue(_NoOpLinkPreviewService()),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: MessageContentWidget(
                  message: ConversationMessageSummary(
                    id: 'msg-2',
                    content: 'Visit $urlA now',
                    createdAt: DateTime(2026, 5, 21),
                    senderType: 'human',
                    messageType: 'text',
                  ),
                ),
              ),
            ),
          ),
        );

        // Let initState microtask fire.
        await tester.pump();

        // Sanity check: counter incremented during initial builds.
        expect(MessageContentWidget.debugBuildCount, greaterThan(0),
            reason: 'Widget must have built at least once');

        // Record count after initial render.
        final countAfterInitial = MessageContentWidget.debugBuildCount;

        // Set URL-A to loading.
        final notifier = container.read(linkPreviewCacheProvider.notifier);
        notifier.state = {urlA: const AsyncValue<LinkMetadata?>.loading()};
        await tester.pump();

        expect(
          MessageContentWidget.debugBuildCount,
          countAfterInitial + 1,
          reason: 'Loading state is different from null — triggers rebuild',
        );

        // Resolve URL-A to data.
        notifier.state = {
          urlA: const AsyncValue.data(
            LinkMetadata(
              url: urlA,
              title: 'Resolved Title',
              domain: 'example.com',
            ),
          ),
        };
        await tester.pump();

        expect(
          MessageContentWidget.debugBuildCount,
          countAfterInitial + 2,
          reason: 'Data state is different from loading — triggers rebuild',
        );
        expect(find.text('Resolved Title'), findsOneWidget);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Fix 2: typingIndicator .select() — production widget rebuild isolation
  // ---------------------------------------------------------------------------
  group('Fix 2: TypingIndicatorWidget rebuild isolation (production widget)',
      () {
    late ProviderContainer container;
    late TypingIndicatorStore store;

    setUp(() {
      TypingIndicatorWidget.debugBuildCount = 0;
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets(
      'INV-SELECT-671-TYPING: refreshing same typer does NOT rebuild '
      'TypingIndicatorWidget',
      (tester) async {
        container = ProviderContainer(
          overrides: [
            typingIndicatorStoreProvider
                .overrideWith(() => _ControllableTypingIndicatorStore()),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light,
              home: const Scaffold(
                body: TypingIndicatorWidget(),
              ),
            ),
          ),
        );
        await tester.pump();

        // Sanity check: counter incremented during initial builds.
        expect(TypingIndicatorWidget.debugBuildCount, greaterThan(0),
            reason: 'Widget must have built at least once');

        // Initially hidden (no typers).
        expect(find.byKey(const ValueKey('typing-indicator')), findsNothing);

        // Add Alice — widget should rebuild and show indicator.
        store = container.read(typingIndicatorStoreProvider.notifier);
        store.addTyper(userId: 'u1', displayName: 'Alice');
        await tester.pump();

        expect(find.text('Alice is typing...'), findsOneWidget);

        // Record build count after Alice is displayed.
        final countAfterAlice = TypingIndicatorWidget.debugBuildCount;
        expect(countAfterAlice, greaterThan(1),
            reason: 'Adding Alice must have triggered at least one rebuild');

        // Refresh Alice (same userId, same displayName).
        // This mutates the store state (new list object) but displayText
        // remains "Alice is typing..." — .select() should suppress rebuild.
        store.addTyper(userId: 'u1', displayName: 'Alice');
        await tester.pump();

        expect(
          TypingIndicatorWidget.debugBuildCount,
          countAfterAlice,
          reason: 'Refreshing the same typer does not change displayText — '
              'widget must not rebuild when using .select()',
        );

        // Verify the display is still correct.
        expect(find.text('Alice is typing...'), findsOneWidget);
      },
    );

    testWidgets(
      'INV-SELECT-671-TYPING: adding a second typer DOES rebuild '
      'TypingIndicatorWidget',
      (tester) async {
        container = ProviderContainer(
          overrides: [
            typingIndicatorStoreProvider
                .overrideWith(() => _ControllableTypingIndicatorStore()),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light,
              home: const Scaffold(
                body: TypingIndicatorWidget(),
              ),
            ),
          ),
        );
        await tester.pump();

        // Add Alice.
        store = container.read(typingIndicatorStoreProvider.notifier);
        store.addTyper(userId: 'u1', displayName: 'Alice');
        await tester.pump();
        expect(find.text('Alice is typing...'), findsOneWidget);

        // Record count.
        final countAfterAlice = TypingIndicatorWidget.debugBuildCount;

        // Add Bob — displayText changes from "Alice is typing..." to
        // "Alice and Bob are typing..."
        store.addTyper(userId: 'u2', displayName: 'Bob');
        await tester.pump();

        expect(
          TypingIndicatorWidget.debugBuildCount,
          countAfterAlice + 1,
          reason: 'Adding a second typer changes displayText — widget must '
              'rebuild',
        );
        expect(find.text('Alice and Bob are typing...'), findsOneWidget);
      },
    );

    testWidgets(
      'INV-SELECT-671-TYPING: removing last typer rebuilds '
      'TypingIndicatorWidget back to hidden',
      (tester) async {
        container = ProviderContainer(
          overrides: [
            typingIndicatorStoreProvider
                .overrideWith(() => _ControllableTypingIndicatorStore()),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light,
              home: const Scaffold(
                body: TypingIndicatorWidget(),
              ),
            ),
          ),
        );
        await tester.pump();

        // Add Alice.
        store = container.read(typingIndicatorStoreProvider.notifier);
        store.addTyper(userId: 'u1', displayName: 'Alice');
        await tester.pump();
        expect(find.text('Alice is typing...'), findsOneWidget);

        // Record count.
        final countAfterAlice = TypingIndicatorWidget.debugBuildCount;

        // Remove Alice — displayText changes from "Alice is typing..." to null.
        store.removeTyper('u1');
        await tester.pump();

        expect(
          TypingIndicatorWidget.debugBuildCount,
          countAfterAlice + 1,
          reason: 'Removing the last typer changes displayText to null — '
              'widget must rebuild',
        );
        expect(find.byKey(const ValueKey('typing-indicator')), findsNothing);
      },
    );
  });
}
