import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/settings/presentation/page/translation_settings_page.dart';
import 'package:slock_app/features/translation/application/translation_settings_store.dart';
import 'package:slock_app/features/translation/data/translation_settings.dart';

void main() {
  testWidgets('renders mode options and language dropdown', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          translationSettingsStoreProvider.overrideWith(
            () => _PreloadedTranslationSettingsStore(
              const TranslationSettings(
                preferredLanguage: 'en',
                mode: TranslationMode.off,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const TranslationSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Mode section title.
    expect(find.text('Translation Mode'), findsOneWidget);

    // All three mode options rendered.
    expect(find.byKey(const ValueKey('translation-mode-auto')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('translation-mode-manual')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('translation-mode-off')), findsOneWidget);

    // Mode descriptions.
    expect(find.text('Automatic'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);

    // Language section.
    expect(find.text('Preferred Language'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('translation-language-dropdown')),
      findsOneWidget,
    );
  });

  testWidgets('shows selected mode with check icon', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          translationSettingsStoreProvider.overrideWith(
            () => _PreloadedTranslationSettingsStore(
              const TranslationSettings(
                preferredLanguage: 'en',
                mode: TranslationMode.auto,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const TranslationSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The check circle icon should appear (auto is selected).
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('shows loading indicator when status is loading', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          translationSettingsStoreProvider.overrideWith(
            _LoadingTranslationSettingsStore.new,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const TranslationSettingsPage(),
        ),
      ),
    );
    // Don't pumpAndSettle — loading state shows CircularProgressIndicator.
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

class _PreloadedTranslationSettingsStore extends TranslationSettingsStore {
  _PreloadedTranslationSettingsStore(this._initial);

  final TranslationSettings _initial;

  @override
  TranslationSettingsState build() {
    return TranslationSettingsState(
      status: TranslationSettingsStatus.success,
      settings: _initial,
    );
  }

  @override
  Future<void> load() async {}

  @override
  Future<void> update(TranslationSettings settings) async {
    state = state.copyWith(settings: settings);
  }
}

class _LoadingTranslationSettingsStore extends TranslationSettingsStore {
  @override
  TranslationSettingsState build() {
    return const TranslationSettingsState(
      status: TranslationSettingsStatus.loading,
    );
  }

  @override
  Future<void> load() async {}
}
