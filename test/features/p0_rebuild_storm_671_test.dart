// =============================================================================
// #671 — P0 linkPreview rebuild storm + typing indicator .select()
//
// Fix 1 Invariant: INV-SELECT-671-LINKPREVIEW
//   MessageContentWidget watches linkPreviewCacheProvider via
//   .select((cache) => cache[_detectedUrl]) so that resolving URL-B does
//   NOT cause a widget displaying URL-A to rebuild.
//
// Fix 2 Invariant: INV-SELECT-671-TYPING
//   TypingIndicatorWidget watches typingIndicatorStoreProvider via
//   .select((s) => s.displayText) so that mutations to the store that
//   don't change displayText (e.g. timer refresh of same typer) don't
//   cause a rebuild.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/conversation/application/typing_indicator_store.dart';
import 'package:slock_app/features/link_preview/application/link_preview_store.dart';
import 'package:slock_app/features/link_preview/data/link_metadata.dart';

// ---------------------------------------------------------------------------
// Fix 1: Link Preview — probe widget that mirrors the .select() expression
// ---------------------------------------------------------------------------

/// A probe that watches the link preview cache for a specific URL,
/// matching the exact .select() expression used in MessageContentWidget.
/// Counts rebuild invocations.
class _LinkPreviewProbe extends ConsumerWidget {
  const _LinkPreviewProbe({required this.url, required this.onBuild});

  final String url;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    onBuild();
    final asyncMeta = ref.watch(
      linkPreviewCacheProvider.select((cache) => cache[url]),
    );
    final label = asyncMeta?.valueOrNull?.title ?? 'none';
    return Text(label, textDirection: TextDirection.ltr);
  }
}

// ---------------------------------------------------------------------------
// Fix 2: Typing Indicator — probe widget that mirrors the .select()
// ---------------------------------------------------------------------------

/// A probe that watches typingIndicatorStoreProvider.select((s) => s.displayText)
/// matching the exact expression used in TypingIndicatorWidget.
class _TypingDisplayTextProbe extends ConsumerWidget {
  const _TypingDisplayTextProbe({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    onBuild();
    final displayText = ref.watch(
      typingIndicatorStoreProvider.select((s) => s.displayText),
    );
    return Text(displayText ?? 'idle', textDirection: TextDirection.ltr);
  }
}

// ---------------------------------------------------------------------------
// Controllable store for typing indicator
// ---------------------------------------------------------------------------

class _ControllableTypingIndicatorStore extends TypingIndicatorStore {
  @override
  TypingIndicatorState build() {
    ref.onDispose(() {});
    return const TypingIndicatorState();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ---------------------------------------------------------------------------
  // Fix 1: linkPreviewCache .select() — rebuild isolation
  // ---------------------------------------------------------------------------
  group('Fix 1: linkPreview rebuild storm isolation', () {
    testWidgets(
      'INV-SELECT-671-LINKPREVIEW: resolving URL-B does NOT rebuild widget '
      'watching URL-A',
      (tester) async {
        int probeBuilds = 0;
        const urlA = 'https://example.com/page-a';
        const urlB = 'https://example.com/page-b';

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: _LinkPreviewProbe(
              url: urlA,
              onBuild: () => probeBuilds++,
            ),
          ),
        );

        // Initial build.
        expect(probeBuilds, 1);
        expect(find.text('none'), findsOneWidget);

        // Resolve URL-B in the cache (irrelevant to our probe).
        final notifier = container.read(linkPreviewCacheProvider.notifier);
        // Directly mutate state to inject URL-B entry.
        notifier.state = {
          ...notifier.state,
          urlB: const AsyncValue.data(
            LinkMetadata(
              url: urlB,
              title: 'Page B',
              domain: 'example.com',
            ),
          ),
        };
        await tester.pump();

        // Probe should NOT have rebuilt — URL-A entry is still null.
        expect(probeBuilds, 1,
            reason:
                'Resolving a different URL must not trigger rebuild of widget '
                'watching URL-A');

        // Now resolve URL-A — probe SHOULD rebuild.
        notifier.state = {
          ...notifier.state,
          urlA: const AsyncValue.data(
            LinkMetadata(
              url: urlA,
              title: 'Page A',
              domain: 'example.com',
            ),
          ),
        };
        await tester.pump();

        expect(probeBuilds, 2,
            reason: 'Resolving URL-A must trigger rebuild of widget watching '
                'URL-A');
        expect(find.text('Page A'), findsOneWidget);
      },
    );

    testWidgets(
      'INV-SELECT-671-LINKPREVIEW: transitioning URL-A from loading to data '
      'triggers rebuild',
      (tester) async {
        int probeBuilds = 0;
        const urlA = 'https://example.com/page-a';

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: _LinkPreviewProbe(
              url: urlA,
              onBuild: () => probeBuilds++,
            ),
          ),
        );

        expect(probeBuilds, 1);

        // Set URL-A to loading.
        final notifier = container.read(linkPreviewCacheProvider.notifier);
        notifier.state = {urlA: const AsyncValue<LinkMetadata?>.loading()};
        await tester.pump();

        // Loading is a different value from null, so should rebuild.
        expect(probeBuilds, 2);
        expect(find.text('none'), findsOneWidget);

        // Resolve URL-A to data.
        notifier.state = {
          urlA: const AsyncValue.data(
            LinkMetadata(
              url: urlA,
              title: 'Resolved',
              domain: 'example.com',
            ),
          ),
        };
        await tester.pump();

        expect(probeBuilds, 3);
        expect(find.text('Resolved'), findsOneWidget);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Fix 2: typingIndicator .select() — rebuild isolation
  // ---------------------------------------------------------------------------
  group('Fix 2: typing indicator displayText .select() isolation', () {
    testWidgets(
      'INV-SELECT-671-TYPING: refreshing same typer does NOT rebuild widget',
      (tester) async {
        int probeBuilds = 0;

        final container = ProviderContainer(
          overrides: [
            typingIndicatorStoreProvider
                .overrideWith(() => _ControllableTypingIndicatorStore()),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: _TypingDisplayTextProbe(onBuild: () => probeBuilds++),
          ),
        );

        expect(probeBuilds, 1);
        expect(find.text('idle'), findsOneWidget);

        // Add Alice — displayText changes from null to "Alice is typing..."
        final store = container.read(typingIndicatorStoreProvider.notifier);
        store.addTyper(userId: 'u1', displayName: 'Alice');
        await tester.pump();

        expect(probeBuilds, 2);
        expect(find.text('Alice is typing...'), findsOneWidget);

        // Refresh Alice (same user, same displayName) — displayText unchanged.
        store.addTyper(userId: 'u1', displayName: 'Alice');
        await tester.pump();

        expect(probeBuilds, 2,
            reason: 'Refreshing the same typer does not change displayText, '
                'so widget must not rebuild');
      },
    );

    testWidgets(
      'INV-SELECT-671-TYPING: adding a second typer DOES rebuild widget',
      (tester) async {
        int probeBuilds = 0;

        final container = ProviderContainer(
          overrides: [
            typingIndicatorStoreProvider
                .overrideWith(() => _ControllableTypingIndicatorStore()),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: _TypingDisplayTextProbe(onBuild: () => probeBuilds++),
          ),
        );

        expect(probeBuilds, 1);

        // Add Alice.
        final store = container.read(typingIndicatorStoreProvider.notifier);
        store.addTyper(userId: 'u1', displayName: 'Alice');
        await tester.pump();

        expect(probeBuilds, 2);
        expect(find.text('Alice is typing...'), findsOneWidget);

        // Add Bob — displayText changes to "Alice and Bob are typing..."
        store.addTyper(userId: 'u2', displayName: 'Bob');
        await tester.pump();

        expect(probeBuilds, 3,
            reason: 'Adding a second typer changes displayText, '
                'so widget must rebuild');
        expect(find.text('Alice and Bob are typing...'), findsOneWidget);
      },
    );

    testWidgets(
      'INV-SELECT-671-TYPING: removing typer back to idle rebuilds widget',
      (tester) async {
        int probeBuilds = 0;

        final container = ProviderContainer(
          overrides: [
            typingIndicatorStoreProvider
                .overrideWith(() => _ControllableTypingIndicatorStore()),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: _TypingDisplayTextProbe(onBuild: () => probeBuilds++),
          ),
        );

        expect(probeBuilds, 1);
        expect(find.text('idle'), findsOneWidget);

        // Add Alice.
        final store = container.read(typingIndicatorStoreProvider.notifier);
        store.addTyper(userId: 'u1', displayName: 'Alice');
        await tester.pump();

        expect(probeBuilds, 2);
        expect(find.text('Alice is typing...'), findsOneWidget);

        // Remove Alice — back to null/idle.
        store.removeTyper('u1');
        await tester.pump();

        expect(probeBuilds, 3,
            reason: 'Removing the last typer changes displayText back to null');
        expect(find.text('idle'), findsOneWidget);
      },
    );
  });
}
