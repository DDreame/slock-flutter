import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/translation/application/translation_cache_store.dart';
import 'package:slock_app/features/translation/presentation/widget/translated_content_overlay.dart';

void main() {
  Widget buildTestWidget({
    required TranslationEntry entry,
    TranslationCacheState? cacheState,
  }) {
    final state = cacheState ??
        TranslationCacheState(
          translations: {entry.messageId: entry},
        );

    return ProviderScope(
      overrides: [
        translationCacheStoreProvider.overrideWith(
          () => _FakeCacheStore(state),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: TranslatedContentOverlay(
            messageId: entry.messageId,
            originalChild: const Text('Hello world'),
            translatedContent: entry.translatedContent,
            entry: entry,
          ),
        ),
      ),
    );
  }

  testWidgets('shows original content and toggle when translated',
      (tester) async {
    final entry = const TranslationEntry(
      messageId: 'msg-1',
      translatedContent: 'こんにちは',
      sourceLanguage: 'en',
      targetLanguage: 'ja',
      status: TranslationEntryStatus.translated,
    );

    await tester.pumpWidget(buildTestWidget(entry: entry));
    await tester.pumpAndSettle();

    // Original content is shown by default.
    expect(find.text('Hello world'), findsOneWidget);
    expect(find.text('こんにちは'), findsNothing);

    // Toggle button is visible.
    expect(find.byKey(const ValueKey('translation-toggle')), findsOneWidget);
    expect(find.text('Show translation'), findsOneWidget);

    // Translated icon visible.
    expect(find.byKey(const ValueKey('translation-done-icon')), findsOneWidget);
  });

  testWidgets('shows translated content when toggle is active', (tester) async {
    final entry = const TranslationEntry(
      messageId: 'msg-1',
      translatedContent: 'こんにちは',
      sourceLanguage: 'en',
      targetLanguage: 'ja',
      status: TranslationEntryStatus.translated,
    );

    final cacheState = TranslationCacheState(
      translations: {'msg-1': entry},
      showTranslation: const {'msg-1': true},
    );

    await tester
        .pumpWidget(buildTestWidget(entry: entry, cacheState: cacheState));
    await tester.pumpAndSettle();

    // Translated content is shown.
    expect(find.text('こんにちは'), findsOneWidget);
    // Original is NOT shown (replaced by translation).
    expect(find.text('Hello world'), findsNothing);

    // Toggle says "Show original".
    expect(find.text('Show original'), findsOneWidget);
  });

  testWidgets('shows spinner when translation is pending', (tester) async {
    final entry = const TranslationEntry(
      messageId: 'msg-1',
      status: TranslationEntryStatus.pending,
    );

    await tester.pumpWidget(buildTestWidget(entry: entry));
    await tester.pump();

    // Original content still visible.
    expect(find.text('Hello world'), findsOneWidget);

    // Pending spinner.
    expect(find.byKey(const ValueKey('translation-pending-spinner')),
        findsOneWidget);
    expect(find.text('Translating…'), findsOneWidget);

    // No toggle button.
    expect(find.byKey(const ValueKey('translation-toggle')), findsNothing);
  });

  testWidgets('shows error icon and retry when translation failed',
      (tester) async {
    final entry = const TranslationEntry(
      messageId: 'msg-1',
      status: TranslationEntryStatus.failed,
    );

    await tester.pumpWidget(buildTestWidget(entry: entry));
    await tester.pumpAndSettle();

    // Original content still visible.
    expect(find.text('Hello world'), findsOneWidget);

    // Error icon.
    expect(
        find.byKey(const ValueKey('translation-failed-icon')), findsOneWidget);

    // Retry text.
    expect(find.byKey(const ValueKey('translation-retry')), findsOneWidget);
    expect(find.text('Translation failed. Tap to retry.'), findsOneWidget);
  });
}

class _FakeCacheStore extends TranslationCacheStore {
  _FakeCacheStore(this._initial);

  final TranslationCacheState _initial;

  @override
  TranslationCacheState build() {
    return _initial;
  }
}
