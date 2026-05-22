// =============================================================================
// #774 — O(n²) Voice Amplitude Accumulation → Growable List
//
// Verifies:
// A. 600 consecutive addAmplitude() calls complete in O(n) not O(n²)
// B. amplitudes list grows correctly and values are normalized
// C. reset() clears the mutable list
// D. AudioWaveformPainter.shouldRepaint() fires on amplitudeCount change
//    even when amplitudes list identity is unchanged (growable list fix)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/voice/application/voice_message_store.dart';
import 'package:slock_app/features/voice/presentation/widgets/audio_waveform_painter.dart';

void main() {
  group('#774 — O(n²) amplitude accumulation fix', () {
    late ProviderContainer container;
    late VoiceMessageStore store;

    setUp(() {
      container = ProviderContainer();
      container.listen(voiceMessageStoreProvider, (_, __) {});
      store = container.read(voiceMessageStoreProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('600 addAmplitude() calls complete under 50ms (O(n) not O(n²))', () {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 600; i++) {
        store.addAmplitude(-80.0 + (i % 80)); // dBFS range -80..0
      }
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(50),
          reason:
              '#774: 600 appends must complete in <50ms (O(n) growable list)');
      expect(store.amplitudes.length, 600);
      expect(container.read(voiceMessageStoreProvider).amplitudeCount, 600);
    });

    test('amplitudes list maintains correct normalized values', () {
      // -160 dBFS → 0.0 (silence)
      store.addAmplitude(-160);
      // 0 dBFS → 1.0 (max)
      store.addAmplitude(0);

      expect(store.amplitudes.length, 2);
      expect(store.amplitudes[0], closeTo(0.0, 0.01));
      expect(store.amplitudes[1], closeTo(1.0, 0.01));
    });

    test('state.amplitudeCount increments with each append', () {
      expect(container.read(voiceMessageStoreProvider).amplitudeCount, 0);

      store.addAmplitude(-40);
      expect(container.read(voiceMessageStoreProvider).amplitudeCount, 1);

      store.addAmplitude(-20);
      expect(container.read(voiceMessageStoreProvider).amplitudeCount, 2);
    });

    test('reset() clears amplitudes list and count', () {
      store.addAmplitude(-40);
      store.addAmplitude(-20);
      expect(store.amplitudes.length, 2);

      store.reset();

      expect(store.amplitudes, isEmpty);
      expect(container.read(voiceMessageStoreProvider).amplitudeCount, 0);
    });

    test('list is same identity across appends (no copy)', () {
      store.addAmplitude(-40);
      final listRef = store.amplitudes;

      store.addAmplitude(-20);

      // Must be same list instance (growable, not copied).
      expect(identical(store.amplitudes, listRef), isTrue,
          reason: '#774: amplitudes must grow in-place, not copy');
    });
  });

  group('#774 — AudioWaveformPainter shouldRepaint with growable list', () {
    test(
        'shouldRepaint returns true when amplitudeCount changes '
        '(same list identity)', () {
      final sharedList = <double>[0.5, 0.7];

      final oldPainter = AudioWaveformPainter(
        amplitudes: sharedList,
        amplitudeCount: 2,
        color: Colors.blue,
      );

      // Append to the SAME list (simulates in-place growth).
      sharedList.add(0.9);

      final newPainter = AudioWaveformPainter(
        amplitudes: sharedList, // Same identity!
        amplitudeCount: 3, // Different count.
        color: Colors.blue,
      );

      expect(newPainter.shouldRepaint(oldPainter), isTrue,
          reason: '#774: shouldRepaint must fire on amplitudeCount change '
              'even when list identity is the same');
    });

    test(
        'shouldRepaint returns false when amplitudeCount is unchanged '
        '(same list, same count)', () {
      final sharedList = <double>[0.5, 0.7];

      final oldPainter = AudioWaveformPainter(
        amplitudes: sharedList,
        amplitudeCount: 2,
        color: Colors.blue,
      );

      final newPainter = AudioWaveformPainter(
        amplitudes: sharedList,
        amplitudeCount: 2,
        color: Colors.blue,
      );

      expect(newPainter.shouldRepaint(oldPainter), isFalse,
          reason: 'No change → no repaint');
    });

    test(
        'shouldRepaint returns true on progress change '
        '(existing behavior preserved)', () {
      final list = <double>[0.5];

      final oldPainter = AudioWaveformPainter(
        amplitudes: list,
        amplitudeCount: 1,
        color: Colors.blue,
        progress: 0.5,
      );

      final newPainter = AudioWaveformPainter(
        amplitudes: list,
        amplitudeCount: 1,
        color: Colors.blue,
        progress: 0.8,
      );

      expect(newPainter.shouldRepaint(oldPainter), isTrue,
          reason: 'Progress change must still trigger repaint');
    });
  });
}
