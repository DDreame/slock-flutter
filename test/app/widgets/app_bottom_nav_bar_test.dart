import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/app_bottom_nav_bar.dart';

void main() {
  group('AppBottomNavBar', () {
    testWidgets('renders all destination labels and line icons', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            bottomNavigationBar: AppBottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
              items: const [
                AppBottomNavItem(
                  icon: Icons.space_dashboard_outlined,
                  label: 'Workspace',
                ),
                AppBottomNavItem(
                  icon: Icons.smart_toy_outlined,
                  label: 'Agents',
                ),
                AppBottomNavItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Workspace'), findsOneWidget);
      expect(find.text('Agents'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      // All icons are line-style (outlined) regardless of active state
      expect(find.byIcon(Icons.space_dashboard_outlined), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets(
        'active item uses same line icon with primary color differentiation', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            bottomNavigationBar: AppBottomNavBar(
              currentIndex: 1,
              onTap: (_) {},
              items: const [
                AppBottomNavItem(
                  icon: Icons.space_dashboard_outlined,
                  label: 'Workspace',
                ),
                AppBottomNavItem(
                  icon: Icons.smart_toy_outlined,
                  label: 'Agents',
                ),
                AppBottomNavItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      );

      // All icons remain line-style
      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons.length, 3);

      // Active item (index 1) is colored with primary
      final activeIcon =
          tester.widgetList<Icon>(find.byIcon(Icons.smart_toy_outlined)).first;
      expect(activeIcon.color, AppColors.light.primary);

      // Inactive items use textTertiary
      final inactiveIcon = tester
          .widgetList<Icon>(find.byIcon(Icons.space_dashboard_outlined))
          .first;
      expect(inactiveIcon.color, AppColors.light.textTertiary);
    });

    testWidgets('inactive items use textTertiary color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            bottomNavigationBar: AppBottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
              items: const [
                AppBottomNavItem(
                  icon: Icons.space_dashboard_outlined,
                  label: 'Workspace',
                ),
                AppBottomNavItem(
                  icon: Icons.smart_toy_outlined,
                  label: 'Agents',
                ),
              ],
            ),
          ),
        ),
      );

      final inactiveIcon =
          tester.widget<Icon>(find.byIcon(Icons.smart_toy_outlined));
      expect(inactiveIcon.color, AppColors.light.textTertiary);
    });

    testWidgets('tapping an item calls onTap with correct index', (
      tester,
    ) async {
      int? tappedIndex;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            bottomNavigationBar: AppBottomNavBar(
              currentIndex: 0,
              onTap: (i) => tappedIndex = i,
              items: const [
                AppBottomNavItem(
                  icon: Icons.space_dashboard_outlined,
                  label: 'Workspace',
                ),
                AppBottomNavItem(
                  icon: Icons.smart_toy_outlined,
                  label: 'Agents',
                ),
                AppBottomNavItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Agents'));
      expect(tappedIndex, 1);

      await tester.tap(find.text('Settings'));
      expect(tappedIndex, 2);
    });

    testWidgets('does not use Material NavigationBar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            bottomNavigationBar: AppBottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
              items: const [
                AppBottomNavItem(
                  icon: Icons.space_dashboard_outlined,
                  label: 'Workspace',
                ),
              ],
            ),
          ),
        ),
      );

      // Should NOT contain Material NavigationBar or BottomNavigationBar
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets('uses surface background with top border', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            bottomNavigationBar: AppBottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
              items: const [
                AppBottomNavItem(
                  icon: Icons.space_dashboard_outlined,
                  label: 'Workspace',
                ),
              ],
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('app-bottom-nav-bar')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.light.surface);
      expect(decoration.border, isNotNull);
    });

    testWidgets('icon uses NavBarTokens.iconSize', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            bottomNavigationBar: AppBottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
              items: const [
                AppBottomNavItem(
                  icon: Icons.space_dashboard_outlined,
                  label: 'Workspace',
                ),
              ],
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.space_dashboard_outlined),
      );
      expect(icon.size, NavBarTokens.iconSize);
    });

    testWidgets('works with dark theme tokens', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            bottomNavigationBar: AppBottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
              items: const [
                AppBottomNavItem(
                  icon: Icons.space_dashboard_outlined,
                  label: 'Workspace',
                ),
                AppBottomNavItem(
                  icon: Icons.smart_toy_outlined,
                  label: 'Agents',
                ),
              ],
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('app-bottom-nav-bar')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.dark.surface);

      final activeIcon =
          tester.widget<Icon>(find.byIcon(Icons.space_dashboard_outlined));
      expect(activeIcon.color, AppColors.dark.primary);

      final inactiveIcon =
          tester.widget<Icon>(find.byIcon(Icons.smart_toy_outlined));
      expect(inactiveIcon.color, AppColors.dark.textTertiary);
    });
  });
}
