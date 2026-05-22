// =============================================================================
// #619 — Conversation sub-widget .select() narrows (3 sites)
//
// Invariant: INV-SELECTION-BAR-SELECT-1
//   _SelectionActionBar.build() at L4687 calls
//   ref.watch(conversationDetailStoreProvider) — only uses
//   selectedMessageIds.length. Mutations to other fields (draft, messages,
//   uploadProgress) MUST NOT trigger a rebuild.
//
// Invariant: INV-TRANSLATION-CACHE-SELECT-1
//   _buildMessageContent() at L3003 calls
//   ref.watch(translationCacheStoreProvider) — only reads
//   translations[message.id]. Adding/removing translations for OTHER
//   messages MUST NOT rebuild this message's widget.
//
// Invariant: INV-VOICE-STATE-SELECT-1
//   _ConversationDetailPageState.build() at L269 calls
//   ref.watch(voiceMessageStoreProvider) — only uses .recordingState.
//   Duration ticks and waveform updates MUST NOT trigger a rebuild.
//
// Strategy:
// T1: draft change must NOT fire selectedMessageIds.length select (skip:true).
// T2: translation for other message must NOT fire this-message select (skip:true).
// T3: elapsed duration change must NOT fire recordingState select (skip:true).
// T4: selectedMessageIds.length change DOES fire select (active).
// T5: translation for THIS message DOES fire select (active).
// T6: recordingState change DOES fire select (active).
//
// Phase A: T1/T2/T3 skip:true — current impl watches full state.
//          T4/T5/T6 active — correctness proof.
//
// Phase B:
// - L4687: .select((s) => s.selectedMessageIds.length)
// - L3003: .select((s) => s.translations[message.id])
// - L269: .select((s) => s.recordingState)
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/core.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_state.dart';
import 'package:slock_app/features/conversation/application/conversation_detail_store.dart';
import 'package:slock_app/features/conversation/data/conversation_repository.dart';
import 'package:slock_app/features/translation/application/translation_cache_store.dart';
import 'package:slock_app/features/voice/application/voice_message_store.dart';
import 'package:slock_app/features/voice/data/voice_recorder_service.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ControllableDetailStore extends ConversationDetailStore {
  @override
  ConversationDetailState build() => ConversationDetailState(
        target: ConversationDetailTarget.channel(
          const ChannelScopeId(serverId: ServerScopeId('srv'), value: 'ch1'),
        ),
        status: ConversationDetailStatus.success,
      );

  void setDraftDirect(String draft) {
    state = state.copyWith(draft: draft);
  }

  void setSelectedMessageIdsDirect(Set<String> ids) {
    state = state.copyWith(selectedMessageIds: ids);
  }
}

class _ControllableTranslationStore extends TranslationCacheStore {
  @override
  TranslationCacheState build() => const TranslationCacheState();

  void addTranslationDirect(String messageId, TranslationEntry entry) {
    state = TranslationCacheState(
      translations: {...state.translations, messageId: entry},
    );
  }
}

class _ControllableVoiceStore extends VoiceMessageStore {
  @override
  VoiceMessageState build() => const VoiceMessageState();

  void setElapsedDirect(Duration elapsed) {
    state = VoiceMessageState(
      recordingState: state.recordingState,
      elapsed: elapsed,
      amplitudeCount: state.amplitudeCount,
      recordedFilePath: state.recordedFilePath,
    );
  }

  void setRecordingStateDirect(VoiceRecorderState recordingState) {
    state = VoiceMessageState(
      recordingState: recordingState,
      elapsed: state.elapsed,
      amplitudeCount: state.amplitudeCount,
      recordedFilePath: state.recordedFilePath,
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // SelectionActionBar — INV-SELECTION-BAR-SELECT-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T1: draft change must NOT fire selectedMessageIds.length select.
  // -------------------------------------------------------------------------
  test(
    'INV-SELECTION-BAR-SELECT-1: draft change does NOT notify '
    'selectedMessageIds.length select',
    () async {
      final container = ProviderContainer(
        overrides: [
          conversationDetailStoreProvider
              .overrideWith(() => _ControllableDetailStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(conversationDetailStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        conversationDetailStoreProvider
            .select((s) => s.selectedMessageIds.length),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(conversationDetailStoreProvider.notifier)
          as _ControllableDetailStore;
      store.setDraftDirect('typing...');

      expect(
        selectNotifyCount,
        0,
        reason: 'draft change must not notify selectedMessageIds.length select '
            '(INV-SELECTION-BAR-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T4: selectedMessageIds.length change DOES fire select.
  // -------------------------------------------------------------------------
  test(
    'INV-SELECTION-BAR-SELECT-1: selectedMessageIds.length change DOES notify '
    'select',
    () async {
      final container = ProviderContainer(
        overrides: [
          conversationDetailStoreProvider
              .overrideWith(() => _ControllableDetailStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(conversationDetailStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        conversationDetailStoreProvider
            .select((s) => s.selectedMessageIds.length),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(conversationDetailStoreProvider.notifier)
          as _ControllableDetailStore;
      store.setSelectedMessageIdsDirect({'msg-1', 'msg-2'});

      expect(
        selectNotifyCount,
        1,
        reason: 'selectedMessageIds.length change must notify select',
      );

      keepAlive.close();
    },
  );

  // =========================================================================
  // Translation cache — INV-TRANSLATION-CACHE-SELECT-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T2: translation for OTHER message must NOT fire this-message select.
  // -------------------------------------------------------------------------
  test(
    'INV-TRANSLATION-CACHE-SELECT-1: other message translation does NOT '
    'notify this-message select',
    () async {
      const thisMessageId = 'msg-abc';
      const otherMessageId = 'msg-xyz';

      final container = ProviderContainer(
        overrides: [
          translationCacheStoreProvider
              .overrideWith(() => _ControllableTranslationStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(translationCacheStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        translationCacheStoreProvider
            .select((s) => s.translations[thisMessageId]),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(translationCacheStoreProvider.notifier)
          as _ControllableTranslationStore;
      store.addTranslationDirect(
        otherMessageId,
        const TranslationEntry(
          messageId: otherMessageId,
          translatedContent: 'Hola',
          sourceLanguage: 'en',
          targetLanguage: 'es',
        ),
      );

      expect(
        selectNotifyCount,
        0,
        reason: 'translation for other message must not notify '
            'this-message select (INV-TRANSLATION-CACHE-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T5: translation for THIS message DOES fire select.
  // -------------------------------------------------------------------------
  test(
    'INV-TRANSLATION-CACHE-SELECT-1: this-message translation DOES notify '
    'select',
    () async {
      const thisMessageId = 'msg-abc';

      final container = ProviderContainer(
        overrides: [
          translationCacheStoreProvider
              .overrideWith(() => _ControllableTranslationStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive =
          container.listen(translationCacheStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        translationCacheStoreProvider
            .select((s) => s.translations[thisMessageId]),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(translationCacheStoreProvider.notifier)
          as _ControllableTranslationStore;
      store.addTranslationDirect(
        thisMessageId,
        const TranslationEntry(
          messageId: thisMessageId,
          translatedContent: 'Hello',
          sourceLanguage: 'es',
          targetLanguage: 'en',
        ),
      );

      expect(
        selectNotifyCount,
        1,
        reason: 'this-message translation must notify select',
      );

      keepAlive.close();
    },
  );

  // =========================================================================
  // Voice message store — INV-VOICE-STATE-SELECT-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T3: elapsed duration change must NOT fire recordingState select.
  // -------------------------------------------------------------------------
  test(
    'INV-VOICE-STATE-SELECT-1: elapsed change does NOT notify '
    'recordingState select',
    () async {
      final container = ProviderContainer(
        overrides: [
          voiceMessageStoreProvider
              .overrideWith(() => _ControllableVoiceStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(voiceMessageStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        voiceMessageStoreProvider.select((s) => s.recordingState),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(voiceMessageStoreProvider.notifier)
          as _ControllableVoiceStore;
      store.setElapsedDirect(const Duration(seconds: 5));

      expect(
        selectNotifyCount,
        0,
        reason: 'elapsed change must not notify recordingState select '
            '(INV-VOICE-STATE-SELECT-1)',
      );

      keepAlive.close();
    },
  );

  // -------------------------------------------------------------------------
  // T6: recordingState change DOES fire select.
  // -------------------------------------------------------------------------
  test(
    'INV-VOICE-STATE-SELECT-1: recordingState change DOES notify select',
    () async {
      final container = ProviderContainer(
        overrides: [
          voiceMessageStoreProvider
              .overrideWith(() => _ControllableVoiceStore()),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(voiceMessageStoreProvider, (_, __) {});

      int selectNotifyCount = 0;
      container.listen(
        voiceMessageStoreProvider.select((s) => s.recordingState),
        (_, __) => selectNotifyCount++,
      );

      final store = container.read(voiceMessageStoreProvider.notifier)
          as _ControllableVoiceStore;
      store.setRecordingStateDirect(VoiceRecorderState.recording);

      expect(
        selectNotifyCount,
        1,
        reason: 'recordingState change must notify select',
      );

      keepAlive.close();
    },
  );
}
