import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/translation/application/translation_cache_store.dart';
import 'package:slock_app/features/translation/application/translation_settings_store.dart';
import 'package:slock_app/features/translation/data/translation_repository.dart';
import 'package:slock_app/features/translation/data/translation_settings.dart';

void main() {
  ProviderContainer createContainer({
    ServerScopeId? serverId = const ServerScopeId('srv-1'),
    TranslationSettings settings = const TranslationSettings(
      preferredLanguage: 'ja',
      mode: TranslationMode.auto,
    ),
    _FakeTranslationRepository? repo,
  }) {
    final fakeRepo = repo ?? _FakeTranslationRepository();
    return ProviderContainer(
      overrides: [
        activeServerScopeIdProvider.overrideWithValue(serverId),
        translationRepositoryProvider.overrideWithValue(fakeRepo),
        translationSettingsStoreProvider.overrideWith(
          () => _PreloadedSettingsStore(settings),
        ),
      ],
    );
  }

  group('TranslationCacheStore.translateMessages', () {
    test('batch-translates and caches results', () async {
      final fakeRepo = _FakeTranslationRepository(
        batchResults: [
          const TranslationResult(
            messageId: 'msg-1',
            translatedContent: 'こんにちは',
            sourceLanguage: 'en',
            targetLanguage: 'ja',
            status: TranslationStatus.translated,
          ),
          const TranslationResult(
            messageId: 'msg-2',
            translatedContent: '世界',
            sourceLanguage: 'en',
            targetLanguage: 'ja',
            status: TranslationStatus.translated,
          ),
        ],
      );
      final container = createContainer(repo: fakeRepo);
      addTearDown(container.dispose);

      final notifier = container.read(translationCacheStoreProvider.notifier);
      await notifier.translateMessages(['msg-1', 'msg-2']);

      final state = container.read(translationCacheStoreProvider);
      expect(state.translations.length, 2);
      expect(state.translations['msg-1']?.translatedContent, 'こんにちは');
      expect(state.translations['msg-1']?.status,
          TranslationEntryStatus.translated);
      expect(state.translations['msg-2']?.translatedContent, '世界');
    });

    test('skips already-cached messages', () async {
      final fakeRepo = _FakeTranslationRepository(
        batchResults: [
          const TranslationResult(
            messageId: 'msg-1',
            translatedContent: 'bonjour',
            sourceLanguage: 'en',
            targetLanguage: 'fr',
            status: TranslationStatus.translated,
          ),
        ],
      );
      final container = createContainer(repo: fakeRepo);
      addTearDown(container.dispose);

      final notifier = container.read(translationCacheStoreProvider.notifier);

      // First call caches msg-1.
      await notifier.translateMessages(['msg-1']);
      expect(fakeRepo.batchCallCount, 1);

      // Second call with same ID — should skip.
      await notifier.translateMessages(['msg-1']);
      expect(fakeRepo.batchCallCount, 1);
    });

    test('marks missing results as failed', () async {
      final fakeRepo = _FakeTranslationRepository(
        batchResults: [
          const TranslationResult(
            messageId: 'msg-1',
            translatedContent: 'hola',
            sourceLanguage: 'en',
            targetLanguage: 'es',
            status: TranslationStatus.translated,
          ),
          // msg-2 not in results.
        ],
      );
      final container = createContainer(repo: fakeRepo);
      addTearDown(container.dispose);

      final notifier = container.read(translationCacheStoreProvider.notifier);
      await notifier.translateMessages(['msg-1', 'msg-2']);

      final state = container.read(translationCacheStoreProvider);
      expect(state.translations['msg-1']?.status,
          TranslationEntryStatus.translated);
      expect(
          state.translations['msg-2']?.status, TranslationEntryStatus.failed);
    });

    test('marks all as failed on API error', () async {
      final fakeRepo = _FakeTranslationRepository(failOnBatch: true);
      final container = createContainer(repo: fakeRepo);
      addTearDown(container.dispose);

      final notifier = container.read(translationCacheStoreProvider.notifier);
      await notifier.translateMessages(['msg-1', 'msg-2']);

      final state = container.read(translationCacheStoreProvider);
      expect(
          state.translations['msg-1']?.status, TranslationEntryStatus.failed);
      expect(
          state.translations['msg-2']?.status, TranslationEntryStatus.failed);
    });

    test('evicts oldest entries when cache exceeds safety cap', () async {
      final results = List.generate(
        210,
        (i) => TranslationResult(
          messageId: 'msg-$i',
          translatedContent: 'translated-$i',
          sourceLanguage: 'en',
          targetLanguage: 'ja',
          status: TranslationStatus.translated,
        ),
      );
      final fakeRepo = _FakeTranslationRepository(batchResults: results);
      final container = createContainer(repo: fakeRepo);
      addTearDown(container.dispose);

      final notifier = container.read(translationCacheStoreProvider.notifier);
      await notifier.translateMessages([
        for (var i = 0; i < 210; i++) 'msg-$i',
      ]);

      final translations =
          container.read(translationCacheStoreProvider).translations;
      expect(translations.length, lessThanOrEqualTo(200));
      expect(translations.containsKey('msg-0'), isFalse);
      expect(translations.containsKey('msg-209'), isTrue);
    });

    test('no-ops when serverId is null', () async {
      final fakeRepo = _FakeTranslationRepository();
      final container = createContainer(serverId: null, repo: fakeRepo);
      addTearDown(container.dispose);

      final notifier = container.read(translationCacheStoreProvider.notifier);
      await notifier.translateMessages(['msg-1']);

      expect(fakeRepo.batchCallCount, 0);
    });

    test('does not mutate disposed cache after delayed response', () async {
      final completer = Completer<List<TranslationResult>>();
      final fakeRepo = _DelayedTranslationRepository(completer);
      final container = createContainer(repo: fakeRepo);

      final notifier = container.read(translationCacheStoreProvider.notifier);
      final translationFuture = notifier.translateMessages(['msg-1']);

      expect(
        container
            .read(translationCacheStoreProvider)
            .translations['msg-1']
            ?.status,
        TranslationEntryStatus.pending,
      );

      container.dispose();
      completer.complete([
        const TranslationResult(
          messageId: 'msg-1',
          translatedContent: '遅延',
          sourceLanguage: 'en',
          targetLanguage: 'ja',
          status: TranslationStatus.translated,
        ),
      ]);

      await translationFuture;
      expect(fakeRepo.batchCallCount, 1);
    });
  });

  group('TranslationCacheStore.translateMessage', () {
    test('translates single message and auto-shows translation', () async {
      final fakeRepo = _FakeTranslationRepository(
        batchResults: [
          const TranslationResult(
            messageId: 'msg-1',
            translatedContent: 'hallo',
            sourceLanguage: 'en',
            targetLanguage: 'de',
            status: TranslationStatus.translated,
          ),
        ],
      );
      final container = createContainer(repo: fakeRepo);
      addTearDown(container.dispose);

      final notifier = container.read(translationCacheStoreProvider.notifier);
      await notifier.translateMessage('msg-1');

      final state = container.read(translationCacheStoreProvider);
      expect(state.translations['msg-1']?.translatedContent, 'hallo');
      expect(state.showTranslation['msg-1'], true);
    });

    test('allows re-translation by clearing cache first', () async {
      final fakeRepo = _FakeTranslationRepository(
        batchResults: [
          const TranslationResult(
            messageId: 'msg-1',
            translatedContent: 'v1',
            sourceLanguage: 'en',
            targetLanguage: 'ja',
            status: TranslationStatus.translated,
          ),
        ],
      );
      final container = createContainer(repo: fakeRepo);
      addTearDown(container.dispose);

      final notifier = container.read(translationCacheStoreProvider.notifier);

      // First translation.
      await notifier.translateMessage('msg-1');
      expect(fakeRepo.batchCallCount, 1);

      // Update fake results for re-translation.
      fakeRepo.batchResults = [
        const TranslationResult(
          messageId: 'msg-1',
          translatedContent: 'v2',
          sourceLanguage: 'en',
          targetLanguage: 'ja',
          status: TranslationStatus.translated,
        ),
      ];

      // Re-translate — should call API again (cache was cleared).
      await notifier.translateMessage('msg-1');
      expect(fakeRepo.batchCallCount, 2);

      final state = container.read(translationCacheStoreProvider);
      expect(state.translations['msg-1']?.translatedContent, 'v2');
    });
  });

  group('TranslationCacheStore toggle', () {
    test('toggleTranslation flips show state', () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(translationCacheStoreProvider.notifier);

      expect(notifier.isShowingTranslation('msg-1'), false);

      notifier.toggleTranslation('msg-1');
      expect(notifier.isShowingTranslation('msg-1'), true);

      notifier.toggleTranslation('msg-1');
      expect(notifier.isShowingTranslation('msg-1'), false);
    });
  });

  group('TranslationCacheStore.clearCache', () {
    test('clears all cached translations and toggle state', () async {
      final fakeRepo = _FakeTranslationRepository(
        batchResults: [
          const TranslationResult(
            messageId: 'msg-1',
            translatedContent: 'salut',
            sourceLanguage: 'en',
            targetLanguage: 'fr',
            status: TranslationStatus.translated,
          ),
        ],
      );
      final container = createContainer(repo: fakeRepo);
      addTearDown(container.dispose);

      final notifier = container.read(translationCacheStoreProvider.notifier);
      await notifier.translateMessages(['msg-1']);
      notifier.toggleTranslation('msg-1');

      expect(
        container.read(translationCacheStoreProvider).translations.isNotEmpty,
        true,
      );

      notifier.clearCache();

      final state = container.read(translationCacheStoreProvider);
      expect(state.translations, isEmpty);
      expect(state.showTranslation, isEmpty);
    });
  });
}

class _PreloadedSettingsStore extends TranslationSettingsStore {
  _PreloadedSettingsStore(this._initial);

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

class _FakeTranslationRepository implements TranslationRepository {
  _FakeTranslationRepository({
    this.batchResults = const [],
    this.failOnBatch = false,
  });

  List<TranslationResult> batchResults;
  final bool failOnBatch;
  int batchCallCount = 0;

  @override
  Future<TranslationSettings> getSettings(ServerScopeId serverId) async {
    return const TranslationSettings();
  }

  @override
  Future<TranslationSettings> updateSettings(
    ServerScopeId serverId,
    TranslationSettings newSettings,
  ) async {
    return newSettings;
  }

  @override
  Future<List<TranslationResult>> translateBatch(
    ServerScopeId serverId, {
    required List<String> messageIds,
    required String targetLanguage,
  }) async {
    batchCallCount++;
    if (failOnBatch) {
      throw const ServerFailure(message: 'API error');
    }
    return batchResults;
  }
}

class _DelayedTranslationRepository extends _FakeTranslationRepository {
  _DelayedTranslationRepository(this.completer);

  final Completer<List<TranslationResult>> completer;

  @override
  Future<List<TranslationResult>> translateBatch(
    ServerScopeId serverId, {
    required List<String> messageIds,
    required String targetLanguage,
  }) async {
    batchCallCount++;
    return completer.future;
  }
}
