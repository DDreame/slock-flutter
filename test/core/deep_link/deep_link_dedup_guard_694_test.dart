// ignore_for_file: prefer_const_constructors

// =============================================================================
// #694 — Cold-start deep link dedup guard
//
// Tests the DeepLinkDedupGuard logic that prevents duplicate route pushes when
// Android OEMs re-emit the cold-start launch intent on uriLinkStream.
//
// Scenarios covered:
// 1. Cold-start URI set, stream re-emits same URI → skip (dedup).
// 2. Cold-start URI set, stream emits different URI → dispatch.
// 3. No cold-start URI, stream event → dispatch normally.
// 4. After first dedup, subsequent stream events always dispatch.
// 5. Integration: concurrent initial + stream with same URI → dispatched once.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:slock_app/core/deep_link/deep_link_lifecycle_binding.dart';

void main() {
  group('#694 — DeepLinkDedupGuard', () {
    late DeepLinkDedupGuard guard;

    setUp(() {
      guard = DeepLinkDedupGuard();
    });

    test('skips first stream event that matches cold-start URI', () {
      final uri = Uri.parse('https://app.slock.ai/invite/abc123');
      guard.setInitialUri(uri);

      // First stream event matches initial → should be skipped.
      expect(guard.shouldDispatch(uri), isFalse);
    });

    test('dispatches first stream event that differs from cold-start URI', () {
      final initial = Uri.parse('https://app.slock.ai/invite/abc123');
      final stream = Uri.parse('https://app.slock.ai/channels/ch1');
      guard.setInitialUri(initial);

      // Different URI → should dispatch.
      expect(guard.shouldDispatch(stream), isTrue);
    });

    test('dispatches when no cold-start URI exists', () {
      guard.setInitialUri(null);

      final uri = Uri.parse('https://app.slock.ai/invite/abc123');
      expect(guard.shouldDispatch(uri), isTrue);
    });

    test('all subsequent stream events dispatch after first dedup', () {
      final initial = Uri.parse('https://app.slock.ai/invite/abc123');
      guard.setInitialUri(initial);

      // First → deduped.
      guard.shouldDispatch(initial);

      // Subsequent events always dispatch, even if same URI.
      expect(guard.shouldDispatch(initial), isTrue);
      expect(
        guard.shouldDispatch(Uri.parse('https://app.slock.ai/other')),
        isTrue,
      );
    });

    test(
      'dispatches stream event if setInitialUri not yet called (race: stream fires before getInitialLink resolves)',
      () {
        // Stream fires before getInitialLink resolves — guard has no initial
        // URI yet, so _consumed is false and _initialUri is null → dispatch.
        final uri = Uri.parse('https://app.slock.ai/invite/abc123');
        expect(guard.shouldDispatch(uri), isTrue);
      },
    );

    test(
      'integration: simulates concurrent cold-start + stream duplicate → dispatched exactly once',
      () {
        final uri = Uri.parse('slock://servers/s1/channels/c1');
        final dispatched = <Uri>[];

        // Simulate the full flow:
        // 1. getInitialLink resolves → handler dispatches + dedup records.
        guard.setInitialUri(uri);
        dispatched.add(uri); // This represents handler.handleDeepLink(uri)

        // 2. uriLinkStream fires same URI → dedup blocks.
        if (guard.shouldDispatch(uri)) {
          dispatched.add(uri);
        }

        // Exactly one dispatch.
        expect(dispatched, hasLength(1));
        expect(dispatched.first, uri);
      },
    );

    test(
      'integration: cold-start null + stream event → dispatches normally',
      () {
        final uri = Uri.parse('https://app.slock.ai/invite/token');
        final dispatched = <Uri>[];

        // No cold-start link.
        guard.setInitialUri(null);

        // Stream fires → should dispatch.
        if (guard.shouldDispatch(uri)) {
          dispatched.add(uri);
        }

        expect(dispatched, hasLength(1));
      },
    );
  });
}
