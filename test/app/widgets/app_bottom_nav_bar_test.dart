import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_colors.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/app/widgets/app_bottom_nav_bar.dart';

void main() {
  group('AppBottomNavBar', () {
    testWidgets('renders all destination labels and icons', (tester) async {
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
                  activeIcon: Icons.space_dashboard,
                  label: 'Workspace',
                ),
                AppBottomNavItem(
                  icon: Icons.smart_toy_outlined,
                  activeIcon: Icons.smart_toy,
                  label: 'Agents',
                ),
                AppBottomNavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
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
      expect(find.byIcon(Icons.space_dashboard), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('active item uses activeIcon and primary color', (
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
                  activeIcon: Icons.space_dashboard,
                  label: 'Workspace',
                ),
                AppBottomNavItem(
                  icon: Icons.smart_toy_outlined,
                  activeIcon: Icons.smart_toy,
                  label: 'Agents',
                ),
                AppBottomNavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      );

      // Active item shows filled icon
      expect(find.byIcon(Icons.smart_toy), findsOneWidget);
      // Inactive items show outlined icons
      expect(find.byIcon(Icons.space_dashboard_outlined), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

      // Active icon is colored with primary
      final activeIcon = tester.widget<Icon>(find.byIcon(Icons.smart_toy));
      expect(activeIcon.color, AppColors.light.primary);
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
                  activeIcon: Icons.space_dashboard,
                  label: 'Workspace',
                ),
                AppBottomNavItem(
                  icon: Icons.smart_toy_outlined,
                  activeIcon: Icons.smart_toy,
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
                  activeIcon: Icons.space_dashboard,
                  label: 'Workspace',
                ),
                AppBottomNavItem(
                  icon: Icons.smart_toy_outlined,
                  activeIcon: Icons.smart_toy,
                  label: 'Agents',
                ),
                AppBottomNavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
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
                  activeIcon: Icons.space_dashboard,
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
                  activeIcon: Icons.space_dashboard,
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
                  activeIcon: Icons.space_dashboard,
                  label: 'Workspace',
                ),
                AppBottomNavItem(
                  icon: Icons.smart_toy_outlined,
                  activeIcon: Icons.smart_toy,
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
          tester.widget<Icon>(find.byIcon(Icons.space_dashboard));
      expect(activeIcon.color, AppColors.dark.primary);

      final inactiveIcon =
          tester.widget<Icon>(find.byIcon(Icons.smart_toy_outlined));
      expect(inactiveIcon.color, AppColors.dark.textTertiary);
    });
  });
}
