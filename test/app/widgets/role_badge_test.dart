import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/role_badge.dart';

void main() {
  group('RoleBadge', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: RoleBadge(label: 'Admin', color: Colors.blue),
            ),
          ),
        ),
      );

      expect(find.text('Admin'), findsOneWidget);
    });

    testWidgets('uses provided color for background tint', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: RoleBadge(label: 'AI', color: Color(0xFF8B5CF6)),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('role-badge')),
      );
      final decoration = container.decoration as BoxDecoration;
      // Background should be a tinted version of the color
      expect(decoration.color, isNotNull);
    });

    testWidgets('has pill shape', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: RoleBadge(label: 'Mod', color: Colors.green),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('role-badge')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(999));
    });

    testWidgets('text uses the provided color', (tester) async {
      const badgeColor = Color(0xFF22C55E);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: Center(
              child: RoleBadge(label: 'Online', color: badgeColor),
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Online'));
      expect(text.style?.color, badgeColor);
    });

    testWidgets('renders correctly in dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: Center(
              child: RoleBadge(label: 'Admin', color: Colors.blue),
            ),
          ),
        ),
      );

      expect(find.text('Admin'), findsOneWidget);
      expect(find.byKey(const ValueKey('role-badge')), findsOneWidget);
    });
  });
}
