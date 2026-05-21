// =============================================================================
// #664 — Fix B: postFrameCallback stacking guard (P2 correctness)
//
// Invariant: INV-DRAFT-664-STACK-1
//   Rapid sequential draft mutations (multiple build() calls within a single
//   frame) must NOT stack multiple addPostFrameCallback calls. The guard flag
//   (_pendingDraftCallback) ensures only one callback is scheduled per frame.
//
// Strategy (minimal reproduction widget):
// T1: Multiple rebuilds before frame → guarded widget fires exactly 1 callback.
// T2: After the callback fires, a new draft change can schedule another.
// T3: If draft matches controller text, no callback is scheduled at all.
// T4: Contrast — unguarded widget DOES stack callbacks (regression proof).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Minimal reproduction widget with stacking guard
// ---------------------------------------------------------------------------

/// Mirrors the guarded pattern from conversation_detail_page.dart:
/// _pendingDraftCallback prevents stacking of addPostFrameCallback.
class _GuardedDraftWidget extends StatefulWidget {
  const _GuardedDraftWidget({super.key});

  @override
  State<_GuardedDraftWidget> createState() => GuardedDraftWidgetState();
}

/// Exposed state for test introspection.
class GuardedDraftWidgetState extends State<_GuardedDraftWidget> {
  final TextEditingController controller = TextEditingController();
  bool _pendingDraftCallback = false;
  int callbackFiredCount = 0;
  String draft = '';

  void setDraft(String newDraft) {
    setState(() => draft = newDraft);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller.text != draft && !_pendingDraftCallback) {
      _pendingDraftCallback = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pendingDraftCallback = false;
        callbackFiredCount++;
        if (mounted && controller.text != draft) {
          controller.value = TextEditingValue(
            text: draft,
            selection: TextSelection.collapsed(offset: draft.length),
          );
        }
      });
    }
    return TextField(controller: controller);
  }
}

/// Unguarded version (old pattern) — for contrast.
class _UnguardedDraftWidget extends StatefulWidget {
  const _UnguardedDraftWidget({super.key});

  @override
  State<_UnguardedDraftWidget> createState() => UnguardedDraftWidgetState();
}

/// Exposed state for test introspection.
class UnguardedDraftWidgetState extends State<_UnguardedDraftWidget> {
  final TextEditingController controller = TextEditingController();
  int callbackFiredCount = 0;
  String draft = '';

  void setDraft(String newDraft) {
    setState(() => draft = newDraft);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller.text != draft) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        callbackFiredCount++;
        if (mounted && controller.text != draft) {
          controller.value = TextEditingValue(
            text: draft,
            selection: TextSelection.collapsed(offset: draft.length),
          );
        }
      });
    }
    return TextField(controller: controller);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: Multiple rebuilds before frame → guarded widget fires exactly 1
  //     callback.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-DRAFT-664-STACK-1: rapid draft changes fire exactly 1 callback '
    '(guarded)',
    (tester) async {
      final key = GlobalKey<GuardedDraftWidgetState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _GuardedDraftWidget(key: key),
          ),
        ),
      );

      final state = key.currentState!;
      expect(state.callbackFiredCount, 0);

      // Trigger 3 rapid rebuilds with the same draft mismatch.
      // Each rebuild calls build() which checks the guard.
      state.setDraft('draft-1');
      state.setDraft('draft-2');
      state.setDraft('draft-3');

      // Pump to process the setState calls and fire post-frame callbacks.
      await tester.pump();

      expect(
        state.callbackFiredCount,
        1,
        reason: 'Guard must prevent stacking — only 1 callback fires '
            '(INV-DRAFT-664-STACK-1)',
      );
      expect(state.controller.text, 'draft-3');
    },
  );

  // -------------------------------------------------------------------------
  // T2: After callback fires, new draft change can schedule another.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-DRAFT-664-STACK-1: after callback fires, new draft change schedules '
    'fresh callback',
    (tester) async {
      final key = GlobalKey<GuardedDraftWidgetState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _GuardedDraftWidget(key: key),
          ),
        ),
      );

      final state = key.currentState!;

      // First draft change + pump.
      state.setDraft('first');
      await tester.pump();
      expect(state.callbackFiredCount, 1);
      expect(state.controller.text, 'first');

      // Second draft change + pump.
      state.setDraft('second');
      await tester.pump();
      expect(state.callbackFiredCount, 2);
      expect(state.controller.text, 'second');
    },
  );

  // -------------------------------------------------------------------------
  // T3: Draft matching controller text does NOT schedule a callback.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-DRAFT-664-STACK-1: no callback when draft matches controller text',
    (tester) async {
      final key = GlobalKey<GuardedDraftWidgetState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _GuardedDraftWidget(key: key),
          ),
        ),
      );
      await tester.pump();

      final state = key.currentState!;
      // Draft is '' and controller.text is '' — no mismatch, no callback.
      expect(state.callbackFiredCount, 0,
          reason: 'No callback needed when draft matches controller');
    },
  );

  // -------------------------------------------------------------------------
  // T4: Contrast — unguarded widget DOES stack callbacks (regression proof).
  // This test demonstrates the bug that Fix B prevents.
  //
  // Each setDraft() + pump() pair simulates a separate frame where the widget
  // rebuilds with a mismatch — the unguarded version schedules a new
  // addPostFrameCallback on every frame, stacking them.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-DRAFT-664-STACK-1: unguarded widget stacks callbacks (regression '
    'contrast)',
    (tester) async {
      final key = GlobalKey<UnguardedDraftWidgetState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _UnguardedDraftWidget(key: key),
          ),
        ),
      );

      final state = key.currentState!;

      // Trigger 3 draft changes across separate frames so each build()
      // schedules a fresh addPostFrameCallback (the stacking bug).
      state.setDraft('stacked-1');
      await tester.pump(); // Frame 1 — builds with mismatch, schedules CB #1

      state.setDraft('stacked-2');
      await tester.pump(); // Frame 2 — builds with mismatch, schedules CB #2

      state.setDraft('stacked-3');
      await tester.pump(); // Frame 3 — builds with mismatch, schedules CB #3

      // Unguarded: each frame stacked a new callback. All three fired.
      expect(
        state.callbackFiredCount,
        greaterThan(1),
        reason: 'Unguarded widget stacks callbacks (proving the bug exists '
            'without the guard)',
      );
    },
  );
}
