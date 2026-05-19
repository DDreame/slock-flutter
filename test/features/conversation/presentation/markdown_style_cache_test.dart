// =============================================================================
// #633 — Markdown style/builder caching
//
// Invariant: INV-MD-STYLE-CACHE-1
//   markdown_message_body.dart L128-160:
//   Every build() call creates a new MarkdownStyleSheet (~15 TextStyle.copyWith
//   + BoxDecoration), new builders Map, and new ExtensionSet.
//   MarkdownStyleSheet lacks == → flutter_markdown re-parses on every rebuild.
//   Phase B converts to StatefulWidget with cached stylesheet/builders.
//   After fix, parent rebuilds that don't change theme or kind must NOT
//   allocate a new stylesheet.
//
// Invariant: INV-MD-STYLE-THEME-INVALIDATE-1
//   The cached stylesheet MUST be invalidated when the theme changes
//   (e.g., light → dark). Otherwise stale colors would persist.
//
// Invariant: INV-MD-BUILDERS-STABLE-1
//   The builders map reference must be stable across non-content rebuilds.
//   New Map allocation on every build prevents flutter_markdown from
//   skipping element-builder reconciliation.
//
// Strategy:
// T1: parent rebuild (no theme/kind change) must NOT create new stylesheet
//     (skip:true — currently Stateless, always creates new).
// T2: theme change DOES create new stylesheet (skip:true — currently no
//     caching to invalidate, but test exercises didChangeDependencies path).
// T3: builders map must be identical across non-content rebuilds (skip:true).
// T4: content change DOES update MarkdownBody data (active — works today).
//
// Phase A: T1-T3 skip:true, T4 active.
// Phase B: Convert to StatefulWidget, cache, un-skip T1-T3.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/app/theme/app_theme.dart';
import 'package:slock_app/features/conversation/presentation/widgets/markdown_message_body.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Wrapper that can trigger parent rebuilds via setState without
/// changing the child's key — preserving child State across rebuilds.
class _RebuildTrigger extends StatefulWidget {
  const _RebuildTrigger({required this.child});

  final Widget child;

  @override
  State<_RebuildTrigger> createState() => _RebuildTriggerState();
}

class _RebuildTriggerState extends State<_RebuildTrigger> {
  int _counter = 0;

  void rebuild() => setState(() => _counter++);

  @override
  Widget build(BuildContext context) {
    // Access _counter to satisfy the linter but don't use it to change keys.
    // This triggers a parent rebuild that propagates to the child without
    // recreating its State (no key change).
    _counter;
    return widget.child;
  }
}

/// Wrapper that can switch themes.
class _ThemeSwitcher extends StatefulWidget {
  const _ThemeSwitcher({required this.child});

  final Widget child;

  @override
  State<_ThemeSwitcher> createState() => _ThemeSwitcherState();
}

class _ThemeSwitcherState extends State<_ThemeSwitcher> {
  bool _isDark = false;

  void switchToDark() => setState(() => _isDark = true);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(body: widget.child),
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // INV-MD-STYLE-CACHE-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T1: parent rebuild (no theme change) must NOT create new stylesheet.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-MD-STYLE-CACHE-1: stylesheet is NOT recreated on non-theme rebuild',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: _RebuildTrigger(
              child: MarkdownMessageBody(
                content: 'Hello **world**',
                kind: MessageBubbleKind.other,
              ),
            ),
          ),
        ),
      );

      // Get initial stylesheet reference.
      final body1 = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      final sheet1 = body1.styleSheet;

      // Trigger parent rebuild without theme change.
      final triggerState = tester.state<_RebuildTriggerState>(
        find.byType(_RebuildTrigger),
      );
      triggerState.rebuild();
      await tester.pump();

      // After rebuild, stylesheet should be the same instance (cached).
      final body2 = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      final sheet2 = body2.styleSheet;

      expect(
        identical(sheet1, sheet2),
        true,
        reason: 'stylesheet must be cached across non-theme rebuilds '
            '(INV-MD-STYLE-CACHE-1)',
      );
    },
  );

  // =========================================================================
  // INV-MD-STYLE-THEME-INVALIDATE-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T2: theme change DOES create new stylesheet.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-MD-STYLE-THEME-INVALIDATE-1: stylesheet IS recreated on theme change',
    (tester) async {
      await tester.pumpWidget(
        const _ThemeSwitcher(
          child: MarkdownMessageBody(
            content: 'Hello **world**',
            kind: MessageBubbleKind.other,
          ),
        ),
      );

      // Get initial stylesheet reference (light theme).
      final body1 = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      final sheet1 = body1.styleSheet;

      // Switch to dark theme.
      final switcherState = tester.state<_ThemeSwitcherState>(
        find.byType(_ThemeSwitcher),
      );
      switcherState.switchToDark();
      await tester.pumpAndSettle();

      // After theme change, stylesheet must be a new instance.
      final body2 = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      final sheet2 = body2.styleSheet;

      expect(
        identical(sheet1, sheet2),
        false,
        reason: 'stylesheet must be invalidated on theme change '
            '(INV-MD-STYLE-THEME-INVALIDATE-1)',
      );
    },
  );

  // =========================================================================
  // INV-MD-BUILDERS-STABLE-1
  // =========================================================================

  // -------------------------------------------------------------------------
  // T3: builders map must be identical across non-content rebuilds.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-MD-BUILDERS-STABLE-1: builders map is stable across rebuilds',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: _RebuildTrigger(
              child: MarkdownMessageBody(
                content: 'Hello **world**',
                kind: MessageBubbleKind.other,
              ),
            ),
          ),
        ),
      );

      // Get initial builders map reference.
      final body1 = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      final builders1 = body1.builders;

      // Trigger parent rebuild without content/theme change.
      final triggerState = tester.state<_RebuildTriggerState>(
        find.byType(_RebuildTrigger),
      );
      triggerState.rebuild();
      await tester.pump();

      // After rebuild, builders map should be the same instance.
      final body2 = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      final builders2 = body2.builders;

      expect(
        identical(builders1, builders2),
        true,
        reason: 'builders map must be stable across non-content rebuilds '
            '(INV-MD-BUILDERS-STABLE-1)',
      );
    },
  );

  // =========================================================================
  // T4 (active): content change updates MarkdownBody data.
  // =========================================================================

  // -------------------------------------------------------------------------
  // T4: content change DOES update MarkdownBody.
  // -------------------------------------------------------------------------
  testWidgets(
    'MarkdownMessageBody: content change updates MarkdownBody data',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: MarkdownMessageBody(
              content: 'Hello',
              kind: MessageBubbleKind.other,
            ),
          ),
        ),
      );

      final body1 = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      expect(body1.data, 'Hello');

      // Change content.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: MarkdownMessageBody(
              content: 'Updated content',
              kind: MessageBubbleKind.other,
            ),
          ),
        ),
      );

      final body2 = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      expect(body2.data, 'Updated content');
    },
  );
}
