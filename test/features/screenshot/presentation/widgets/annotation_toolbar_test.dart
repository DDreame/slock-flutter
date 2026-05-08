import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/features/screenshot/data/annotation.dart';
import 'package:slock_app/features/screenshot/presentation/widgets/annotation_toolbar.dart';

void main() {
  group('AnnotationToolbar', () {
    late AnnotationTool lastToolSelected;
    late Color lastColorSelected;
    var undoCalls = 0;
    var redoCalls = 0;

    Widget buildToolbar({
      AnnotationTool selectedTool = AnnotationTool.freehand,
      Color selectedColor = const Color(0xFFFF0000),
      bool canUndo = true,
      bool canRedo = true,
    }) {
      lastToolSelected = selectedTool;
      lastColorSelected = selectedColor;
      undoCalls = 0;
      redoCalls = 0;

      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: AnnotationToolbar(
              selectedTool: selectedTool,
              selectedColor: selectedColor,
              canUndo: canUndo,
              canRedo: canRedo,
              onToolSelected: (tool) => lastToolSelected = tool,
              onColorSelected: (color) => lastColorSelected = color,
              onUndo: () => undoCalls++,
              onRedo: () => redoCalls++,
            ),
          ),
        ),
      );
    }

    testWidgets('renders all three tool buttons', (tester) async {
      await tester.pumpWidget(buildToolbar());

      expect(find.byIcon(Icons.brush), findsOneWidget);
      expect(find.byIcon(Icons.text_fields), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('tapping text tool calls onToolSelected', (tester) async {
      await tester.pumpWidget(buildToolbar());

      await tester.tap(find.byIcon(Icons.text_fields));
      expect(lastToolSelected, AnnotationTool.text);
    });

    testWidgets('tapping arrow tool calls onToolSelected', (tester) async {
      await tester.pumpWidget(buildToolbar());

      await tester.tap(find.byIcon(Icons.arrow_forward));
      expect(lastToolSelected, AnnotationTool.arrow);
    });

    testWidgets('undo button calls onUndo when canUndo is true',
        (tester) async {
      await tester.pumpWidget(buildToolbar(canUndo: true));

      await tester.tap(find.byIcon(Icons.undo));
      expect(undoCalls, 1);
    });

    testWidgets('redo button calls onRedo when canRedo is true',
        (tester) async {
      await tester.pumpWidget(buildToolbar(canRedo: true));

      await tester.tap(find.byIcon(Icons.redo));
      expect(redoCalls, 1);
    });

    testWidgets('undo button is disabled when canUndo is false',
        (tester) async {
      await tester.pumpWidget(buildToolbar(canUndo: false));

      final iconButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.undo),
      );
      expect(iconButton.onPressed, isNull);
    });

    testWidgets('redo button is disabled when canRedo is false',
        (tester) async {
      await tester.pumpWidget(buildToolbar(canRedo: false));

      final iconButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.redo),
      );
      expect(iconButton.onPressed, isNull);
    });

    testWidgets('renders exactly 6 color dots', (tester) async {
      await tester.pumpWidget(buildToolbar());

      // Each color dot is a GestureDetector wrapping a Container.
      // The toolbar has 6 colors: red, green, blue, yellow, white, black.
      // Find all GestureDetector widgets that wrap a Container with a circle
      // decoration. There may be other GestureDetectors so we count decorated
      // containers instead.
      final colorDots = find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        if (decoration is! BoxDecoration) return false;
        return decoration.shape == BoxShape.circle;
      });
      expect(colorDots, findsNWidgets(6));
    });

    testWidgets('tapping a color dot calls onColorSelected with that color',
        (tester) async {
      await tester.pumpWidget(
        buildToolbar(selectedColor: const Color(0xFFFF0000)),
      );

      // Find the green color dot (0xFF00FF00) by its decoration color.
      final greenDot = find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        if (decoration is! BoxDecoration) return false;
        return decoration.color == const Color(0xFF00FF00);
      });
      expect(greenDot, findsOneWidget);

      await tester.tap(greenDot);
      expect(lastColorSelected, const Color(0xFF00FF00));
    });

    testWidgets('tapping blue color dot selects blue', (tester) async {
      await tester.pumpWidget(
        buildToolbar(selectedColor: const Color(0xFFFF0000)),
      );

      final blueDot = find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        if (decoration is! BoxDecoration) return false;
        return decoration.color == const Color(0xFF0000FF);
      });
      expect(blueDot, findsOneWidget);

      await tester.tap(blueDot);
      expect(lastColorSelected, const Color(0xFF0000FF));
    });

    testWidgets('selected color dot has thicker border', (tester) async {
      const selectedColor = Color(0xFFFF0000);
      await tester.pumpWidget(buildToolbar(selectedColor: selectedColor));

      final selectedDot = tester.widget<Container>(
        find.byWidgetPredicate((widget) {
          if (widget is! Container) return false;
          final decoration = widget.decoration;
          if (decoration is! BoxDecoration) return false;
          return decoration.color == selectedColor;
        }),
      );

      final decoration = selectedDot.decoration! as BoxDecoration;
      // Selected dot has border width 2.5, unselected has 1.0.
      expect(decoration.border, isA<Border>());
      final border = decoration.border! as Border;
      expect(border.top.width, 2.5);
    });
  });
}
