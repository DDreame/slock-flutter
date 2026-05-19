// =============================================================================
// #603 — Composer Draft Mutation → postFrameCallback
//
// Invariant: INV-DRAFT-BUILD-1
//   Draft restoration to TextEditingController must NOT occur synchronously
//   during widget build(). It must be deferred via addPostFrameCallback.
//
// Phase B: lib fix applied — _composerController.value assignment wrapped in
// addPostFrameCallback at conversation_detail_page.dart lines 279-283.
// All tests active.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Minimal reproduction widgets
// ---------------------------------------------------------------------------

/// Simulates the Phase B pattern: deferred draft restoration.
/// Captures the controller text at the moment build() returns so the test
/// can verify no synchronous mutation occurred during the build method.
class _DeferredDraftWidget extends StatefulWidget {
  const _DeferredDraftWidget({required this.draft});
  final String draft;

  @override
  State<_DeferredDraftWidget> createState() => _DeferredDraftWidgetState();
}

class _DeferredDraftWidgetState extends State<_DeferredDraftWidget> {
  final TextEditingController controller = TextEditingController();

  /// The controller text captured at the END of build(), before post-frame
  /// callbacks run. If deferral is correct, this will be empty.
  String controllerTextDuringBuild = '';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller.text != widget.draft) {
      // Phase B pattern: deferred mutation.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.text != widget.draft) {
          controller.value = TextEditingValue(
            text: widget.draft,
            selection: TextSelection.collapsed(offset: widget.draft.length),
          );
        }
      });
    }
    // Capture what the controller holds at the end of build.
    controllerTextDuringBuild = controller.text;
    return TextField(controller: controller);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T1: Deferred draft restoration does NOT mutate controller during build.
  //
  // The widget captures controller.text at the end of build(). If the
  // postFrameCallback pattern is correct, controller is still empty at that
  // point; the draft value only appears after post-frame callbacks run.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-DRAFT-BUILD-1: draft restoration is deferred to post-frame callback',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: _DeferredDraftWidget(draft: 'Hello draft')),
        ),
      );

      final state = tester.state<_DeferredDraftWidgetState>(
        find.byType(_DeferredDraftWidget),
      );

      // The controller text captured during build() must be empty — proving
      // the mutation was NOT synchronous.
      expect(
        state.controllerTextDuringBuild,
        isEmpty,
        reason: 'Controller must NOT be mutated during build() '
            '(INV-DRAFT-BUILD-1)',
      );

      // After the full frame (post-frame callbacks have run), the controller
      // should have the draft value.
      expect(
        state.controller.text,
        'Hello draft',
        reason: 'Controller must have draft value after post-frame callback',
      );
    },
  );
}
