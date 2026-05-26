import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/link_preview/data/link_metadata.dart';
import 'package:slock_app/features/link_preview/presentation/widgets/link_preview_card.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  Widget buildCard({
    required LinkMetadata metadata,
    VoidCallback? onTap,
  }) {
    return MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: LinkPreviewCard(
          metadata: metadata,
          onTap: onTap,
        ),
      ),
    );
  }

  group('LinkPreviewCard', () {
    testWidgets('renders title and domain', (tester) async {
      await tester.pumpWidget(buildCard(
        metadata: const LinkMetadata(
          url: 'https://example.com/article',
          title: 'Test Article',
          domain: 'example.com',
        ),
      ));

      expect(find.text('Test Article'), findsOneWidget);
      expect(find.text('example.com'), findsOneWidget);
    });

    testWidgets('renders description when provided', (tester) async {
      await tester.pumpWidget(buildCard(
        metadata: const LinkMetadata(
          url: 'https://example.com',
          title: 'Title',
          description: 'A detailed description of the page.',
          domain: 'example.com',
        ),
      ));

      expect(find.text('A detailed description of the page.'), findsOneWidget);
    });

    testWidgets('does not render description when null', (tester) async {
      await tester.pumpWidget(buildCard(
        metadata: const LinkMetadata(
          url: 'https://example.com',
          title: 'Title',
          domain: 'example.com',
        ),
      ));

      expect(
          find.byKey(const ValueKey('link-preview-description')), findsNothing);
    });

    testWidgets('renders image when imageUrl provided', (tester) async {
      await tester.pumpWidget(buildCard(
        metadata: const LinkMetadata(
          url: 'https://example.com',
          title: 'Title',
          imageUrl: 'https://example.com/image.jpg',
          domain: 'example.com',
        ),
      ));

      expect(find.byKey(const ValueKey('link-preview-image')), findsOneWidget);
    });

    testWidgets('does not render image when imageUrl is null', (tester) async {
      await tester.pumpWidget(buildCard(
        metadata: const LinkMetadata(
          url: 'https://example.com',
          title: 'Title',
          domain: 'example.com',
        ),
      ));

      expect(find.byKey(const ValueKey('link-preview-image')), findsNothing);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildCard(
        metadata: const LinkMetadata(
          url: 'https://example.com',
          title: 'Title',
          domain: 'example.com',
        ),
        onTap: () => tapped = true,
      ));

      await tester.tap(find.byKey(const ValueKey('link-preview-card')));
      expect(tapped, isTrue);
    });

    testWidgets('truncates long title to 2 lines', (tester) async {
      await tester.pumpWidget(buildCard(
        metadata: const LinkMetadata(
          url: 'https://example.com',
          title: 'A very long title that should be truncated after two lines '
              'because it contains way too much text for a preview card',
          domain: 'example.com',
        ),
      ));

      final titleWidget = tester.widget<Text>(
        find.byKey(const ValueKey('link-preview-title')),
      );
      expect(titleWidget.maxLines, 2);
      expect(titleWidget.overflow, TextOverflow.ellipsis);
    });

    testWidgets('truncates long description to 2 lines', (tester) async {
      await tester.pumpWidget(buildCard(
        metadata: const LinkMetadata(
          url: 'https://example.com',
          title: 'Title',
          description:
              'A very long description that should be truncated after two '
              'lines because it is way too verbose for a compact card',
          domain: 'example.com',
        ),
      ));

      final descWidget = tester.widget<Text>(
        find.byKey(const ValueKey('link-preview-description')),
      );
      expect(descWidget.maxLines, 2);
      expect(descWidget.overflow, TextOverflow.ellipsis);
    });
  });
}
