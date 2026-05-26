import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/voice/presentation/widgets/audio_waveform_painter.dart';
import 'package:slock_app/features/voice/presentation/widgets/voice_message_bubble.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  group('VoiceMessageBubble', () {
    Widget buildBubble({
      Duration duration = const Duration(seconds: 30),
      Duration position = Duration.zero,
      bool isPlaying = false,
      List<double> waveform = const [0.3, 0.7, 0.5, 0.8, 0.2, 0.9, 0.4],
      VoidCallback? onPlayPause,
      ValueChanged<double>? onSeek,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VoiceMessageBubble(
            duration: duration,
            position: position,
            isPlaying: isPlaying,
            waveform: waveform,
            onPlayPause: onPlayPause ?? () {},
            onSeek: onSeek ?? (_) {},
          ),
        ),
      );
    }

    testWidgets('renders play button when not playing', (tester) async {
      await tester.pumpWidget(buildBubble());

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);
    });

    testWidgets('renders pause button when playing', (tester) async {
      await tester.pumpWidget(buildBubble(isPlaying: true));

      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('shows duration formatted as m:ss', (tester) async {
      await tester.pumpWidget(buildBubble(
        duration: const Duration(minutes: 1, seconds: 23),
      ));

      expect(find.text('1:23'), findsOneWidget);
    });

    testWidgets('shows position when playing', (tester) async {
      await tester.pumpWidget(buildBubble(
        duration: const Duration(minutes: 1, seconds: 23),
        position: const Duration(seconds: 45),
        isPlaying: true,
      ));

      expect(find.text('0:45'), findsOneWidget);
    });

    testWidgets('renders waveform painter', (tester) async {
      await tester.pumpWidget(buildBubble());

      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is AudioWaveformPainter,
        ),
        findsOneWidget,
      );
    });

    testWidgets('play/pause button calls onPlayPause', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildBubble(
        onPlayPause: () => tapped = true,
      ));

      await tester.tap(find.byKey(const ValueKey('voice-play-pause')));
      expect(tapped, isTrue);
    });

    testWidgets('renders with empty waveform', (tester) async {
      await tester.pumpWidget(buildBubble(waveform: const []));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with zero duration', (tester) async {
      await tester.pumpWidget(buildBubble(duration: Duration.zero));
      expect(find.text('0:00'), findsOneWidget);
    });

    testWidgets('seek fraction is computed from waveform area, not full bubble',
        (tester) async {
      double? seekFraction;
      await tester.pumpWidget(buildBubble(
        duration: const Duration(seconds: 60),
        onSeek: (f) => seekFraction = f,
      ));

      // Find the CustomPaint (waveform area) and tap its center.
      final waveformFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is AudioWaveformPainter,
      );
      expect(waveformFinder, findsOneWidget);

      // Tap the center of the waveform area.
      await tester.tap(waveformFinder);
      await tester.pump();

      // Seek fraction should be close to 0.5 (center of waveform area).
      expect(seekFraction, isNotNull);
      expect(seekFraction!, closeTo(0.5, 0.15));
    });

    testWidgets('seek at left edge of waveform returns fraction near 0.0',
        (tester) async {
      double? seekFraction;
      await tester.pumpWidget(buildBubble(
        duration: const Duration(seconds: 60),
        onSeek: (f) => seekFraction = f,
      ));

      final waveformFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is AudioWaveformPainter,
      );
      final waveformBox = tester.getRect(waveformFinder);

      // Tap near the left edge of the waveform.
      await tester.tapAt(Offset(waveformBox.left + 2, waveformBox.center.dy));
      await tester.pump();

      expect(seekFraction, isNotNull);
      expect(seekFraction!, lessThan(0.1));
    });
  });
}
