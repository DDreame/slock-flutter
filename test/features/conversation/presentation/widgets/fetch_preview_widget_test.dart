// =============================================================================
// #647 Phase A — FetchPreviewWidget base class lifecycle tests
//
// Invariants verified:
// INV-FETCH-LIFECYCLE-1: loading → success transition
// INV-FETCH-LIFECYCLE-2: loading → error transition
// INV-FETCH-LIFECYCLE-3: mounted guard prevents setState after dispose
// INV-FETCH-LIFECYCLE-4: null/empty URL triggers error state immediately
// INV-FETCH-LIFECYCLE-5: diagnostics error logged on fetch failure
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/telemetry/diagnostics_collector.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/fetch_preview_widget.dart';

// =============================================================================
// Concrete test implementation of FetchPreviewWidget
// =============================================================================

class _TestPreviewWidget extends FetchPreviewWidget {
  const _TestPreviewWidget({
    super.key,
    required super.attachment,
    super.fallback,
    super.contentFetcher,
  });

  @override
  ConsumerState<_TestPreviewWidget> createState() => _TestPreviewWidgetState();
}

class _TestPreviewWidgetState
    extends FetchPreviewWidgetState<_TestPreviewWidget> {
  String? content;

  @override
  String get diagnosticsTag => 'TestPreview';

  @override
  void onFetchSuccess(String fetchedContent) {
    setState(() {
      content = fetchedContent;
      loading = false;
    });
  }

  @override
  Widget buildContent(BuildContext context) {
    return Text(
      content ?? '',
      key: const ValueKey('test-content'),
    );
  }
}

// =============================================================================
// Fake diagnostics collector to verify error logging
// =============================================================================

class _FakeDiagnosticsCollector extends DiagnosticsCollector {
  final List<String> errorMessages = [];

  @override
  void error(String tag, String message, {Map<String, dynamic>? metadata}) {
    errorMessages.add('$tag: $message');
  }
}

void main() {
  // ---------------------------------------------------------------------------
  // INV-FETCH-LIFECYCLE-1: loading → success
  // ---------------------------------------------------------------------------
  group('INV-FETCH-LIFECYCLE-1: loading → success', () {
    testWidgets('shows loading indicator then content after fetch completes',
        (tester) async {
      final completer = Completer<String>();
      const attachment = MessageAttachment(
        name: 'test.txt',
        type: 'text/plain',
        url: 'https://example.com/test.txt',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _TestPreviewWidget(
                attachment: attachment,
                contentFetcher: (url) => completer.future,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Should be in loading state.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const ValueKey('test-content')), findsNothing);

      // Complete the fetch.
      completer.complete('Hello World');
      await tester.pumpAndSettle();

      // Should transition to content.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const ValueKey('test-content')), findsOneWidget);
      expect(find.text('Hello World'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // INV-FETCH-LIFECYCLE-2: loading → error
  // ---------------------------------------------------------------------------
  group('INV-FETCH-LIFECYCLE-2: loading → error', () {
    testWidgets('shows fallback widget when fetch throws', (tester) async {
      final fallback = Container(key: const ValueKey('custom-fallback'));
      const attachment = MessageAttachment(
        name: 'broken.txt',
        type: 'text/plain',
        url: 'https://example.com/broken.txt',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _TestPreviewWidget(
                attachment: attachment,
                fallback: fallback,
                contentFetcher: (url) async =>
                    throw Exception('network failure'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show the custom fallback.
      expect(find.byKey(const ValueKey('custom-fallback')), findsOneWidget);
      expect(find.byKey(const ValueKey('test-content')), findsNothing);
    });

    testWidgets('shows DefaultPreviewFallback when no custom fallback',
        (tester) async {
      const attachment = MessageAttachment(
        name: 'broken.txt',
        type: 'text/plain',
        url: 'https://example.com/broken.txt',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _TestPreviewWidget(
                attachment: attachment,
                contentFetcher: (url) async =>
                    throw Exception('network failure'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show the default fallback with file name.
      expect(find.byType(DefaultPreviewFallback), findsOneWidget);
      expect(find.text('broken.txt'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // INV-FETCH-LIFECYCLE-3: mounted guard
  // ---------------------------------------------------------------------------
  group('INV-FETCH-LIFECYCLE-3: mounted guard prevents post-dispose setState',
      () {
    testWidgets('no crash when widget disposed during fetch', (tester) async {
      final completer = Completer<String>();
      const attachment = MessageAttachment(
        name: 'slow.txt',
        type: 'text/plain',
        url: 'https://example.com/slow.txt',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _TestPreviewWidget(
                attachment: attachment,
                contentFetcher: (url) => completer.future,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Widget is loading.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Dispose the widget by replacing it.
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Container(key: const ValueKey('replacement')),
            ),
          ),
        ),
      );
      await tester.pump();

      // Complete the fetch AFTER dispose — should not crash.
      completer.complete('late content');
      await tester.pumpAndSettle();

      // Replacement widget should be shown, no error thrown.
      expect(find.byKey(const ValueKey('replacement')), findsOneWidget);
    });

    testWidgets('no crash when widget disposed during error', (tester) async {
      final completer = Completer<String>();
      const attachment = MessageAttachment(
        name: 'slow.txt',
        type: 'text/plain',
        url: 'https://example.com/slow.txt',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _TestPreviewWidget(
                attachment: attachment,
                contentFetcher: (url) => completer.future,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Dispose the widget.
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Container(key: const ValueKey('replacement')),
            ),
          ),
        ),
      );
      await tester.pump();

      // Error AFTER dispose — should not crash.
      completer.completeError(Exception('late error'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('replacement')), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // INV-FETCH-LIFECYCLE-4: null/empty URL
  // ---------------------------------------------------------------------------
  group('INV-FETCH-LIFECYCLE-4: null/empty URL triggers error', () {
    testWidgets('null URL shows error state immediately', (tester) async {
      const attachment = MessageAttachment(
        name: 'no-url.txt',
        type: 'text/plain',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _TestPreviewWidget(
                attachment: attachment,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show default fallback (error state).
      expect(find.byType(DefaultPreviewFallback), findsOneWidget);
      expect(find.text('no-url.txt'), findsOneWidget);
    });

    testWidgets('empty URL shows error state immediately', (tester) async {
      const attachment = MessageAttachment(
        name: 'empty-url.txt',
        type: 'text/plain',
        url: '',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _TestPreviewWidget(
                attachment: attachment,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DefaultPreviewFallback), findsOneWidget);
      expect(find.text('empty-url.txt'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // INV-FETCH-LIFECYCLE-5: diagnostics error logged on failure
  // ---------------------------------------------------------------------------
  group('INV-FETCH-LIFECYCLE-5: diagnostics error logging', () {
    testWidgets('logs error via diagnosticsCollectorProvider on fetch failure',
        (tester) async {
      final fakeDiagnostics = _FakeDiagnosticsCollector();
      const attachment = MessageAttachment(
        name: 'fail.txt',
        type: 'text/plain',
        url: 'https://example.com/fail.txt',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diagnosticsCollectorProvider.overrideWithValue(fakeDiagnostics),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: _TestPreviewWidget(
                attachment: attachment,
                contentFetcher: (url) async =>
                    throw Exception('connection refused'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(fakeDiagnostics.errorMessages, hasLength(1));
      expect(
        fakeDiagnostics.errorMessages.first,
        contains('TestPreview'),
      );
      expect(
        fakeDiagnostics.errorMessages.first,
        contains('fail.txt'),
      );
    });
  });
}
