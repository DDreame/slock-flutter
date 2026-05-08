import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/voice/presentation/widgets/audio_waveform_painter.dart';

void main() {
  group('AudioWaveformPainter', () {
    test('shouldRepaint returns true when amplitudes change', () {
      const painter1 = AudioWaveformPainter(
        amplitudes: [0.5, 0.8],
        color: Color(0xFFFF0000),
      );
      const painter2 = AudioWaveformPainter(
        amplitudes: [0.5, 0.8, 0.3],
        color: Color(0xFFFF0000),
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns false when amplitudes are identical', () {
      const amplitudes = [0.5, 0.8, 0.3];
      const painter1 = AudioWaveformPainter(
        amplitudes: amplitudes,
        color: Color(0xFFFF0000),
      );
      const painter2 = AudioWaveformPainter(
        amplitudes: amplitudes,
        color: Color(0xFFFF0000),
      );

      expect(painter1.shouldRepaint(painter2), isFalse);
    });

    test('shouldRepaint returns true when progress changes', () {
      const painter1 = AudioWaveformPainter(
        amplitudes: [0.5],
        color: Color(0xFFFF0000),
        progress: 0.3,
      );
      const painter2 = AudioWaveformPainter(
        amplitudes: [0.5],
        color: Color(0xFFFF0000),
        progress: 0.7,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns true when color changes', () {
      const painter1 = AudioWaveformPainter(
        amplitudes: [0.5],
        color: Color(0xFFFF0000),
      );
      const painter2 = AudioWaveformPainter(
        amplitudes: [0.5],
        color: Color(0xFF0000FF),
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    testWidgets('paints without error with empty amplitudes', (tester) async {
      await tester.pumpWidget(
        const CustomPaint(
          painter: AudioWaveformPainter(
            amplitudes: [],
            color: Color(0xFFFF0000),
          ),
          size: Size(200, 40),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('paints without error with amplitude data', (tester) async {
      await tester.pumpWidget(
        const CustomPaint(
          painter: AudioWaveformPainter(
            amplitudes: [0.1, 0.5, 0.8, 0.3, 0.9, 0.4, 0.6],
            color: Color(0xFFFF0000),
            progress: 0.5,
          ),
          size: Size(200, 40),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('paints with active and inactive colors', (tester) async {
      await tester.pumpWidget(
        const CustomPaint(
          painter: AudioWaveformPainter(
            amplitudes: [0.5, 0.8, 0.3],
            color: Color(0xFFFF0000),
            inactiveColor: Color(0xFFCCCCCC),
            progress: 0.5,
          ),
          size: Size(200, 40),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
