import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/voice/application/voice_message_store.dart';
import 'package:slock_app/features/voice/data/voice_recorder_service.dart';
import 'package:slock_app/features/voice/presentation/widgets/audio_waveform_painter.dart';
import 'package:slock_app/features/voice/presentation/widgets/voice_recorder_widget.dart';

void main() {
  group('VoiceRecorderWidget', () {
    Widget buildWidget({
      VoiceMessageState? initialState,
      List<double>? initialAmplitudes,
      VoidCallback? onSend,
      VoidCallback? onCancel,
    }) {
      return ProviderScope(
        overrides: [
          if (initialState != null)
            voiceMessageStoreProvider.overrideWith(
              () => _TestVoiceMessageStore(initialState,
                  initialAmplitudes: initialAmplitudes),
            ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: VoiceRecorderWidget(
              onSend: onSend ?? () {},
              onCancel: onCancel ?? () {},
            ),
          ),
        ),
      );
    }

    testWidgets('renders timer showing 00:00 in idle state', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('0:00'), findsOneWidget);
    });

    testWidgets('renders cancel button', (tester) async {
      await tester.pumpWidget(buildWidget(
        initialState: const VoiceMessageState(
          recordingState: VoiceRecorderState.recording,
          elapsed: Duration(seconds: 5),
        ),
      ));

      expect(
        find.byKey(const ValueKey('voice-cancel')),
        findsOneWidget,
      );
    });

    testWidgets('renders send button when recording', (tester) async {
      await tester.pumpWidget(buildWidget(
        initialState: const VoiceMessageState(
          recordingState: VoiceRecorderState.recording,
          elapsed: Duration(seconds: 5),
        ),
      ));

      expect(
        find.byKey(const ValueKey('voice-send')),
        findsOneWidget,
      );
    });

    testWidgets('displays elapsed time formatted as m:ss', (tester) async {
      await tester.pumpWidget(buildWidget(
        initialState: const VoiceMessageState(
          recordingState: VoiceRecorderState.recording,
          elapsed: Duration(minutes: 2, seconds: 35),
        ),
      ));

      expect(find.text('2:35'), findsOneWidget);
    });

    testWidgets('renders waveform painter during recording', (tester) async {
      await tester.pumpWidget(buildWidget(
        initialState: const VoiceMessageState(
          recordingState: VoiceRecorderState.recording,
          amplitudeCount: 3,
          elapsed: Duration(seconds: 1),
        ),
        initialAmplitudes: [0.3, 0.7, 0.5],
      ));

      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is AudioWaveformPainter,
        ),
        findsOneWidget,
      );
    });

    testWidgets('cancel button calls onCancel', (tester) async {
      var cancelled = false;
      await tester.pumpWidget(buildWidget(
        initialState: const VoiceMessageState(
          recordingState: VoiceRecorderState.recording,
        ),
        onCancel: () => cancelled = true,
      ));

      await tester.tap(find.byKey(const ValueKey('voice-cancel')));
      expect(cancelled, isTrue);
    });

    testWidgets('send button calls onSend', (tester) async {
      var sent = false;
      await tester.pumpWidget(buildWidget(
        initialState: const VoiceMessageState(
          recordingState: VoiceRecorderState.recording,
        ),
        onSend: () => sent = true,
      ));

      await tester.tap(find.byKey(const ValueKey('voice-send')));
      expect(sent, isTrue);
    });

    testWidgets('shows recording indicator dot when recording', (tester) async {
      await tester.pumpWidget(buildWidget(
        initialState: const VoiceMessageState(
          recordingState: VoiceRecorderState.recording,
          elapsed: Duration(seconds: 3),
        ),
      ));

      expect(
        find.byKey(const ValueKey('recording-indicator')),
        findsOneWidget,
      );
    });

    // -----------------------------------------------------------------------
    // #774: Widget-path shouldRepaint regression.
    // Verifies that appending one amplitude through the real notifier causes
    // the widget to build a new AudioWaveformPainter that reports
    // shouldRepaint(oldPainter) == true. Fails if:
    // - The painter stops checking amplitudeCount (painter regression)
    // - The widget stops passing amplitudeCount (pass-through regression)
    // -----------------------------------------------------------------------
    testWidgets(
      '#774: one amplitude append triggers shouldRepaint on widget rebuild',
      (tester) async {
        // Use the REAL VoiceMessageStore (no override) so addAmplitude()
        // mutates the growable list and updates amplitudeCount in state.
        final widget = ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VoiceRecorderWidget(
                onSend: () {},
                onCancel: () {},
              ),
            ),
          ),
        );

        await tester.pumpWidget(widget);

        // Capture the current painter before appending.
        final paintBefore = _findWaveformPainter(tester);
        expect(paintBefore, isNotNull,
            reason: 'Painter must exist in initial build');

        // Append one amplitude through the real notifier.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(VoiceRecorderWidget)),
        );
        final store = container.read(voiceMessageStoreProvider.notifier);
        store.addAmplitude(-40.0); // Will normalize and append

        // Pump to trigger rebuild with new amplitudeCount.
        await tester.pump();

        // Capture the new painter after rebuild.
        final paintAfter = _findWaveformPainter(tester);
        expect(paintAfter, isNotNull, reason: 'Painter must exist after pump');

        // Assert shouldRepaint fires (amplitudeCount 0→1, same list identity).
        expect(paintAfter!.shouldRepaint(paintBefore!), isTrue,
            reason: '#774: widget must pass updated amplitudeCount so '
                'shouldRepaint detects append on same-identity list');
      },
    );
  });
}

/// Extracts the [AudioWaveformPainter] from the current render tree.
AudioWaveformPainter? _findWaveformPainter(WidgetTester tester) {
  final customPaint = tester.widgetList<CustomPaint>(
    find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is AudioWaveformPainter,
    ),
  );
  if (customPaint.isEmpty) return null;
  return customPaint.first.painter as AudioWaveformPainter;
}

class _TestVoiceMessageStore extends VoiceMessageStore {
  _TestVoiceMessageStore(this._initial, {this.initialAmplitudes});

  final VoiceMessageState _initial;
  final List<double>? initialAmplitudes;

  @override
  VoiceMessageState build() {
    if (initialAmplitudes != null) {
      seedAmplitudes(initialAmplitudes!);
    }
    return _initial;
  }
}
