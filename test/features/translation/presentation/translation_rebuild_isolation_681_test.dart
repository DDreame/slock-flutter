// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

// =============================================================================
// #681 — Translation rebuild isolation test
//
// Validates that updating message 1's translation does NOT rebuild message 2's
// TranslatedContentOverlay. This proves the .select() narrow subscription in
// translated_content_overlay.dart line 40 is effective.
//
// Uses @visibleForTesting debugBuildCount on the production widget (same
// pattern as #671's MessageContentWidget rebuild isolation tests).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/translation/application/translation_cache_store.dart';
import 'package:slock_app/features/translation/presentation/widgets/translated_content_overlay.dart';
import 'package:slock_app/features/voice/application/voice_message_store.dart';
import 'package:slock_app/features/voice/data/voice_recorder_service.dart';

void main() {
  group('#681 — TranslatedContentOverlay rebuild isolation', () {
    setUp(() {
      TranslatedContentOverlay.debugBuildCount = 0;
    });

    testWidgets(
      'updating message 1 showTranslation does NOT rebuild message 2 overlay',
      (tester) async {
        // Set up two messages with translations in the cache.
        const entry1 = TranslationEntry(
          messageId: 'msg-1',
          translatedContent: 'Hola mundo',
          sourceLanguage: 'en',
          targetLanguage: 'es',
          status: TranslationEntryStatus.translated,
        );
        const entry2 = TranslationEntry(
          messageId: 'msg-2',
          translatedContent: 'Bonjour monde',
          sourceLanguage: 'en',
          targetLanguage: 'fr',
          status: TranslationEntryStatus.translated,
        );

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: Column(
                  children: [
                    TranslatedContentOverlay(
                      key: ValueKey('overlay-msg-1'),
                      messageId: 'msg-1',
                      originalChild: Text('Hello world'),
                      translatedContent: entry1.translatedContent,
                      entry: entry1,
                    ),
                    TranslatedContentOverlay(
                      key: ValueKey('overlay-msg-2'),
                      messageId: 'msg-2',
                      originalChild: Text('Good morning world'),
                      translatedContent: entry2.translatedContent,
                      entry: entry2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Both overlays rendered once during initial build.
        // debugBuildCount captures ALL overlay builds (both widgets).
        expect(TranslatedContentOverlay.debugBuildCount, 2,
            reason: 'Both overlays must build exactly once on initial render');

        // Record build count after initial render.
        final countAfterInitial = TranslatedContentOverlay.debugBuildCount;

        // Toggle showTranslation for msg-1 ONLY.
        container
            .read(translationCacheStoreProvider.notifier)
            .toggleTranslation('msg-1');
        await tester.pump();

        // With .select(), only message 1's overlay should rebuild.
        // Message 2's overlay should NOT rebuild since its
        // showTranslation[msg-2] is unchanged.
        expect(
          TranslatedContentOverlay.debugBuildCount,
          countAfterInitial + 1,
          reason: 'Only msg-1 overlay should rebuild when msg-1 translation '
              'is toggled — msg-2 overlay must NOT rebuild '
              '(proves .select() isolation)',
        );

        // msg-1 should now show translation.
        expect(find.text('Hola mundo'), findsOneWidget);
        // msg-2 still shows original.
        expect(find.text('Good morning world'), findsOneWidget);
      },
    );

    testWidgets(
      'adding a new translation for msg-3 does NOT rebuild existing overlays',
      (tester) async {
        const entry1 = TranslationEntry(
          messageId: 'msg-1',
          translatedContent: 'Hola mundo',
          sourceLanguage: 'en',
          targetLanguage: 'es',
          status: TranslationEntryStatus.translated,
        );

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: TranslatedContentOverlay(
                  key: ValueKey('overlay-msg-1'),
                  messageId: 'msg-1',
                  originalChild: Text('Hello world'),
                  translatedContent: entry1.translatedContent,
                  entry: entry1,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(TranslatedContentOverlay.debugBuildCount, 1);
        final countAfterInitial = TranslatedContentOverlay.debugBuildCount;

        // Toggle a DIFFERENT message (msg-3) that has no overlay widget.
        // This modifies the showTranslation map but not for 'msg-1'.
        container
            .read(translationCacheStoreProvider.notifier)
            .toggleTranslation('msg-3');
        await tester.pump();

        // msg-1 overlay must NOT rebuild because showTranslation['msg-1']
        // is unchanged.
        expect(
          TranslatedContentOverlay.debugBuildCount,
          countAfterInitial,
          reason: 'Toggling an unrelated message must NOT rebuild existing '
              'overlays (proves per-message .select() isolation)',
        );
      },
    );
  });

  group('#681 — voiceMessageStoreProvider autoDispose', () {
    test('provider auto-disposes when all listeners are removed', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Add a listener (simulates VoiceRecorderWidget watching the state).
      final sub = container.listen(
        voiceMessageStoreProvider,
        (_, __) {},
      );

      // Modify state while listener is active.
      container
          .read(voiceMessageStoreProvider.notifier)
          .setRecordingState(VoiceRecorderState.recording);
      expect(
        container.read(voiceMessageStoreProvider).recordingState,
        VoiceRecorderState.recording,
      );

      // Remove the listener (simulates page disposal).
      sub.close();

      // Allow Riverpod's autoDispose scheduling to complete.
      // The provider needs multiple microtask boundaries to finalize disposal.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // Re-read the provider — autoDispose should have reset it.
      // A new instance is created with the default idle state.
      final stateAfter = container.read(voiceMessageStoreProvider);
      expect(stateAfter.recordingState, VoiceRecorderState.idle);
      expect(stateAfter.amplitudeCount, 0);
      expect(stateAfter.elapsed, Duration.zero);
    });
  });

  group('#681 — voiceWaveformCacheProvider autoDispose', () {
    test('waveform cache auto-disposes when all listeners are removed',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Add a listener (simulates conversation page watching the cache).
      final sub = container.listen(
        voiceWaveformCacheProvider,
        (_, __) {},
      );

      // Populate the cache while listener is active.
      container
          .read(voiceWaveformCacheProvider.notifier)
          .put('voice_123.m4a', [0.3, 0.7, 0.5]);
      container
          .read(voiceWaveformCacheProvider.notifier)
          .put('voice_456.m4a', [0.1, 0.9]);
      expect(container.read(voiceWaveformCacheProvider), hasLength(2));

      // Remove the listener (simulates page disposal).
      sub.close();

      // Allow Riverpod's autoDispose scheduling to complete.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // Re-read the provider — autoDispose should have reset it.
      // A new instance is created with empty cache.
      final cacheAfter = container.read(voiceWaveformCacheProvider);
      expect(cacheAfter, isEmpty,
          reason: 'Waveform cache must be empty after autoDispose reset');
    });
  });
}
