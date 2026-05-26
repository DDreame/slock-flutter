// Phase A: Accessibility tests for #821 — Annotation Toolbar Color Dot Semantics
// + Voice Message Scrubber Accessibility.
//
// Item 1 (HIGH): Color dots in annotation_toolbar.dart have zero screen reader
//   coverage. Each dot needs Semantics(label, selected, button).
// Item 2 (MED): Voice scrubber in voice_message_bubble.dart has no Semantics.
//   Needs slider semantics with position value.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/screenshot/data/annotation.dart';
import 'package:slock_app/features/screenshot/presentation/widgets/annotation_toolbar.dart';
import 'package:slock_app/features/voice/presentation/widgets/voice_message_bubble.dart';
import 'package:slock_app/l10n/l10n.dart';

void main() {
  // ===========================================================================
  // Item 1: Annotation toolbar color dot semantics
  // ===========================================================================

  group('Item 1 — Annotation color dot semantics', () {
    Widget buildToolbar({
      Color selectedColor = const Color(0xFFFF0000),
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: AnnotationToolbar(
              selectedTool: AnnotationTool.freehand,
              selectedColor: selectedColor,
              canUndo: false,
              canRedo: false,
              onToolSelected: (_) {},
              onColorSelected: (_) {},
              onUndo: () {},
              onRedo: () {},
            ),
          ),
        ),
      );
    }

    testWidgets('each color dot has a semantic label', (tester) async {
      await tester.pumpWidget(buildToolbar());

      // All 6 colors should have semantics labels.
      expect(find.bySemanticsLabel('Red'), findsOneWidget);
      expect(find.bySemanticsLabel('Green'), findsOneWidget);
      expect(find.bySemanticsLabel('Blue'), findsOneWidget);
      expect(find.bySemanticsLabel('Yellow'), findsOneWidget);
      expect(find.bySemanticsLabel('White'), findsOneWidget);
      expect(find.bySemanticsLabel('Black'), findsOneWidget);
    });

    testWidgets('red dot has semantic label "Red"', (tester) async {
      await tester.pumpWidget(buildToolbar());

      expect(find.bySemanticsLabel('Red'), findsOneWidget);
    });

    testWidgets('green dot has semantic label "Green"', (tester) async {
      await tester.pumpWidget(buildToolbar());

      expect(find.bySemanticsLabel('Green'), findsOneWidget);
    });

    testWidgets('blue dot has semantic label "Blue"', (tester) async {
      await tester.pumpWidget(buildToolbar());

      expect(find.bySemanticsLabel('Blue'), findsOneWidget);
    });

    testWidgets('yellow dot has semantic label "Yellow"', (tester) async {
      await tester.pumpWidget(buildToolbar());

      expect(find.bySemanticsLabel('Yellow'), findsOneWidget);
    });

    testWidgets('white dot has semantic label "White"', (tester) async {
      await tester.pumpWidget(buildToolbar());

      expect(find.bySemanticsLabel('White'), findsOneWidget);
    });

    testWidgets('black dot has semantic label "Black"', (tester) async {
      await tester.pumpWidget(buildToolbar());

      expect(find.bySemanticsLabel('Black'), findsOneWidget);
    });

    testWidgets('selected color dot is marked selected in semantics',
        (tester) async {
      final semanticsHandle = tester.ensureSemantics();

      await tester.pumpWidget(buildToolbar(
        selectedColor: const Color(0xFF0000FF), // Blue
      ));

      final blueDot = find.bySemanticsLabel('Blue');
      expect(blueDot, findsOneWidget);

      final semanticsNode = tester.getSemantics(blueDot);
      expect(
        semanticsNode.flagsCollection.isSelected == Tristate.isTrue,
        isTrue,
        reason: 'Selected color dot must have isSelected flag',
      );

      semanticsHandle.dispose();
    });

    testWidgets('non-selected color dot is NOT marked selected',
        (tester) async {
      final semanticsHandle = tester.ensureSemantics();

      await tester.pumpWidget(buildToolbar(
        selectedColor: const Color(0xFFFF0000), // Red selected
      ));

      // Blue is NOT selected.
      final blueDot = find.bySemanticsLabel('Blue');
      expect(blueDot, findsOneWidget);

      final semanticsNode = tester.getSemantics(blueDot);
      expect(
        semanticsNode.flagsCollection.isSelected == Tristate.isTrue,
        isFalse,
        reason: 'Non-selected color dot must not have isSelected flag',
      );

      semanticsHandle.dispose();
    });
  });

  // ===========================================================================
  // Item 2: Voice message scrubber accessibility
  // ===========================================================================

  group('Item 2 — Voice scrubber semantics', () {
    Widget buildBubble({
      Duration duration = const Duration(seconds: 30),
      Duration position = Duration.zero,
      bool isPlaying = false,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VoiceMessageBubble(
            duration: duration,
            position: position,
            isPlaying: isPlaying,
            waveform: const [0.3, 0.7, 0.5, 0.8, 0.2, 0.9, 0.4],
            onPlayPause: () {},
            onSeek: (_) {},
          ),
        ),
      );
    }

    testWidgets('scrubber has slider semantics', (tester) async {
      final semanticsHandle = tester.ensureSemantics();

      await tester.pumpWidget(buildBubble());

      // The scrubber area should expose slider semantics so accessibility
      // services can seek within the voice message.
      final scrubberSemantics = find.bySemanticsLabel(
        RegExp('.*scrubber.*|.*Scrubber.*|.*seek.*|.*Seek.*',
            caseSensitive: false),
      );
      expect(scrubberSemantics, findsOneWidget,
          reason: 'Voice scrubber must have semantic label for screen readers');

      semanticsHandle.dispose();
    });

    testWidgets('scrubber reports progress percentage at 0%', (tester) async {
      final semanticsHandle = tester.ensureSemantics();

      await tester.pumpWidget(buildBubble(
        duration: const Duration(seconds: 30),
        position: Duration.zero,
      ));

      // At 0% progress, the semantics value should indicate 0%.
      final scrubber = find.bySemanticsLabel(
        RegExp('.*scrubber.*|.*Scrubber.*|.*seek.*|.*Seek.*',
            caseSensitive: false),
      );
      final semantics = tester.getSemantics(scrubber);
      expect(semantics.value, contains('0'),
          reason: 'Scrubber at start should show 0% progress');

      semanticsHandle.dispose();
    });

    testWidgets('scrubber reports progress percentage at 50%', (tester) async {
      final semanticsHandle = tester.ensureSemantics();

      await tester.pumpWidget(buildBubble(
        duration: const Duration(seconds: 30),
        position: const Duration(seconds: 15),
      ));

      final scrubber = find.bySemanticsLabel(
        RegExp('.*scrubber.*|.*Scrubber.*|.*seek.*|.*Seek.*',
            caseSensitive: false),
      );
      final semantics = tester.getSemantics(scrubber);
      expect(semantics.value, contains('50'),
          reason: 'Scrubber at midpoint should show 50% progress');

      semanticsHandle.dispose();
    });
  });
}
