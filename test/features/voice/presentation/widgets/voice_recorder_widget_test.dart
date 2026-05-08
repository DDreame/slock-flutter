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
      VoidCallback? onSend,
      VoidCallback? onCancel,
    }) {
      return ProviderScope(
        overrides: [
          if (initialState != null)
            voiceMessageStoreProvider.overrideWith(
              () => _TestVoiceMessageStore(initialState),
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
          amplitudes: [0.3, 0.7, 0.5],
          elapsed: Duration(seconds: 1),
        ),
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
  });
}

class _TestVoiceMessageStore extends VoiceMessageStore {
  _TestVoiceMessageStore(this._initial);

  final VoiceMessageState _initial;

  @override
  VoiceMessageState build() => _initial;
}
