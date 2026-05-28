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
    // Use order-independent but collision-resistant mixing:
    // sum individual hashes (non-commutative when combined with length).
    var h = translations.length * 31;
    for (final entry in translations.entries) {
      h += Object.hash(entry.key, entry.value).hashCode;
    }
    h = h * 37 + showTranslation.length;
    for (final entry in showTranslation.entries) {
      h += Object.hash(entry.key, entry.value).hashCode;
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
  static const _maxCacheSize = 200;
  static const _cacheTrimCount = 50;

  /// Tracks message IDs with in-flight translation requests to prevent
  /// duplicate API calls from concurrent translateMessages() invocations.
  final Set<String> _inFlight = {};
  bool _disposed = false;

  @override
  bool updateShouldNotify(
    TranslationCacheState previous,
    TranslationCacheState next,
  ) =>
      previous != next;
  @override
  TranslationCacheState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _inFlight.clear();
    });
    return const TranslationCacheState();
  }

  /// Returns the cached translation for [messageId], or null.
  ///
  /// Cache hits are promoted to the back of the insertion-ordered map, making
  /// [_trimTranslations] evict least-recently-used entries instead of merely
  /// oldest-inserted entries.
  TranslationEntry? getTranslation(String messageId) {
    final entry = state.translations[messageId];
    if (entry == null) return null;
    _promoteTranslations([messageId]);
    return entry;
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
  Future<void> translateMessages(List<String> messageIds) {
    return _translateMessages(messageIds);
  }

  Future<void> _translateMessages(
    List<String> messageIds, {
    bool forceRefresh = false,
    Map<String, TranslationEntry> restoreOnFailure = const {},
  }) async {
    if (messageIds.isEmpty) return;

    final serverId = ref.read(activeServerScopeIdProvider);
    if (serverId == null) return;

    // Read preferred language from settings.
    final settingsState = ref.read(translationSettingsStoreProvider);
    final targetLanguage = settingsState.settings.preferredLanguage;

    _promoteTranslations(messageIds);

    // Filter out already-cached (translated or pending) messages
    // AND messages currently in-flight (concurrent dedup guard).
    // Manual re-translation can force a refresh while preserving the
    // existing entry to avoid a visible original-content flash.
    final uncached = messageIds
        .where((id) =>
            (forceRefresh || !state.translations.containsKey(id)) &&
            !_inFlight.contains(id))
        .toList();
    if (uncached.isEmpty) return;

    // Register as in-flight before any async work.
    _inFlight.addAll(uncached);

    // Mark uncached as pending. Preserve any existing content in-place so
    // manual re-translation never flashes back to the untranslated message.
    final pending = Map<String, TranslationEntry>.from(state.translations);
    for (final id in uncached) {
      pending[id] = pending[id]?.copyWith(
            status: TranslationEntryStatus.pending,
          ) ??
          TranslationEntry(
            messageId: id,
            status: TranslationEntryStatus.pending,
          );
    }
    state = state.copyWith(translations: _trimTranslations(pending));

    try {
      final repo = ref.read(translationRepositoryProvider);
      final results = await repo.translateBatch(
        serverId,
        messageIds: uncached,
        targetLanguage: targetLanguage,
      );
      if (_disposed) return;

      // Merge results into cache.
      final updated = Map<String, TranslationEntry>.from(state.translations);
      for (final result in results) {
        updated.remove(result.messageId);
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
      // Use Set for O(1) lookup instead of O(n) .any() per iteration.
      final returnedIds = results.map((r) => r.messageId).toSet();
      for (final id in uncached) {
        if (!returnedIds.contains(id)) {
          updated.remove(id);
          updated[id] = TranslationEntry(
            messageId: id,
            status: TranslationEntryStatus.failed,
          );
        }
      }

      state = state.copyWith(translations: _trimTranslations(updated));
    } on AppFailure {
      if (_disposed) return;
      // Mark all pending as failed.
      final failed = Map<String, TranslationEntry>.from(state.translations);
      for (final id in uncached) {
        final existing = failed[id];
        if (existing != null &&
            existing.status == TranslationEntryStatus.pending) {
          failed[id] = restoreOnFailure[id] ??
              existing.copyWith(
                status: TranslationEntryStatus.failed,
              );
        }
      }
      state = state.copyWith(translations: _trimTranslations(failed));
    } catch (_) {
      if (_disposed) return;
      // Mark all pending as failed on unexpected errors.
      final failed = Map<String, TranslationEntry>.from(state.translations);
      for (final id in uncached) {
        final existing = failed[id];
        if (existing != null &&
            existing.status == TranslationEntryStatus.pending) {
          failed[id] = restoreOnFailure[id] ??
              existing.copyWith(
                status: TranslationEntryStatus.failed,
              );
        }
      }
      state = state.copyWith(translations: _trimTranslations(failed));
    } finally {
      if (!_disposed) {
        _inFlight.removeAll(uncached);
      }
    }
  }

  /// Translate a single message (manual mode).
  Future<void> translateMessage(String messageId) async {
    final previous = state.translations[messageId];

    await _translateMessages(
      [messageId],
      forceRefresh: true,
      restoreOnFailure: {
        if (previous != null) messageId: previous,
      },
    );

    if (_disposed) return;

    // Auto-show translation after manual trigger.
    if (state.translations[messageId]?.status ==
        TranslationEntryStatus.translated) {
      state = state.copyWith(
        showTranslation: {...state.showTranslation, messageId: true},
      );
    }
  }

  void _promoteTranslations(Iterable<String> messageIds) {
    final translations = state.translations;
    if (translations.isEmpty) return;
    final copy = Map<String, TranslationEntry>.from(translations);
    var changed = false;
    for (final messageId in messageIds) {
      final entry = copy.remove(messageId);
      if (entry == null) continue;
      copy[messageId] = entry;
      changed = true;
    }
    if (changed) {
      state = state.copyWith(translations: copy);
    }
  }

  Map<String, TranslationEntry> _trimTranslations(
    Map<String, TranslationEntry> translations,
  ) {
    if (translations.length <= _maxCacheSize) return translations;

    final trimmed = Map<String, TranslationEntry>.from(translations);
    final removeCount = (trimmed.length - _maxCacheSize) > _cacheTrimCount
        ? trimmed.length - _maxCacheSize
        : _cacheTrimCount;
    for (final key in trimmed.keys.take(removeCount).toList()) {
      trimmed.remove(key);
    }
    return trimmed;
  }

  /// Clears the entire translation cache.
  void clearCache() {
    state = const TranslationCacheState();
  }
}
