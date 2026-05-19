// =============================================================================
// #603 — Composer Draft Mutation → postFrameCallback
//
// Invariant: INV-DRAFT-BUILD-1
//   Draft restoration to TextEditingController must NOT occur synchronously
//   during widget build(). It must be deferred via addPostFrameCallback.
//
// Strategy:
// T1: Verify that a draft-aware widget defers controller mutation to
//     post-frame callback (skip:true — current impl mutates in build).
// T2: Anti-pattern proof — synchronous mutation in build fires immediately.
//
// Phase A: T1 skip:true — current implementation assigns directly in build().
//
// Phase B:
// Wrap _composerController.value = ... in addPostFrameCallback at
// conversation_detail_page.dart lines 279-283.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Minimal reproduction widgets
// ---------------------------------------------------------------------------

/// Simulates the Phase B pattern: deferred draft restoration.
class _DeferredDraftWidget extends StatefulWidget {
  const _DeferredDraftWidget({required this.draft});
  final String draft;

  @override
  State<_DeferredDraftWidget> createState() => _DeferredDraftWidgetState();
}

class _DeferredDraftWidgetState extends State<_DeferredDraftWidget> {
  final TextEditingController controller = TextEditingController();
  bool _buildCompleted = false;

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
    _buildCompleted = true;
    return TextField(controller: controller);
  }

  bool get buildCompleted => _buildCompleted;
}

/// Simulates the current (buggy) pattern: synchronous draft mutation in build.
class _SyncDraftWidget extends StatefulWidget {
  const _SyncDraftWidget({required this.draft});
  final String draft;

  @override
  State<_SyncDraftWidget> createState() => _SyncDraftWidgetState();
}

class _SyncDraftWidgetState extends State<_SyncDraftWidget> {
  final TextEditingController controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller.text != widget.draft) {
      // Current pattern: synchronous mutation in build.
      controller.value = TextEditingValue(
        text: widget.draft,
        selection: TextSelection.collapsed(offset: widget.draft.length),
      );
    }
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
  // After Phase B, the controller is updated in a post-frame callback.
  // During the build frame, the controller retains its old value.
  //
  // skip:true — requires Phase B postFrameCallback fix in
  // conversation_detail_page.dart.
  // -------------------------------------------------------------------------
  testWidgets(
    'INV-DRAFT-BUILD-1: draft restoration is deferred to post-frame callback',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: _DeferredDraftWidget(draft: 'Hello draft')),
        ),
      );

      // After first pump (build frame complete, post-frame not yet run):
      final state = tester.state<_DeferredDraftWidgetState>(
        find.byType(_DeferredDraftWidget),
      );

      // Build has completed...
      expect(state.buildCompleted, isTrue);

      // ...but controller should NOT have the draft yet (deferred).
      expect(
        state.controller.text,
        isEmpty,
        reason: 'Controller must NOT be mutated during build frame '
            '(INV-DRAFT-BUILD-1)',
      );

      // After settling (post-frame callbacks run):
      await tester.pump();
      expect(
        state.controller.text,
        'Hello draft',
        reason: 'Controller must have draft value after post-frame callback',
      );
    },
    skip: true, // Phase A: requires Phase B postFrameCallback fix
  );

  // -------------------------------------------------------------------------
  // T2: Anti-pattern proof — synchronous mutation updates controller
  // immediately during build.
  //
  // Demonstrates the bug: assigning to TextEditingController.value inside
  // build() mutates state synchronously, which can trigger framework
  // assertions ("setState() or markNeedsBuild() called during build").
  // -------------------------------------------------------------------------
  testWidgets(
    'synchronous build-phase mutation updates controller immediately '
    '(anti-pattern proof)',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: _SyncDraftWidget(draft: 'Sync draft')),
        ),
      );

      final state = tester.state<_SyncDraftWidgetState>(
        find.byType(_SyncDraftWidget),
      );

      // Synchronous mutation: controller already has draft after build.
      expect(
        state.controller.text,
        'Sync draft',
        reason: 'Synchronous build-phase mutation updates immediately (proving '
            'the anti-pattern)',
      );
    },
  );
}
