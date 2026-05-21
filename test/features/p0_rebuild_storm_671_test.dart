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
// debugOnRebuildDirtyWidget to detect actual rebuilds at the widget
// boundary.
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
class _ControllableTypingIndicatorStore extends TypingIndicatorStore {
  @override
  TypingIndicatorState build() {
    // Register the same disposal logic as the real store so timers
    // are properly cleaned up when the provider is disposed.
    ref.onDispose(() {
      clearAll();
    });
    return const TypingIndicatorState();
  }
}

// ---------------------------------------------------------------------------
// Rebuild tracking helper
// ---------------------------------------------------------------------------

/// Tracks rebuilds of a specific widget type using debugOnRebuildDirtyWidget.
///
/// Only counts RE-builds (builtOnce == true), not the initial build.
class _RebuildTracker {
  _RebuildTracker(this._targetTypeName);

  final String _targetTypeName;
  int rebuildCount = 0;

  void install() {
    rebuildCount = 0;
    debugOnRebuildDirtyWidget = (Element element, bool builtOnce) {
      if (builtOnce &&
          element.widget.runtimeType.toString() == _targetTypeName) {
        rebuildCount++;
      }
    };
  }

  void reset() {
    rebuildCount = 0;
  }

  void uninstall() {
    debugOnRebuildDirtyWidget = null;
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
    late _RebuildTracker tracker;

    setUp(() {
      tracker = _RebuildTracker('MessageContentWidget');
    });

    tearDown(() {
      tracker.uninstall();
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

        // --- Install tracker AFTER initial build ---
        tracker.install();

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
        expect(tracker.rebuildCount, 0,
            reason: 'Resolving an unrelated URL must not rebuild '
                'MessageContentWidget when using .select()');

        // Now update URL-A — this SHOULD trigger a rebuild.
        tracker.reset();
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

        expect(tracker.rebuildCount, 1,
            reason:
                'Updating the watched URL must trigger exactly one rebuild');
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

        // Install tracker after initial build.
        tracker.install();

        // Set URL-A to loading.
        final notifier = container.read(linkPreviewCacheProvider.notifier);
        notifier.state = {urlA: const AsyncValue<LinkMetadata?>.loading()};
        await tester.pump();

        expect(tracker.rebuildCount, 1,
            reason: 'Loading state is different from null — triggers rebuild');

        // Resolve URL-A to data.
        tracker.reset();
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

        expect(tracker.rebuildCount, 1,
            reason: 'Data state is different from loading — triggers rebuild');
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
    late _RebuildTracker tracker;
    late TypingIndicatorStore store;

    setUp(() {
      tracker = _RebuildTracker('TypingIndicatorWidget');
    });

    tearDown(() {
      tracker.uninstall();
      // clearAll cancels all expiry timers before container disposal.
      store.clearAll();
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

        // Initially hidden (no typers).
        expect(find.byKey(const ValueKey('typing-indicator')), findsNothing);

        // Add Alice — widget should rebuild and show indicator.
        store = container.read(typingIndicatorStoreProvider.notifier);
        store.addTyper(userId: 'u1', displayName: 'Alice');
        await tester.pump();

        expect(find.text('Alice is typing...'), findsOneWidget);

        // Install tracker AFTER the first meaningful render.
        tracker.install();

        // Refresh Alice (same userId, same displayName).
        // This mutates the store state (timer reset, new list object)
        // but displayText remains "Alice is typing...".
        store.addTyper(userId: 'u1', displayName: 'Alice');
        await tester.pump();

        expect(tracker.rebuildCount, 0,
            reason: 'Refreshing the same typer does not change displayText — '
                'widget must not rebuild when using .select()');

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

        // Install tracker.
        tracker.install();

        // Add Bob — displayText changes from "Alice is typing..." to
        // "Alice and Bob are typing..."
        store.addTyper(userId: 'u2', displayName: 'Bob');
        await tester.pump();

        expect(tracker.rebuildCount, 1,
            reason: 'Adding a second typer changes displayText — widget must '
                'rebuild');
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

        // Install tracker.
        tracker.install();

        // Remove Alice — displayText changes from "Alice is typing..." to null.
        store.removeTyper('u1');
        await tester.pump();

        expect(tracker.rebuildCount, 1,
            reason: 'Removing the last typer changes displayText to null — '
                'widget must rebuild');
        expect(find.byKey(const ValueKey('typing-indicator')), findsNothing);
      },
    );
  });
}
