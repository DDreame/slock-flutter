import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/unread_badge.dart';

void main() {
  group('UnreadBadge', () {
    testWidgets('renders count text with primary fill', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(child: UnreadBadge(count: 5)),
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget);

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('unread-badge')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.light.primary);
    });

    testWidgets('clamps display at 99+', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(child: UnreadBadge(count: 150)),
          ),
        ),
      );

      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('hides when count is 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(child: UnreadBadge(count: 0)),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('unread-badge')), findsNothing);
    });

    testWidgets('uses pill shape (full border radius)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(child: UnreadBadge(count: 3)),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('unread-badge')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(999));
    });

    testWidgets('text uses primaryForeground color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(child: UnreadBadge(count: 7)),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('7'));
      expect(text.style?.color, AppColors.light.primaryForeground);
    });

    testWidgets('dark theme uses dark primary fill', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: Center(child: UnreadBadge(count: 2)),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('unread-badge')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.dark.primary);
    });
  });
}
