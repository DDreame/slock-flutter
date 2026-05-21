import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/home/application/active_server_scope_provider.dart';
import 'package:slock_app/features/translation/application/translation_settings_store.dart';
import 'package:slock_app/features/translation/data/translation_repository.dart';
import 'package:slock_app/features/translation/data/translation_settings.dart';

/// Per-message translation status within the cache.
enum TranslationEntryStatus {
  /// Translation request sent, waiting for response.
  pending,

  /// Translation completed successfully.
  translated,

  /// Translation failed — may retry.
  failed,
}

/// A single cached translation entry for a message.
@immutable
class TranslationEntry {
  const TranslationEntry({
    required this.messageId,
    this.translatedContent,
    this.sourceLanguage,
    this.targetLanguage,
    this.status = TranslationEntryStatus.pending,
  });

  final String messageId;
  final String? translatedContent;
  final String? sourceLanguage;
  final String? targetLanguage;
  final TranslationEntryStatus status;

  TranslationEntry copyWith({
    String? translatedContent,
    String? sourceLanguage,
    String? targetLanguage,
    TranslationEntryStatus? status,
  }) {
    return TranslationEntry(
      messageId: messageId,
      translatedContent: translatedContent ?? this.translatedContent,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranslationEntry &&
          runtimeType == other.runtimeType &&
          messageId == other.messageId &&
          translatedContent == other.translatedContent &&
          sourceLanguage == other.sourceLanguage &&
          targetLanguage == other.targetLanguage &&
          status == other.status;

  @override
  int get hashCode => Object.hash(
        messageId,
        translatedContent,
        sourceLanguage,
        targetLanguage,
        status,
      );
}

/// State for the translation cache.
@immutable
class TranslationCacheState {
  const TranslationCacheState({
    this.translations = const {},
    this.showTranslation = const {},
  });

  /// Cached translation entries keyed by message ID.
  final Map<String, TranslationEntry> translations;

  /// Per-message toggle: whether to display translated content.
  /// Messages not in this map default to `false` (show original).
  final Map<String, bool> showTranslation;

  TranslationCacheState copyWith({
    Map<String, TranslationEntry>? translations,
    Map<String, bool>? showTranslation,
  }) {
    return TranslationCacheState(
      translations: translations ?? this.translations,
      showTranslation: showTranslation ?? this.showTranslation,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranslationCacheState &&
          runtimeType == other.runtimeType &&
          mapEquals(translations, other.translations) &&
          mapEquals(showTranslation, other.showTranslation);

  @override
  int get hashCode {
    var h = 0;
    for (final entry in translations.entries) {
      h ^= Object.hash(entry.key, entry.value);
    }
    for (final entry in showTranslation.entries) {
      h ^= Object.hash(entry.key, entry.value);
    }
    return h;
  }
}

final translationCacheStoreProvider =
    AutoDisposeNotifierProvider<TranslationCacheStore, TranslationCacheState>(
  TranslationCacheStore.new,
);

/// Ephemeral per-conversation translation cache.
///
/// Caches batch-translated results keyed by messageId. The cache is
/// AutoDispose so it's cleared when the conversation page is disposed.
class TranslationCacheStore extends AutoDisposeNotifier<TranslationCacheState> {
  @override
  bool updateShouldNotify(
    TranslationCacheState previous,
    TranslationCacheState next,
  ) =>
      previous != next;
  @override
  TranslationCacheState build() {
    return const TranslationCacheState();
  }

  /// Returns the cached translation for [messageId], or null.
  TranslationEntry? getTranslation(String messageId) {
    return state.translations[messageId];
  }

  /// Whether the translated view is active for [messageId].
  bool isShowingTranslation(String messageId) {
    return state.showTranslation[messageId] ?? false;
  }

  /// Toggle between original and translated content for [messageId].
  /// INV-TRANSLATE-1: toggle never replaces original — both exist in cache.
  void toggleTranslation(String messageId) {
    final current = state.showTranslation[messageId] ?? false;
    state = state.copyWith(
      showTranslation: {...state.showTranslation, messageId: !current},
    );
  }

  /// Batch-translate messages. Marks them as pending immediately, then
  /// updates with API results. Skips messages already cached.
  Future<void> translateMessages(List<String> messageIds) async {
    if (messageIds.isEmpty) return;

    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) return;

    // Read preferred language from settings.
    final settingsState = ref.read(translationSettingsStoreProvider);
    final targetLanguage = settingsState.settings.preferredLanguage;

    // Filter out already-cached (translated or pending) messages.
    final uncached =
        messageIds.where((id) => !state.translations.containsKey(id)).toList();
    if (uncached.isEmpty) return;

    // Mark uncached as pending.
    final pending = Map<String, TranslationEntry>.from(state.translations);
    for (final id in uncached) {
      pending[id] = TranslationEntry(
        messageId: id,
        status: TranslationEntryStatus.pending,
      );
    }
    state = state.copyWith(translations: pending);

    try {
      final repo = ref.read(translationRepositoryProvider);
      final results = await repo.translateBatch(
        serverId,
        messageIds: uncached,
        targetLanguage: targetLanguage,
      );

      // Merge results into cache.
      final updated = Map<String, TranslationEntry>.from(state.translations);
      for (final result in results) {
        updated[result.messageId] = TranslationEntry(
          messageId: result.messageId,
          translatedContent: result.translatedContent,
          sourceLanguage: result.sourceLanguage,
          targetLanguage: result.targetLanguage,
          status: result.status == TranslationStatus.translated
              ? TranslationEntryStatus.translated
              : result.status == TranslationStatus.failed
                  ? TranslationEntryStatus.failed
                  : TranslationEntryStatus.pending,
        );
      }

      // Mark any uncached IDs not in results as failed.
      for (final id in uncached) {
        if (!results.any((r) => r.messageId == id)) {
          updated[id] = TranslationEntry(
            messageId: id,
            status: TranslationEntryStatus.failed,
          );
        }
      }

      state = state.copyWith(translations: updated);
    } on AppFailure {
      // Mark all pending as failed.
      final failed = Map<String, TranslationEntry>.from(state.translations);
      for (final id in uncached) {
        final existing = failed[id];
        if (existing != null &&
            existing.status == TranslationEntryStatus.pending) {
          failed[id] = existing.copyWith(
            status: TranslationEntryStatus.failed,
          );
        }
      }
      state = state.copyWith(translations: failed);
    }
  }

  /// Translate a single message (manual mode).
  Future<void> translateMessage(String messageId) async {
    // Remove from cache to allow re-translation.
    final cleaned = Map<String, TranslationEntry>.from(state.translations)
      ..remove(messageId);
    state = state.copyWith(translations: cleaned);

    await translateMessages([messageId]);

    // Auto-show translation after manual trigger.
    if (state.translations[messageId]?.status ==
        TranslationEntryStatus.translated) {
      state = state.copyWith(
        showTranslation: {...state.showTranslation, messageId: true},
      );
    }
  }

  /// Clears the entire translation cache.
  void clearCache() {
    state = const TranslationCacheState();
  }
}
