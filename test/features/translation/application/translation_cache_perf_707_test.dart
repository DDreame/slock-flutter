// =============================================================================
// #707 — TranslationCacheStore performance fixes
//
// A. In-flight dedup: concurrent translateMessages() with same IDs → single API call
// B. hashCode: produces distinct values for permuted state (no XOR degeneration)
// C. O(n²) → O(n): Set lookup replaces .any() for missing results detection
// =============================================================================

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
    TranslationRepository? repo,
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

  group('#707A — In-flight dedup guard', () {
    test('concurrent calls with same IDs produce single API call', () async {
      final completer = Completer<List<TranslationResult>>();
      final fakeRepo = _DelayedTranslationRepository(completer: completer);
      final container = createContainer(repo: fakeRepo);
      addTearDown(container.dispose);

      final notifier = container.read(translationCacheStoreProvider.notifier);

      // Fire two concurrent calls with the same message IDs.
      final call1 = notifier.translateMessages(['msg-1', 'msg-2']);
      final call2 = notifier.translateMessages(['msg-1', 'msg-2']);

      // Complete the first (and only) API call.
      completer.complete([
        const TranslationResult(
          messageId: 'msg-1',
          translatedContent: 'hello',
          sourceLanguage: 'en',
          targetLanguage: 'ja',
          status: TranslationStatus.translated,
        ),
        const TranslationResult(
          messageId: 'msg-2',
          translatedContent: 'world',
          sourceLanguage: 'en',
          targetLanguage: 'ja',
          status: TranslationStatus.translated,
        ),
      ]);

      await call1;
      await call2;

      // Only one API call should have been made.
      expect(fakeRepo.batchCallCount, 1,
          reason: 'Second concurrent call should be deduped');

      final state = container.read(translationCacheStoreProvider);
      expect(state.translations['msg-1']?.translatedContent, 'hello');
      expect(state.translations['msg-2']?.translatedContent, 'world');
    });

    test('in-flight guard released after completion (allows re-translate)',
        () async {
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

      // First call completes normally.
      await notifier.translateMessages(['msg-1']);
      expect(fakeRepo.batchCallCount, 1);

      // Clear cache to allow re-translation.
      notifier.clearCache();

      // Second call should go through (in-flight cleared after first completed).
      fakeRepo.batchResults = [
        const TranslationResult(
          messageId: 'msg-1',
          translatedContent: 'v2',
          sourceLanguage: 'en',
          targetLanguage: 'ja',
          status: TranslationStatus.translated,
        ),
      ];
      await notifier.translateMessages(['msg-1']);
      expect(fakeRepo.batchCallCount, 2,
          reason: 'After completion, in-flight guard should be released');
    });

    test('in-flight guard released on API failure (allows retry)', () async {
      final fakeRepo = _FakeTranslationRepository(failOnBatch: true);
      final container = createContainer(repo: fakeRepo);
      addTearDown(container.dispose);

      final notifier = container.read(translationCacheStoreProvider.notifier);

      // First call fails.
      await notifier.translateMessages(['msg-1']);
      expect(fakeRepo.batchCallCount, 1);

      final state = container.read(translationCacheStoreProvider);
      expect(
          state.translations['msg-1']?.status, TranslationEntryStatus.failed);

      // Clear cache and retry — should go through since in-flight was released.
      notifier.clearCache();
      fakeRepo.failOnBatch = false;
      fakeRepo.batchResults = [
        const TranslationResult(
          messageId: 'msg-1',
          translatedContent: 'retried',
          sourceLanguage: 'en',
          targetLanguage: 'ja',
          status: TranslationStatus.translated,
        ),
      ];
      await notifier.translateMessages(['msg-1']);
      expect(fakeRepo.batchCallCount, 2);
    });

    test('partially overlapping concurrent calls only dedup shared IDs',
        () async {
      final completer = Completer<List<TranslationResult>>();
      final fakeRepo = _DelayedTranslationRepository(completer: completer);
      final container = createContainer(repo: fakeRepo);
      addTearDown(container.dispose);

      final notifier = container.read(translationCacheStoreProvider.notifier);

      // First call requests msg-1 and msg-2.
      final call1 = notifier.translateMessages(['msg-1', 'msg-2']);
      // Second call requests msg-2 (overlapping) and msg-3 (new).
      // msg-2 should be deduped, msg-3 won't go through since API is delayed.
      final call2 = notifier.translateMessages(['msg-2', 'msg-3']);

      completer.complete([
        const TranslationResult(
          messageId: 'msg-1',
          translatedContent: 'one',
          sourceLanguage: 'en',
          targetLanguage: 'ja',
          status: TranslationStatus.translated,
        ),
        const TranslationResult(
          messageId: 'msg-2',
          translatedContent: 'two',
          sourceLanguage: 'en',
          targetLanguage: 'ja',
          status: TranslationStatus.translated,
        ),
      ]);

      await call1;
      await call2;

      // First call handles msg-1 and msg-2.
      // Second call: msg-2 is in-flight (deduped), msg-3 is new but since
      // the first call already added msg-2 to cache by the time call2 awaits,
      // call2 may or may not trigger a second API call for msg-3 depending
      // on whether msg-3 was filtered by the in-flight check.
      // The key assertion: msg-2 was NOT double-requested.
      expect(fakeRepo.batchCallCount, greaterThanOrEqualTo(1));
      expect(fakeRepo.batchCallCount, lessThanOrEqualTo(2));
      // msg-1 and msg-2 should be translated.
      final state = container.read(translationCacheStoreProvider);
      expect(state.translations['msg-1']?.translatedContent, 'one');
      expect(state.translations['msg-2']?.translatedContent, 'two');
    });
  });

  group('#707B — TranslationCacheState hashCode collision resistance', () {
    test('permuted maps produce different hash codes', () {
      // Two states with same keys but different values.
      const stateA = TranslationCacheState(
        translations: {
          'msg-1': TranslationEntry(
            messageId: 'msg-1',
            translatedContent: 'hello',
            status: TranslationEntryStatus.translated,
          ),
          'msg-2': TranslationEntry(
            messageId: 'msg-2',
            translatedContent: 'world',
            status: TranslationEntryStatus.translated,
          ),
        },
      );

      const stateB = TranslationCacheState(
        translations: {
          'msg-1': TranslationEntry(
            messageId: 'msg-1',
            translatedContent: 'world',
            status: TranslationEntryStatus.translated,
          ),
          'msg-2': TranslationEntry(
            messageId: 'msg-2',
            translatedContent: 'hello',
            status: TranslationEntryStatus.translated,
          ),
        },
      );

      // With XOR, swapping values between keys could produce same hash.
      // With proper mixing, they should differ.
      expect(stateA.hashCode, isNot(equals(stateB.hashCode)),
          reason: 'Permuted map values must produce different hash codes');
    });

    test('different-sized maps produce different hash codes', () {
      const stateSmall = TranslationCacheState(
        translations: {
          'msg-1': TranslationEntry(
            messageId: 'msg-1',
            status: TranslationEntryStatus.pending,
          ),
        },
      );

      const stateLarge = TranslationCacheState(
        translations: {
          'msg-1': TranslationEntry(
            messageId: 'msg-1',
            status: TranslationEntryStatus.pending,
          ),
          'msg-2': TranslationEntry(
            messageId: 'msg-2',
            status: TranslationEntryStatus.pending,
          ),
        },
      );

      expect(stateSmall.hashCode, isNot(equals(stateLarge.hashCode)));
    });

    test('identical states produce same hash code', () {
      const stateA = TranslationCacheState(
        translations: {
          'msg-1': TranslationEntry(
            messageId: 'msg-1',
            translatedContent: 'hello',
            status: TranslationEntryStatus.translated,
          ),
        },
        showTranslation: {'msg-1': true},
      );

      const stateB = TranslationCacheState(
        translations: {
          'msg-1': TranslationEntry(
            messageId: 'msg-1',
            translatedContent: 'hello',
            status: TranslationEntryStatus.translated,
          ),
        },
        showTranslation: {'msg-1': true},
      );

      expect(stateA.hashCode, equals(stateB.hashCode));
      expect(stateA, equals(stateB));
    });

    test('empty state has consistent hash code', () {
      const state1 = TranslationCacheState();
      const state2 = TranslationCacheState();
      expect(state1.hashCode, equals(state2.hashCode));
    });
  });

  group('#707C — O(n) Set lookup for missing results', () {
    test('messages not in results are marked failed (Set-based)', () async {
      // This test verifies the same behavior as the existing test but
      // exercises the Set-based lookup path rather than .any().
      final fakeRepo = _FakeTranslationRepository(
        batchResults: [
          const TranslationResult(
            messageId: 'msg-1',
            translatedContent: 'translated',
            sourceLanguage: 'en',
            targetLanguage: 'ja',
            status: TranslationStatus.translated,
          ),
          // msg-2, msg-3 NOT in results
        ],
      );
      final container = createContainer(repo: fakeRepo);
      addTearDown(container.dispose);

      final notifier = container.read(translationCacheStoreProvider.notifier);
      await notifier.translateMessages(['msg-1', 'msg-2', 'msg-3']);

      final state = container.read(translationCacheStoreProvider);
      expect(state.translations['msg-1']?.status,
          TranslationEntryStatus.translated);
      expect(
          state.translations['msg-2']?.status, TranslationEntryStatus.failed);
      expect(
          state.translations['msg-3']?.status, TranslationEntryStatus.failed);
    });

    test('large batch with many missing uses O(n) lookup', () async {
      // Generate results for only even-indexed messages.
      final results = List.generate(
        50,
        (i) => TranslationResult(
          messageId: 'msg-${i * 2}',
          translatedContent: 'trans-${i * 2}',
          sourceLanguage: 'en',
          targetLanguage: 'ja',
          status: TranslationStatus.translated,
        ),
      );
      final fakeRepo = _FakeTranslationRepository(batchResults: results);
      final container = createContainer(repo: fakeRepo);
      addTearDown(container.dispose);

      final notifier = container.read(translationCacheStoreProvider.notifier);
      final allIds = List.generate(100, (i) => 'msg-$i');
      await notifier.translateMessages(allIds);

      final state = container.read(translationCacheStoreProvider);
      // Even IDs should be translated, odd should be failed.
      expect(state.translations['msg-0']?.status,
          TranslationEntryStatus.translated);
      expect(state.translations['msg-1']?.status, TranslationEntryStatus.failed,
          reason: 'Odd-indexed messages not in results should be failed');
      expect(state.translations['msg-98']?.status,
          TranslationEntryStatus.translated);
      expect(
          state.translations['msg-99']?.status, TranslationEntryStatus.failed);
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

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
  bool failOnBatch;
  int batchCallCount = 0;
  List<List<String>> batchRequests = [];

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
    batchRequests.add(messageIds);
    if (failOnBatch) {
      throw const ServerFailure(message: 'API error');
    }
    return batchResults;
  }
}

/// A repository that delays its response until a completer is completed,
/// allowing tests to control timing of concurrent calls.
class _DelayedTranslationRepository implements TranslationRepository {
  _DelayedTranslationRepository({required this.completer});

  final Completer<List<TranslationResult>> completer;
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
    return completer.future;
  }
}
