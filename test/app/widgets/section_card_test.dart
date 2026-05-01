import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/section_card.dart';

void main() {
  group('SectionCard', () {
    testWidgets('renders child with surface background and border', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SectionCard(child: Text('Card content')),
          ),
        ),
      );

      expect(find.text('Card content'), findsOneWidget);

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('section-card')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.light.surface);
      expect(decoration.border, isNotNull);
      // Zero shadow
      expect(decoration.boxShadow, isNull);
    });

    testWidgets('uses medium border radius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SectionCard(child: Text('Test')),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('section-card')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(12));
    });

    testWidgets('border uses theme border color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SectionCard(child: Text('Test')),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('section-card')),
      );
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, AppColors.light.border);
    });

    testWidgets('dark theme applies dark tokens', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: SectionCard(child: Text('Dark')),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('section-card')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.dark.surface);
    });
  });
}
