import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/message_bubble.dart';

void main() {
  group('MessageBubble', () {
    testWidgets('self variant is right-aligned with primary fill', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: MessageBubble(
                variant: MessageBubbleVariant.self,
                child: Text('Hello'),
              ),
            ),
          ),
        ),
      );

      final align = tester.widget<Align>(
        find.byKey(const ValueKey('message-bubble-shell')),
      );
      expect(align.alignment, Alignment.centerRight);

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('message-bubble-container')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.light.primary);
    });

    testWidgets('self variant uses primaryForeground text color', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: MessageBubble(
                variant: MessageBubbleVariant.self,
                child: Text('Hello'),
              ),
            ),
          ),
        ),
      );

      final defaultTextStyleFinder = find.descendant(
        of: find.byKey(const ValueKey('message-bubble-container')),
        matching: find.byType(DefaultTextStyle),
      );
      final defaultTextStyle =
          tester.widget<DefaultTextStyle>(defaultTextStyleFinder.first);
      expect(
        defaultTextStyle.style.color,
        AppColors.light.primaryForeground,
      );
    });

    testWidgets('other variant is left-aligned with surfaceAlt fill', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: MessageBubble(
                variant: MessageBubbleVariant.other,
                senderName: 'Alice',
                child: Text('Hi there'),
              ),
            ),
          ),
        ),
      );

      final align = tester.widget<Align>(
        find.byKey(const ValueKey('message-bubble-shell')),
      );
      expect(align.alignment, Alignment.centerLeft);

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('message-bubble-container')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.light.surfaceAlt);

      // Sender name label shown
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('agent variant is left-aligned with agentLight fill', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: MessageBubble(
                variant: MessageBubbleVariant.agent,
                senderName: 'Bot',
                child: Text('Agent reply'),
              ),
            ),
          ),
        ),
      );

      final align = tester.widget<Align>(
        find.byKey(const ValueKey('message-bubble-shell')),
      );
      expect(align.alignment, Alignment.centerLeft);

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('message-bubble-container')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.light.agentLight);

      // AI label shown next to sender name
      expect(find.text('AI'), findsOneWidget);
      expect(find.text('Bot'), findsOneWidget);
    });

    testWidgets('system variant is centered, italic, no bubble decoration', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: MessageBubble(
                variant: MessageBubbleVariant.system,
                child: Text('User joined the channel'),
              ),
            ),
          ),
        ),
      );

      final align = tester.widget<Align>(
        find.byKey(const ValueKey('message-bubble-shell')),
      );
      expect(align.alignment, Alignment.center);

      // System messages have no container decoration (no fill)
      final container = tester.widget<Container>(
        find.byKey(const ValueKey('message-bubble-container')),
      );
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.color, isNull);

      // Text is italic
      final defaultTextStyleFinder = find.descendant(
        of: find.byKey(const ValueKey('message-bubble-container')),
        matching: find.byType(DefaultTextStyle),
      );
      final defaultTextStyle =
          tester.widget<DefaultTextStyle>(defaultTextStyleFinder.first);
      expect(defaultTextStyle.style.fontStyle, FontStyle.italic);
    });

    testWidgets('self bubble has asymmetric corners (6px on sender side)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: MessageBubble(
                variant: MessageBubbleVariant.self,
                child: Text('Test'),
              ),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('message-bubble-container')),
      );
      final decoration = container.decoration as BoxDecoration;
      final radius = decoration.borderRadius as BorderRadius;

      // Self = right-aligned, so top-right corner should be small (6px)
      expect(radius.topLeft, const Radius.circular(BubbleTokens.radiusLarge));
      expect(radius.topRight, const Radius.circular(BubbleTokens.radiusSmall));
      expect(
          radius.bottomLeft, const Radius.circular(BubbleTokens.radiusLarge));
      expect(
          radius.bottomRight, const Radius.circular(BubbleTokens.radiusLarge));
    });

    testWidgets('other bubble has asymmetric corners (6px on sender side)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: MessageBubble(
                variant: MessageBubbleVariant.other,
                senderName: 'Bob',
                child: Text('Test'),
              ),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('message-bubble-container')),
      );
      final decoration = container.decoration as BoxDecoration;
      final radius = decoration.borderRadius as BorderRadius;

      // Other = left-aligned, so top-left corner should be small (6px)
      expect(radius.topLeft, const Radius.circular(BubbleTokens.radiusSmall));
      expect(radius.topRight, const Radius.circular(BubbleTokens.radiusLarge));
      expect(
          radius.bottomLeft, const Radius.circular(BubbleTokens.radiusLarge));
      expect(
          radius.bottomRight, const Radius.circular(BubbleTokens.radiusLarge));
    });

    testWidgets('dark theme applies correct colors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: Center(
              child: MessageBubble(
                variant: MessageBubbleVariant.agent,
                senderName: 'Bot',
                child: Text('Dark mode'),
              ),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('message-bubble-container')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.dark.agentLight);
    });

    testWidgets('bubble constrains max width', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: MessageBubble(
                variant: MessageBubbleVariant.self,
                child: Text('Short'),
              ),
            ),
          ),
        ),
      );

      final constrainedBox = tester.widget<ConstrainedBox>(
        find.descendant(
          of: find.byKey(const ValueKey('message-bubble-shell')),
          matching: find.byType(ConstrainedBox),
        ),
      );
      // Max width should be capped (not take full width)
      expect(
        constrainedBox.constraints.maxWidth,
        BubbleTokens.maxWidth,
      );
    });
  });
}
