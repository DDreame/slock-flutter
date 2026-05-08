import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/conversation/presentation/widgets/message_content_widget.dart';
import 'package:slock_app/features/link_preview/application/link_preview_store.dart';
import 'package:slock_app/features/link_preview/data/link_metadata.dart';
import 'package:slock_app/features/link_preview/data/link_preview_service.dart';

void main() {
  ConversationMessageSummary makeMessage(String content) {
    return ConversationMessageSummary(
      id: 'msg-1',
      content: content,
      createdAt: DateTime(2026, 1, 1),
      senderType: 'human',
      messageType: 'message',
      senderName: 'Alice',
    );
  }

  group('MessageContentWidget link preview integration', () {
    testWidgets('shows link preview card when URL found and metadata cached',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          linkPreviewServiceProvider.overrideWithValue(
            _FakeLinkPreviewService(const LinkMetadata(
              url: 'https://example.com/article',
              title: 'Example Article',
              description: 'A great article.',
              domain: 'example.com',
            )),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: MessageContentWidget(
                message:
                    makeMessage('Check this out: https://example.com/article'),
              ),
            ),
          ),
        ),
      );

      // Initial pump — fetch is triggered.
      await tester.pump();
      // Wait for async fetch to complete.
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('link-preview-card')), findsOneWidget);
      expect(find.text('Example Article'), findsOneWidget);
      expect(find.text('A great article.'), findsOneWidget);
      expect(find.text('example.com'), findsOneWidget);
    });

    testWidgets('does not show link preview for system messages',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          linkPreviewServiceProvider.overrideWithValue(
            _FakeLinkPreviewService(const LinkMetadata(
              url: 'https://example.com',
              title: 'Title',
              domain: 'example.com',
            )),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: MessageContentWidget(
                message: makeMessage('Visit https://example.com'),
                isSystem: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('link-preview-card')), findsNothing);
    });

    testWidgets('no card shown when message has no URL', (tester) async {
      final container = ProviderContainer(
        overrides: [
          linkPreviewServiceProvider.overrideWithValue(
            _FakeLinkPreviewService(null),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: MessageContentWidget(
                message: makeMessage('Hello, no links here!'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('link-preview-card')), findsNothing);
    });

    testWidgets('shows tappable fallback link when metadata fetch returns null',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          linkPreviewServiceProvider.overrideWithValue(
            _FakeLinkPreviewService(null),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: MessageContentWidget(
                message: makeMessage('Check https://no-og-tags.invalid'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // No preview card.
      expect(find.byKey(const ValueKey('link-preview-card')), findsNothing);
      // But a tappable fallback link chip.
      expect(find.byKey(const ValueKey('link-fallback-chip')), findsOneWidget);
      expect(find.text('https://no-og-tags.invalid'), findsOneWidget);
    });

    testWidgets('tapping fallback link chip calls onLinkTap', (tester) async {
      String? tappedHref;
      final container = ProviderContainer(
        overrides: [
          linkPreviewServiceProvider.overrideWithValue(
            _FakeLinkPreviewService(null),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: MessageContentWidget(
                message: makeMessage('Check https://no-og-tags.invalid'),
                onLinkTap: (text, href, title) {
                  tappedHref = href;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const ValueKey('link-fallback-chip')));
      expect(tappedHref, 'https://no-og-tags.invalid');
    });

    testWidgets('shows fallback link chip on fetch error (not inert text)',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          linkPreviewServiceProvider.overrideWithValue(
            _ThrowingLinkPreviewService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: MessageContentWidget(
                message: makeMessage('Check https://failing-server.invalid'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // No preview card.
      expect(find.byKey(const ValueKey('link-preview-card')), findsNothing);
      // Tappable fallback link — NOT inert text.
      expect(find.byKey(const ValueKey('link-fallback-chip')), findsOneWidget);
      expect(find.text('https://failing-server.invalid'), findsOneWidget);
    });

    testWidgets('tapping card calls onLinkTap', (tester) async {
      String? tappedHref;
      final container = ProviderContainer(
        overrides: [
          linkPreviewServiceProvider.overrideWithValue(
            _FakeLinkPreviewService(const LinkMetadata(
              url: 'https://example.com',
              title: 'Example',
              domain: 'example.com',
            )),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: MessageContentWidget(
                message: makeMessage('Visit https://example.com'),
                onLinkTap: (text, href, title) {
                  tappedHref = href;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const ValueKey('link-preview-card')));
      expect(tappedHref, 'https://example.com');
    });
  });
}

/// A fake [LinkPreviewService] that returns a fixed [LinkMetadata].
class _FakeLinkPreviewService extends LinkPreviewService {
  _FakeLinkPreviewService(this._metadata) : super();

  final LinkMetadata? _metadata;

  @override
  Future<LinkMetadata?> fetchMetadata(String url) async {
    return _metadata;
  }
}

/// A [LinkPreviewService] that always throws (simulates network error).
class _ThrowingLinkPreviewService extends LinkPreviewService {
  _ThrowingLinkPreviewService() : super();

  @override
  Future<LinkMetadata?> fetchMetadata(String url) async {
    throw Exception('Network error');
  }
}
